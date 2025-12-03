import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';
import '../api/api_config.dart';

/// 이미지 URL 생성 헬퍼 (baseUrl에서 /api 제거)
String _getImageUrl(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) return '';
  final hostUrl = ApiConfig.baseUrl.replaceAll('/api', '');

  // imagePath가 이미 'uploads/'로 시작하는지 확인
  String normalizedPath = imagePath;
  if (!normalizedPath.startsWith('uploads/') && !normalizedPath.startsWith('/uploads/')) {
    normalizedPath = 'uploads/$normalizedPath';
  }

  // 경로가 '/'로 시작하지 않으면 추가
  if (!normalizedPath.startsWith('/')) {
    normalizedPath = '/$normalizedPath';
  }

  return '$hostUrl$normalizedPath';
}

/// 관리자용 점호 상세 화면
class AdminInspectionDetailScreen extends StatefulWidget {
  final int inspectionId;
  final AdminInspectionModel? initialInspection;

  const AdminInspectionDetailScreen({
    super.key,
    required this.inspectionId,
    this.initialInspection,
  });

  @override
  State<AdminInspectionDetailScreen> createState() =>
      _AdminInspectionDetailScreenState();
}

class _AdminInspectionDetailScreenState
    extends State<AdminInspectionDetailScreen> {
  final InspectionService _inspectionService = InspectionService();

  AdminInspectionModel? _inspection;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialInspection != null) {
      _inspection = widget.initialInspection;
      _isLoading = false;
    } else {
      _loadInspectionDetail();
    }
  }

  /// 점호 상세 정보 로드
  Future<void> _loadInspectionDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
      await _inspectionService.getInspectionDetail(widget.inspectionId);

      if (response.success && response.inspection != null) {
        setState(() {
          _inspection = response.inspection;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? '점호 정보를 불러올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '점호 정보 로드 실패: $e';
        _isLoading = false;
      });
    }
  }

  /// 점호 반려 다이얼로그
  Future<void> _showRejectDialog() async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('점호 반려'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 점호 기록을 반려하시겠습니까?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '반려 시 해당 점호 기록이 삭제되며, 사용자에게 반려 사유가 전달됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: '반려 사유 *',
                hintText: '반려 사유를 입력하세요 (5자 이상)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().length < 5) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('반려 사유는 5자 이상 입력해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('반려'),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.trim().isNotEmpty) {
      await _rejectInspection(reasonController.text.trim());
    }
  }

  /// 점호 반려 처리
  Future<void> _rejectInspection(String rejectReason) async {
    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('반려 처리 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await _inspectionService.rejectInspection(
        widget.inspectionId,
        rejectReason,
      );

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('점호가 성공적으로 반려되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // 상세 화면 닫기 (true = 변경됨)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? '반려 처리 실패'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('반려 처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 점호 삭제 다이얼로그
  Future<void> _showDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('점호 삭제'),
          ],
        ),
        content: Text(
          '이 점호 기록을 삭제하시겠습니까?\n삭제된 기록은 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteInspection();
    }
  }

  /// 점호 삭제 처리
  Future<void> _deleteInspection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('삭제 처리 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success =
      await _inspectionService.deleteInspection(widget.inspectionId);

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('점호가 성공적으로 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // 상세 화면 닫기 (true = 변경됨)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 처리 실패'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 처리 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text('점호 상세'),
        centerTitle: true,
        actions: [
          if (_inspection != null) ...[
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'reject':
                    _showRejectDialog();
                    break;
                  case 'delete':
                    _showDeleteDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('반려'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('점호 정보를 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInspectionDetail,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_inspection == null) {
      return Center(
        child: Text('점호 정보가 없습니다.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInspectionDetail,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            SizedBox(height: 16),
            _buildUserInfoCard(),
            SizedBox(height: 16),
            _buildImageCard(),
            SizedBox(height: 16),
            _buildFeedbackCard(),
            SizedBox(height: 16),
            _buildActionButtons(),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 상태 카드
  Widget _buildStatusCard() {
    final statusColor =
    _inspection!.status == 'PASS' ? Colors.green : Colors.red;
    final statusText = _inspection!.status == 'PASS' ? '통과' : '실패';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${_inspection!.score}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_inspection!.isReInspection) ...[
                        SizedBox(width: 8),
                        Container(
                          padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '재검',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '점수: ${_inspection!.score}/10',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm')
                        .format(_inspection!.inspectionDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 사용자 정보 카드
  Widget _buildUserInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '사용자 정보',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            _buildInfoRow('이름', _inspection!.userName),
            _buildInfoRow('학번', _inspection!.userId),
            _buildInfoRow('방 번호', _inspection!.roomNumber),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 이미지 카드
  Widget _buildImageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '제출 사진',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _inspection!.imagePath.isNotEmpty
                  ? Image.network(
                _getImageUrl(_inspection!.imagePath),
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('이미지를 불러올 수 없습니다',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              )
                  : Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[200],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.no_photography,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('이미지가 없습니다',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 피드백 카드
  Widget _buildFeedbackCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.feedback, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'AI 피드백',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _inspection!.geminiFeedback ?? '피드백이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            if (_inspection!.adminComment != null &&
                _inspection!.adminComment!.isNotEmpty) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    '관리자 코멘트',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _inspection!.adminComment!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 액션 버튼들
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showRejectDialog,
            icon: Icon(Icons.cancel_outlined),
            label: Text('반려'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showDeleteDialog,
            icon: Icon(Icons.delete_outline),
            label: Text('삭제'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}