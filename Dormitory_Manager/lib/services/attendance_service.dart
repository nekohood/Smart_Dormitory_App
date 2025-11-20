import 'package:dio/dio.dart';
import '../api/dio_client.dart';
import '../models/attendance.dart';
import '../utils/storage_helper.dart';

/// 출석 테이블 관리 서비스
class AttendanceService {
  String? _authToken;

  /// 인증 토큰 설정
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// 요청 헤더 생성
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// 출석 테이블 생성
  Future<AttendanceTableResponse> createAttendanceTable(DateTime date) async {
    try {
      print('[DEBUG] 출석 테이블 생성 요청 - 날짜: $date');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final dateStr = _formatDate(date);

      final response = await DioClient.post(
        '/attendance/table/create?date=$dateStr',
        data: {},
      );

      print('[DEBUG] 출석 테이블 생성 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AttendanceTableResponse.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '출석 테이블 생성 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 출석 테이블 생성 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '출석 테이블 생성 실패');
      }
      throw Exception('출석 테이블 생성 중 오류가 발생했습니다');
    }
  }

  /// 출석 테이블 조회
  Future<AttendanceTableResponse> getAttendanceTable(DateTime date) async {
    try {
      print('[DEBUG] 출석 테이블 조회 요청 - 날짜: $date');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final dateStr = _formatDate(date);

      final response = await DioClient.get(
        '/attendance/table?date=$dateStr',
      );

      print('[DEBUG] 출석 테이블 조회 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AttendanceTableResponse.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '출석 테이블 조회 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 출석 테이블 조회 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '출석 테이블 조회 실패');
      }
      throw Exception('출석 테이블 조회 중 오류가 발생했습니다');
    }
  }

  /// 오늘 출석 테이블 조회
  Future<AttendanceTableResponse> getTodayAttendanceTable() async {
    try {
      print('[DEBUG] 오늘 출석 테이블 조회 요청');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final response = await DioClient.get('/attendance/table/today');

      print('[DEBUG] 오늘 출석 테이블 조회 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AttendanceTableResponse.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '오늘 출석 테이블 조회 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 오늘 출석 테이블 조회 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '오늘 출석 테이블 조회 실패');
      }
      throw Exception('오늘 출석 테이블 조회 중 오류가 발생했습니다');
    }
  }

  /// 출석 항목 수정
  Future<void> updateAttendanceEntry(
      int entryId, {
        bool? isSubmitted,
        int? score,
        String? status,
        String? notes,
      }) async {
    try {
      print('[DEBUG] 출석 항목 수정 요청 - ID: $entryId');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final requestData = <String, dynamic>{};
      if (isSubmitted != null) requestData['isSubmitted'] = isSubmitted;
      if (score != null) requestData['score'] = score;
      if (status != null) requestData['status'] = status;
      if (notes != null) requestData['notes'] = notes;

      final response = await DioClient.put(
        '/attendance/entry/$entryId',
        data: requestData,
      );

      print('[DEBUG] 출석 항목 수정 성공');

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '출석 항목 수정 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 출석 항목 수정 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '출석 항목 수정 실패');
      }
      throw Exception('출석 항목 수정 중 오류가 발생했습니다');
    }
  }

  /// 출석 테이블 삭제
  Future<void> deleteAttendanceTable(DateTime date) async {
    try {
      print('[DEBUG] 출석 테이블 삭제 요청 - 날짜: $date');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final dateStr = _formatDate(date);

      final response = await DioClient.delete(
        '/attendance/table?date=$dateStr',
      );

      print('[DEBUG] 출석 테이블 삭제 성공');

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '출석 테이블 삭제 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 출석 테이블 삭제 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '출석 테이블 삭제 실패');
      }
      throw Exception('출석 테이블 삭제 중 오류가 발생했습니다');
    }
  }

  /// 날짜를 yyyy-MM-dd 형식으로 변환
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}