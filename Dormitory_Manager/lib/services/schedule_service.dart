import 'package:dio/dio.dart';
import 'package:dormitory_manager/api/dio_client.dart';
import 'package:dormitory_manager/models/schedule.dart';

class ScheduleService {

  // ✅ DioClient의 static 메서드를 사용하므로 생성자나 멤버 변수 불필요

  /// 모든 일정 조회 (GET /api/schedules)
  Future<List<Schedule>> getSchedules() async { // ✅ getAllSchedules -> getSchedules
    try {
      // ✅ DioClient의 static 'get' 메서드 사용
      final response = await DioClient.get('/schedules');

      if (response.data['success'] == true && response.data['data'] != null) {
        List<dynamic> dataList = response.data['data'];
        return dataList.map((item) => Schedule.fromJson(item)).toList();
      } else {
        throw Exception(response.data['message'] ?? '일정 불러오기 실패');
      }
    } on DioException catch (e) {
      print('Error getting all schedules: $e');
      throw Exception('일정 조회 실패: ${e.message}');
    }
  }

  // ❌ getUpcomingSchedules() 함수 삭제
  // (D-Day 계산은 home_screen에서 getSchedules()로 받은 전체 목록으로 처리)

  // --- (관리자 기능용) ---

  // ✅ 매개변수를 Schedule 객체로 받도록 수정
  Future<Schedule> createSchedule(Schedule schedule) async {
    try {
      final response = await DioClient.post(
        '/schedules', // ✅ API 경로 수정
        data: schedule.toJson(),
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return Schedule.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '일정 생성 실패');
      }
    } on DioException catch (e) {
      print('Error creating schedule: $e');
      throw Exception('일정 생성 실패: ${e.message}');
    }
  }

  // ✅ 매개변수를 Schedule 객체로 받도록 수정
  Future<Schedule> updateSchedule(int id, Schedule schedule) async {
    try {
      final response = await DioClient.put(
        '/schedules/$id', // ✅ API 경로 수정
        data: schedule.toJson(),
      );
      if (response.data['success'] == true && response.data['data'] != null) {
        return Schedule.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '일정 수정 실패');
      }
    } on DioException catch (e) {
      print('Error updating schedule: $e');
      throw Exception('일정 수정 실패: ${e.message}');
    }
  }

  // ✅ API 경로 수정
  Future<void> deleteSchedule(int id) async {
    try {
      final response = await DioClient.delete('/schedules/$id');
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '일정 삭제 실패');
      }
    } on DioException catch (e) {
      print('Error deleting schedule: $e');
      throw Exception('일정 삭제 실패: ${e.message}');
    }
  }
}