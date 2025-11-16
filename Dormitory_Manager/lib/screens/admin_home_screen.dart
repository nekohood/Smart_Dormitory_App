import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';
import '../utils/storage_helper.dart';

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
    _initializeService();
    _loadDashboardData();
  }

  /// 서비스 초기화
  Future<void> _initializeService() async {
    try {
      final token = await StorageHelper.getToken();
      if (token != null) {
        _inspectionService.setAuthToken(token);
      }
    } catch (e) {
      print('[ERROR] 관리자 홈 - 토큰 설정 실패: $e');
    }
  }

  /// 대시보드 데이터 로드
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 오늘 통계와 최근 점호 기록을 병렬로 로드
      final futures = await Future.wait([
        _inspectionService.getInspectionStatistics(date: DateTime.now()),
        _inspectionService.getInspectionsByDate(DateTime.now()),
      ]);

      final statsResponse = futures[0] as InspectionStatisticsResponse;
      final todayResponse = futures[1] as InspectionListResponse;

      setState(() {
        if (statsResponse.success) {
          _todayStats = statsResponse.statistics;
        }
        if (todayResponse.success) {
          _recentInspections = todayResponse.inspections.take(5).toList();
        }
      });
    } catch (e) {
      print('[ERROR] 관리자 대시보드 데이터 로드 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
            onPressed: _loadDashboardData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 환영 메시지
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '관리자님, 안녕하세요!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // 오늘의 점호 통계
            Text(
              '오늘의 점호 현황',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildTodayStats(),
            SizedBox(height: 24),

            // 빠른 액션 버튼들
            Text(
              '빠른 액션',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildQuickActions(), // ⭐ [수정] 수정된 위젯 호출
            SizedBox(height: 24),

            // 최근 점호 기록
            Text(
              '오늘의 점호 기록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildRecentInspections(),
          ],
        ),
      ),
    );
  }

  /// 오늘의 통계 위젯
  Widget _buildTodayStats() {
    if (_todayStats == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('통계 데이터를 불러올 수 없습니다.'),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '총 점호',
                  _todayStats!.totalInspections.toString(),
                  Colors.blue,
                  Icons.assignment,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '통과',
                  _todayStats!.passedInspections.toString(),
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '불합격',
                  _todayStats!.failedInspections.toString(),
                  Colors.red,
                  Icons.cancel,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '재검',
                  _todayStats!.reInspections.toString(),
                  Colors.orange,
                  Icons.refresh,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '통과율',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${_todayStats!.passRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _todayStats!.passRate >= 80
                        ? Colors.green
                        : _todayStats!.passRate >= 60
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 통계 카드 위젯
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// ⭐ [수정] 빠른 액션 버튼들 (Wrap으로 변경 및 '일정 관리' 추가)
  Widget _buildQuickActions() {
    // 화면 너비에 맞춰 카드 크기 계산
    double cardWidth = (MediaQuery.of(context).size.width - 16 * 2 - 12 * 2) / 3;
    if (cardWidth < 100) cardWidth = (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2; // 좁으면 2줄

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.start,
      children: [
        SizedBox(
          width: cardWidth,
          child: _buildActionCard(
            '점호 관리',
            '점호 기록 관리',
            Icons.assignment_turned_in,
            Colors.blue,
                () {
              Navigator.pushReplacementNamed(context, '/admin_main');
            },
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _buildActionCard(
            '통계 보기',
            '자세한 통계 확인',
            Icons.analytics,
            Colors.green,
                () {
              Navigator.pushNamed(context, '/admin/inspection');
            },
          ),
        ),
        // ⭐ [신규] 일정 관리 버튼
        SizedBox(
          width: cardWidth,
          child: _buildActionCard(
            '일정 관리',
            '캘린더 일정 수정',
            Icons.calendar_today,
            Colors.purple,
                () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminScheduleScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 액션 카드 위젯
  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  /// 최근 점호 기록 위젯
  Widget _buildRecentInspections() {
    if (_recentInspections.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('오늘 점호 기록이 없습니다.'),
        ),
      );
    }

    return Container(
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
      child: Column(
        children: [
          ...(_recentInspections.take(3).map((inspection) => _buildInspectionListItem(inspection))),
          if (_recentInspections.length > 3)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/inspection');
                },
                child: Text(
                  '모든 점호 기록 보기 (+${_recentInspections.length - 3}건)',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 점호 기록 리스트 아이템
  Widget _buildInspectionListItem(AdminInspectionModel inspection) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 상태 아이콘
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: inspection.getStatusColor(),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inspection.getStatusIcon(),
              color: Colors.white,
              size: 16,
            ),
          ),
          SizedBox(width: 12),

          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inspection.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '방번호: ${inspection.roomNumber}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 점수와 시간
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${inspection.score}점',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: inspection.getStatusColor(),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                DateFormat('HH:mm').format(inspection.inspectionDate),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}