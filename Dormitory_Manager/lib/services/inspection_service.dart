import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/inspection.dart';
import '../api/api_config.dart';

/// 점호 관련 API 서비스
class InspectionService {
  String get baseUrl => ApiConfig.baseUrl;

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
    print('[DEBUG] InspectionService 토큰 설정: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}');
  }

  Map<String, String> _getHeaders() {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// 점호 제출 (수정된 버전)
  Future<InspectionResponse> submitInspection(String roomNumber, Uint8List imageBytes, String fileName) async {
    try {
      print('[DEBUG] 점호 제출 시작 - 방번호: $roomNumber, 파일명: $fileName');

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/inspections/submit'));

      if (_authToken != null) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }
      request.fields['roomNumber'] = roomNumber;

      request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          )
      );

      print('[DEBUG] 서버로 요청 전송 중...');
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      print('[DEBUG] 서버 응답 상태: ${streamedResponse.statusCode}');
      print('[DEBUG] 서버 응답 본문: $responseBody');

      // 응답 상태 코드 확인
      if (streamedResponse.statusCode != 200) {
        print('[ERROR] 서버 오류 응답: ${streamedResponse.statusCode}');
        return InspectionResponse(
            success: false,
            error: '서버 오류 (코드: ${streamedResponse.statusCode})'
        );
      }

      // JSON 파싱
      Map<String, dynamic> data;
      try {
        data = json.decode(responseBody);
      } catch (e) {
        print('[ERROR] JSON 파싱 실패: $e');
        return InspectionResponse(
            success: false,
            error: 'JSON 파싱 실패: $e'
        );
      }

      // InspectionResponse 생성
      final response = InspectionResponse.fromJson(data);

      if (response.success && response.inspection != null) {
        print('[SUCCESS] 점호 제출 성공 - 점수: ${response.inspection!.score}, 상태: ${response.inspection!.status}');
      } else {
        print('[FAILURE] 점호 제출 실패 - 오류: ${response.error}');
      }

      return response;

    } catch (e) {
      print('[ERROR] 점호 제출 중 예외 발생: $e');
      return InspectionResponse(
          success: false,
          error: '점호 제출 중 오류가 발생했습니다: $e'
      );
    }
  }

  /// 내 점호 기록 조회
  Future<InspectionListResponse> getMyInspections() async {
    try {
      print('[DEBUG] 내 점호 기록 조회 시작');
      final response = await http.get(Uri.parse('$baseUrl/inspections/my'), headers: _getHeaders());

      print('[DEBUG] 내 점호 기록 응답 상태: ${response.statusCode}');
      print('[DEBUG] 내 점호 기록 응답: ${response.body}');

      if (response.statusCode == 200) {
        return InspectionListResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('내 점호 기록 조회 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 내 점호 기록 조회 실패: $e');
      rethrow;
    }
  }

  /// 오늘 점호 상태 확인
  Future<TodayInspectionResponse> getTodayInspection() async {
    try {
      print('[DEBUG] 오늘 점호 상태 확인 시작');
      final response = await http.get(Uri.parse('$baseUrl/inspections/today'), headers: _getHeaders());

      print('[DEBUG] 오늘 점호 응답 상태: ${response.statusCode}');
      print('[DEBUG] 오늘 점호 응답: ${response.body}');

      if (response.statusCode == 200) {
        return TodayInspectionResponse.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? '오늘 점호 상태 확인 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 오늘 점호 상태 확인 실패: $e');
      rethrow;
    }
  }

  /// 모든 점호 기록 조회 (관리자용)
  Future<InspectionListResponse> getAllInspections() async {
    try {
      print('[DEBUG] 전체 점호 기록 조회 시작');
      final response = await http.get(Uri.parse('$baseUrl/inspections/admin/all'), headers: _getHeaders());

      print('[DEBUG] 전체 점호 기록 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return InspectionListResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('전체 점호 기록 조회 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 전체 점호 기록 조회 실패: $e');
      rethrow;
    }
  }

  /// 날짜별 점호 기록 조회 (관리자용)
  Future<InspectionListResponse> getInspectionsByDate(DateTime date) async {
    try {
      String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      print('[DEBUG] 날짜별 점호 기록 조회 시작: $dateStr');

      final response = await http.get(Uri.parse('$baseUrl/inspections/admin/date/$dateStr'), headers: _getHeaders());

      print('[DEBUG] 날짜별 점호 기록 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return InspectionListResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('날짜별 점호 기록 조회 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 날짜별 점호 기록 조회 실패: $e');
      rethrow;
    }
  }

  /// 점호 기록 삭제 (관리자용)
  Future<bool> deleteInspection(int inspectionId) async {
    try {
      print('[DEBUG] 점호 기록 삭제 시작: $inspectionId');
      final response = await http.delete(Uri.parse('$baseUrl/inspections/admin/$inspectionId'), headers: _getHeaders());

      print('[DEBUG] 점호 기록 삭제 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['success'] ?? false;
      } else {
        throw Exception('점호 기록 삭제 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 점호 기록 삭제 실패: $e');
      rethrow;
    }
  }

  /// 점호 기록 수정 (관리자용)
  Future<AdminInspectionModel> updateInspection(int inspectionId, InspectionUpdateRequest updateRequest) async {
    try {
      print('[DEBUG] 점호 기록 수정 시작: $inspectionId');
      final response = await http.put(
        Uri.parse('$baseUrl/inspections/admin/$inspectionId'),
        headers: _getHeaders(),
        body: json.encode(updateRequest.toJson()),
      );

      print('[DEBUG] 점호 기록 수정 응답 상태: ${response.statusCode}');
      print('[DEBUG] 점호 기록 수정 응답: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['inspection'] != null) {
          return AdminInspectionModel.fromJson(data['inspection']);
        } else {
          throw Exception(data['message'] ?? '점호 기록 수정 실패');
        }
      } else {
        throw Exception('점호 기록 수정 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 점호 기록 수정 실패: $e');
      rethrow;
    }
  }

  /// 점호 통계 조회
  Future<InspectionStatisticsResponse> getInspectionStatistics({DateTime? date}) async {
    try {
      String url = '$baseUrl/inspections/statistics';
      if (date != null) {
        String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        url += '?date=$dateStr';
      }

      print('[DEBUG] 점호 통계 조회 시작: $url');
      final response = await http.get(Uri.parse(url), headers: _getHeaders());

      print('[DEBUG] 점호 통계 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        return InspectionStatisticsResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('점호 통계 조회 실패 (코드: ${response.statusCode})');
      }
    } catch (e) {
      print('[ERROR] 점호 통계 조회 실패: $e');
      rethrow;
    }
  }
}