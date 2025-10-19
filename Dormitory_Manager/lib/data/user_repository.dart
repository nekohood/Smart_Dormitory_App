import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../api/dio_client.dart';
import '../utils/storage_helper.dart';
import '../utils/string_utils.dart';

class UserRepository {
  static User? _currentUser;
  static String? _currentToken;

  static User? get currentUser => _currentUser;
  static String? get currentToken => _currentToken;

  static Future<User> login(String id, String password) async {
    try {
      final user = await UserService.login(id, password);

      // DioClient에서 토큰 가져오기 (Authorization 헤더에서 추출)
      final token = await StorageHelper.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('로그인 후 토큰을 가져오지 못했습니다');
      }
      await setUser(user, token);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout() async {
    try {
      await UserService.logout();
      await clearUser();
    } catch (e) {
      await clearUser();
      rethrow;
    }
  }

  static Future<void> setUser(User user, String token) async {
    _currentUser = user;
    _currentToken = token;
    await DioClient.setToken(token);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', user.id);
      await prefs.setBool('is_admin', user.isAdmin);
      printCurrentState();
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> loadStoredUser() async {
    try {
      final token = await StorageHelper.getToken();
      final user = await StorageHelper.getUser(); // SecureStorage에서 전체 User 객체 로드

      if (user != null && token != null && token.isNotEmpty) {
        _currentUser = user;
        _currentToken = token;
        await DioClient.setToken(token);
        print('[DEBUG] 저장된 사용자 정보 로드 완료: ${user.id}');
        printCurrentState();
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getStoredToken() async {
    return await StorageHelper.getToken();
  }

  static Future<void> updateToken(String token) async {
    _currentToken = token;
    await DioClient.setToken(token);
  }

  static Future<void> clearUser() async {
    _currentUser = null;
    _currentToken = null;
    await DioClient.clearToken();
    await StorageHelper.clearAll();
  }

  static bool isAdmin() {
    return _currentUser?.isAdmin ?? false;
  }

  static bool isLoggedIn() {
    return _currentUser != null && _currentToken != null && _currentToken!.isNotEmpty;
  }

  static void printCurrentState() {
    print('[DEBUG] === UserRepository 현재 상태 ===');
    print('[DEBUG] 사용자: ${_currentUser?.id ?? 'null'}');
    print('[DEBUG] 관리자: ${_currentUser?.isAdmin ?? 'false'}');
    print('[DEBUG] 토큰: ${_currentToken != null ? 'O' : 'X'}');
    print('[DEBUG] 로그인 상태: ${isLoggedIn()}');
    print('[DEBUG] ==============================');
  }
}