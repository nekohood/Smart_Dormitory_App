import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../models/user.dart';
import '../services/inspection_service.dart';
import '../utils/storage_helper.dart';
import '../utils/auth_provider.dart';

/// 점호 메인 화면
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final InspectionService _inspectionService = InspectionService();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _dormitoryBuildingController = TextEditingController(); // ✅ 거주 동 컨트롤러 추가
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  bool _isLoading = true;
  bool _isSubmitting = false;
  TodayInspectionResponse? _todayStatus;
  List<InspectionModel> _recentInspections = [];

  // ✅ 사용자 정보 (자동 기입용)
  User? _currentUser;
  String? _userName;
  String? _dormitoryBuilding;
  String? _roomNumber;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await _initializeService();
    await _loadUserInfo(); // ✅ 사용자 정보 로드 추가
    await _loadTodayStatus();
    await _loadRecentInspections();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeService() async {
    try {
      final token = await StorageHelper.getToken();
      if (token != null) {
        _inspectionService.setAuthToken(token);
      } else {
        _showErrorSnackBar('로그인 정보가 없습니다. 다시 로그인해주세요.');
      }
    } catch (e) {
      print('[ERROR] 점호 화면: 토큰 설정 실패: $e');
    }
  }

  // ✅ 사용자 정보 로드 (자동 기입용)
  Future<void> _loadUserInfo() async {
    try {
      final user = await StorageHelper.getUser();
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _userName = user.name;
          _dormitoryBuilding = user.dormitoryBuilding;
          _roomNumber = user.roomNumber;

          // ✅ 컨트롤러에 자동으로 값 설정
          _roomNumberController.text = user.roomNumber ?? '';
          _dormitoryBuildingController.text = user.dormitoryBuilding ?? '';
        });
        print('[DEBUG] 사용자 정보 로드 완료 - 이름: $_userName, 거주 동: $_dormitoryBuilding, 방 번호: $_roomNumber');
      }
    } catch (e) {
      print('[ERROR] 사용자 정보 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _dormitoryBuildingController.dispose(); // ✅ 거주 동 컨트롤러 dispose 추가
    super.dispose();
  }

  Future<void> _loadTodayStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await _inspectionService.getTodayInspection();
      if (mounted) {
        setState(() {
          _todayStatus = response;
        });
      }
    } catch (e) {
      _showErrorSnackBar('점호 상태를 확인할 수 없습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRecentInspections() async {
    try {
      final response = await _inspectionService.getMyInspections();
      if (response.success && mounted) {
        setState(() {
          // ✅ AdminInspectionModel을 InspectionModel로 변환
          _recentInspections = response.inspections
              .map((adminModel) => InspectionModel(
            id: adminModel.id,
            userId: adminModel.userId,
            roomNumber: adminModel.roomNumber,
            imagePath: adminModel.imagePath,
            score: adminModel.score,
            status: adminModel.status,
            geminiFeedback: adminModel.geminiFeedback,
            adminComment: adminModel.adminComment,
            isReInspection: adminModel.isReInspection,
            inspectionDate: adminModel.inspectionDate,
            createdAt: adminModel.createdAt,
          ))
              .take(5)
              .toList();
        });
      }
    } catch (e) {
      print('[ERROR] 최근 점호 기록 로드 실패: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = image.name;
          if (!kIsWeb) {
            _selectedImage = File(image.path);
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('이미지 처리 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _submitInspection() async {
    if (_selectedImageBytes == null) {
      _showErrorSnackBar('방 사진을 선택해주세요.');
      return;
    }
    if (_roomNumberController.text.trim().isEmpty) {
      _showErrorSnackBar('방 번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _inspectionService.submitInspection(
        _roomNumberController.text.trim(),
        _selectedImageBytes!,
        _selectedImageName ?? 'inspection_image.jpg',
      );

      if (response.success && response.inspection != null) {
        _showSuccessDialog(response);
        await _loadTodayStatus();
        await _loadRecentInspections();
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
          _selectedImageName = null;
          // ✅ 방 번호는 유지 (다음 제출 시에도 자동 입력 유지)
        });
      } else {
        _showErrorSnackBar(response.error ?? '점호 제출에 실패했습니다.');
      }
    } catch (e) {
      _showErrorSnackBar('점호 제출 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 개선된 성공 다이얼로그
  void _showSuccessDialog(InspectionResponse response) {
    final inspection = response.inspection!;

    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 방지
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: inspection.getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                inspection.isPassed ? Icons.check_circle : Icons.warning,
                color: inspection.getStatusColor(),
                size: 28,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '점호 제출 완료',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    inspection.isPassed ? '통과' : '재점호 필요',
                    style: TextStyle(
                      fontSize: 14,
                      color: inspection.getStatusColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 점수 표시
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: inspection.getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${inspection.score}점',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: inspection.getStatusColor(),
                      ),
                    ),
                    Text(
                      '/ 10점',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // AI 피드백
              if (inspection.geminiFeedback != null &&
                  inspection.geminiFeedback!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.smart_toy, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text(
                            'AI 피드백',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        inspection.geminiFeedback!,
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 12),

              // 상세 정보
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('방 번호:', style: TextStyle(fontSize: 13)),
                        Text(inspection.roomNumber,
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('제출 시간:', style: TextStyle(fontSize: 13)),
                        Text(
                          DateFormat('MM-dd HH:mm')
                              .format(inspection.inspectionDate),
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              '확인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('이미지 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('카메라로 촬영'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('점호'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('점호'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadTodayStatus();
              _loadRecentInspections();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTodayStatus();
          await _loadRecentInspections();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 오늘 점호 상태
              _buildTodayStatusCard(),
              SizedBox(height: 20),

              // 점호 제출 폼
              if (_todayStatus?.completed != true) _buildSubmissionForm(),

              SizedBox(height: 20),

              // 최근 점호 기록
              _buildRecentInspections(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatusCard() {
    bool isCompleted = _todayStatus?.completed ?? false;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isCompleted
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.orange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.pending,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 점호',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isCompleted ? '점호가 완료되었습니다.' : '점호를 제출해주세요.',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // ✅ 사용자 정보 표시 추가
                  if (_dormitoryBuilding != null || _roomNumber != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_dormitoryBuilding ?? ''} ${_roomNumber ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_todayStatus?.inspection != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _todayStatus!.inspection!.getStatusColor(),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_todayStatus!.inspection!.score}점',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '점호 제출',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // ✅ 거주 동 입력 필드 추가 (자동 입력, 읽기 전용)
            TextField(
              controller: _dormitoryBuildingController,
              readOnly: true, // 읽기 전용
              decoration: InputDecoration(
                labelText: '거주 동',
                hintText: '거주 동이 자동으로 입력됩니다',
                prefixIcon: Icon(Icons.apartment),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            SizedBox(height: 12),

            // ✅ 방 번호 입력 필드 (자동 입력)
            TextField(
              controller: _roomNumberController,
              decoration: InputDecoration(
                labelText: '방 번호',
                hintText: '방 번호가 자동으로 입력됩니다',
                prefixIcon: Icon(Icons.meeting_room),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                // ✅ 자동 입력된 경우 배경색 변경
                filled: _roomNumber != null,
                fillColor: _roomNumber != null ? Colors.blue[50] : null,
              ),
              keyboardType: TextInputType.text,
            ),

            // ✅ 자동 입력 안내 메시지
            if (_roomNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      '마이페이지 정보가 자동으로 입력되었습니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: 16),

            // 이미지 선택 영역
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImageBytes != null
                    ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _selectedImageBytes!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImage = null;
                            _selectedImageBytes = null;
                            _selectedImageName = null;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '방 사진을 선택해주세요',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '카메라로 촬영하거나 갤러리에서 선택',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // 제출 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInspection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  '점호 제출',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentInspections() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 점호 기록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        if (_recentInspections.isEmpty)
          Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '점호 기록이 없습니다',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _recentInspections.length,
            itemBuilder: (context, index) {
              final inspection = _recentInspections[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    inspection.getStatusColor().withOpacity(0.2),
                    child: Text(
                      '${inspection.score}',
                      style: TextStyle(
                        color: inspection.getStatusColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    DateFormat('yyyy-MM-dd HH:mm')
                        .format(inspection.inspectionDate),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '방 ${inspection.roomNumber} | ${inspection.isPassed ? "통과" : "재점호 필요"}',
                  ),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inspection.getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      inspection.isPassed ? 'PASS' : 'FAIL',
                      style: TextStyle(
                        color: inspection.getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}