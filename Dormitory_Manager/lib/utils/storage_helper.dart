import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageHelper {
  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();


  // 저장 키 상수
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'current_user'; // 보안 저장소에 저장될 키
  static const String _lastLoginKey = 'last_login_time';
  static const String _loginAttemptsKey = 'login_attempts';
  static const String _lockoutTimeKey = 'lockout_time';
  static const String _appSettingsKey = 'app_settings';

  // 초기화
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // =============================================================================
  // JWT 토큰 관리 (개선됨)
  // =============================================================================

  /// JWT 토큰 저장
  static Future<bool> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      // 마지막 로그인 시간은 일반 정보이므로 SharedPreferences에 저장
      await init();
      await _prefs!.setString('last_login_time', DateTime.now().toIso8601String());
      print('[DEBUG] StorageHelper: 보안 토큰 저장 성공');
      return true;
    } catch (e) {
      print('[ERROR] StorageHelper: 보안 토큰 저장 실패 - $e');
      return false;
    }
  }

  /// JWT 토큰 가져오기
  static Future<String?> getToken() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null && await isTokenExpired(token)) {
        print('[DEBUG] StorageHelper: 토큰이 만료되어 제거합니다');
        await removeToken();
        return null;
      }
      return token;
    } catch (e) {
      print('[ERROR] StorageHelper: 보안 토큰 가져오기 실패 - $e');
      return null;
    }
  }

  /// JWT 토큰 제거
  static Future<bool> removeToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      return true;
    } catch (e) {
      print('[ERROR] StorageHelper: 보안 토큰 제거 실패 - $e');
      return false;
    }
  }

  /// 토큰 존재 여부 확인
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 토큰 만료 시간 체크 (간단한 JWT 디코딩)
  static Future<bool> isTokenExpired(String token) async {
    try {
      // JWT는 "header.payload.signature" 형식
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Base64 디코딩 (패딩 추가)
      String payload = parts[1];
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
          return true;
      }

      final decodedBytes = base64.decode(payload);
      final decodedPayload = utf8.decode(decodedBytes);
      final Map<String, dynamic> payloadMap = json.decode(decodedPayload);

      // exp 클레임 확인 (초 단위)
      if (payloadMap.containsKey('exp')) {
        final exp = payloadMap['exp'] as int;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return now >= exp;
      }

      return false; // exp 클레임이 없으면 만료되지 않은 것으로 처리
    } catch (e) {
      print('[ERROR] StorageHelper: 토큰 만료 확인 실패 - $e');
      return true; // 오류 발생 시 만료된 것으로 처리
    }
  }

  // =============================================================================
  // 사용자 정보 관리 (보안 강화)
  // =============================================================================

  /// 사용자 정보 저장 (FlutterSecureStorage 사용)
  static Future<bool> saveUser(User user) async {
    try {
      final userJson = json.encode(user.toJson());
      await _secureStorage.write(key: _userKey, value: userJson);
      print('[DEBUG] StorageHelper: 사용자 정보 보안 저장 성공 - ${user.id}');
      return true;
    } catch (e) {
      print('[ERROR] StorageHelper: 사용자 정보 보안 저장 실패 - $e');
      return false;
    }
  }

  /// 사용자 정보 가져오기 (FlutterSecureStorage 사용)
  static Future<User?> getUser() async {
    try {
      final userJson = await _secureStorage.read(key: _userKey);
      if (userJson != null) {
        final userMap = json.decode(userJson);
        return User.fromJson(userMap);
      }
      return null;
    } catch (e) {
      print('[ERROR] StorageHelper: 사용자 정보 보안 가져오기 실패 - $e');
      return null;
    }
  }

  /// 사용자 정보 제거 (FlutterSecureStorage 사용)
  static Future<bool> removeUser() async {
    try {
      await _secureStorage.delete(key: _userKey);
      return true;
    } catch (e) {
      print('[ERROR] StorageHelper: 사용자 정보 보안 제거 실패 - $e');
      return false;
    }
  }

  /// 현재 사용자가 관리자인지 확인
  static Future<bool> isCurrentUserAdmin() async {
    final user = await getUser();
    return user?.isAdmin ?? false;
  }

  // =============================================================================
  // 로그인 관련 정보 관리 (SharedPreferences)
  // =============================================================================

  /// 마지막 로그인 시간 가져오기
  static Future<DateTime?> getLastLoginTime() async {
    await init();
    try {
      final timeString = _prefs!.getString(_lastLoginKey);
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
      return null;
    } catch (e) {
      print('[ERROR] StorageHelper: 마지막 로그인 시간 가져오기 실패 - $e');
      return null;
    }
  }

  /// 자동 로그인 가능 여부 확인 (토큰이 있고 유효한 경우)
  static Future<bool> canAutoLogin() async {
    return await hasToken();
  }

  // =============================================================================
  // 보안 관련 기능
  // =============================================================================

  /// 로그인 시도 횟수 증가
  static Future<void> incrementLoginAttempts(String userId) async {
    await init();
    try {
      final key = '${_loginAttemptsKey}_$userId';
      final attempts = _prefs!.getInt(key) ?? 0;
      await _prefs!.setInt(key, attempts + 1);

      // 5회 실패 시 잠금 시간 설정
      if (attempts + 1 >= 5) {
        final lockoutKey = '${_lockoutTimeKey}_$userId';
        final lockoutTime = DateTime.now().add(const Duration(minutes: 30));
        await _prefs!.setString(lockoutKey, lockoutTime.toIso8601String());
      }
    } catch (e) {
      print('[ERROR] StorageHelper: 로그인 시도 횟수 증가 실패 - $e');
    }
  }

  /// 로그인 시도 횟수 초기화
  static Future<void> resetLoginAttempts(String userId) async {
    await init();
    try {
      final attemptsKey = '${_loginAttemptsKey}_$userId';
      final lockoutKey = '${_lockoutTimeKey}_$userId';
      await _prefs!.remove(attemptsKey);
      await _prefs!.remove(lockoutKey);
    } catch (e) {
      print('[ERROR] StorageHelper: 로그인 시도 횟수 초기화 실패 - $e');
    }
  }

  /// 계정 잠금 여부 확인
  static Future<bool> isAccountLocked(String userId) async {
    await init();
    try {
      final lockoutKey = '${_lockoutTimeKey}_$userId';
      final lockoutTimeString = _prefs!.getString(lockoutKey);

      if (lockoutTimeString != null) {
        final lockoutTime = DateTime.parse(lockoutTimeString);
        if (DateTime.now().isBefore(lockoutTime)) {
          return true;
        } else {
          // 잠금 시간이 지났으면 정보 제거
          await resetLoginAttempts(userId);
        }
      }
      return false;
    } catch (e) {
      print('[ERROR] StorageHelper: 계정 잠금 확인 실패 - $e');
      return false;
    }
  }

  /// 잠금 해제까지 남은 시간 (분)
  static Future<int> getRemainingLockoutTime(String userId) async {
    await init();
    try {
      final lockoutKey = '${_lockoutTimeKey}_$userId';
      final lockoutTimeString = _prefs!.getString(lockoutKey);

      if (lockoutTimeString != null) {
        final lockoutTime = DateTime.parse(lockoutTimeString);
        final remaining = lockoutTime.difference(DateTime.now()).inMinutes;
        return remaining > 0 ? remaining : 0;
      }
      return 0;
    } catch (e) {
      print('[ERROR] StorageHelper: 잠금 시간 계산 실패 - $e');
      return 0;
    }
  }

  // =============================================================================
  // 모든 데이터 관리
  // =============================================================================

  /// 모든 데이터 삭제 (로그아웃 시)
  static Future<void> clearAll() async {
    await init();
    try {
      // SharedPreferences와 SecureStorage 모두 클리어
      await _prefs!.clear();
      await _secureStorage.deleteAll();
      print('[DEBUG] StorageHelper: 모든 데이터 삭제 완료');
    } catch (e) {
      print('[ERROR] StorageHelper: 데이터 삭제 실패 - $e');
    }
  }

  /// 사용자별 데이터 삭제 (특정 사용자 로그아웃)
  static Future<void> clearUserData(String userId) async {
    await init();
    try {
      final attemptsKey = '${_loginAttemptsKey}_$userId';
      final lockoutKey = '${_lockoutTimeKey}_$userId';

      // SecureStorage에서 사용자 정보와 토큰 삭제
      await removeToken();
      await removeUser();

      // SharedPreferences에서 관련 정보 삭제
      await _prefs!.remove(_lastLoginKey);
      await _prefs!.remove(attemptsKey);
      await _prefs!.remove(lockoutKey);

      print('[DEBUG] StorageHelper: 사용자 데이터 삭제 완료 - $userId');
    } catch (e) {
      print('[ERROR] StorageHelper: 사용자 데이터 삭제 실패 - $e');
    }
  }

  // ... (이하 나머지 코드는 동일)
  // =============================================================================
  // 앱 설정 관리 (개선됨)
  // =============================================================================

  /// 앱 설정 저장
  static Future<bool> saveSetting(String key, dynamic value) async {
    await init();
    try {
      // 설정을 JSON 객체로 관리
      final settingsJson = _prefs!.getString(_appSettingsKey) ?? '{}';
      final settings = Map<String, dynamic>.from(json.decode(settingsJson));

      settings[key] = value;

      final success = await _prefs!.setString(_appSettingsKey, json.encode(settings));
      if (success) {
        print('[DEBUG] StorageHelper: 설정 저장 성공 - $key: $value');
      }
      return success;
    } catch (e) {
      print('[ERROR] StorageHelper: 설정 저장 실패 - $e');
      return false;
    }
  }

  /// 앱 설정 가져오기
  static Future<T?> getSetting<T>(String key, [T? defaultValue]) async {
    await init();
    try {
      final settingsJson = _prefs!.getString(_appSettingsKey) ?? '{}';
      final settings = Map<String, dynamic>.from(json.decode(settingsJson));

      if (settings.containsKey(key)) {
        final value = settings[key];
        if (value is T) {
          return value;
        }
      }

      return defaultValue;
    } catch (e) {
      print('[ERROR] StorageHelper: 설정 가져오기 실패 - $e');
      return defaultValue;
    }
  }

  /// 설정 제거
  static Future<bool> removeSetting(String key) async {
    await init();
    try {
      final settingsJson = _prefs!.getString(_appSettingsKey) ?? '{}';
      final settings = Map<String, dynamic>.from(json.decode(settingsJson));

      settings.remove(key);

      return await _prefs!.setString(_appSettingsKey, json.encode(settings));
    } catch (e) {
      print('[ERROR] StorageHelper: 설정 제거 실패 - $e');
      return false;
    }
  }

  /// 모든 설정 가져오기
  static Future<Map<String, dynamic>> getAllSettings() async {
    await init();
    try {
      final settingsJson = _prefs!.getString(_appSettingsKey) ?? '{}';
      return Map<String, dynamic>.from(json.decode(settingsJson));
    } catch (e) {
      print('[ERROR] StorageHelper: 모든 설정 가져오기 실패 - $e');
      return {};
    }
  }

  // =============================================================================
  // 캐시 관리
  // =============================================================================

  /// 캐시 데이터 저장 (만료 시간 포함)
  static Future<bool> setCacheData(String key, Map<String, dynamic> data, {Duration? expiry}) async {
    await init();
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiry': expiry != null ? DateTime.now().add(expiry).toIso8601String() : null,
      };

      return await _prefs!.setString('cache_$key', json.encode(cacheData));
    } catch (e) {
      print('[ERROR] StorageHelper: 캐시 저장 실패 - $e');
      return false;
    }
  }

  /// 캐시 데이터 가져오기
  static Future<Map<String, dynamic>?> getCacheData(String key) async {
    await init();
    try {
      final cacheJson = _prefs!.getString('cache_$key');
      if (cacheJson == null) return null;

      final cacheData = json.decode(cacheJson);

      // 만료 시간 확인
      if (cacheData['expiry'] != null) {
        final expiryTime = DateTime.parse(cacheData['expiry']);
        if (DateTime.now().isAfter(expiryTime)) {
          // 만료된 캐시 제거
          await _prefs!.remove('cache_$key');
          return null;
        }
      }

      return Map<String, dynamic>.from(cacheData['data']);
    } catch (e) {
      print('[ERROR] StorageHelper: 캐시 가져오기 실패 - $e');
      return null;
    }
  }

  /// 캐시 제거
  static Future<bool> removeCacheData(String key) async {
    await init();
    try {
      return await _prefs!.remove('cache_$key');
    } catch (e) {
      print('[ERROR] StorageHelper: 캐시 제거 실패 - $e');
      return false;
    }
  }

  /// 만료된 캐시 정리
  static Future<void> cleanupExpiredCache() async {
    await init();
    try {
      final keys = _prefs!.getKeys().where((key) => key.startsWith('cache_')).toList();

      for (final key in keys) {
        final cacheJson = _prefs!.getString(key);
        if (cacheJson != null) {
          try {
            final cacheData = json.decode(cacheJson);
            if (cacheData['expiry'] != null) {
              final expiryTime = DateTime.parse(cacheData['expiry']);
              if (DateTime.now().isAfter(expiryTime)) {
                await _prefs!.remove(key);
                print('[DEBUG] StorageHelper: 만료된 캐시 제거 - $key');
              }
            }
          } catch (e) {
            // 잘못된 형식의 캐시 데이터 제거
            await _prefs!.remove(key);
          }
        }
      }
    } catch (e) {
      print('[ERROR] StorageHelper: 캐시 정리 실패 - $e');
    }
  }

  // =============================================================================
  // 디버깅 및 유틸리티
  // =============================================================================

  /// 저장된 모든 키 출력 (디버깅용)
  static Future<void> printAllKeys() async {
    await init();
    try {
      final prefsKeys = _prefs!.getKeys();
      print('[DEBUG] SharedPreferences 저장된 키 목록');
      for (final key in prefsKeys) {
        print('  - $key');
      }

      final secureKeys = await _secureStorage.readAll();
      print('[DEBUG] SecureStorage 저장된 키 목록');
      for (final key in secureKeys.keys) {
        print('  - $key');
      }
    } catch (e) {
      print('[ERROR] StorageHelper: 키 목록 출력 실패 - $e');
    }
  }

  /// 저장소 상태 출력 (디버깅용)
  static Future<void> printStorageStatus() async {
    await init();
    try {
      final hasTokenValue = await hasToken();
      final user = await getUser();
      final lastLogin = await getLastLoginTime();

      print('[DEBUG] === StorageHelper 상태 ===');
      print('[DEBUG] 토큰 존재: $hasTokenValue');
      print('[DEBUG] 사용자 정보: ${user?.id ?? '없음'}');
      print('[DEBUG] 관리자 여부: ${user?.isAdmin ?? false}');
      print('[DEBUG] 마지막 로그인: ${lastLogin ?? '없음'}');
      print('[DEBUG] SharedPreferences 키 개수: ${_prefs!.getKeys().length}');
      print('[DEBUG] SecureStorage 키 개수: ${(await _secureStorage.readAll()).length}');
      print('[DEBUG] ========================');
    } catch (e) {
      print('[ERROR] StorageHelper: 상태 출력 실패 - $e');
    }
  }
}