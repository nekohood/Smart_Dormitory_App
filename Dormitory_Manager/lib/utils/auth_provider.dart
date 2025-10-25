import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../utils/storage_helper.dart';
import '../api/dio_client.dart'; // DioClient 임포트

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  /// 초기화 - 앱 시작 시 호출
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    try {
      print('[DEBUG] AuthProvider: 초기화 시작');
      await DioClient.initialize(); // DioClient 초기화

      // 저장된 토큰 확인
      final token = await StorageHelper.getToken();
      if (token != null) {
        print('[DEBUG] AuthProvider: 저장된 토큰 발견, 자동 로그인 시도');
        // DioClient에 토큰이 이미 설정되었으므로 추가 설정 불필요

        // 저장된 사용자 정보 로드
        final savedUser = await StorageHelper.getUser();
        if (savedUser != null) {
          _currentUser = savedUser;
          print('[DEBUG] AuthProvider: 자동 로그인 성공 - ${savedUser.id}');
        } else {
          print('[DEBUG] AuthProvider: 토큰은 있으나 사용자 정보가 없음, 로그아웃 처리');
          await _clearAuthData();
        }
      }

      _isInitialized = true;
      print('[DEBUG] AuthProvider: 초기화 완료');

    } catch (e) {
      print('[ERROR] AuthProvider: 초기화 실패 - $e');
      await _clearAuthData();
    } finally {
      _setLoading(false);
    }
  }

  /// 로그인
  Future<bool> login(String id, String password) async {
    _setLoading(true);
    _clearError();

    try {
      print('[DEBUG] AuthProvider: 로그인 시도 - $id');

      // 계정 잠금 확인
      final isLocked = await StorageHelper.isAccountLocked(id);
      if (isLocked) {
        final remainingTime = await StorageHelper.getRemainingLockoutTime(id);
        _setError('계정이 잠겨있습니다. $remainingTime분 후 다시 시도해주세요.');
        return false;
      }

      // 로그인 시도
      final user = await UserService.login(id, password);

      // 성공 시 인증 데이터 저장
      await _saveAuthData(user);

      // 로그인 시도 횟수 초기화
      await StorageHelper.resetLoginAttempts(id);

      print('[DEBUG] AuthProvider: 로그인 성공 - ${user.id}');
      return true;

    } catch (e) {
      print('[ERROR] AuthProvider: 로그인 실패 - $e');

      // 로그인 실패 시 시도 횟수 증가
      await StorageHelper.incrementLoginAttempts(id);

      _setError('로그인 실패: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  /// 회원가입
  Future<bool> register(String id, String password, bool isAdmin) async {
    _setLoading(true);
    _clearError();

    try {
      print('[DEBUG] AuthProvider: 회원가입 시도 - $id');

      final user = await UserService.register(id, password, isAdmin);

      // 회원가입 성공 시 바로 로그인 처리되지는 않으므로, 로그인 화면으로 유도
      print('[DEBUG] AuthProvider: 회원가입 성공 - ${user.id}');
      return true;

    } catch (e) {
      print('[ERROR] AuthProvider: 회원가입 실패 - $e');
      _setError('회원가입 실패: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  /// 로그아웃
  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      print('[DEBUG] AuthProvider: 로그아웃 시작');

      // 서버에 로그아웃 요청
      await UserService.logout();

      // 인증 데이터 삭제
      await _clearAuthData();

      print('[DEBUG] AuthProvider: 로그아웃 완료');

    } catch (e) {
      print('[ERROR] AuthProvider: 로그아웃 중 오류 - $e');
      // 오류가 발생해도 로컬 데이터는 삭제
      await _clearAuthData();

    } finally {
      _setLoading(false);
    }
  }

  /// 사용자 정보 업데이트
  Future<bool> updateUser(Map<String, dynamic> updates) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      print('[DEBUG] AuthProvider: 사용자 정보 업데이트');

      final updatedUser = await UserService.updateUser(_currentUser!.id, updates);

      _currentUser = updatedUser;
      await StorageHelper.saveUser(updatedUser);

      notifyListeners();
      print('[DEBUG] AuthProvider: 사용자 정보 업데이트 성공');
      return true;

    } catch (e) {
      print('[ERROR] AuthProvider: 사용자 정보 업데이트 실패 - $e');
      _setError('사용자 정보 업데이트 실패: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  /// 비밀번호 변경
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      print('[DEBUG] AuthProvider: 비밀번호 변경');
      // UserService에는 비밀번호 변경 함수가 없으므로 직접 API 호출
      await DioClient.put('/users/me/password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });

      print('[DEBUG] AuthProvider: 비밀번호 변경 성공');
      return true;

    } catch (e) {
      print('[ERROR] AuthProvider: 비밀번호 변경 실패 - $e');
      _setError('비밀번호 변경 실패: $e');
      return false;

    } finally {
      _setLoading(false);
    }
  }

  /// 현재 사용자 정보 새로고침
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;

    try {
      print('[DEBUG] AuthProvider: 사용자 정보 새로고침');

      final updatedUser = await UserService.getCurrentUser();
      _currentUser = updatedUser;
      await StorageHelper.saveUser(updatedUser);

      notifyListeners();
      print('[DEBUG] AuthProvider: 사용자 정보 새로고침 완료');

    } catch (e) {
      print('[ERROR] AuthProvider: 사용자 정보 새로고침 실패 - $e');

      // 인증 오류인 경우 로그아웃 처리
      if (e.toString().contains('401') || e.toString().contains('인증')) {
        await _clearAuthData();
      }
    }
  }

  // =============================================================================
  // Private 메서드들
  // =============================================================================

  /// 인증 데이터 저장
  Future<void> _saveAuthData(User user) async {
    _currentUser = user;
    await StorageHelper.saveUser(user);
    notifyListeners();
  }

  /// 인증 데이터 삭제
  Future<void> _clearAuthData() async {
    if (_currentUser != null) {
      await StorageHelper.clearUserData(_currentUser!.id);
    } else {
      await StorageHelper.clearAll();
    }
    await DioClient.clearToken();
    _currentUser = null;
    notifyListeners();
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 에러 메시지 설정
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// 에러 메시지 초기화
  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}