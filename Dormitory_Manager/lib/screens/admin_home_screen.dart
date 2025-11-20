import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';

// ⭐ [신규] 관리자 일정 화면 임포트
import 'admin_schedule_screen.dart';

/// 관리자 전용 홈 화면
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final InspectionService _inspectionService = InspectionService();

  InspectionStatistics? _todayStats;
  List<AdminInspectionModel> _recentInspections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // DioClient가 자동으로 토큰을 관리하므로 _initializeService() 제거
    _loadDashboardData();
  }

  /// 대시보드 데이터 로드 (✅ 수정됨)
  Future<void> _loadDashboardData() async {
    if (!mounted) return; // ✅ mounted 체크

    setState(() {
      _isLoading = true;
    });

    try {
      print('[DEBUG] 관리자 대시보드: 데이터 로드 시작');

      // ✅ 수정: InspectionStatisticsResponse와 InspectionListResponse 반환
      final statsResponse = await _inspectionService.getInspectionStatistics(
        date: DateTime.now(),
      );

      final todayResponse = await _inspectionService.getInspectionsByDate(
        DateTime.now(),
      );

      if (!mounted) return; // ✅ 비동기 작업 후 mounted 체크

      setState(() {
        // InspectionStatisticsResponse에서 statistics 추출
        if (statsResponse.success) {
          _todayStats = statsResponse.statistics;
        }

        // ✅ InspectionListResponse에서 inspections 리스트 추출
        if (todayResponse.success) {
          _recentInspections = todayResponse.inspections.take(5).toList();
        }

        _isLoading = false;
      });

      print('[DEBUG] 관리자 대시보드: 데이터 로드 완료');
      print('[DEBUG] 오늘 점호 수: ${_recentInspections.length}건');

    } catch (e) {
      print('[ERROR] 관리자 대시보드 데이터 로드 실패: $e');

      if (mounted) { // ✅ mounted 체크
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('관리자 대시보드'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboardData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('데이터를 불러오는 중...'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              SizedBox(height: 16),
              _buildTodayStatsCard(),
              SizedBox(height: 16),
              _buildRecentInspectionsCard(),
              SizedBox(height: 16),
              _buildQuickActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// 환영 카드
  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  '관리자 대시보드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(DateTime.now()),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 오늘 통계 카드
  Widget _buildTodayStatsCard() {
    if (_todayStats == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('통계 정보를 불러올 수 없습니다.'),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '오늘의 점호 통계',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '전체',
                  _todayStats!.totalInspections.toString(),
                  Colors.blue,
                  Icons.assignment,
                ),
                _buildStatItem(
                  '통과',
                  _todayStats!.passedInspections.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildStatItem(
                  '실패',
                  _todayStats!.failedInspections.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
                _buildStatItem(
                  '통과율',
                  '${_todayStats!.passRate.toStringAsFixed(1)}%',
                  Colors.orange,
                  Icons.percent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 통계 아이템
  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 최근 점호 기록 카드
  Widget _buildRecentInspectionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '최근 점호 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // 전체 점호 목록으로 이동
                    // Navigator.pushNamed(context, '/admin/inspections');
                  },
                  child: Text('전체보기'),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_recentInspections.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '오늘 점호 기록이 없습니다.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._recentInspections.map((inspection) => _buildInspectionItem(inspection)),
          ],
        ),
      ),
    );
  }

  /// 점호 아이템
  Widget _buildInspectionItem(AdminInspectionModel inspection) {
    final statusColor = inspection.status == 'PASS' ? Colors.green : Colors.red;
    final statusText = inspection.status == 'PASS' ? '통과' : '실패';

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Text(
              inspection.score.toString(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${inspection.userName} (${inspection.userId})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '방 번호: ${inspection.roomNumber} | $statusText',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(inspection.inspectionDate),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// 빠른 작업 카드
  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '빠른 작업',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildQuickActionButton(
                  '점호 관리',
                  Icons.assignment_turned_in,
                  Colors.blue,
                      () {
                    // Navigator.pushNamed(context, '/admin/inspections');
                  },
                ),
                _buildQuickActionButton(
                  '민원 현황',
                  Icons.report_problem,
                  Colors.orange,
                      () {
                    // Navigator.pushNamed(context, '/admin/complaints');
                  },
                ),
                _buildQuickActionButton(
                  '서류 관리',
                  Icons.description,
                  Colors.green,
                      () {
                    // Navigator.pushNamed(context, '/admin/documents');
                  },
                ),
                _buildQuickActionButton(
                  '일정 관리',
                  Icons.calendar_today,
                  Colors.purple,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminScheduleScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 빠른 작업 버튼
  Widget _buildQuickActionButton(
      String label,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}