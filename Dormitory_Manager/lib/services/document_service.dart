import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../models/document.dart';
import '../api/dio_client.dart';

/// 서류 API 서비스
/// ✅ 수정: XFile + Uint8List 지원으로 웹/앱 호환성 확보
class DocumentService {
  /// 서류 제출
  /// ✅ 수정: XFile + imageBytes 지원 (웹/앱 호환)
  static Future<Document> submitDocument({
    required String title,
    required String content,
    required String category,
    required String writerId,
    XFile? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      print('[DocumentService] 서류 제출 시작 - 제목: $title');

      final formData = FormData.fromMap({
        'title': title,
        'content': content,
        'category': category,
        'writerId': writerId,
        'status': '대기',
        'submittedAt': DateTime.now().toIso8601String(),
      });

      // ✅ 파일 추가 (XFile 또는 Uint8List)
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            bytes,
            filename: imageFile.name,
          ),
        ));
        print('[DocumentService] 파일 첨부 (XFile): ${imageFile.name}');
      } else if (imageBytes != null) {
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            imageBytes,
            filename: fileName ?? 'document_file.jpg',
          ),
        ));
        print('[DocumentService] 파일 첨부 (bytes): ${fileName ?? 'document_file.jpg'}');
      }

      final response = await DioClient.post('/documents', data: formData);
      final responseData = response.data;

      // ✅ ApiResponse 구조 처리: 'data' 또는 'document' 필드에서 서류 데이터 추출
      if (responseData['success'] == true) {
        // 'data' 필드 먼저 확인, 없으면 'document' 필드 확인
        final documentData = responseData['data'] ?? responseData['document'];
        if (documentData != null) {
          print('[DocumentService] 서류 제출 성공 - ID: ${documentData['id']}');
          return Document.fromJson(documentData);
        } else {
          throw Exception('응답에 서류 데이터가 없습니다.');
        }
      } else {
        throw Exception(responseData['message'] ?? '서류 제출에 실패했습니다.');
      }
    } catch (e) {
      print('[DocumentService] 서류 제출 실패: $e');
      throw Exception('서류 제출 실패: $e');
    }
  }

  // 사용자별 서류 목록 조회
  static Future<List<Document>> getUserDocuments(String writerId) async {
    try {
      print('[DocumentService] 사용자 서류 목록 조회 - writerId: $writerId');

      final response = await DioClient.get('/documents/user/$writerId');
      final responseData = response.data;

      if (responseData['success'] == true) {
        // ✅ API 응답 구조 다양하게 처리
        List<dynamic> documentsData = [];

        // 1. 최상위 'documents' 필드 확인 (현재 API 구조)
        if (responseData.containsKey('documents') && responseData['documents'] is List) {
          documentsData = responseData['documents'];
        }
        // 2. 'data.documents' 구조 확인
        else if (responseData['data'] is Map && responseData['data'].containsKey('documents')) {
          documentsData = responseData['data']['documents'] ?? [];
        }
        // 3. 'data'가 직접 리스트인 경우
        else if (responseData['data'] is List) {
          documentsData = responseData['data'];
        }

        print('[DocumentService] 사용자 서류 ${documentsData.length}건 조회됨');
        return documentsData.map((item) => Document.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('[DocumentService] 사용자 서류 목록 조회 실패: $e');
      throw Exception('서류 목록 조회 실패: $e');
    }
  }

  // 모든 서류 목록 조회 (관리자용)
  static Future<List<Document>> getAllDocuments() async {
    try {
      print('[DocumentService] 전체 서류 목록 조회');

      final response = await DioClient.get('/documents');
      final responseData = response.data;

      if (responseData['success'] == true) {
        // ✅ API 응답 구조 다양하게 처리
        List<dynamic> documentsData = [];

        // 1. 최상위 'documents' 필드 확인 (현재 API 구조)
        if (responseData.containsKey('documents') && responseData['documents'] is List) {
          documentsData = responseData['documents'];
        }
        // 2. 'data.documents' 구조 확인
        else if (responseData['data'] is Map && responseData['data'].containsKey('documents')) {
          documentsData = responseData['data']['documents'] ?? [];
        }
        // 3. 'data'가 직접 리스트인 경우
        else if (responseData['data'] is List) {
          documentsData = responseData['data'];
        }

        print('[DocumentService] 서류 ${documentsData.length}건 조회됨');
        return documentsData.map((item) => Document.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('[DocumentService] 전체 서류 목록 조회 실패: $e');
      throw Exception('서류 목록 조회 실패: $e');
    }
  }

  // 특정 서류 조회
  static Future<Document> getDocumentById(int documentId) async {
    try {
      print('[DocumentService] 서류 상세 조회 - ID: $documentId');

      final response = await DioClient.get('/documents/$documentId');
      final responseData = response.data;

      if (responseData['success'] == true && responseData['data'] != null) {
        return Document.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? '서류를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('[DocumentService] 서류 상세 조회 실패: $e');
      throw Exception('서류 조회 실패: $e');
    }
  }

  // 서류 상태 업데이트 (관리자용)
  static Future<Document> updateDocumentStatus({
    required int documentId,
    required String status,
    String? adminComment,
  }) async {
    try {
      print('[DocumentService] 서류 상태 업데이트 - ID: $documentId, 상태: $status');

      final response = await DioClient.patch(
        '/documents/$documentId/status',
        data: {
          'status': status,
          if (adminComment != null) 'adminComment': adminComment,
        },
      );

      final responseData = response.data;

      if (responseData['success'] == true && responseData['data'] != null) {
        return Document.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? '상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      print('[DocumentService] 서류 상태 업데이트 실패: $e');
      throw Exception('상태 업데이트 실패: $e');
    }
  }

  // 서류 삭제 (관리자용)
  static Future<void> deleteDocument(int documentId) async {
    try {
      print('[DocumentService] 서류 삭제 - ID: $documentId');

      final response = await DioClient.delete('/documents/$documentId');
      final responseData = response.data;

      if (responseData['success'] != true) {
        throw Exception(responseData['message'] ?? '서류 삭제에 실패했습니다.');
      }
    } catch (e) {
      print('[DocumentService] 서류 삭제 실패: $e');
      throw Exception('서류 삭제 실패: $e');
    }
  }

  // 서류 카테고리 목록
  static List<String> getDocumentCategories() {
    return [
      '외박 신청',
      '외출 신청',
      '퇴사 신청',
      '호실 변경 신청',
      '시설 이용 신청',
      '기타 서류',
    ];
  }

  // ✅ 상태 목록 (관리자용)
  static List<String> getStatusList() {
    return [
      '대기',
      '검토중',
      '승인',
      '반려',
    ];
  }

  // 서류 통계 조회 (관리자용)
  static Future<Map<String, dynamic>> getDocumentStatistics() async {
    try {
      print('[DocumentService] 서류 통계 조회');

      final response = await DioClient.get('/documents/statistics');
      final responseData = response.data;

      if (responseData['success'] == true && responseData['data'] != null) {
        return Map<String, dynamic>.from(responseData['data']);
      }
      return {};
    } catch (e) {
      print('[DocumentService] 서류 통계 조회 실패: $e');
      throw Exception('서류 통계 조회 실패: $e');
    }
  }
}