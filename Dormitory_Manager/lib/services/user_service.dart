import '../models/user.dart';
import '../api/dio_client.dart';

class UserService {
  // 로그인
  static Future<User> login(String id, String password) async {
    try {
      final response = await DioClient.post('/auth/login', data: {
        'id': id,
        'password': password,
      });

      final responseData = response.data;
      if (responseData['success'] == true && responseData['token'] != null) {
        // 토큰 설정은 DioClient와 StorageHelper가 담당
        await DioClient.setToken(responseData['token']);
        return User.fromJson(responseData['user']);
      } else {
        throw Exception(responseData['error'] ?? '로그인에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('로그인 실패: $e');
    }
  }

  // 회원가입
  static Future<User> register(String id, String password, bool isAdmin) async {
    try {
      final response = await DioClient.post('/auth/register', data: {
        'id': id,
        'password': password,
        'isAdmin': isAdmin,
      });

      final responseData = response.data;
      if (responseData['success'] == true) {
        return User.fromJson(responseData['user']);
      } else {
        throw Exception(responseData['error'] ?? '회원가입에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('회원가입 실패: $e');
    }
  }

  // 로그아웃
  static Future<void> logout() async {
    try {
      // 서버에 로그아웃 요청 (필요 시)
      // await DioClient.post('/auth/logout');
      await DioClient.clearToken();
    } catch (e) {
      // 로그아웃 실패 시에도 로컬 토큰은 제거
      await DioClient.clearToken();
      throw Exception('로그아웃 실패: $e');
    }
  }

  // 현재 사용자 정보 조회 (수정된 부분)
  static Future<User> getCurrentUser() async {
    try {
      final response = await DioClient.get('/users/me');
      final responseData = response.data;
      // 'data' 키 안에 있는 실제 사용자 정보를 User.fromJson으로 넘겨줍니다.
      if (responseData['success'] == true && responseData['data'] != null) {
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['message'] ?? '사용자 정보 조회에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('사용자 정보 조회 실패: $e');
    }
  }

  // 사용자 정보 수정
  static Future<User> updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      final response = await DioClient.put('/users/me', data: userData);
      final responseData = response.data;
      if (responseData['success'] == true && responseData['data'] != null) {
        return User.fromJson(responseData['data']);
      } else {
        throw Exception(responseData['error'] ?? '사용자 정보 수정에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('사용자 정보 수정 실패: $e');
    }
  }
}