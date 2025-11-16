import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  // Railway 서버 주소 설정 (https 추가 및 /api 경로 포함)
  static const String _productionUrl = 'https://smartdormitoryapp-production.up.railway.app/api';

  // 로컬 개발용 주소들
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8080/api';
  static const String _desktopOrWebUrl = 'http://localhost:8080/api';

  static String get baseUrl {
    // 플랫폼별 로컬 서버 주소 반환 (원래 로직 복원)
    String url; // 선택된 URL을 담을 변수

    if (kIsWeb) {
      url = _desktopOrWebUrl;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      url = _androidEmulatorUrl;
    } else {
      url = _desktopOrWebUrl;
    }

    // 환경 정보 출력
    print('✅ [ApiConfig] 현재 환경: $currentEnvironment, 선택된 Base URL: $url');

    return url;
  }

  // API 엔드포인트들
  static const String auth = '/auth';
  static const String inspections = '/inspections';
  static const String notices = '/notices';
  static const String documents = '/documents';
  static const String complaints = '/complaints';

  // 연결 시간 설정
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // 서버 상태 확인용 URL
  static String get healthCheckUrl {
    // baseUrl이 항상 /api로 끝나므로 안전하게 제거
    final hostUrl = baseUrl.replaceAll('/api', '');
    // Spring Boot Actuator 경로 사용
    return '$hostUrl/actuator/health';
  }

  // 현재 환경 확인 (디버깅 목적으로 유지)
  static String get currentEnvironment {
    if (kIsWeb) return 'Web (Chrome)';

    // 웹이 아닐 때만 플랫폼 확인
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android Emulator';
      case TargetPlatform.windows:
        return 'Windows Desktop';
      case TargetPlatform.linux:
        return 'Linux Desktop';
      case TargetPlatform.macOS:
        return 'macOS Desktop';
      case TargetPlatform.iOS:
        return 'iOS Device';
      default:
        return 'Unknown';
    }
  }
}