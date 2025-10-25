import 'package:flutter/material.dart';
import '../data/user_repository.dart';
import '../utils/storage_helper.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final id = _idController.text.trim();
      final pw = _pwController.text.trim();

      print('🚀 로그인 시도: $id');

      // UserRepository.login을 호출하는 것으로 모든 로직을 위임합니다.
      final user = await UserRepository.login(id, pw);

      print('✅ 로그인 성공! 사용자: ${user.id}');
      UserRepository.printCurrentState();

      if (mounted) {
        // 사용자 역할에 따라 다른 화면으로 이동
        if (user.isAdmin) {
          Navigator.pushReplacementNamed(context, '/admin_main');
        } else {
          Navigator.pushReplacementNamed(context, '/main');
        }
      }
    } catch (e) {
      print('❌ 로그인 오류: $e');
      if (mounted) {
        String errorMessage = '로그인 실패: ${e.toString().replaceFirst("Exception: ", "")}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 서버 연결 테스트 함수
  Future<void> _testConnection() async {
    // DioClient가 초기화되었는지 확인 후 사용
    try {
      print('🔍 서버 연결 테스트 중...');
      // final response = await DioClient.get('/hello'); // DioClient를 통해 테스트
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text('서버 연결 성공! (${response.statusCode})'),
      //       backgroundColor: Colors.green,
      //     ),
      //   );
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서버 연결 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 인증 API 연결 테스트 함수
  Future<void> _testInspectionAPI() async {
    try {
      print('🔍 인증 API 연결 테스트 중...');
      final token = await StorageHelper.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('토큰이 없습니다. 먼저 로그인하세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // final response = await DioClient.get('/users/me');
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //       content: Text('인증 API 연결 성공! (${response.statusCode})'),
      //       backgroundColor: Colors.green,
      //     ),
      //   );
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('인증 API 연결 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 토큰 확인 함수 (디버깅용)
  Future<void> _checkToken() async {
    try {
      final token = await StorageHelper.getToken();
      final userModel = await StorageHelper.getUser();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('저장된 정보'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('토큰 존재: ${token != null && token.isNotEmpty}'),
                  if (token != null && token.isNotEmpty)
                    Text('토큰: ${_safeSubstring(token, 0, 20)}...'),
                  SizedBox(height: 8),
                  Text('사용자 정보 존재: ${userModel != null}'),
                  if (userModel != null) ...[
                    Text('사용자 ID: ${userModel.id}'),
                    Text('관리자 여부: ${userModel.isAdmin}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('[ERROR] _checkToken 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정보 확인 중 오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _safeSubstring(String str, int start, int end) {
    if (str.isEmpty) return '';
    int safeStart = start.clamp(0, str.length);
    int safeEnd = end.clamp(safeStart, str.length);
    return str.substring(safeStart, safeEnd);
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom - 48,
            ),
            child: IntrinsicHeight(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.home,
                      size: 80,
                      color: Colors.blue,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'DormMate',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      '기숙사 관리 시스템',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 32),
                    TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: '학번',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '학번을 입력해주세요';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _pwController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        '로그인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    if (const bool.fromEnvironment('dart.vm.product') == false) ...[
                      SizedBox(height: 16),
                      Text(
                        '개발용 기능',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _testConnection,
                              child: Text('연결 테스트'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _testInspectionAPI,
                              child: Text('인증 API'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _checkToken,
                              child: Text('토큰 확인'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await StorageHelper.clearAll();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('저장된 정보가 삭제되었습니다')),
                                );
                              },
                              child: Text('정보 삭제'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _idController.text = '1111';
                                _pwController.text = '1111';
                              },
                              child: Text('일반 사용자'),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _idController.text = 'admin001';
                                _pwController.text = 'admin123';
                              },
                              child: Text('관리자'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}