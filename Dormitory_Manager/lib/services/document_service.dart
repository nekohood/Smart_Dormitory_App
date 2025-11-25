import 'dart:io';
import 'package:dio/dio.dart';
import '../models/document.dart';
import '../api/dio_client.dart';
import '../utils/storage_helper.dart';

/// 토큰 상태 확인 및 디버깅 클래스
class DocumentSubmissionDebug {

  /// 토큰 상태 확인 및 디버깅
  static Future<void> debugTokenStatus() async {
    try {
      print('[DEBUG] === 토큰 상태 확인 시작 ===');

      // 1. 저장된 토큰 확인
      final token = await StorageHelper.getToken();
      if (token == null) {
        print('[ERROR] 저장된 토큰이 없습니다');
        return;
      }

      print('[DEBUG] 토큰 존재 확인: ${token.substring(0, 20)}...');

      // 2. 토큰 만료 여부 확인
      final isExpired = await StorageHelper.isTokenExpired(token);
      print('[DEBUG] 토큰 만료 여부: $isExpired');

      // 3. 서버에 토큰 검증 요청
      try {
        final response = await DioClient.post('/auth/validate');
        print('[DEBUG] 서버 토큰 검증 결과: ${response.data}');
      } catch (e) {
        print('[ERROR] 서버 토큰 검증 실패: $e');
      }

    } catch (e) {
      print('[ERROR] 토큰 상태 확인 실패: $e');
    }
  }

  /// 서류 제출 전 사전 검증
  static Future<bool> preValidateSubmission() async {
    try {
      print('[DEBUG] === 서류 제출 사전 검증 시작 ===');

      // 1. 토큰 상태 확인
      await debugTokenStatus();

      // 2. 현재 사용자 정보 확인
      final token = await StorageHelper.getToken();
      if (token == null) {
        print('[ERROR] 인증 토큰이 없습니다');
        return false;
      }

      // 3. 간단한 인증 테스트 (사용자 정보 조회)
      try {
        final response = await DioClient.post('/auth/validate');
        if (response.data['valid'] == true) {
          print('[DEBUG] 인증 상태 정상');
          return true;
        } else {
          print('[ERROR] 인증 상태 비정상: ${response.data}');
          return false;
        }
      } catch (e) {
        print('[ERROR] 인증 확인 실패: $e');
        return false;
      }

    } catch (e) {
      print('[ERROR] 사전 검증 실패: $e');
      return false;
    }
  }
}

/// 서류 관련 API 서비스
class DocumentService {

  /// 서류 제출 (디버깅 포함)
  static Future<Document> submitDocument({
    required String title,
    required String content,
    required String category,
    required String writerId,
    File? imageFile,
  }) async {
    try {
      print('[DEBUG] === 서류 제출 시작 ===');
      print('[DEBUG] 제목: $title, 카테고리: $category, 작성자ID: $writerId');

      // 사전 검증 수행
      final isValid = await DocumentSubmissionDebug.preValidateSubmission();
      if (!isValid) {
        throw Exception('인증 상태가 유효하지 않습니다. 다시 로그인해주세요.');
      }

      Response response;
      final fields = {
        'title': title,
        'content': content,
        'category': category,
        'writerId': writerId,
        'status': '대기',
        'submittedAt': DateTime.now().toIso8601String(),
      };

      print('[DEBUG] 요청 데이터: $fields');

      if (imageFile != null) {
        print('[DEBUG] 파일과 함께 제출: ${imageFile.path}');
        // 파일이 있는 경우 multipart 요청
        response = await DioClient.uploadFile(
          '/documents',
          imageFile.path,
          fieldName: 'file',
          fields: fields,
        );
      } else {
        print('[DEBUG] 파일 없이 제출');
        // 파일이 없는 경우 JSON 전용 엔드포인트 사용
        response = await DioClient.post('/documents/submit-json', data: fields);
      }

      print('[DEBUG] 서버 응답: ${response.data}');

      final responseData = response.data;
      if (responseData['success'] == true && responseData['document'] != null) {
        print('[DEBUG] 서류 제출 성공');
        return Document.fromJson(responseData['document']);
      } else {
        throw Exception(responseData['message'] ?? '서류 제출에 실패했습니다.');
      }
    } catch (e) {
      print('[ERROR] 서류 제출 실패: $e');

      // 403 에러인 경우 토큰 관련 문제로 판단하고 재로그인 유도
      if (e.toString().contains('403')) {
        await StorageHelper.removeToken();
        throw Exception('인증이 만료되었습니다. 다시 로그인해주세요.');
      }

      // DioException 상세 처리
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          await StorageHelper.removeToken();
          throw Exception('접근 권한이 없습니다. 다시 로그인해주세요.');
        } else if (e.response?.statusCode == 401) {
          await StorageHelper.removeToken();
          throw Exception('인증이 필요합니다. 다시 로그인해주세요.');
        }
      }

