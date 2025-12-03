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
/// ✅ 수정: 수동 FAIL/PASS 처리 기능 추가
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

  /// ✅ 신규 추가: 수동 FAIL 처리 다이얼로그
  Future<void> _showManualFailDialog() async {
    final TextEditingController commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.thumb_down, color: Colors.orange),
            SizedBox(width: 8),
            Text('수동 FAIL 처리'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 점호를 FAIL 처리하시겠습니까?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '점호 기록은 삭제되지 않으며, 상태만 FAIL로 변경됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: '관리자 코멘트 (선택)',
                hintText: 'FAIL 처리 사유를 입력하세요',
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
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('FAIL 처리'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _processManualFail(commentController.text.trim());
    }
  }

  /// ✅ 신규 추가: 수동 FAIL 처리 실행
  Future<void> _processManualFail(String? adminComment) async {
    _showLoadingDialog('FAIL 처리 중...');

    try {
      final response = await _inspectionService.manualFailInspection(
        widget.inspectionId,
        adminComment?.isNotEmpty == true ? adminComment : null,
      );

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (response.success && response.inspection != null) {
        setState(() {
          _inspection = response.inspection;
        });
        _showSuccessSnackBar('점호가 FAIL 처리되었습니다.');
      } else {
        _showErrorSnackBar(response.message ?? 'FAIL 처리 실패');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('FAIL 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// ✅ 신규 추가: 수동 PASS 처리 다이얼로그
  Future<void> _showManualPassDialog() async {
    final TextEditingController commentController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.thumb_up, color: Colors.green),
            SizedBox(width: 8),
            Text('수동 PASS 처리'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 점호를 PASS 처리하시겠습니까?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '점호 기록은 삭제되지 않으며, 상태만 PASS로 변경됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: '관리자 코멘트 (선택)',
                hintText: 'PASS 처리 사유를 입력하세요',
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
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('PASS 처리'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _processManualPass(commentController.text.trim());
    }
  }

  /// ✅ 신규 추가: 수동 PASS 처리 실행
  Future<void> _processManualPass(String? adminComment) async {
    _showLoadingDialog('PASS 처리 중...');

    try {
      final response = await _inspectionService.manualPassInspection(
        widget.inspectionId,
        adminComment?.isNotEmpty == true ? adminComment : null,
      );

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (response.success && response.inspection != null) {
        setState(() {
          _inspection = response.inspection;
        });
        _showSuccessSnackBar('점호가 PASS 처리되었습니다.');
      } else {
        _showErrorSnackBar(response.message ?? 'PASS 처리 실패');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('PASS 처리 중 오류가 발생했습니다: $e');
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
            Icon(Icons.warning_amber_rounded, color: Colors.red),
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
              '⚠️ 반려 시 해당 점호 기록이 삭제됩니다.',
              style: TextStyle(fontSize: 14, color: Colors.red[600], fontWeight: FontWeight.bold),
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
    _showLoadingDialog('반려 처리 중...');

    try {
      final response = await _inspectionService.rejectInspection(
        widget.inspectionId,
        rejectReason,
      );

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (response.success) {
        _showSuccessSnackBar('점호가 성공적으로 반려되었습니다.');
        Navigator.pop(context, true); // 상세 화면 닫기 (true = 변경됨)
      } else {
        _showErrorSnackBar(response.message ?? '반려 처리 실패');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('반려 처리 중 오류가 발생했습니다: $e');
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
          '이 점호 기록을 완전히 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 16),
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
    _showLoadingDialog('삭제 처리 중...');

    try {
      final success = await _inspectionService.deleteInspection(widget.inspectionId);

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (success) {
        _showSuccessSnackBar('점호가 성공적으로 삭제되었습니다.');
        Navigator.pop(context, true); // 상세 화면 닫기 (true = 변경됨)
      } else {
        _showErrorSnackBar('삭제 처리 실패');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('삭제 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// 로딩 다이얼로그 표시
  void _showLoadingDialog(String message) {
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
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 성공 스낵바 표시
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
                  case 'manual_fail':
                    _showManualFailDialog();
                    break;
                  case 'manual_pass':
                    _showManualPassDialog();
                    break;
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
                  value: 'manual_fail',
                  child: Row(
                    children: [
                      Icon(Icons.thumb_down_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('수동 FAIL 처리'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'manual_pass',
                  child: Row(
                    children: [
                      Icon(Icons.thumb_up_outlined, color: Colors.green),
                      SizedBox(width: 8),
                      Text('수동 PASS 처리'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Colors.red),
                      SizedBox(width: 8),
                      Text('반려 (삭제)'),
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
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInspectionDetail,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_inspection == null) {
      return Center(child: Text('점호 정보를 찾을 수 없습니다.'));
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
            _buildImageCard(),
            SizedBox(height: 16),
            _buildInfoCard(),
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

  Widget _buildStatusCard() {
    final inspection = _inspection!;
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (inspection.status) {
      case 'PASS':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = '통과';
        break;
      case 'FAIL':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = '실패';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.help;
        statusText = inspection.status;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${inspection.score}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      '/ 10',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
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
                      Icon(statusIcon, color: statusColor, size: 24),
                      SizedBox(width: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '사용자: ${inspection.userName}',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '호실: ${inspection.roomNumber}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (inspection.isReInspection)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '재검',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildImageCard() {
    final inspection = _inspection!;
    final imageUrl = _getImageUrl(inspection.imagePath);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '제출 이미지',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('이미지를 불러올 수 없습니다'),
                        ],
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
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
              ),
            )
          else
            Container(
              height: 200,
              color: Colors.grey[200],
              child: Center(
                child: Text('이미지 없음'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final inspection = _inspection!;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상세 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('점호 ID', '${inspection.id}'),
            _buildInfoRow('사용자 ID', inspection.userId),
            _buildInfoRow('사용자 이름', inspection.userName),
            _buildInfoRow('호실', inspection.roomNumber),
            _buildInfoRow('점호 시간', dateFormat.format(inspection.inspectionDate)),
            _buildInfoRow('등록 시간', dateFormat.format(inspection.createdAt)),
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
            width: 100,
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
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final inspection = _inspection!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI 평가 피드백',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Text(
                inspection.geminiFeedback ?? 'AI 피드백 없음',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            if (inspection.adminComment != null && inspection.adminComment!.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                '관리자 코멘트',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Text(
                  inspection.adminComment!,
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final inspection = _inspection!;

    return Column(
      children: [
        // 상태 변경 버튼
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: inspection.status == 'FAIL' ? null : _showManualFailDialog,
                icon: Icon(Icons.thumb_down),
                label: Text('FAIL 처리'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: inspection.status == 'PASS' ? null : _showManualPassDialog,
                icon: Icon(Icons.thumb_up),
                label: Text('PASS 처리'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        // 삭제 버튼
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showDeleteDialog,
            icon: Icon(Icons.delete_outline),
            label: Text('점호 기록 삭제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red),
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}