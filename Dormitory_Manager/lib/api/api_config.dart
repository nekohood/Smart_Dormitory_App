import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, kReleaseMode;

class ApiConfig {
  // Railway 서버 주소 (프로덕션)
  static const String _productionUrl = 'https://smartdormitoryapp-production-384e.up.railway.app/api';

  // 로컬 개발용 주소들
  static const String _androidEmulatorUrl = 'http://10.0.2.2:8080/api';
  static const String _desktopOrWebUrl = 'http://localhost:8080/api';

  // ✅ 로컬 개발 모드 스위치 (로컬 서버 테스트 시 true로 변경)
  static const bool _useLocalServer = false;

  static String get baseUrl {
    // ✅ Release 모드에서는 항상 프로덕션 URL 사용
    if (kReleaseMode) {
      print('✅ [ApiConfig] Release 모드 - Production URL 사용');
      return _productionUrl;
    }

    // ✅ Web 환경에서는 프로덕션 URL 사용 (로컬 모드가 아닐 때)
    if (kIsWeb) {
      if (_useLocalServer) {
        print('✅ [ApiConfig] Web (Debug/Local) - 로컬 서버 사용: $_desktopOrWebUrl');
        return _desktopOrWebUrl;
      }
      print('✅ [ApiConfig] Web (Debug) - Production URL 사용: $_productionUrl');
      return _productionUrl;
    }

    // ✅ 모바일/데스크톱 Debug 모드
    if (_useLocalServer) {
      // 로컬 서버 사용
      String url;
      if (defaultTargetPlatform == TargetPlatform.android) {
        url = _androidEmulatorUrl;
      } else {
        url = _desktopOrWebUrl;
      }
      print('✅ [ApiConfig] Debug (Local) - $currentEnvironment: $url');
      return url;
    }

    // ✅ Debug 모드에서도 프로덕션 URL 사용 (기본값)
    print('✅ [ApiConfig] Debug - Production URL 사용: $_productionUrl');
    return _productionUrl;
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
    final hostUrl = baseUrl.replaceAll('/api', '');
    return '$hostUrl/actuator/health';
  }

  // 현재 환경 확인
  static String get currentEnvironment {
    if (kReleaseMode) return 'Production (Release)';

    if (kIsWeb) return 'Web (Chrome)';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows Desktop';
      case TargetPlatform.linux:
        return 'Linux Desktop';
      case TargetPlatform.macOS:
        return 'macOS Desktop';
      default:
        return 'Unknown';
    }
  }

  // 현재 사용 중인 서버 모드
  static String get serverMode {
    if (kReleaseMode) return 'Production';
    if (_useLocalServer) return 'Local Development';
    return 'Production (Debug)';
  }
}