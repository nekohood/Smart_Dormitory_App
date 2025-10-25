import 'dart:io';
import 'package:dio/dio.dart'; // MultipartFile을 사용하기 위해 임포트
import '../models/complaint.dart';
import '../api/dio_client.dart'; // 통합된 DioClient 사용

class ComplaintService {
  // 민원 신고 제출
  static Future<Complaint> submitComplaint({
    required String title,
    required String content,
    required String category,
    required String writerId,
    File? imageFile,
  }) async {
    try {
      Response response;
      // DioClient의 uploadFile은 Map<String, String>을 받으므로 변환
      final fields = {
        'title': title,
        'content': content,
        'category': category,
        'writerId': writerId,
        'status': '대기',
        'submittedAt': DateTime.now().toIso8601String(),
      };

      if (imageFile != null) {
        // 파일이 있는 경우 multipart 요청
        response = await DioClient.uploadFile(
          '/complaints',
          imageFile.path, // 파일 경로 전달
          fieldName: 'file', // 서버에서 받을 필드명
          fields: fields,
        );
      } else {
        // 파일이 없는 경우 일반 POST 요청
        response = await DioClient.post('/complaints', data: fields);
      }

      final responseData = response.data;
      if (responseData['success'] == true && responseData['complaint'] != null) {
        return Complaint.fromJson(responseData['complaint']);
      } else {
        throw Exception(responseData['message'] ?? '민원 제출에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('민원 신고 제출 실패: $e');
    }
  }

  // 사용자별 민원 목록 조회
  static Future<List<Complaint>> getUserComplaints(String writerId) async {
    try {
      final response = await DioClient.get('/complaints/user/$writerId');
      final responseData = response.data;
      if (responseData['success'] == true) {
        List<dynamic> complaintData = responseData['complaints'];
        return complaintData.map((data) => Complaint.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('사용자 민원 목록 조회 실패: $e');
    }
  }

  // 모든 민원 목록 조회 (관리자용)
  static Future<List<Complaint>> getAllComplaints() async {
    try {
      final response = await DioClient.get('/complaints');
      final responseData = response.data;
      if (responseData['success'] == true) {
        List<dynamic> complaintData = responseData['complaints'];
        return complaintData.map((data) => Complaint.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('전체 민원 목록 조회 실패: $e');
    }
  }

  // 특정 민원 조회
  static Future<Complaint> getComplaintById(int complaintId) async {
    try {
      final response = await DioClient.get('/complaints/$complaintId');
      final responseData = response.data;
      if (responseData['success'] == true && responseData['complaint'] != null) {
        return Complaint.fromJson(responseData['complaint']);
      } else {
        throw Exception(responseData['message'] ?? '민원을 찾을 수 없습니다.');
      }
    } catch (e) {
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
      final response = await DioClient.put('/complaints/$complaintId/status', data: {
        'status': status,
        if (adminComment != null) 'adminComment': adminComment,
        'processedAt': DateTime.now().toIso8601String(),
      });

      final responseData = response.data;
      if (responseData['success'] == true && responseData['complaint'] != null) {
        return Complaint.fromJson(responseData['complaint']);
      } else {
        throw Exception(responseData['message'] ?? '민원 상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('민원 상태 업데이트 실패: $e');
    }
  }

  // 민원 삭제 (관리자용)
  static Future<void> deleteComplaint(int complaintId) async {
    try {
      final response = await DioClient.delete('/complaints/$complaintId');
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '민원 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('민원 삭제 실패: $e');
    }
  }

  // 민원 통계 조회 (관리자용)
  static Future<Map<String, dynamic>> getComplaintStatistics() async {
    try {
      final response = await DioClient.get('/complaints/statistics');
      final responseData = response.data;
      if (responseData['success'] == true && responseData['statistics'] != null) {
        return responseData['statistics'];
      } else {
        throw Exception(responseData['message'] ?? '통계 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('민원 통계 조회 실패: $e');
    }
  }

  // 민원 카테고리 목록
  static List<String> getComplaintCategories() {
    return [
      '시설 문제',
      '소음 문제',
      '청소 문제',
      '보안 문제',
      '기타 불편사항',
      '개선 건의',
      '분실물 신고',
      '기타',
    ];
  }

  // 상태 목록 (관리자용)
  static List<String> getStatusList() {
    return [
      '대기',
      '처리중',
      '완료',
      '반려',
    ];
  }
}