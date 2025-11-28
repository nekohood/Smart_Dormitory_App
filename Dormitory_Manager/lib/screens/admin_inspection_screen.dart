import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/inspection_service.dart';
import '../models/inspection.dart';
import '../utils/auth_provider.dart';
import 'admin_inspection_detail_screen.dart';

/// 관리자용 점호 관리 화면 - 상세 조회 기능 추가
class AdminInspectionScreen extends StatefulWidget {
  const AdminInspectionScreen({super.key});

  @override
  State<AdminInspectionScreen> createState() => _AdminInspectionScreenState();
}

class _AdminInspectionScreenState extends State<AdminInspectionScreen> {
  final InspectionService _inspectionService = InspectionService();

  List<AdminInspectionModel> _allInspections = [];
  List<AdminInspectionModel> _todayInspections = [];
  InspectionStatistics? _statistics;

  bool _isLoading = true;
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// 데이터 로드
  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      setState(() {
        _errorMessage = '로그인이 필요합니다';
        _isLoading = false;
      });
      return;
    }

    if (!authProvider.isAdmin) {
      setState(() {
        _errorMessage = '관리자 권한이 필요합니다';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('[DEBUG] AdminInspectionScreen: 데이터 로드 시작');
      print('[DEBUG] 현재 사용자: ${authProvider.currentUser?.id}');
      print('[DEBUG] 관리자 여부: ${authProvider.isAdmin}');

      final results = await Future.wait([
        _inspectionService.getAllInspections(),
        _inspectionService.getInspectionsByDate(DateTime.now()),
        _inspectionService.getInspectionStatistics(),
      ]);

      if (mounted) {
        setState(() {
          final allInspectionsResponse = results[0] as InspectionListResponse;
          _allInspections = allInspectionsResponse.inspections;

          final todayInspectionsResponse = results[1] as InspectionListResponse;
          _todayInspections = todayInspectionsResponse.inspections;

          final statisticsResponse = results[2] as InspectionStatisticsResponse;
          _statistics = statisticsResponse.statistics;

          _isLoading = false;
          _isInitialized = true;
        });

        print('[DEBUG] 데이터 로드 완료');
        print('[DEBUG] 전체 점호: ${_allInspections.length}건');
        print('[DEBUG] 오늘 점호: ${_todayInspections.length}건');
      }
    } catch (e) {
      print('[ERROR] 데이터 로드 실패: $e');

      if (mounted) {
        setState(() {
          _errorMessage = '데이터를 불러오는데 실패했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 새로고침
  Future<void> _refreshData() async {
    await _loadData();
  }

  /// 점호 상세 화면으로 이동
  Future<void> _navigateToDetail(AdminInspectionModel inspection) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminInspectionDetailScreen(
          inspectionId: inspection.id,
          initialInspection: inspection,
        ),
      ),
    );

    // 상세 화면에서 변경이 있었으면 데이터 새로고침
    if (result == true) {
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              title: const Text('점호 관리'),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '로그인이 필요합니다',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          );
        }

        if (!authProvider.isAdmin) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              title: const Text('점호 관리'),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '관리자 권한이 필요합니다',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              title: const Text(
                '점호 관리',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: '전체'),
                  Tab(text: '오늘'),
                  Tab(text: '통계'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _refreshData,
                  tooltip: '새로고침',
                ),
              ],
            ),
            body: _buildBody(),
          ),
        );
      },
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
            Text('데이터를 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      children: [
        _buildAllInspectionsList(),
        _buildTodayInspectionsList(),
        _buildStatisticsTab(),
      ],
    );
  }

  Widget _buildAllInspectionsList() {
    if (_allInspections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '점호 기록이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8),
        itemCount: _allInspections.length,
        itemBuilder: (context, index) {
          return _buildInspectionCard(_allInspections[index]);
        },
      ),
    );
  }

  Widget _buildTodayInspectionsList() {
    if (_todayInspections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.today_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '오늘 점호 기록이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 8),
        itemCount: _todayInspections.length,
        itemBuilder: (context, index) {
          return _buildInspectionCard(_todayInspections[index]);
        },
      ),
    );
  }

  Widget _buildStatisticsTab() {
    if (_statistics == null) {
      return Center(child: Text('통계 정보를 불러올 수 없습니다.'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('점호 통계',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _buildStatisticsCard(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
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
          _buildStatRow('전체 점호 수', _statistics!.totalInspections.toString(),
              Icons.checklist, Colors.blue),
          _buildStatRow('통과한 점호', _statistics!.passedInspections.toString(),
              Icons.check_circle, Colors.green),
          _buildStatRow('실패한 점호', _statistics!.failedInspections.toString(),
              Icons.cancel, Colors.red),
          _buildStatRow('재검 점호', _statistics!.reInspections.toString(),
              Icons.refresh, Colors.orange),
          _buildStatRow(
              '통과율',
              '${_statistics!.passRate.toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.purple),
        ],
      ),
    );
  }

  Widget _buildStatRow(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /// ✅ 수정: 점호 카드 (탭하면 상세 화면으로 이동)
  Widget _buildInspectionCard(AdminInspectionModel inspection) {
    final statusColor =
    inspection.status == 'PASS' ? Colors.green : Colors.red;
    final statusText = inspection.status == 'PASS' ? '통과' : '실패';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(inspection),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // 점수 표시
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    inspection.score.toString(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${inspection.userName} (${inspection.userId})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '방 번호: ${inspection.roomNumber}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey[500]),
                        SizedBox(width: 4),
                        Text(
                          _formatDateTime(inspection.inspectionDate),
                          style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        if (inspection.isReInspection) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '재검',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 화살표 아이콘 (상세 보기 표시)
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}