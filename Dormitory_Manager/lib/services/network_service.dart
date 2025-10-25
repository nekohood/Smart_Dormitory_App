import 'package:dio/dio.dart';
import '../api/api_config.dart';

class NetworkService {
  static final Dio _dio = Dio();

  /// 서버 연결 상태 확인
  static Future<bool> checkServerConnection() async {
    try {
      print('[NetworkService] 서버 연결 확인 시작');
      print('[NetworkService] 환경: ${ApiConfig.currentEnvironment}');
      print('[NetworkService] URL: ${ApiConfig.baseUrl}');

      // Dio 인스턴스 설정
      _dio.options.connectTimeout = Duration(seconds: 10);
      _dio.options.receiveTimeout = Duration(seconds: 10);

      final response = await _dio.get(ApiConfig.healthCheckUrl);

      print('[NetworkService] 서버 응답: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('[NetworkService] 서버 연결 실패: $e');
      return false;
    }
  }

  /// 네트워크 진단 정보
  static Future<Map<String, dynamic>> getDiagnosticInfo() async {
    final Map<String, dynamic> info = {};

    info['environment'] = ApiConfig.currentEnvironment;
    info['baseUrl'] = ApiConfig.baseUrl;
    info['timestamp'] = DateTime.now().toIso8601String();

    try {
      final serverConnected = await checkServerConnection();
      info['serverConnected'] = serverConnected;

      if (serverConnected) {
        // 추가 API 테스트
        final response = await _dio.get('${ApiConfig.baseUrl}/auth/health');
        info['authApiWorking'] = response.statusCode == 200;
      }
    } catch (e) {
      info['serverConnected'] = false;
      info['error'] = e.toString();
    }

    return info;
  }
}