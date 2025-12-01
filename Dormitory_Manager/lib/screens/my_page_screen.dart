import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../api/dio_client.dart';
import '../data/user_repository.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/allowed_user_service.dart';
import 'admin_allowed_users_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AllowedUserService _allowedUserService = AllowedUserService();

  // 사용자 정보 수정용 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
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
          _roomNumberController.text = user.roomNumber ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('사용자 정보를 불러오는데 실패했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 사용자 정보 업데이트
  Future<void> _updateUserInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'roomNumber': _roomNumberController.text.trim(),
      };

      final updatedUser = await UserService.updateUser(_user!.id, updateData);

      if (mounted) {
        setState(() {
          _user = updatedUser;
          _isEditing = false;
        });
        _showSuccessSnackBar('개인정보가 성공적으로 업데이트되었습니다.');
        await _loadUserInfo();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('개인정보 업데이트에 실패했습니다: $e');
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
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorSnackBar('모든 비밀번호 필드를 입력해주세요.');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showErrorSnackBar('새 비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await DioClient.put(
        '/users/me/password',
        data: {
          'oldPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
          'confirmPassword': _confirmPasswordController.text,
        },
      );
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
        _showSuccessSnackBar('비밀번호가 성공적으로 변경되었습니다.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('비밀번호 변경에 실패했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 로그아웃
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('로그아웃'),
        content: Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await UserRepository.logout();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        _showErrorSnackBar('로그아웃 중 오류가 발생했습니다.');
      }
    }
  }

  // ===============================================
  // 관리자 전용: 엑셀 파일 업로드
  // ===============================================
  Future<void> _uploadStudentExcel() async {
    try {
      // 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return;

      setState(() {
        _isUploadingExcel = true;
      });

      // 파일 업로드
      final uploadResult = await _allowedUserService.uploadExcelFile(result.files.first);

      // 결과 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('업로드 결과'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUploadResultRow('전체', uploadResult.totalCount, Colors.blue),
                SizedBox(height: 8),
                _buildUploadResultRow('성공', uploadResult.successCount, Colors.green),
                SizedBox(height: 8),
                _buildUploadResultRow('실패', uploadResult.failCount, Colors.red),
                if (uploadResult.errors.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text('오류 내역:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: uploadResult.errors.map((error) =>
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $error',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                              ),
                            )
                        ).toList(),
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
      if (mounted) {
        _showErrorSnackBar('엑셀 파일 업로드 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingExcel = false;
        });
      }
    }
  }

  Widget _buildUploadResultRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count건',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
