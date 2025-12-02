import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/allowed_user_service.dart';
import '../models/allowed_user.dart';

/// 관리자 - 허용 사용자 관리 화면
/// ✅ 수정: CRUD 완전 지원 (Update 기능 추가)
/// ✅ 수정: 등록된 사용자도 수정/삭제 가능
/// ✅ 수정: 리스트 표시 정보 변경 (이름/학번/거주 기숙사/거주 호실)
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

  // 검색 기능
  final TextEditingController _searchController = TextEditingController();
  List<AllowedUser> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadAllowedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _filteredUsers = response.users;
        _totalCount = response.totalCount;
        _registeredCount = response.registeredCount;
        _unregisteredCount = response.unregisteredCount;
      });
    } catch (e) {
      print('[ERROR] 허용 사용자 목록 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('허용 사용자 목록 로드 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 검색 필터링
  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final lowerQuery = query.toLowerCase();
          return user.name.toLowerCase().contains(lowerQuery) ||
              user.userId.toLowerCase().contains(lowerQuery) ||
              (user.dormitoryBuilding?.toLowerCase().contains(lowerQuery) ?? false) ||
              (user.roomNumber?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
    });
  }

  /// 엑셀 파일 업로드
  Future<void> _uploadExcelFile() async {
    try {
      // 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final file = result.files.first;
      final response = await _service.uploadExcelFile(file);

      // 결과 표시
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.upload_file, color: Colors.blue),
              SizedBox(width: 8),
              Text('업로드 결과'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('전체', response.totalCount, Colors.blue),
              _buildResultRow('성공', response.successCount, Colors.green),
              _buildResultRow('실패', response.failCount, Colors.red),
              if (response.errors.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('오류 목록:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.all(8),
                    itemCount: response.errors.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        response.errors[index],
                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                      ),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 파일 업로드 실패: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildResultRow(String label, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count건',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 사용자 추가 다이얼로그
  Future<void> _showAddUserDialog() async {
    final userIdController = TextEditingController();
    final nameController = TextEditingController();
    final dormitoryController = TextEditingController();
    final roomController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_add, color: Colors.purple),
            SizedBox(width: 8),
            Text('허용 사용자 추가'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userIdController,
                decoration: InputDecoration(
                  labelText: '학번 *',
                  hintText: '예: 20231234',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '이름 *',
                  hintText: '예: 홍길동',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: dormitoryController,
                decoration: InputDecoration(
                  labelText: '기숙사명 *',
                  hintText: '예: 행복관, 제1기숙사',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: roomController,
                decoration: InputDecoration(
                  labelText: '호실 *',
                  hintText: '예: 101, 202',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.door_front_door),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  hintText: '예: 010-1234-5678',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  hintText: '예: user@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 8),
              Text(
                '* 표시는 필수 입력 항목입니다',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
              // 필수 필드 검증
              if (userIdController.text.trim().isEmpty ||
                  nameController.text.trim().isEmpty ||
                  dormitoryController.text.trim().isEmpty ||
                  roomController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('필수 항목을 모두 입력해주세요')),
                );
                return;
              }

              try {
                await _service.addAllowedUser(
                  userId: userIdController.text.trim(),
                  name: nameController.text.trim(),
                  dormitoryBuilding: dormitoryController.text.trim(),
                  roomNumber: roomController.text.trim(),
                  phoneNumber: phoneController.text.trim().isEmpty
                      ? null : phoneController.text.trim(),
                  email: emailController.text.trim().isEmpty
                      ? null : emailController.text.trim(),
                );
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('사용자 추가 실패: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Text('추가'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _loadAllowedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('허용 사용자가 추가되었습니다')),
        );
      }
    }

    userIdController.dispose();
    nameController.dispose();
    dormitoryController.dispose();
    roomController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  /// ✅ 사용자 수정 다이얼로그
  /// ✅ 등록된 사용자도 수정 가능
  Future<void> _showEditUserDialog(AllowedUser user) async {
    final nameController = TextEditingController(text: user.name);
    final dormitoryController = TextEditingController(text: user.dormitoryBuilding ?? '');
    final roomController = TextEditingController(text: user.roomNumber ?? '');
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final emailController = TextEditingController(text: user.email ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('사용자 정보 수정'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 학번 (수정 불가)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('학번: ${user.userId}', style: TextStyle(fontWeight: FontWeight.bold)),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.isRegistered ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.isRegistered ? '등록완료' : '미등록',
                        style: TextStyle(
                          fontSize: 11,
                          color: user.isRegistered ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '이름 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: dormitoryController,
                decoration: InputDecoration(
                  labelText: '기숙사명 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: roomController,
                decoration: InputDecoration(
                  labelText: '호실 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.door_front_door),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
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
              // 필수 필드 검증
              if (nameController.text.trim().isEmpty ||
                  dormitoryController.text.trim().isEmpty ||
                  roomController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('필수 항목을 모두 입력해주세요')),
                );
                return;
              }

              try {
                await _service.updateAllowedUser(
                  userId: user.userId,
                  name: nameController.text.trim(),
                  dormitoryBuilding: dormitoryController.text.trim(),
                  roomNumber: roomController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  email: emailController.text.trim(),
                );
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('사용자 수정 실패: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('저장'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _loadAllowedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 정보가 수정되었습니다')),
        );
      }
    }

    nameController.dispose();
    dormitoryController.dispose();
    roomController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  /// ✅ 사용자 삭제
  /// ✅ 등록된 사용자도 삭제 가능 (경고 메시지 표시)
  Future<void> _deleteUser(AllowedUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('사용자 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다음 사용자를 허용 목록에서 삭제하시겠습니까?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이름: ${user.name}', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('학번: ${user.userId}'),
                  Text('기숙사: ${user.dormitoryBuilding ?? '-'}'),
                  Text('호실: ${user.roomNumber ?? '-'}'),
                ],
              ),
            ),
            // ✅ 등록된 사용자 삭제 시 경고 메시지
            if (user.isRegistered) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '이미 가입한 사용자입니다.\n삭제하면 해당 사용자의 허용 정보만 삭제됩니다.',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          // ✅ 등록 여부와 관계없이 삭제 버튼 활성화
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteAllowedUser(user.userId);
        await _loadAllowedUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('사용자가 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
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
            icon: Icon(Icons.upload_file),
            tooltip: '엑셀 파일 업로드',
            onPressed: _uploadExcelFile,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _loadAllowedUsers,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildStatistics(),
          _buildSearchBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_allowed_users',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '이름, 학번, 기숙사, 호실로 검색',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _filterUsers('');
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
        onChanged: _filterUsers,
      ),
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? '검색 결과가 없습니다'
                  : '등록된 허용 사용자가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? '다른 검색어로 시도해보세요'
                  : '엑셀 파일을 업로드하거나 개별 추가하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  /// ✅ 사용자 카드 - 표시 정보 변경: 이름/학번/거주 기숙사/거주 호실
  /// ✅ 등록된 사용자도 수정/삭제 가능
  Widget _buildUserCard(AllowedUser user) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditUserDialog(user),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // 아바타
              CircleAvatar(
                radius: 24,
                backgroundColor: user.isRegistered
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                child: Icon(
                  user.isRegistered ? Icons.check_circle : Icons.pending,
                  color: user.isRegistered ? Colors.green : Colors.orange,
                  size: 28,
                ),
              ),
              SizedBox(width: 12),

              // ✅ 사용자 정보 - 변경된 표시 순서
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 + 등록 상태
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: user.isRegistered
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.isRegistered ? '등록완료' : '미등록',
                            style: TextStyle(
                              fontSize: 10,
                              color: user.isRegistered ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // 학번
                    Text(
                      '학번: ${user.userId}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 2),
                    // ✅ 거주 기숙사 / 거주 호실
                    Row(
                      children: [
                        Icon(Icons.apartment, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: 4),
                        Text(
                          user.dormitoryBuilding ?? '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.door_front_door, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: 4),
                        Text(
                          user.roomNumber != null ? '${user.roomNumber}호' : '-',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ 액션 버튼들 - 등록 여부와 관계없이 모두 활성화
              Column(
                children: [
                  // 수정 버튼
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue, size: 20),
                    tooltip: '수정',
                    onPressed: () => _showEditUserDialog(user),
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(height: 4),
                  // ✅ 삭제 버튼 - 등록 여부와 관계없이 활성화
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    tooltip: '삭제',
                    onPressed: () => _deleteUser(user),
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}