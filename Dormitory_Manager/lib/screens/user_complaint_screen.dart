import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/complaint.dart';
import '../data/complaint_repository.dart';
import '../utils/storage_helper.dart';
import 'complaint_submit_screen.dart';
import 'complaint_detail_screen.dart';

/// 사용자 민원 목록 화면 - 제출한 민원 및 처리 현황 확인
class UserComplaintScreen extends StatefulWidget {
  const UserComplaintScreen({super.key});

  @override
  State<UserComplaintScreen> createState() => _UserComplaintScreenState();
}

class _UserComplaintScreenState extends State<UserComplaintScreen>
    with SingleTickerProviderStateMixin {
  List<Complaint> _complaints = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _userId;

  late TabController _tabController;
  final List<String> _statusTabs = ['전체', '대기', '검토중', '완료', '반려'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _loadUserAndComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndComplaints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final user = await StorageHelper.getUser();
      if (user == null) {
        setState(() {
          _errorMessage = '사용자 정보를 찾을 수 없습니다.';
          _isLoading = false;
        });
        return;
      }

      _userId = user.id;
      await _loadComplaints();
    } catch (e) {
      setState(() {
        _errorMessage = '데이터를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComplaints() async {
    if (_userId == null) return;

    try {
      final complaints = await ComplaintRepository.getUserComplaints(_userId!);
      setState(() {
        _complaints = complaints;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '민원 목록을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  // 상태별 필터링된 민원 목록
  List<Complaint> get _filteredComplaints {
    final selectedStatus = _statusTabs[_tabController.index];
    if (selectedStatus == '전체') {
      return _complaints;
    }
    return _complaints.where((c) => c.status == selectedStatus).toList();
  }

  // 통계 계산
  int get _totalCount => _complaints.length;
  int get _pendingCount => _complaints.where((c) => c.status == '대기').length;
  int get _processingCount => _complaints.where((c) => c.status == '검토중').length;
  int get _completedCount => _complaints.where((c) => c.status == '완료').length;
  int get _rejectedCount => _complaints.where((c) => c.status == '반려').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '내 민원 현황',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          isScrollable: true,
          tabs: _statusTabs.map((status) {
            int count = 0;
            switch (status) {
              case '전체':
                count = _totalCount;
                break;
              case '대기':
                count = _pendingCount;
                break;
              case '검토중':
                count = _processingCount;
                break;
              case '완료':
                count = _completedCount;
                break;
              case '반려':
                count = _rejectedCount;
                break;
            }
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(status),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComplaintSubmitScreen()),
          );
          // 돌아오면 목록 새로고침
          _loadComplaints();
        },
        icon: const Icon(Icons.add),
        label: const Text('민원 신고'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('민원 목록을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUserAndComplaints,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      child: Column(
        children: [
          // 상단 통계 카드
          _buildStatisticsCard(),

          // 민원 목록
          Expanded(
            child: _filteredComplaints.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredComplaints.length,
                    itemBuilder: (context, index) {
                      return _buildComplaintCard(_filteredComplaints[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(Icons.bar_chart, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                '민원 현황',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('전체', _totalCount, Colors.blue),
              _buildStatItem('대기', _pendingCount, Colors.orange),
              _buildStatItem('검토중', _processingCount, Colors.purple),
              _buildStatItem('완료', _completedCount, Colors.green),
              _buildStatItem('반려', _rejectedCount, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '민원 내역이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 민원을 신고해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    return GestureDetector(
      onTap: () async {
        // 상세 화면으로 이동
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComplaintDetailScreen(complaint: complaint),
          ),
        );
        // 돌아오면 목록 새로고침
        _loadComplaints();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            // 상단: 카테고리 & 상태
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 카테고리 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    complaint.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 상태 뱃지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: complaint.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        complaint.statusIcon,
                        size: 14,
                        color: complaint.statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        complaint.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: complaint.statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 제목
            Text(
              complaint.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // 내용 미리보기
            Text(
              complaint.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // 하단: 날짜 & 관리자 코멘트 표시
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 제출 날짜
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(complaint.submittedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                // 관리자 코멘트 여부
                if (complaint.adminComment != null && complaint.adminComment!.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.comment, size: 14, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(
                        '답변 있음',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // 관리자 코멘트 미리보기 (있을 경우)
            if (complaint.adminComment != null && complaint.adminComment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 14, color: Colors.blue[600]),
                        const SizedBox(width: 4),
                        Text(
                          '관리자 답변',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      complaint.adminComment!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
