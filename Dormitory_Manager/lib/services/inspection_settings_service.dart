
import '../api/dio_client.dart';
import '../models/inspection_settings.dart';

/// 점호 설정 API 서비스
class InspectionSettingsService {
  /// 점호 허용 여부 확인
  static Future<InspectionTimeCheckResult> checkInspectionTime() async {
    try {
      print('[DEBUG] 점호 허용 시간 확인 요청');

      final response = await DioClient.get('/inspection-settings/check-time');

      if (response.data['success'] == true && response.data['data'] != null) {
        return InspectionTimeCheckResult.fromJson(response.data['data']);
      }

      return InspectionTimeCheckResult(
        allowed: true,
        message: '점호 시간 확인에 실패했습니다.',
      );
    } catch (e) {
      print('[ERROR] 점호 시간 확인 실패: $e');
      // 오류 발생 시 기본적으로 허용
      return InspectionTimeCheckResult(
        allowed: true,
        message: '시간 확인 오류 - 기본 허용',
      );
    }
  }

  /// 현재 적용 설정 조회
  static Future<InspectionSettings?> getCurrentSettings() async {
    try {
      print('[DEBUG] 현재 점호 설정 조회');

      final response = await DioClient.get('/inspection-settings/current');

      if (response.data['success'] == true && response.data['data'] != null) {
        return InspectionSettings.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 현재 설정 조회 실패: $e');
      return null;
    }
  }

  /// 전체 설정 조회 (관리자용)
  static Future<List<InspectionSettings>> getAllSettings() async {
    try {
      print('[DEBUG] 전체 점호 설정 조회');

      final response = await DioClient.get('/inspection-settings');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> dataList = response.data['data'];
        return dataList.map((json) => InspectionSettings.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('[ERROR] 전체 설정 조회 실패: $e');
      rethrow;
    }
  }

  /// 설정 생성 (관리자용)
  static Future<InspectionSettings?> createSettings(InspectionSettings settings) async {
    try {
      print('[DEBUG] 점호 설정 생성: ${settings.settingName}');

      final response = await DioClient.post(
        '/inspection-settings',
        data: settings.toJson(),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return InspectionSettings.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 설정 생성 실패: $e');
      rethrow;
    }
  }

  /// 설정 수정 (관리자용)
  static Future<InspectionSettings?> updateSettings(int id, InspectionSettings settings) async {
    try {
      print('[DEBUG] 점호 설정 수정: ID=$id');

      final response = await DioClient.put(
        '/inspection-settings/$id',
        data: settings.toJson(),
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return InspectionSettings.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 설정 수정 실패: $e');
      rethrow;
    }
  }

  /// 설정 삭제 (관리자용)
  static Future<bool> deleteSettings(int id) async {
    try {
      print('[DEBUG] 점호 설정 삭제: ID=$id');

      final response = await DioClient.delete('/inspection-settings/$id');

      return response.data['success'] == true;
    } catch (e) {
      print('[ERROR] 설정 삭제 실패: $e');
      rethrow;
    }
  }

  /// 설정 활성화 토글 (관리자용)
  static Future<InspectionSettings?> toggleSettings(int id) async {
    try {
      print('[DEBUG] 점호 설정 토글: ID=$id');

      final response = await DioClient.patch('/inspection-settings/$id/toggle');

      if (response.data['success'] == true && response.data['data'] != null) {
        return InspectionSettings.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 설정 토글 실패: $e');
      rethrow;
    }
  }

  /// 기본 설정 초기화 (관리자용)
  static Future<InspectionSettings?> initializeDefaultSettings() async {
    try {
      print('[DEBUG] 기본 점호 설정 초기화');

      final response = await DioClient.post('/inspection-settings/initialize-default');

      if (response.data['success'] == true && response.data['data'] != null) {
        return InspectionSettings.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 기본 설정 초기화 실패: $e');
      rethrow;
    }
  }
}