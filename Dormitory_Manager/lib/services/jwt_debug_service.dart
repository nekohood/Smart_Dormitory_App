import 'dart:convert';
import '../utils/storage_helper.dart';
import '../api/dio_client.dart';

class JwtDebugService {
  /// JWT 토큰 권한 정보 디버깅
  static Future<void> debugTokenAuthority() async {
    try {
      print('[DEBUG] === JWT 토큰 권한 정보 디버깅 ===');

      // 1. 저장된 토큰 가져오기
      final token = await StorageHelper.getToken();
      if (token == null) {
        print('[ERROR] 저장된 토큰이 없습니다');
        return;
      }

      // 2. JWT 페이로드 디코딩
      final payload = _decodeJwtPayload(token);
      if (payload != null) {
        print('[DEBUG] 사용자 ID: ${payload['sub']}');
        print('[DEBUG] 관리자 여부: ${payload['isAdmin']}');
        print('[DEBUG] 발급 시간: ${DateTime.fromMillisecondsSinceEpoch((payload['iat'] ?? 0) * 1000)}');
        print('[DEBUG] 만료 시간: ${DateTime.fromMillisecondsSinceEpoch((payload['exp'] ?? 0) * 1000)}');

        // 3. 서버에서 토큰 검증
        try {
          final response = await DioClient.post('/auth/validate');
          print('[DEBUG] 서버 검증 결과: ${response.data}');

          if (response.data['valid'] == true) {
            print('[✅] 토큰이 서버에서 유효함');
            print('[DEBUG] 서버 인식 사용자: ${response.data['userId']}');
            print('[DEBUG] 서버 인식 관리자: ${response.data['isAdmin']}');
          } else {
            print('[❌] 서버에서 토큰이 무효함: ${response.data['error']}');
          }

        } catch (e) {
          print('[ERROR] 서버 토큰 검증 실패: $e');
        }

        // 4. 권한 시뮬레이션
        final isAdmin = payload['isAdmin'] == true;
        print('[DEBUG] === 권한 시뮬레이션 ===');
        print('[DEBUG] 일반 사용자 권한: ${!isAdmin ? '✅' : '❌'}');
        print('[DEBUG] 관리자 권한: ${isAdmin ? '✅' : '❌'}');
        print('[DEBUG] 서류 제출 권한: ${!isAdmin || isAdmin ? '✅' : '❌'}'); // 모든 인증된 사용자
        print('[DEBUG] 서류 상태 변경 권한: ${isAdmin ? '✅' : '❌'}'); // 관리자만

      } else {
        print('[ERROR] JWT 토큰 디코딩 실패');
      }

    } catch (e) {
      print('[ERROR] JWT 권한 디버깅 실패: $e');
    }
  }

  /// JWT 페이로드 디코딩
  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1];

      // Base64 패딩 추가
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          return null;
      }

      final bytes = base64Url.decode(payload);
      final jsonString = utf8.decode(bytes);
      return json.decode(jsonString);

    } catch (e) {
      print('[ERROR] JWT 디코딩 실패: $e');
      return null;
    }
  }

  /// 현재 사용자의 권한으로 API 테스트
  static Future<void> testApiPermissions() async {
    print('[DEBUG] === API 권한 테스트 ===');

    // 1. 토큰 검증 테스트
    await _testEndpoint('POST', '/auth/validate', '토큰 검증');

    // 2. 서류 조회 테스트 (인증된 사용자)
    await _testEndpoint('GET', '/documents', '서류 목록 조회');

    // 3. 서류 제출 테스트 (인증된 사용자)
    await _testEndpoint('POST', '/documents', '서류 제출', data: {
      'title': '테스트 서류',
      'content': '권한 테스트용',
      'category': '기타',
      'writerId': '테스트',
      'status': '대기',
      'submittedAt': DateTime.now().toIso8601String(),
    });

    // 4. 공지사항 조회 테스트 (인증된 사용자)
    await _testEndpoint('GET', '/notices', '공지사항 조회');
  }

  static Future<void> _testEndpoint(String method, String endpoint, String description, {Map<String, dynamic>? data}) async {
    try {
      dynamic response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await DioClient.get(endpoint);
          break;
        case 'POST':
          response = await DioClient.post(endpoint, data: data);
          break;
        default:
          print('[SKIP] $description: 지원하지 않는 메서드 $method');
          return;
      }

      print('[✅] $description: 성공 (${response.statusCode})');

    } catch (e) {
      if (e.toString().contains('403')) {
        print('[❌] $description: 권한 없음 (403)');
      } else if (e.toString().contains('401')) {
        print('[❌] $description: 인증 필요 (401)');
      } else {
        print('[❌] $description: 실패 - $e');
      }
    }
  }
}