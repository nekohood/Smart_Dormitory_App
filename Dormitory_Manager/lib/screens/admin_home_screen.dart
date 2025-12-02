import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';
import '../utils/auth_provider.dart';

// ✅ 화면 임포트
import 'admin_schedule_screen.dart';
import 'admin_inspection_screen.dart';
import 'admin_complaint_screen.dart';
import 'admin_document_screen.dart';
import 'admin_inspection_settings_screen.dart';
import 'admin_room_template_screen.dart';

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
    _loadDashboardData();
  }

  /// 대시보드 데이터 로드
  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    // ✅ 로그아웃 상태 체크 - 로그인되어 있지 않으면 API 호출하지 않음
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      print('[DEBUG] 관리자 대시보드: 로그인되어 있지 않음 - API 호출 스킵');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('[DEBUG] 관리자 대시보드: 데이터 로드 시작');

      // ✅ API 호출 전 다시 한번 mounted 및 인증 상태 체크
      if (!mounted) return;
      final authCheck = Provider.of<AuthProvider>(context, listen: false);
      if (!authCheck.isAuthenticated) {
        print('[DEBUG] 관리자 대시보드: API 호출 전 로그아웃 감지 - 중단');
        return;
      }

      final statsResponse = await _inspectionService.getInspectionStatistics(
        date: DateTime.now(),
      );

      // ✅ 응답 후 다시 체크
      if (!mounted) return;
      final authCheck2 = Provider.of<AuthProvider>(context, listen: false);
      if (!authCheck2.isAuthenticated) {
        print('[DEBUG] 관리자 대시보드: 첫 번째 API 응답 후 로그아웃 감지 - 중단');
        return;
      }

      final todayResponse = await _inspectionService.getInspectionsByDate(
        DateTime.now(),
      );

      if (!mounted) return;

      // ✅ 최종 상태 업데이트 전 인증 체크
      final authCheck3 = Provider.of<AuthProvider>(context, listen: false);
      if (!authCheck3.isAuthenticated) {
        print('[DEBUG] 관리자 대시보드: 두 번째 API 응답 후 로그아웃 감지 - 중단');
        return;
      }

      setState(() {
        if (statsResponse.success) {
          _todayStats = statsResponse.statistics;
        }

        if (todayResponse.success) {
          _recentInspections = todayResponse.inspections.take(5).toList();
        }

        _isLoading = false;
      });

      print('[DEBUG] 관리자 대시보드: 데이터 로드 완료');
      print('[DEBUG] 오늘 점호 수: ${_recentInspections.length}건');

    } catch (e) {
      print('[ERROR] 관리자 대시보드 데이터 로드 실패: $e');

      if (mounted) {
        // ✅ 에러 발생 시에도 인증 상태 체크
        final authCheck = Provider.of<AuthProvider>(context, listen: false);
        if (!authCheck.isAuthenticated) {
          print('[DEBUG] 관리자 대시보드: 에러 발생 but 로그아웃 상태 - 무시');
          return;
        }

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
    // ✅ 빌드 시에도 인증 상태 체크
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 오늘 날짜 표시
              Text(
                DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),

              // 통계 카드들
              _buildStatsCards(),
              SizedBox(height: 24),

              // 빠른 메뉴
              _buildQuickMenuSection(),
              SizedBox(height: 24),

              // 최근 점호 기록
              _buildRecentInspectionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// 통계 카드들
  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘의 점호 현황',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '전체',
                '${_todayStats?.totalInspections ?? 0}건',
                Colors.blue,
                Icons.assignment,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '통과',
                '${_todayStats?.passedInspections ?? 0}건',
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
                '실패',
                '${_todayStats?.failedInspections ?? 0}건',
                Colors.red,
                Icons.cancel,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '통과율',
                '${_todayStats?.passRate.toStringAsFixed(1) ?? 0}%',
                Colors.orange,
                Icons.percent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 빠른 메뉴 섹션
  Widget _buildQuickMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '빠른 메뉴',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildQuickMenuItem(
              '점호 설정',
              Icons.settings,
              Colors.blue,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminInspectionSettingsScreen()),
              ),
            ),
            _buildQuickMenuItem(
              '기준 사진',
              Icons.photo_library,
              Colors.green,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminRoomTemplateScreen()),
              ),
            ),
            _buildQuickMenuItem(
              '민원 관리',
              Icons.support_agent,
              Colors.orange,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminComplaintScreen()),
              ),
            ),
            _buildQuickMenuItem(
              '서류 관리',
              Icons.description,
              Colors.purple,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminDocumentScreen()),
              ),
            ),
            _buildQuickMenuItem(
              '일정 관리',
              Icons.calendar_month,
              Colors.teal,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminScheduleScreen()),
              ),
            ),
            _buildQuickMenuItem(
              '점호 관리',
              Icons.checklist,
              Colors.indigo,
                  () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminInspectionScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 최근 점호 기록 섹션
  Widget _buildRecentInspectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '최근 점호 기록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminInspectionScreen()),
              ),
              child: Text('전체 보기'),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_recentInspections.isEmpty)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  SizedBox(height: 8),
                  Text(
                    '오늘 점호 기록이 없습니다.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(
            _recentInspections.length,
                (index) => _buildInspectionItem(_recentInspections[index]),
          ),
      ],
    );
  }

  Widget _buildInspectionItem(AdminInspectionModel inspection) {
    final isPassed = inspection.status == 'PASS';
    final statusColor = isPassed ? Colors.green : Colors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(
              isPassed ? Icons.check : Icons.close,
              color: statusColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inspection.userName.isNotEmpty ? inspection.userName : inspection.userId,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${inspection.roomNumber}호 • ${inspection.score}점',
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
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}