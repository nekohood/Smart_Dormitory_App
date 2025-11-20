import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/allowed_user_service.dart';
import '../models/allowed_user.dart';

/// 관리자 - 허용 사용자 관리 화면
class AdminAllowedUsersScreen extends StatefulWidget {
  const AdminAllowedUsersScreen({super.key});

  @override
  State<AdminAllowedUsersScreen> createState() => _AdminAllowedUsersScreenState();
}

class _AdminAllowedUsersScreenState extends State<AdminAllowedUsersScreen> {
  final AllowedUserService _service = AllowedUserService();
  
  List<AllowedUser> _users = [];
  bool _isLoading = false;
  int _totalCount = 0;
  int _registeredCount = 0;
  int _unregisteredCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllowedUsers();
  }

  /// 허용 사용자 목록 로드
  Future<void> _loadAllowedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _service.getAllAllowedUsers();
      
      setState(() {
        _users = response.users;
        _totalCount = response.totalCount;
        _registeredCount = response.registeredCount;
        _unregisteredCount = response.unregisteredCount;
      });
    } catch (e) {
      print('[ERROR] 허용 사용자 목록 로드 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('허용 사용자 목록 로드 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 엑셀 파일 업로드
  Future<void> _uploadExcelFile() async {
    try {
      // 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return;

      setState(() {
        _isLoading = true;
      });

      // 파일 업로드
      final uploadResult = await _service.uploadExcelFile(result.files.first);

      // 결과 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('업로드 결과'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전체: ${uploadResult.totalCount}건'),
              Text('성공: ${uploadResult.successCount}건',
                style: TextStyle(color: Colors.green)),
              Text('실패: ${uploadResult.failCount}건',
                style: TextStyle(color: Colors.red)),
              if (uploadResult.errors.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('오류 내역:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  constraints: BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
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

      // 목록 새로고침
      await _loadAllowedUsers();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('엑셀 파일 업로드 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 개별 사용자 추가 다이얼로그
  Future<void> _showAddUserDialog() async {
    final userIdController = TextEditingController();
    final nameController = TextEditingController();
    final roomController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('허용 사용자 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdController,
                decoration: InputDecoration(
                  labelText: '학번 *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '이름 *',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: roomController,
                decoration: InputDecoration(
                  labelText: '호실',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (userIdController.text.isEmpty || nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('학번과 이름은 필수 항목입니다')),
                );
                return;
              }

              try {
                await _service.addAllowedUser(
                  userId: userIdController.text,
                  name: nameController.text,
                  roomNumber: roomController.text.isEmpty ? null : roomController.text,
                  phoneNumber: phoneController.text.isEmpty ? null : phoneController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                );
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('사용자 추가 실패: $e')),
                );
              }
            },
            child: Text('추가'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _loadAllowedUsers();
    }

    userIdController.dispose();
    nameController.dispose();
    roomController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  /// 사용자 삭제
  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용자 삭제'),
        content: Text('이 사용자를 허용 목록에서 삭제하시겠습니까?\n\n이미 등록된 사용자는 삭제할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteAllowedUser(userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사용자가 삭제되었습니다')),
      );

      await _loadAllowedUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사용자 삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('허용 사용자 관리'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllowedUsers,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _uploadExcelFile,
            tooltip: '엑셀 업로드',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatistics(),
                Expanded(child: _buildUserList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: Icon(Icons.person_add),
        label: Text('개별 추가'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('전체', _totalCount.toString(), Colors.blue),
          _buildStatItem('등록 완료', _registeredCount.toString(), Colors.green),
          _buildStatItem('미등록', _unregisteredCount.toString(), Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              '등록된 허용 사용자가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              '엑셀 파일을 업로드하거나 개별 추가하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(AllowedUser user) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isRegistered 
              ? Colors.green.withOpacity(0.1) 
              : Colors.orange.withOpacity(0.1),
          child: Icon(
            user.isRegistered ? Icons.check_circle : Icons.pending,
            color: user.isRegistered ? Colors.green : Colors.orange,
          ),
        ),
        title: Row(
          children: [
            Text(
              user.name,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Text(
              user.userId,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.roomNumber != null)
              Text('호실: ${user.roomNumber}'),
            if (user.phoneNumber != null)
              Text('전화: ${user.phoneNumber}'),
            Text(
              user.isRegistered ? '등록 완료' : '미등록',
              style: TextStyle(
                color: user.isRegistered ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: !user.isRegistered
            ? IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteUser(user.userId),
              )
            : null,
      ),
    );
  }
}
