import 'package:dio/dio.dart';
import '../models/calendar_event.dart';
import '../api/api_config.dart';

/// 캘린더 서비스
class CalendarService {
  final Dio _dio = Dio();
  String? _authToken;

  CalendarService() {
    _dio.options.baseUrl = ApiConfig.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  /// 인증 토큰 설정
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// 모든 일정 조회
  Future<List<CalendarEvent>> getAllEvents() async {
    try {
      final response = await _dio.get('/calendar');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '일정 목록 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 일정 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// ID로 일정 조회
  Future<CalendarEvent> getEventById(int id) async {
    try {
      final response = await _dio.get('/calendar/$id');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return CalendarEvent.fromJson(response.data['event']);
      } else {
        throw Exception(response.data['message'] ?? '일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 특정 월의 일정 조회
  Future<List<CalendarEvent>> getEventsByMonth(int year, int month) async {
    try {
      final response = await _dio.get(
        '/calendar/month',
        queryParameters: {
          'year': year,
          'month': month,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '월별 일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 월별 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 오늘의 일정 조회
  Future<List<CalendarEvent>> getTodayEvents() async {
    try {
      final response = await _dio.get('/calendar/today');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '오늘 일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 오늘 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 이번 주 일정 조회
  Future<List<CalendarEvent>> getThisWeekEvents() async {
    try {
      final response = await _dio.get('/calendar/week');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '이번 주 일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 이번 주 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 다가오는 일정 조회
  Future<List<CalendarEvent>> getUpcomingEvents({int days = 30}) async {
    try {
      final response = await _dio.get(
        '/calendar/upcoming',
        queryParameters: {'days': days},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '다가오는 일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 다가오는 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 카테고리별 일정 조회
  Future<List<CalendarEvent>> getEventsByCategory(String category) async {
    try {
      final response = await _dio.get('/calendar/category/$category');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '카테고리별 일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 카테고리별 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 중요 일정 조회
  Future<List<CalendarEvent>> getImportantEvents() async {
    try {
      final response = await _dio.get('/calendar/important');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '중요 일정 조회 실패');
      }
    } catch (e) {
      print('[ERROR] 중요 일정 조회 실패: $e');
      rethrow;
    }
  }

  /// 일정 생성 (관리자 전용)
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    try {
      final response = await _dio.post(
        '/calendar',
        data: event.toJson(),
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return CalendarEvent.fromJson(response.data['event']);
      } else {
        throw Exception(response.data['message'] ?? '일정 생성 실패');
      }
    } catch (e) {
      print('[ERROR] 일정 생성 실패: $e');
      rethrow;
    }
  }

  /// 일정 수정 (관리자 전용)
  Future<CalendarEvent> updateEvent(int id, CalendarEvent event) async {
    try {
      final response = await _dio.put(
        '/calendar/$id',
        data: event.toJson(),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return CalendarEvent.fromJson(response.data['event']);
      } else {
        throw Exception(response.data['message'] ?? '일정 수정 실패');
      }
    } catch (e) {
      print('[ERROR] 일정 수정 실패: $e');
      rethrow;
    }
  }

  /// 일정 삭제 (관리자 전용)
  Future<void> deleteEvent(int id) async {
    try {
      final response = await _dio.delete('/calendar/$id');

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '일정 삭제 실패');
      }
    } catch (e) {
      print('[ERROR] 일정 삭제 실패: $e');
      rethrow;
    }
  }

  /// 일정 검색
  Future<List<CalendarEvent>> searchEvents(String title) async {
    try {
      final response = await _dio.get(
        '/calendar/search',
        queryParameters: {'title': title},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> eventsJson = response.data['events'];
        return eventsJson.map((json) => CalendarEvent.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? '일정 검색 실패');
      }
    } catch (e) {
      print('[ERROR] 일정 검색 실패: $e');
      rethrow;
    }
  }
}