      throw Exception('서류 제출 실패: $e');
    }
  }

  /// 사용자별 서류 목록 조회
  static Future<List<Document>> getUserDocuments(String writerId) async {
    try {
      print('[DEBUG] 사용자별 서류 목록 조회: $writerId');
      final response = await DioClient.get('/documents/user/$writerId');
      final responseData = response.data;

      print('[DEBUG] 서버 응답: ${responseData['success']}, 개수: ${responseData['count']}');

      if (responseData['success'] == true) {
        List<dynamic> documentData = responseData['documents'];
        return documentData.map((data) => Document.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      print('[ERROR] 사용자 서류 목록 조회 실패: $e');
      throw Exception('사용자 서류 목록 조회 실패: $e');
    }
  }

  /// 모든 서류 목록 조회 (관리자용)
  static Future<List<Document>> getAllDocuments() async {
    try {
      print('[DEBUG] 전체 서류 목록 조회');
      final response = await DioClient.get('/documents');
      final responseData = response.data;

      print('[DEBUG] 전체 서류 응답: ${responseData['success']}, 개수: ${responseData['count']}');

      if (responseData['success'] == true) {
        List<dynamic> documentData = responseData['documents'];
        return documentData.map((data) => Document.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      print('[ERROR] 전체 서류 목록 조회 실패: $e');
      throw Exception('전체 서류 목록 조회 실패: $e');
    }
  }

  /// 특정 서류 조회
  static Future<Document> getDocumentById(int documentId) async {
    try {
      print('[DEBUG] 특정 서류 조회: ID $documentId');
      final response = await DioClient.get('/documents/$documentId');
      final responseData = response.data;

      if (responseData['success'] == true && responseData['document'] != null) {
        return Document.fromJson(responseData['document']);
      } else {
        throw Exception(responseData['message'] ?? '서류를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('[ERROR] 서류 조회 실패: $e');
      throw Exception('서류 조회 실패: $e');
    }
  }

  /// ✅ 서류 상태 업데이트 (관리자용) - @RequestParam 방식으로 수정
  static Future<Document> updateDocumentStatus({
    required int documentId,
    required String status,
    String? adminComment,
  }) async {
    try {
      print('[DEBUG] DocumentService: 서류 상태 업데이트 시작');
      print('[DEBUG] - documentId: $documentId');
      print('[DEBUG] - status: $status');
      print('[DEBUG] - adminComment: $adminComment');

      // ✅ Spring Boot @RequestParam 방식으로 URL 쿼리 파라미터 사용
      String url = '/documents/$documentId/status?status=${Uri.encodeComponent(status)}';
      if (adminComment != null && adminComment.isNotEmpty) {
        url += '&adminComment=${Uri.encodeComponent(adminComment)}';
      }

      print('[DEBUG] DocumentService: 요청 URL = $url');

      final response = await DioClient.put(url);

      print('[DEBUG] DocumentService: 응답 데이터 = ${response.data}');

      final responseData = response.data;
      if (responseData['success'] == true && responseData['document'] != null) {
        print('[DEBUG] DocumentService: 상태 업데이트 성공');
        return Document.fromJson(responseData['document']);
      } else {
        throw Exception(responseData['message'] ?? '서류 상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      print('[ERROR] DocumentService: 서류 상태 업데이트 실패 - $e');
      throw Exception('서류 상태 업데이트 실패: $e');
    }
  }

  /// 서류 삭제 (관리자용)
  static Future<void> deleteDocument(int documentId) async {
    try {
      print('[DEBUG] 서류 삭제: ID $documentId');
      final response = await DioClient.delete('/documents/$documentId');
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '서류 삭제에 실패했습니다.');
      }
      print('[DEBUG] 서류 삭제 완료');
    } catch (e) {
      print('[ERROR] 서류 삭제 실패: $e');
      throw Exception('서류 삭제 실패: $e');
    }
  }

  /// 서류 통계 조회 (관리자용)
  static Future<Map<String, dynamic>> getDocumentStatistics() async {
    try {
      print('[DEBUG] 서류 통계 조회');
      final response = await DioClient.get('/documents/statistics');
      final responseData = response.data;
      if (responseData['success'] == true && responseData['statistics'] != null) {
        return responseData['statistics'];
      } else {
        throw Exception(responseData['message'] ?? '통계 조회에 실패했습니다.');
      }
    } catch (e) {
      print('[ERROR] 서류 통계 조회 실패: $e');
      throw Exception('서류 통계 조회 실패: $e');
    }
  }

  /// 서류 카테고리 목록
  static List<String> getDocumentCategories() {
    return [
      '외박 신청',
      '퇴사 신청',
      '호실 변경',
      '시설 수리',
      '분실물 신고',
      '기타',
    ];
  }

  /// ✅ 상태 목록 (관리자용) - '검토중' 추가
  static List<String> getStatusList() {
    return [
      '대기',
      '검토중',
      '승인',
      '반려',
    ];
  }
}