import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/api_config.dart';
import '../services/allowed_user_service.dart';

/// 회원가입 화면
/// ✅ 수정: 관리자 코드 입력 기능 추가
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
  final TextEditingController _dormitoryBuildingController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _adminCodeController = TextEditingController();  // ✅ 신규

  bool _isAdmin = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureAdminCode = true;  // ✅ 신규

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _dormitoryBuildingController.dispose();
    _roomNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _adminCodeController.dispose();  // ✅ 신규
    super.dispose();
  }

  // 서버 URL 설정
  String get serverUrl => '${ApiConfig.baseUrl}/auth/register';

  // 이메일 형식 검증
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 전화번호 형식 검증
  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9-]{10,13}$').hasMatch(phone);
  }

  // 관리자 토글 시 거주 동/방 번호 자동 설정
  void _toggleAdminMode(bool value) {
    setState(() {
      _isAdmin = value;

      if (_isAdmin) {
        // 관리자로 변경 시 자동으로 "관리실" 설정
        _dormitoryBuildingController.text = "관리실";
        _roomNumberController.text = "관리실";
      } else {
        // 일반 사용자로 변경 시 필드 초기화
        _dormitoryBuildingController.clear();
        _roomNumberController.clear();
        _adminCodeController.clear();  // ✅ 관리자 코드도 초기화
      }
    });
  }

  // 회원가입 처리
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ✅ 관리자인 경우 관리자 코드 필수 확인
    if (_isAdmin && _adminCodeController.text.trim().isEmpty) {
      _showErrorDialog('관리자 코드를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 일반 사용자인 경우 허용 목록 확인
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

      // 회원가입 요청 데이터
      final requestData = {
        "id": _idController.text.trim(),
        "password": _passwordController.text.trim(),
        "name": _nameController.text.trim(),
        "isAdmin": _isAdmin,
      };

      // 관리자가 아닌 경우에만 거주 동/방 번호 추가
      if (!_isAdmin) {
        requestData["dormitoryBuilding"] = _dormitoryBuildingController.text.trim();
        requestData["roomNumber"] = _roomNumberController.text.trim();
      }

      // ✅ 관리자인 경우 관리자 코드 추가
      if (_isAdmin) {
        requestData["adminCode"] = _adminCodeController.text.trim();
      }

      // 선택 정보 (값이 있는 경우에만 추가)
      if (_emailController.text.trim().isNotEmpty) {
        requestData["email"] = _emailController.text.trim();
      }
      if (_phoneController.text.trim().isNotEmpty) {
        requestData["phoneNumber"] = _phoneController.text.trim();
      }

      print('🚀 회원가입 요청: ${requestData['id']} (관리자: $_isAdmin)');
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

      if (response.statusCode == 200 || response.statusCode == 201) {
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
                    '${_nameController.text.trim()}님의 계정이 성공적으로 생성되었습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (_isAdmin) ...[
                    SizedBox(height: 8),
                    Text(
                      '관리자 계정으로 등록되었습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.bold),
                    ),
                  ],
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
        // 서버 오류 메시지 처리
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        String errorMessage = errorData['message'] ?? "회원가입에 실패했습니다.";

        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print('❌ 오류 발생: $e');
      _showErrorDialog('회원가입 중 오류가 발생했습니다.\n\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error, color: Colors.red, size: 48),
        title: Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('회원가입'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 계정 유형 선택 카드
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isAdmin ? Colors.orange[100] : Colors.blue[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: _isAdmin ? Colors.orange : Colors.blue,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isAdmin ? '관리자 계정' : '일반 사용자',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: _isAdmin ? Colors.orange[900] : Colors.blue[900],
                                ),
                              ),
                              Text(
                                _isAdmin
                                    ? '관리자 코드가 필요합니다'
                                    : '거주 동과 방 번호를 입력해야 합니다',
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
                          onChanged: _toggleAdminMode,
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // 필수 정보 섹션
                _buildSectionHeader('필수 정보', Icons.star, Colors.red),
                SizedBox(height: 16),

                // 학번
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

                // 이름
                _buildTextFormField(
                  controller: _nameController,
                  label: '이름',
                  hint: '실명을 입력하세요',
                  prefixIcon: Icons.badge,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요';
                    }
                    if (value.trim().length < 2) {
                      return '이름은 2자 이상이어야 합니다';
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
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.length < 4) {
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
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '비밀번호 확인을 입력해주세요';
                    }
                    if (value != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),

                // ✅ 관리자 코드 입력 (관리자 선택 시에만 표시)
                if (_isAdmin) ...[
                  _buildSectionHeader('관리자 인증', Icons.admin_panel_settings, Colors.orange),
                  SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _adminCodeController,
                    label: '관리자 코드',
                    hint: '관리자 코드를 입력하세요',
                    prefixIcon: Icons.vpn_key,
                    obscureText: _obscureAdminCode,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureAdminCode ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureAdminCode = !_obscureAdminCode),
                    ),
                    validator: (value) {
                      if (_isAdmin && (value == null || value.trim().isEmpty)) {
                        return '관리자 코드를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '관리자 코드는 기존 관리자에게 문의하세요.',
                            style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],

                // 거주 정보 (일반 사용자만)
                if (!_isAdmin) ...[
                  _buildSectionHeader('거주 정보', Icons.home, Colors.green),
                  SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _dormitoryBuildingController,
                    label: '거주 동',
                    hint: '예: 인재동',
                    prefixIcon: Icons.apartment,
                    validator: (value) {
                      if (!_isAdmin && (value == null || value.trim().isEmpty)) {
                        return '거주 동을 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  _buildTextFormField(
                    controller: _roomNumberController,
                    label: '방 번호',
                    hint: '예: 101',
                    prefixIcon: Icons.meeting_room,
                    validator: (value) {
                      if (!_isAdmin && (value == null || value.trim().isEmpty)) {
                        return '방 번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                ],

                // 선택 정보 섹션
                _buildSectionHeader('선택 정보', Icons.info_outline, Colors.grey),
                SizedBox(height: 16),

                // 이메일
                _buildTextFormField(
                  controller: _emailController,
                  label: '이메일',
                  hint: 'example@email.com',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !_isValidEmail(value)) {
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
                  hint: '010-1234-5678',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !_isValidPhone(value)) {
                      return '올바른 전화번호 형식을 입력해주세요';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 32),

                // 회원가입 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAdmin ? Colors.orange : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Text(
                      _isAdmin ? '관리자로 가입하기' : '회원가입',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }
}