// my_page_screen.dart 파일에서 _showExcelFormatGuide 메서드를
// 아래 코드로 교체하세요
// =====================================================

  /// 엑셀 양식 안내 다이얼로그
  /// ✅ 수정: 필수 필드 변경 (학번, 이름, 기숙사명, 호실번호)
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
              Text(
                '엑셀 파일(.xlsx)의 첫 번째 시트에 다음 형식으로 데이터를 입력해주세요:',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),

              // ✅ 필수 항목 안내
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.red, size: 16),
                        SizedBox(width: 4),
                        Text('필수 항목', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildColumnInfo('A열', '학번', '필수'),
                    _buildColumnInfo('B열', '이름', '필수'),
                    _buildColumnInfo('C열', '기숙사명', '필수'),
                    _buildColumnInfo('D열', '호실번호', '필수'),
                  ],
                ),
              ),
              SizedBox(height: 12),

              // ✅ 선택 항목 안내
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.grey[600], size: 16),
                        SizedBox(width: 4),
                        Text('선택 항목', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildColumnInfo('E열', '전화번호', '선택'),
                    _buildColumnInfo('F열', '이메일', '선택'),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // 주의사항
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '첫 번째 행은 헤더로 인식되어 건너뜁니다.',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // 예시 테이블
              Text(
                '예시:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.blue.withOpacity(0.1)),
                  columnSpacing: 10,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 36,
                  columns: [
                    DataColumn(label: Text('학번*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('이름*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('기숙사*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('호실*', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('전화번호', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                    DataColumn(label: Text('이메일', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                  ],
                  rows: [
                    DataRow(cells: [
                      DataCell(Text('20211234', style: TextStyle(fontSize: 11))),
                      DataCell(Text('홍길동', style: TextStyle(fontSize: 11))),
                      DataCell(Text('인재동', style: TextStyle(fontSize: 11))),
                      DataCell(Text('101', style: TextStyle(fontSize: 11))),
                      DataCell(Text('010-1234-5678', style: TextStyle(fontSize: 11))),
                      DataCell(Text('hong@email.com', style: TextStyle(fontSize: 11))),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('20215678', style: TextStyle(fontSize: 11))),
                      DataCell(Text('김철수', style: TextStyle(fontSize: 11))),
                      DataCell(Text('소망동', style: TextStyle(fontSize: 11))),
                      DataCell(Text('203', style: TextStyle(fontSize: 11))),
                      DataCell(Text('', style: TextStyle(fontSize: 11))),
                      DataCell(Text('', style: TextStyle(fontSize: 11))),
                    ]),
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

  Widget _buildColumnInfo(String column, String name, String required) {
    final isRequired = required == '필수';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              column,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blue[700]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isRequired ? Colors.red[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              required,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isRequired ? Colors.red[700] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9-]{10,13}$').hasMatch(phone);
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return Scaffold(appBar: AppBar(title: Text('마이페이지')), body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('마이페이지')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('사용자 정보를 불러올 수 없습니다.'),
            ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: Text('로그인 화면으로')),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('마이페이지'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!_isEditing && !_isChangingPassword)
            IconButton(icon: Icon(Icons.logout), onPressed: _logout, tooltip: '로그아웃'),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 헤더
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(_user!.isAdmin ? Icons.admin_panel_settings : Icons.person, size: 40, color: Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(_user!.id, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _user!.isAdmin ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _user!.isAdmin ? '관리자' : '일반 사용자',
                      style: TextStyle(color: _user!.isAdmin ? Colors.orange : Colors.blue, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // ===============================================
            // 관리자 전용: 학생 관리 섹션
            // ===============================================
            if (_user!.isAdmin) ...[
              _buildSectionCard(
                title: '학생 관리',
                icon: Icons.people_outline,
                iconColor: Colors.purple,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '학생 명단을 엑셀 파일로 업로드하여 가입 허용 목록을 관리할 수 있습니다.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),

                    // 엑셀 업로드 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingExcel ? null : _uploadStudentExcel,
                        icon: _isUploadingExcel
                            ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
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

                    // 양식 안내 버튼
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

                    // 허용 사용자 관리 화면으로 이동
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
                    _buildInfoField(label: '이름', controller: _nameController, icon: Icons.badge_outlined, enabled: _isEditing, validator: (v) => (v != null && v.isNotEmpty && v.length < 2) ? '이름은 2자 이상' : null),
                    SizedBox(height: 16),
                    _buildInfoField(label: '이메일', controller: _emailController, icon: Icons.email_outlined, enabled: _isEditing, keyboardType: TextInputType.emailAddress, validator: (v) => (v != null && v.isNotEmpty && !_isValidEmail(v)) ? '올바른 이메일 형식' : null),
                    SizedBox(height: 16),
                    _buildInfoField(label: '전화번호', controller: _phoneController, icon: Icons.phone_outlined, enabled: _isEditing, keyboardType: TextInputType.phone, validator: (v) => (v != null && v.isNotEmpty && !_isValidPhone(v)) ? '올바른 전화번호 형식' : null),
                    SizedBox(height: 16),
                    _buildInfoField(label: '방번호', controller: _roomNumberController, icon: Icons.home_outlined, enabled: _isEditing),
                    SizedBox(height: 20),
                    if (!_isEditing && !_isChangingPassword)
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => setState(() => _isEditing = true), icon: Icon(Icons.edit), label: Text('개인정보 수정'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12)))),
                    if (_isEditing)
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () { setState(() => _isEditing = false); _loadUserInfo(); }, child: Text('취소'))),
                        SizedBox(width: 12),
                        Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _updateUserInfo, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: _isLoading ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('저장'))),
                      ]),
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
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => setState(() => _isChangingPassword = true), icon: Icon(Icons.lock_reset), label: Text('비밀번호 변경'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12)))),
                  if (_isChangingPassword)
                    Column(children: [
                      _buildPasswordField(label: '현재 비밀번호', controller: _currentPasswordController, obscureText: _obscureCurrentPassword, onToggleVisibility: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword)),
                      SizedBox(height: 16),
                      _buildPasswordField(label: '새 비밀번호', controller: _newPasswordController, obscureText: _obscureNewPassword, onToggleVisibility: () => setState(() => _obscureNewPassword = !_obscureNewPassword)),
                      SizedBox(height: 16),
                      _buildPasswordField(label: '새 비밀번호 확인', controller: _confirmPasswordController, obscureText: _obscureConfirmPassword, onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                      SizedBox(height: 20),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () { setState(() => _isChangingPassword = false); _currentPasswordController.clear(); _newPasswordController.clear(); _confirmPasswordController.clear(); }, child: Text('취소'))),
                        SizedBox(width: 12),
                        Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _changePassword, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: _isLoading ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('변경'))),
                      ]),
                    ]),
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
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 섹션 카드 위젯
  Widget _buildSectionCard({required String title, required IconData icon, required Widget child, Color? iconColor}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
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

  // 정보 입력 필드
  Widget _buildInfoField({required String label, required TextEditingController controller, required IconData icon, bool enabled = true, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blue, width: 2)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }

  // 비밀번호 입력 필드
  Widget _buildPasswordField({required String label, required TextEditingController controller, required bool obscureText, required VoidCallback onToggleVisibility}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
        suffixIcon: IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey[600]), onPressed: onToggleVisibility),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.orange, width: 2)),
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