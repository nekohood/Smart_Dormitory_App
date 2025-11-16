import 'package:dormitory_manager/api/dio_client.dart';
import 'package:dormitory_manager/models/schedule.dart';
import '../api/dio_client.dart'; // DioClient 임포트

class ScheduleService {
  final DioClient _dioClient;

  ScheduleService() : _dioClient = DioClient();

  // 모든 일정 조회 (캘린더용)
  Future<List<Schedule>> getAllSchedules() async {
    try {
      final response = await DioClient.get('/schedule');
      List<dynamic> data = response.data['data'];
      return data.map((item) => Schedule.fromJson(item)).toList();
    } catch (e) {
      print('Error getting all schedules: $e');
      return [];
    }
  }

  // 다가오는 일정 조회 (D-Day용)
  Future<List<Schedule>> getUpcomingSchedules() async {
    try {
      final response = await DioClient.get('/schedule/upcoming');
      List<dynamic> data = response.data['data'];
      return data.map((item) => Schedule.fromJson(item)).toList();
    } catch (e) {
      print('Error getting upcoming schedules: $e');
      return [];
    }
  }

  // --- (관리자 기능용) ---

  // 일정 생성
  Future<bool> createSchedule(String title, DateTime eventDate) async {
    try {
      await DioClient.post(
        '/schedule',
        data: {
          'title': title,
          'eventDate': eventDate.toIso8601String().split('T').first, // "YYYY-MM-DD"
        },
      );
      return true;
    } catch (e) {
      print('Error creating schedule: $e');
      return false;
    }
  }

  // 일정 수정
  Future<bool> updateSchedule(int id, String title, DateTime eventDate) async {
    try {
      await DioClient.put(
        '/schedule/$id',
        data: {
          'title': title,
          'eventDate': eventDate.toIso8601String().split('T').first,
        },
      );
      return true;
    } catch (e) {
      print('Error updating schedule: $e');
      return false;
    }
  }

  // 일정 삭제
  Future<bool> deleteSchedule(int id) async {
    try {
      await DioClient.delete('/schedule/$id');
      return true;
    } catch (e) {
      print('Error deleting schedule: $e');
      return false;
    }
  }
}