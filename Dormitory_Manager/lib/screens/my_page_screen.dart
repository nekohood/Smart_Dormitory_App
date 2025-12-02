import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../api/dio_client.dart';
import '../data/user_repository.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/allowed_user_service.dart';
import '../utils/auth_provider.dart';
import 'admin_allowed_users_screen.dart';

/// 마이페이지 화면
/// ✅ 수정: 일반 사용자는 기숙사/호실 정보 수정 불가 (읽기 전용)
/// - 관리자가 허용 사용자 관리에서만 기숙사/호실 정보 수정 가능
/// ✅ 수정: 로그아웃 버튼 추가
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AllowedUserService _allowedUserService = AllowedUserService();

  // 사용자 정보 수정용 컨트롤러들 (이름, 이메일, 전화번호만 수정 가능)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // ✅ 기숙사/호실 정보는 표시용 (수정 불가)
  final TextEditingController _dormitoryBuildingController = TextEditingController();
  final TextEditingController _roomNumberController = TextEditingController();

  // 비밀번호 변경용 컨트롤러들
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUploadingExcel = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dormitoryBuildingController.dispose();
    _roomNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 사용자 정보 로드
  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await UserService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _nameController.text = user.name ?? '';
          _emailController.text = user.email ?? '';
          _phoneController.text = user.phoneNumber ?? '';
          _dormitoryBuildingController.text = user.dormitoryBuilding ?? '';
          _roomNumberController.text = user.roomNumber ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[ERROR] 사용자 정보 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보를 불러올 수 없습니다')),
        );
      }
    }
  }

  // 사용자 정보 수정 (이름, 이메일, 전화번호만)
  Future<void> _updateUserInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ 기숙사/호실 정보는 전송하지 않음 (서버에서도 무시됨)
      await DioClient.put('/users/me', data: {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        // dormitoryBuilding과 roomNumber는 전송하지 않음
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정보가 성공적으로 수정되었습니다')),
        );
        setState(() {
          _isEditing = false;
        });
        await _loadUserInfo();
      }
    } catch (e) {
      print('[ERROR] 사용자 정보 수정 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정보 수정에 실패했습니다')),
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

  // 비밀번호 변경
  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('새 비밀번호가 일치하지 않습니다')),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호는 6자 이상이어야 합니다')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await DioClient.put('/users/me/password', data: {
        'currentPassword': _currentPasswordController.text,
        'newPassword': _newPasswordController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호가 성공적으로 변경되었습니다')),
        );
        setState(() {
          _isChangingPassword = false;
        });
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      print('[ERROR] 비밀번호 변경 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('비밀번호 변경에 실패했습니다. 현재 비밀번호를 확인하세요.')),
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

  // 엑셀 파일 업로드 (관리자용)
  Future<void> _uploadStudentExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isUploadingExcel = true;
      });

      final file = result.files.first;
      final response = await _allowedUserService.uploadExcelFile(file);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('업로드 완료'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('전체: ${response.totalCount}건'),
                Text('성공: ${response.successCount}건', style: TextStyle(color: Colors.green)),
                Text('실패: ${response.failCount}건', style: TextStyle(color: Colors.red)),
                if (response.errors.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text('오류 목록:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    height: 100,
                    child: ListView.builder(
                      itemCount: response.errors.length,
                      itemBuilder: (context, index) => Text(
                        response.errors[index],
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ],
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
      print('[ERROR] 엑셀 업로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 파일 업로드에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingExcel = false;
        });
      }
    }
  }

  // 엑셀 양식 안내
  void _showExcelFormatGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('엑셀 양식 안내'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('엑셀 파일 형식 (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('필수 컬럼:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('• A열: 학번'),
              Text('• B열: 이름'),
              Text('• C열: 기숙사명'),
              Text('• D열: 호실번호'),
              SizedBox(height: 8),
              Text('선택 컬럼:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('• E열: 전화번호'),
              Text('• F열: 이메일'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '첫 번째 행은 헤더로 인식됩니다',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
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

  // 이메일 유효성 검사
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // 전화번호 유효성 검사
  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9\-]{9,15}$').hasMatch(phone.replaceAll(' ', ''));
  }

  // 날짜 포맷
  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('마이페이지')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('마이페이지')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('사용자 정보를 불러올 수 없습니다'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserInfo,
                child: Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('마이페이지'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUserInfo,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 프로필 헤더
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      _user!.isAdmin ? Icons.admin_panel_settings : Icons.person,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _user!.name ?? _user!.id,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _user!.isAdmin ? '관리자' : '일반 사용자',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // 관리자 전용 섹션
            if (_user!.isAdmin) ...[
              _buildSectionCard(
                title: '관리자 기능',
                icon: Icons.admin_panel_settings,
                iconColor: Colors.purple,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingExcel ? null : _uploadStudentExcel,
                        icon: _isUploadingExcel
                            ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Icon(Icons.upload_file),
                        label: Text(_isUploadingExcel ? '업로드 중...' : '학생 명단 엑셀 업로드'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showExcelFormatGuide,
                        icon: Icon(Icons.info_outline),
                        label: Text('엑셀 양식 안내'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: BorderSide(color: Colors.purple),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AdminAllowedUsersScreen()),
                          );
                        },
                        icon: Icon(Icons.manage_accounts),
                        label: Text('허용 사용자 목록 관리'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: BorderSide(color: Colors.purple),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
            ],

            // 개인정보 섹션
            _buildSectionCard(
              title: '개인정보',
              icon: Icons.person_outline,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ✅ 수정 가능한 필드들
                    _buildInfoField(
                      label: '이름',
                      controller: _nameController,
                      icon: Icons.badge_outlined,
                      enabled: _isEditing,
                      validator: (v) => (v != null && v.isNotEmpty && v.length < 2) ? '이름은 2자 이상이어야 합니다' : null,
                    ),
                    SizedBox(height: 16),
                    _buildInfoField(
                      label: '이메일',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      enabled: _isEditing,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v != null && v.isNotEmpty && !_isValidEmail(v)) ? '유효한 이메일을 입력해주세요' : null,
                    ),
                    SizedBox(height: 16),
                    _buildInfoField(
                      label: '전화번호',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v != null && v.isNotEmpty && !_isValidPhone(v)) ? '유효한 전화번호를 입력해주세요' : null,
                    ),
                    SizedBox(height: 16),

                    // ✅ 읽기 전용 필드들 (기숙사/호실)
                    _buildReadOnlyField(
                      label: '기숙사',
                      value: _user!.dormitoryBuilding ?? '미지정',
                      icon: Icons.apartment,
                    ),
                    SizedBox(height: 16),
                    _buildReadOnlyField(
                      label: '호실',
                      value: _user!.roomNumber ?? '미지정',
                      icon: Icons.door_front_door,
                    ),

                    // ✅ 기숙사/호실 안내 메시지
                    if (!_user!.isAdmin) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '기숙사 및 호실 정보는 관리자만 수정할 수 있습니다.',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 20),

                    // 수정 버튼들
                    if (!_isEditing && !_isChangingPassword)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: Icon(Icons.edit),
                          label: Text('개인정보 수정'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (_isEditing)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _isEditing = false);
                                _loadUserInfo();
                              },
                              child: Text('취소'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updateUserInfo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : Text('저장'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // 비밀번호 변경 섹션
            _buildSectionCard(
              title: '비밀번호 변경',
              icon: Icons.lock_outline,
              child: Column(
                children: [
                  if (!_isChangingPassword && !_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isChangingPassword = true),
                        icon: Icon(Icons.lock_reset),
                        label: Text('비밀번호 변경'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (_isChangingPassword)
                    Column(
                      children: [
                        _buildPasswordField(
                          label: '현재 비밀번호',
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrentPassword,
                          onToggleVisibility: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                        ),
                        SizedBox(height: 16),
                        _buildPasswordField(
                          label: '새 비밀번호',
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          onToggleVisibility: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                        ),
                        SizedBox(height: 16),
                        _buildPasswordField(
                          label: '새 비밀번호 확인',
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _isChangingPassword = false);
                                  _currentPasswordController.clear();
                                  _newPasswordController.clear();
                                  _confirmPasswordController.clear();
                                },
                                child: Text('취소'),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _changePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                                    : Text('변경'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // 계정 정보 섹션
            _buildSectionCard(
              title: '계정 정보',
              icon: Icons.info_outline,
              child: Column(
                children: [
                  _buildInfoRow('학번/ID', _user!.id),
                  Divider(height: 24),
                  _buildInfoRow('계정 유형', _user!.isAdmin ? '관리자' : '일반 사용자'),
                  if (_user!.createdAt != null) ...[
                    Divider(height: 24),
                    _buildInfoRow('가입일', _formatDate(_user!.createdAt!)),
                  ],
                ],
              ),
            ),
            SizedBox(height: 24),

            // ✅ 로그아웃 버튼 추가
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('로그아웃'),
                      content: Text('정말 로그아웃 하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('취소'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text('로그아웃'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    await authProvider.logout();
                    if (mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    }
                  }
                },
                icon: Icon(Icons.logout),
                label: Text('로그아웃'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 섹션 카드 위젯
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? Colors.blue),
              SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  // 정보 입력 필드 (수정 가능)
  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }

  // ✅ 읽기 전용 필드 (기숙사/호실 정보용)
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          // ✅ 잠금 아이콘으로 수정 불가 표시
          Icon(Icons.lock, color: Colors.grey[400], size: 18),
        ],
      ),
    );
  }

  // 비밀번호 입력 필드
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.orange, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  // 정보 표시 행
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}