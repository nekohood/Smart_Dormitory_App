import 'package:dio/dio.dart';
import '../models/dday.dart';
import '../api/api_config.dart';

/// D-Day 서비스
class DDayService {
  final Dio _dio = Dio();
  String? _authToken;

  DDayService() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  /// 인증 토큰 설정
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 모든 활성화된 D-Day 조회
  Future<List<DDay>> getAllActiveDDays() async {
    try {
      final response = await _dio.get('/dday');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> ddaysJson = response.data['ddays'];
        return ddaysJson.map((json) => DDay.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 목록 조회 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// 모든 D-Day 조회 (비활성화 포함 - 관리자용)
  Future<List<DDay>> getAllDDays() async {
    try {
      final response = await _dio.get('/dday/all');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> ddaysJson = response.data['ddays'];
        return ddaysJson.map((json) => DDay.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '전체 D-Day 목록 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 전체 D-Day 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// ID로 D-Day 조회
  Future<DDay> getDDayById(int id) async {
    try {
      final response = await _dio.get('/dday/$id');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return DDay.fromJson(response.data['dday']);
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 조회 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 조회 실패: $e');
      rethrow;
    }
  }

  /// 중요 D-Day 조회
  Future<List<DDay>> getImportantDDays() async {
    try {
      final response = await _dio.get('/dday/important');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> ddaysJson = response.data['ddays'];
        return ddaysJson.map((json) => DDay.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '중요 D-Day 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 중요 D-Day 조회 실패: $e');
      rethrow;
    }
  }

  /// 다가오는 D-Day 조회
  Future<List<DDay>> getUpcomingDDays({int days = 30}) async {
    try {
      final response = await _dio.get(
        '/dday/upcoming',
        queryParameters: {'days': days},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> ddaysJson = response.data['ddays'];
        return ddaysJson.map((json) => DDay.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '다가오는 D-Day 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 다가오는 D-Day 조회 실패: $e');
      rethrow;
    }
  }

  /// 오늘 도래하는 D-Day 조회
  Future<List<DDay>> getTodayDDays() async {
    try {
      final response = await _dio.get('/dday/today');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> ddaysJson = response.data['ddays'];
        return ddaysJson.map((json) => DDay.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '오늘 D-Day 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 오늘 D-Day 조회 실패: $e');
      rethrow;
    }
  }

  /// D-Day 생성 (관리자 전용)
  Future<DDay> createDDay(DDay dday) async {
    try {
      final response = await _dio.post(
        '/dday',
        data: dday.toJson(),
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return DDay.fromJson(response.data['dday']);
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 생성 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 생성 실패: $e');
      rethrow;
    }
  }

  /// D-Day 수정 (관리자 전용)
  Future<DDay> updateDDay(int id, DDay dday) async {
    try {
      final response = await _dio.put(
        '/dday/$id',
        data: dday.toJson(),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return DDay.fromJson(response.data['dday']);
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 수정 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 수정 실패: $e');
      rethrow;
    }
  }

  /// D-Day 삭제 (관리자 전용)
  Future<void> deleteDDay(int id) async {
    try {
      final response = await _dio.delete('/dday/$id');

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'D-Day 삭제 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 삭제 실패: $e');
      rethrow;
    }
  }

  /// D-Day 활성화/비활성화 토글 (관리자 전용)
  Future<DDay> toggleDDayActive(int id) async {
    try {
      final response = await _dio.put('/dday/$id/toggle');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return DDay.fromJson(response.data['dday']);
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 상태 변경 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 상태 변경 실패: $e');
      rethrow;
    }
  }

  /// D-Day 검색
  Future<List<DDay>> searchDDays(String title) async {
    try {
      final response = await _dio.get(
        '/dday/search',
        queryParameters: {'title': title},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> ddaysJson = response.data['ddays'];
        return ddaysJson.map((json) => DDay.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 검색 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 검색 실패: $e');
      rethrow;
    }
  }

  /// D-Day 통계 조회 (관리자용)
  Future<Map<String, dynamic>> getDDayStatistics() async {
    try {
      final response = await _dio.get('/dday/statistics');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['statistics'];
      } else {
        throw Exception(response.data['message'] ?? 'D-Day 통계 조회 실패');
      }
    } catch (e) {
      print('[ERROR] D-Day 통계 조회 실패: $e');
      rethrow;
    }
  }
}
