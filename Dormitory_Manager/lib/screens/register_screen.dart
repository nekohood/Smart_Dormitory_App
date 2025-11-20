import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/api_config.dart'; // ApiConfig 임포트
import '../services/allowed_user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AllowedUserService _allowedUserService = AllowedUserService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 텍스트 컨트롤러들
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();

  bool _isAdmin = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roomNumberController.dispose();
    super.dispose();
  }

  // 서버 URL 설정 (ApiConfig 사용)
  String get serverUrl => '${ApiConfig.baseUrl}/auth/register';

  // 이메일 형식 검증
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 전화번호 형식 검증
  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9-]{10,13}$').hasMatch(phone);
  }

  // 회원가입 처리
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ [신규] 일반 사용자인 경우 허용 목록 확인
      if (!_isAdmin) {
        print('[DEBUG] 허용 사용자 확인 중...');
        final isAllowed = await _allowedUserService.checkUserAllowed(_idController.text.trim());

        if (!isAllowed) {
          setState(() {
            _isLoading = false;
          });

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('회원가입 불가'),
              content: Text(
                  '회원가입이 허용되지 않은 학번입니다.\n\n'
                      '관리자에게 문의하여 허용 목록에 추가를 요청하세요.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('확인'),
                ),
              ],
            ),
          );
          return;
        }
        print('[DEBUG] 허용된 학번 확인 완료');
      }

      // 기존 회원가입 로직 계속 진행
      final requestData = {
        "id": _idController.text.trim(),
        "password": _passwordController.text.trim(),
        "isAdmin": _isAdmin,
        "name": _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        "email": _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        "phone": _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        "roomNumber": _roomNumberController.text.trim().isEmpty ? null : _roomNumberController.text.trim(),
      };

      print('🚀 회원가입 요청: ${requestData['id']}');
      print('📡 서버 URL: $serverUrl');

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestData),
      ).timeout(Duration(seconds: 15));

      print('📡 응답 상태: ${response.statusCode}');
      print('📝 응답 내용: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) { // 201 Created도 성공으로 처리
        if (mounted) {
          // 성공 다이얼로그 표시
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
              title: Text('회원가입 완료'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('환영합니다!'),
                  SizedBox(height: 8),
                  Text(
                    '${_idController.text.trim()}님의 계정이 성공적으로 생성되었습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // 다이얼로그 닫기
                    Navigator.of(context).pop(); // 회원가입 화면 닫기
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('로그인하러 가기'),
                ),
              ],
            ),
          );
        }
      } else {
        // 서버에서 온 상세 오류 메시지 처리
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        String errorMessage = "회원가입에 실패했습니다.";

        if (errorData.containsKey('error')) {
          errorMessage = errorData['error'];
        } else if (errorData.containsKey('message')) {
          errorMessage = errorData['message'];
        }

        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      print('❌ 회원가입 오류: $e');

      String errorMessage = '회원가입 실패';
      if (e.toString().contains('Connection refused')) {
        errorMessage = '서버에 연결할 수 없습니다. 서버가 실행 중인지 확인하세요.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = '서버 응답 시간이 초과되었습니다. 다시 시도해주세요.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = '네트워크 연결을 확인하세요.';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: '확인',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI 코드는 변경 없음)
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('회원가입'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더 섹션
                Icon(
                  Icons.person_add,
                  size: 64,
                  color: Colors.blue,
                ),
                SizedBox(height: 16),
                Text(
                  'DormMate 회원가입',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '기숙사 관리 시스템에 오신 것을 환영합니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 32),

                // 필수 정보 섹션
                _buildSectionHeader('필수 정보', Icons.star, Colors.red),
                SizedBox(height: 16),

                // 학번/아이디
                _buildTextFormField(
                  controller: _idController,
                  label: '학번',
                  hint: '학번을 입력하세요',
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '학번을 입력해주세요';
                    }
                    if (value.trim().length < 3) {
                      return '학번은 3자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 비밀번호
                _buildTextFormField(
                  controller: _passwordController,
                  label: '비밀번호',
                  hint: '비밀번호를 입력하세요',
                  prefixIcon: Icons.lock,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.trim().length < 4) {
                      return '비밀번호는 4자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 비밀번호 확인
                _buildTextFormField(
                  controller: _confirmPasswordController,
                  label: '비밀번호 확인',
                  hint: '비밀번호를 다시 입력하세요',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '비밀번호 확인을 입력해주세요';
                    }
                    if (value.trim() != _passwordController.text.trim()) {
                      return '비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),

                // 선택 정보 섹션
                _buildSectionHeader('선택 정보', Icons.info_outline, Colors.blue),
                SizedBox(height: 16),

                // 이름
                _buildTextFormField(
                  controller: _nameController,
                  label: '이름',
                  hint: '실명을 입력하세요 (선택)',
                  prefixIcon: Icons.badge,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && value.trim().length < 2) {
                      return '이름은 2자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 이메일
                _buildTextFormField(
                  controller: _emailController,
                  label: '이메일',
                  hint: 'example@domain.com (선택)',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && !_isValidEmail(value.trim())) {
                      return '올바른 이메일 형식을 입력해주세요';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 전화번호
                _buildTextFormField(
                  controller: _phoneController,
                  label: '전화번호',
                  hint: '010-1234-5678 (선택)',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty && !_isValidPhone(value.trim())) {
                      return '올바른 전화번호 형식을 입력해주세요';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 방번호
                _buildTextFormField(
                  controller: _roomNumberController,
                  label: '방번호',
                  hint: '예: 101호, A동 203호 (선택)',
                  prefixIcon: Icons.home,
                ),
                SizedBox(height: 24),

                // 관리자 계정 체크박스
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관리자 계정',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '관리자 권한이 필요한 경우에만 체크하세요',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAdmin,
                        onChanged: (value) {
                          setState(() {
                            _isAdmin = value;
                          });
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // 회원가입 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
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
                    '회원가입',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // 로그인 페이지로 이동
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    '이미 계정이 있으신가요? 로그인하기',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),

                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 섹션 헤더 위젯
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            margin: EdgeInsets.only(left: 12),
            color: color.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  // 텍스트 입력 필드 위젯
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}