import 'package:flutter/material.dart';
import '../models/complaint.dart';
import '../data/complaint_repository.dart';
import '../data/user_repository.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Complaint currentComplaint;
  bool isLoading = false;
  bool _hasAutoUpdatedStatus = false; // 자동 상태 업데이트 여부
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    currentComplaint = widget.complaint;

    // 관리자가 '대기' 상태의 민원을 열면 자동으로 '검토중'으로 변경
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoUpdateStatusIfNeeded();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 관리자가 대기 상태의 민원을 열면 자동으로 '검토중'으로 변경
  Future<void> _autoUpdateStatusIfNeeded() async {
    final isAdmin = UserRepository.currentUser?.isAdmin ?? false;

    if (isAdmin && currentComplaint.status == '대기' && !_hasAutoUpdatedStatus) {
      _hasAutoUpdatedStatus = true;

      try {
        final updatedComplaint = await ComplaintRepository.updateComplaintStatus(
          complaintId: currentComplaint.id,
          status: '검토중',
          adminComment: null,
        );

        if (mounted) {
          setState(() {
            currentComplaint = updatedComplaint;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('민원이 검토중 상태로 변경되었습니다.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('[ERROR] 자동 상태 업데이트 실패: $e');
      }
    }
  }

  Future<void> _updateStatus(String newStatus, {String? comment}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final updatedComplaint = await ComplaintRepository.updateComplaintStatus(
        complaintId: currentComplaint.id,
        status: newStatus,
        adminComment: comment,
      );

      setState(() {
        currentComplaint = updatedComplaint;
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('민원 상태가 "$newStatus"(으)로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상태 변경 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 승인 처리 다이얼로그
  void _showApproveDialog() {
    _commentController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const SizedBox(width: 12),
            const Text('민원 완료 처리'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이 민원을 완료 처리하시겠습니까?'),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: '처리 내용 (선택)',
                hintText: '처리 결과를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('완료', comment: _commentController.text.trim().isNotEmpty
                  ? _commentController.text.trim()
                  : null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('완료 처리'),
          ),
        ],
      ),
    );
  }

  /// 반려 처리 다이얼로그
  void _showRejectDialog() {
    _commentController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('민원 반려 처리'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이 민원을 반려 처리하시겠습니까?'),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: '반려 사유 (필수)',
                hintText: '반려 사유를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('반려 사유를 입력해주세요.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _updateStatus('반려', comment: _commentController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('반려 처리'),
          ),
        ],
      ),
    );
  }

  /// 상태 변경 다이얼로그 (기존 호환)
  void _showStatusUpdateDialog() {
    final isAdmin = UserRepository.currentUser?.isAdmin ?? false;
    if (!isAdmin) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('민원 상태 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('변경할 상태를 선택하세요:'),
            const SizedBox(height: 16),
            ...ComplaintRepository.getStatusList().map((status) =>
                RadioListTile<String>(
                  title: Text(status),
                  value: status,
                  groupValue: currentComplaint.status,
                  onChanged: (value) {
                    Navigator.pop(context);
                    if (value != null && value != currentComplaint.status) {
                      if (value == '완료') {
                        _showApproveDialog();
                      } else if (value == '반려') {
                        _showRejectDialog();
                      } else {
                        _updateStatus(value);
                      }
                    }
                  },
                ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 상태별 색상
  Color _getStatusColor(String status) {
    switch (status) {
      case '대기':
        return Colors.orange;
      case '검토중':
        return Colors.blue;
      case '완료':
        return Colors.green;
      case '반려':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// 상태별 아이콘
  IconData _getStatusIcon(String status) {
    switch (status) {
      case '대기':
        return Icons.schedule;
      case '검토중':
        return Icons.search;
      case '완료':
        return Icons.check_circle;
      case '반려':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = UserRepository.currentUser?.isAdmin ?? false;
    final canProcess = isAdmin && !currentComplaint.isCompleted;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          '민원 상세',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: canProcess
            ? [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showStatusUpdateDialog,
            tooltip: '상태 변경',
          ),
        ]
            : null,
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 민원 헤더 정보
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상태와 카테고리
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentComplaint.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getStatusIcon(currentComplaint.status),
                                      size: 14,
                                      color: _getStatusColor(currentComplaint.status),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      currentComplaint.status,
                                      style: TextStyle(
                                        color: _getStatusColor(currentComplaint.status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  currentComplaint.category,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 제목
                          Text(
                            currentComplaint.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 작성자 정보
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                currentComplaint.writerName ?? currentComplaint.writerId,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                currentComplaint.formattedDateTime,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          // 거주 정보 (있는 경우)
                          if (currentComplaint.hasLocationInfo) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  currentComplaint.formattedLocation!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 민원 내용
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '민원 내용',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 첨부 이미지
                          if (currentComplaint.imageUrl != null) ...[
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(
                                maxHeight: 300,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  currentComplaint.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              '이미지를 불러올 수 없습니다',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[100],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 내용
                          Text(
                            currentComplaint.content,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 관리자 의견 (있는 경우)
                    if (currentComplaint.adminComment != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: currentComplaint.status == '반려'
                              ? Colors.red.withOpacity(0.05)
                              : Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: currentComplaint.status == '반려'
                                ? Colors.red.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  currentComplaint.status == '반려'
                                      ? Icons.warning
                                      : Icons.admin_panel_settings,
                                  color: currentComplaint.status == '반려'
                                      ? Colors.red
                                      : Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  currentComplaint.status == '반려'
                                      ? '반려 사유'
                                      : '관리자 의견',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: currentComplaint.status == '반려'
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currentComplaint.adminComment!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                            if (currentComplaint.processedAt != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '처리일시: ${_formatDateTime(currentComplaint.processedAt!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 100), // 하단 버튼 공간 확보
                  ],
                ),
              ),
            ),
          ),

          // 관리자 처리 버튼 (하단 고정)
          if (canProcess)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // 반려 버튼
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showRejectDialog,
                        icon: const Icon(Icons.cancel),
                        label: const Text('반려'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 완료 버튼
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _showApproveDialog,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('완료 처리'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}