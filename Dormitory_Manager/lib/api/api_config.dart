import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8080/api';
  static const String _desktopOrWebUrl = 'http://localhost:8080/api';

  static String get baseUrl {
    String url; // 선택된 URL을 담을 변수

    if (kIsWeb) {
      url = _desktopOrWebUrl;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      url = _androidEmulatorUrl;
    } else {
      url = _desktopOrWebUrl;
    }

    // *** 여기에 탐지기를 심습니다! ***
    print('✅ [ApiConfig] 현재 환경: $currentEnvironment, 선택된 Base URL: $url');

    return url;
  }

  // ... (이하 나머지 코드는 동일) ...
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
    final hostUrl = baseUrl.replaceAll('/api', '');
    return '$hostUrl/actuator/health';
  }

  // 현재 환경 확인
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