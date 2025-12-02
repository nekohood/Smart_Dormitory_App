import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../models/complaint.dart';
import '../api/dio_client.dart';

/// 민원 API 서비스
/// ✅ 수정: XFile + Uint8List 지원으로 웹/앱 호환성 확보
class ComplaintService {
  /// 민원 신고 제출
  /// ✅ 수정: XFile + imageBytes 지원 (웹/앱 호환)
  static Future<Complaint> submitComplaint({
    required String title,
    required String content,
    required String category,
    required String writerId,
    XFile? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      print('[ComplaintService] 민원 제출 시작 - 제목: $title');

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
        print('[ComplaintService] 이미지 첨부 (XFile): ${imageFile.name}');
      } else if (imageBytes != null) {
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            imageBytes,
            filename: fileName ?? 'complaint_image.jpg',
          ),
        ));
        print('[ComplaintService] 이미지 첨부 (bytes): ${fileName ?? 'complaint_image.jpg'}');
      }

      final response = await DioClient.post('/complaints', data: formData);
      final responseData = response.data;

      // ✅ ApiResponse 구조 처리: data 필드에서 민원 데이터 추출
      if (responseData['success'] == true) {
        final complaintData = responseData['data'];
        if (complaintData != null) {
          print('[ComplaintService] 민원 제출 성공 - ID: ${complaintData['id']}');
          return Complaint.fromJson(complaintData);
        } else {
          throw Exception('응답에 민원 데이터가 없습니다.');
        }
      } else {
        throw Exception(responseData['message'] ?? '민원 제출에 실패했습니다.');
      }
    } catch (e) {
      print('[ComplaintService] 민원 제출 실패: $e');
      throw Exception('민원 제출 실패: $e');
    }
  }

  // 사용자별 민원 목록 조회
  static Future<List<Complaint>> getUserComplaints(String writerId) async {
    try {
      print('[ComplaintService] 사용자 민원 목록 조회 - writerId: $writerId');

      final response = await DioClient.get('/complaints/user/$writerId');
      final responseData = response.data;

      if (responseData['success'] == true) {
        final data = responseData['data'];

        // ✅ API 응답 구조: { data: { complaints: [...], count: N } }
        List<dynamic> complaintsData = [];
        if (data is Map && data.containsKey('complaints')) {
          complaintsData = data['complaints'] ?? [];
        } else if (data is List) {
          // 혹시 직접 리스트로 오는 경우 대비
          complaintsData = data;
        }

        print('[ComplaintService] 사용자 민원 ${complaintsData.length}건 조회됨');
        return complaintsData.map((item) => Complaint.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('[ComplaintService] 사용자 민원 목록 조회 실패: $e');
      throw Exception('민원 목록 조회 실패: $e');
    }
  }

  // 모든 민원 목록 조회 (관리자용)
  static Future<List<Complaint>> getAllComplaints() async {
    try {
      print('[ComplaintService] 전체 민원 목록 조회');

      final response = await DioClient.get('/complaints');
      final responseData = response.data;

      if (responseData['success'] == true) {
        final data = responseData['data'];

        // ✅ API 응답 구조: { data: { complaints: [...], count: N } }
        List<dynamic> complaintsData = [];
        if (data is Map && data.containsKey('complaints')) {
          complaintsData = data['complaints'] ?? [];
        } else if (data is List) {
          // 혹시 직접 리스트로 오는 경우 대비
          complaintsData = data;
        }

        print('[ComplaintService] 민원 ${complaintsData.length}건 조회됨');
        return complaintsData.map((item) => Complaint.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('[ComplaintService] 전체 민원 목록 조회 실패: $e');
      throw Exception('민원 목록 조회 실패: $e');
    }
  }

  // 특정 민원 조회
  static Future<Complaint> getComplaintById(int complaintId) async {
    try {
      print('[ComplaintService] 민원 상세 조회 - ID: $complaintId');

      final response = await DioClient.get('/complaints/$complaintId');
      final responseData = response.data;

      if (responseData['success'] == true && responseData['data'] != null) {
        return Complaint.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? '민원을 찾을 수 없습니다.');
      }
    } catch (e) {
      print('[ComplaintService] 민원 상세 조회 실패: $e');
      throw Exception('민원 조회 실패: $e');
    }
  }

  // 민원 상태 업데이트 (관리자용)
  static Future<Complaint> updateComplaintStatus({
    required int complaintId,
    required String status,
    String? adminComment,
  }) async {
    try {
      print('[ComplaintService] 민원 상태 업데이트 - ID: $complaintId, 상태: $status');

      final response = await DioClient.patch(
        '/complaints/$complaintId/status',
        data: {
          'status': status,
          if (adminComment != null) 'adminComment': adminComment,
        },
      );

      final responseData = response.data;

      if (responseData['success'] == true && responseData['data'] != null) {
        return Complaint.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? '상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      print('[ComplaintService] 민원 상태 업데이트 실패: $e');
      throw Exception('상태 업데이트 실패: $e');
    }
  }

  // 민원 삭제 (관리자용)
  static Future<void> deleteComplaint(int complaintId) async {
    try {
      print('[ComplaintService] 민원 삭제 - ID: $complaintId');

      final response = await DioClient.delete('/complaints/$complaintId');
      final responseData = response.data;

      if (responseData['success'] != true) {
        throw Exception(responseData['message'] ?? '민원 삭제에 실패했습니다.');
      }
    } catch (e) {
      print('[ComplaintService] 민원 삭제 실패: $e');
      throw Exception('민원 삭제 실패: $e');
    }
  }

  // 민원 카테고리 목록
  static List<String> getComplaintCategories() {
    return [
      '시설 문제',
      '소음 문제',
      '위생 문제',
      '안전 문제',
      '기타 건의',
    ];
  }

  // ✅ 상태 목록 (관리자용)
  static List<String> getStatusList() {
    return [
      '대기',
      '처리중',
      '완료',
      '반려',
    ];
  }

  // 민원 통계 조회 (관리자용)
  static Future<Map<String, dynamic>> getComplaintStatistics() async {
    try {
      print('[ComplaintService] 민원 통계 조회');

      final response = await DioClient.get('/complaints/statistics');
      final responseData = response.data;

      if (responseData['success'] == true && responseData['data'] != null) {
        return Map<String, dynamic>.from(responseData['data']);
      }
      return {};
    } catch (e) {
      print('[ComplaintService] 민원 통계 조회 실패: $e');
      throw Exception('민원 통계 조회 실패: $e');
    }
  }
}