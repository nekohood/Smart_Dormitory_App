import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';
import '../utils/storage_helper.dart';

/// 점호 메인 화면
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  final InspectionService _inspectionService = InspectionService();
  final TextEditingController _roomNumberController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  bool _isLoading = true;
  bool _isSubmitting = false;
  TodayInspectionResponse? _todayStatus;
  List<InspectionModel> _recentInspections = [];

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await _initializeService();
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

  @override
  void dispose() {
    _roomNumberController.dispose();
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
          _roomNumberController.clear();
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
                size: 32,
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
                    inspection.getStatusMessage(),
                    style: TextStyle(
                      fontSize: 14,
                      color: inspection.getStatusColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          constraints: BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: inspection.getStatusColor().withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '점수',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${inspection.score}/10점',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: inspection.getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // AI 분석 결과
                if (inspection.geminiFeedback != null && inspection.geminiFeedback!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 20,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'AI 분석 결과',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      inspection.geminiFeedback!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // 관리자 코멘트가 있는 경우
                if (inspection.adminComment != null && inspection.adminComment!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 20,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '관리자 코멘트',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      inspection.adminComment!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 16),

                // 제출 정보
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '제출 정보',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('방 번호:', style: TextStyle(fontSize: 13)),
                          Text(inspection.roomNumber, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('제출 시간:', style: TextStyle(fontSize: 13)),
                          Text(
                            DateFormat('MM-dd HH:mm').format(inspection.inspectionDate),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
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
                isCompleted ? Icons.check_circle : Icons.schedule,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 점호 상태',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isCompleted ? '오늘 점호가 완료되었습니다.' : '오늘 점호가 아직 완료되지 않았습니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isCompleted && _todayStatus?.inspection != null) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _todayStatus!.inspection!.getStatusColor(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_todayStatus!.inspection!.getStatusMessage()} - ${_todayStatus!.inspection!.scoreText}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
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
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            // 방 번호 입력
            TextField(
              controller: _roomNumberController,
              decoration: InputDecoration(
                labelText: '방 번호',
                hintText: '방 번호를 입력하세요',
                prefixIcon: Icon(Icons.home),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),

            SizedBox(height: 16),

            // 이미지 선택
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: _selectedImageBytes != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                  ),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '방 사진 촬영',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '탭하여 사진을 선택하세요',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

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
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('제출 중...'),
                  ],
                )
                    : Text(
                  '점호 제출',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '최근 점호 기록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),

            if (_recentInspections.isEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '아직 점호 기록이 없습니다',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_recentInspections.map((inspection) => _buildInspectionItem(inspection))),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionItem(InspectionModel inspection) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: inspection.getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              inspection.isPassed ? Icons.check_circle : Icons.warning,
              color: inspection.getStatusColor(),
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '방 ${inspection.roomNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: inspection.getStatusColor(),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        inspection.getStatusMessage(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inspection.getFormattedDate(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      inspection.scoreText,
                      style: TextStyle(
                        color: inspection.getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}