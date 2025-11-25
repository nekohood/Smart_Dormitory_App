import 'dart:io';
import 'package:dio/dio.dart';
import '../models/complaint.dart';
import '../api/dio_client.dart';

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
          imageFile.path,
          fieldName: 'file',
          fields: fields,
        );
      } else {
        // 파일이 없는 경우 일반 POST 요청
        response = await DioClient.post('/complaints', data: fields);
      }

      final responseData = response.data;

      // ✅ ApiResponse 구조 처리: data 필드에서 민원 데이터 추출
      if (responseData['success'] == true) {
        final complaintData = responseData['data'];
        if (complaintData != null) {
          return Complaint.fromJson(complaintData);
        } else {
          throw Exception('응답에 민원 데이터가 없습니다.');
        }
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
        // ✅ ApiResponse 구조: data 필드에서 complaints 추출
        final data = responseData['data'];
        if (data != null && data['complaints'] != null) {
          List<dynamic> complaintData = data['complaints'];
          return complaintData.map((data) => Complaint.fromJson(data)).toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('사용자 민원 목록 조회 실패: $e');
    }
  }

  // 모든 민원 목록 조회 (관리자용)
  static Future<List<Complaint>> getAllComplaints() async {
    try {
      print('[DEBUG] ComplaintService: 전체 민원 목록 조회 시작');
      final response = await DioClient.get('/complaints');
      final responseData = response.data;

      print('[DEBUG] ComplaintService: 응답 구조: ${responseData.keys}');
      print('[DEBUG] ComplaintService: success = ${responseData['success']}');

      if (responseData['success'] == true) {
        // ✅ ApiResponse 구조: data 필드에서 complaints 추출
        final data = responseData['data'];
        if (data != null && data['complaints'] != null) {
          List<dynamic> complaintData = data['complaints'];
          print('[DEBUG] ComplaintService: 민원 개수 = ${complaintData.length}');
          return complaintData.map((data) => Complaint.fromJson(data)).toList();
        }
      }
      return [];
    } catch (e) {
      print('[ERROR] ComplaintService: 전체 민원 목록 조회 실패 - $e');
      throw Exception('전체 민원 목록 조회 실패: $e');
    }
  }

  // 특정 민원 조회
  static Future<Complaint> getComplaintById(int complaintId) async {
    try {
      final response = await DioClient.get('/complaints/$complaintId');
      final responseData = response.data;

      if (responseData['success'] == true) {
        // ✅ ApiResponse 구조: data 필드에서 민원 데이터 추출
        final complaintData = responseData['data'];
        if (complaintData != null) {
          return Complaint.fromJson(complaintData);
        } else {
          throw Exception('민원을 찾을 수 없습니다.');
        }
      } else {
        throw Exception(responseData['message'] ?? '민원을 찾을 수 없습니다.');
      }
    } catch (e) {
      throw Exception('민원 조회 실패: $e');
    }
  }

  /// ✅ 민원 상태 업데이트 (관리자용) - @RequestParam 방식으로 수정
  static Future<Complaint> updateComplaintStatus({
    required int complaintId,
    required String status,
    String? adminComment,
  }) async {
    try {
      print('[DEBUG] ComplaintService: 민원 상태 업데이트 시작');
      print('[DEBUG] - complaintId: $complaintId');
      print('[DEBUG] - status: $status');
      print('[DEBUG] - adminComment: $adminComment');

      // ✅ Spring Boot @RequestParam 방식으로 URL 쿼리 파라미터 사용
      String url = '/complaints/$complaintId/status?status=${Uri.encodeComponent(status)}';
      if (adminComment != null && adminComment.isNotEmpty) {
        url += '&adminComment=${Uri.encodeComponent(adminComment)}';
      }

      print('[DEBUG] ComplaintService: 요청 URL = $url');

      final response = await DioClient.put(url);

      print('[DEBUG] ComplaintService: 응답 데이터 = ${response.data}');

      final responseData = response.data;

      if (responseData['success'] == true) {
        // ✅ ApiResponse 구조: data 필드에서 민원 데이터 추출
        final complaintData = responseData['data'];
        if (complaintData != null) {
          print('[DEBUG] ComplaintService: 상태 업데이트 성공');
          return Complaint.fromJson(complaintData);
        } else {
          throw Exception('민원 상태 업데이트에 실패했습니다.');
        }
      } else {
        throw Exception(responseData['message'] ?? '민원 상태 업데이트에 실패했습니다.');
      }
    } catch (e) {
      print('[ERROR] ComplaintService: 민원 상태 업데이트 실패 - $e');
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

      if (responseData['success'] == true) {
        // ✅ ApiResponse 구조: data 필드에서 통계 데이터 추출
        final statisticsData = responseData['data'];
        if (statisticsData != null) {
          return statisticsData;
        } else {
          throw Exception('통계 조회에 실패했습니다.');
        }
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

  // ✅ 상태 목록 (관리자용) - '검토중' 추가
  static List<String> getStatusList() {
    return [
      '대기',
      '처리중',
      '완료',
      '반려',
    ];
  }
}