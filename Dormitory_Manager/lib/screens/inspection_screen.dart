import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../models/inspection_settings.dart';
import '../models/user.dart';
import '../services/inspection_service.dart';
import '../services/inspection_settings_service.dart';
import '../utils/storage_helper.dart';

/// 점호 메인 화면
/// ✅ 수정: 점호 시간/날짜 체크 기능 추가
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final InspectionService _inspectionService = InspectionService();
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _dormitoryBuildingController = TextEditingController();
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

  // ✅ 신규: 점호 시간 체크 결과
  InspectionTimeCheckResult? _timeCheckResult;
  bool _isInspectionAllowed = false;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await _initializeService();
    await _loadUserInfo();
    await _checkInspectionTime();  // ✅ 점호 시간 체크 추가
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

          _roomNumberController.text = user.roomNumber ?? '';
          _dormitoryBuildingController.text = user.dormitoryBuilding ?? '';
        });
        print('[DEBUG] 사용자 정보 로드 완료 - 거주 동: $_dormitoryBuilding, 방 번호: $_roomNumber');
      }
    } catch (e) {
      print('[ERROR] 사용자 정보 로드 실패: $e');
    }
  }

  // ✅ 신규: 점호 시간 체크
  Future<void> _checkInspectionTime() async {
    try {
      print('[DEBUG] 점호 시간 체크 시작');
      final result = await InspectionSettingsService.checkInspectionTime();

      if (mounted) {
        setState(() {
          _timeCheckResult = result;
          _isInspectionAllowed = result.allowed;
        });
        print('[DEBUG] 점호 허용 여부: $_isInspectionAllowed, 메시지: ${result.message}');
      }
    } catch (e) {
      print('[ERROR] 점호 시간 체크 실패: $e');
      // 오류 시 기본적으로 허용
      if (mounted) {
        setState(() {
          _isInspectionAllowed = true;
        });
      }
    }
  }

  Future<void> _loadTodayStatus() async {
    try {
      final status = await _inspectionService.getTodayInspection();
      if (mounted) {
        setState(() {
          _todayStatus = status;
        });
      }
    } catch (e) {
      print('[ERROR] 점호 화면: 오늘 상태 로드 실패: $e');
    }
  }

  Future<void> _loadRecentInspections() async {
    try {
      final response = await _inspectionService.getMyInspections();
      if (response.success && mounted) {
        setState(() {
          // AdminInspectionModel을 InspectionModel로 변환
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
      print('[ERROR] 점호 화면: 최근 기록 로드 실패: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
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
    // ✅ 점호 시간 체크
    if (!_isInspectionAllowed) {
      _showErrorSnackBar(_timeCheckResult?.message ?? '점호 시간이 아닙니다.');
      return;
    }

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

  void _showSuccessDialog(InspectionResponse response) {
    final inspection = response.inspection!;

    showDialog(
      context: context,
      barrierDismissible: false,
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
                    inspection.isPassed ? '합격' : '불합격',
                    style: TextStyle(
                      fontSize: 14,
                      color: inspection.getStatusColor(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${inspection.score}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: inspection.getStatusColor(),
                    ),
                  ),
                  Text(
                    ' / 10점',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (inspection.geminiFeedback != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'AI 피드백',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('점호'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _checkInspectionTime();  // ✅ 새로고침 시 시간 체크
              await _loadTodayStatus();
              await _loadRecentInspections();
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await _checkInspectionTime();
          await _loadTodayStatus();
          await _loadRecentInspections();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 신규: 점호 시간 안내 배너
              _buildInspectionTimeBanner(),
              SizedBox(height: 16),
              _buildTodayStatusCard(),
              SizedBox(height: 16),
              _buildSubmissionForm(),
              SizedBox(height: 24),
              _buildRecentInspections(),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ 신규: 점호 시간 안내 배너
  Widget _buildInspectionTimeBanner() {
    if (_timeCheckResult == null) return SizedBox.shrink();

    final isAllowed = _timeCheckResult!.allowed;
    final message = _timeCheckResult!.message;
    final nextDate = _timeCheckResult!.nextInspectionDate;
    final daysUntil = _timeCheckResult!.daysUntilNext;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAllowed ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAllowed ? Colors.green[300]! : Colors.orange[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAllowed ? Icons.check_circle : Icons.schedule,
                color: isAllowed ? Colors.green[700] : Colors.orange[700],
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAllowed ? '점호 가능 시간입니다' : '점호 시간이 아닙니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAllowed ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isAllowed ? Colors.green[600] : Colors.orange[600],
            ),
          ),
          // ✅ 다음 점호 날짜 표시
          if (!isAllowed && nextDate != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 18, color: Colors.blue),
                  SizedBox(width: 6),
                  Text(
                    '다음 점호: ${DateFormat('M월 d일 (E)', 'ko').format(nextDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                  if (daysUntil != null && daysUntil > 0) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'D-$daysUntil',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard() {
    final isCompleted = _todayStatus?.completed ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.pending,
                color: isCompleted ? Colors.green : Colors.orange,
                size: 32,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 점호',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    isCompleted ? '점호가 완료되었습니다.' : '점호를 제출해주세요.',
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
    final isCompleted = _todayStatus?.completed ?? false;
    // ✅ 점호 불가 시 비활성화
    final canSubmit = _isInspectionAllowed && !isCompleted;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '점호 제출',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                // ✅ 점호 불가 시 상태 표시
                if (!_isInspectionAllowed)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Text(
                          '제출 불가',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            // ✅ 점호 불가 시 오버레이 표시
            Opacity(
              opacity: canSubmit ? 1.0 : 0.5,
              child: AbsorbPointer(
                absorbing: !canSubmit,
                child: Column(
                  children: [
                    // 거주 동 입력 필드
                    TextField(
                      controller: _dormitoryBuildingController,
                      readOnly: true,
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

                    // 방 번호 입력 필드
                    TextField(
                      controller: _roomNumberController,
                      decoration: InputDecoration(
                        labelText: '방 번호',
                        hintText: '방 번호가 자동으로 입력됩니다',
                        prefixIcon: Icon(Icons.meeting_room),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: _roomNumber != null,
                        fillColor: _roomNumber != null ? Colors.grey[100] : null,
                      ),
                    ),
                    SizedBox(height: 16),

                    // 이미지 선택 영역
                    GestureDetector(
                      onTap: () => _showImageSourceDialog(),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: _selectedImageBytes != null
                            ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
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
                        onPressed: (_isSubmitting || !canSubmit) ? null : _submitInspection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmit ? Colors.blue : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          canSubmit
                              ? '점호 제출'
                              : (_isInspectionAllowed ? '이미 제출 완료' : '점호 시간이 아닙니다'),
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.green),
                title: Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
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
                child: Text(
                  '점호 기록이 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          ...(_recentInspections.map((inspection) => _buildInspectionItem(inspection))),
      ],
    );
  }

  Widget _buildInspectionItem(InspectionModel inspection) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: inspection.getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            inspection.isPassed ? Icons.check : Icons.close,
            color: inspection.getStatusColor(),
          ),
        ),
        title: Text(
          DateFormat('yyyy년 M월 d일').format(inspection.inspectionDate),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '방 ${inspection.roomNumber}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: inspection.getStatusColor(),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${inspection.score}점',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _dormitoryBuildingController.dispose();
    super.dispose();
  }
}