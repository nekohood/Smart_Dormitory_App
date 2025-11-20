import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ⭐ Provider 추가
import '../services/inspection_service.dart';
import '../models/inspection.dart';
import '../utils/auth_provider.dart'; // ⭐ AuthProvider 추가

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
    // ⭐ 초기화 시 바로 데이터 로드 (AuthProvider가 이미 초기화됨)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  /// 데이터 로드
  Future<void> _loadData() async {
    // ⭐ AuthProvider에서 사용자 정보 확인
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

      // 병렬로 데이터 로드
      final results = await Future.wait([
        _inspectionService.getAllInspections(),
        _inspectionService.getInspectionsByDate(DateTime.now()),
        _inspectionService.getInspectionStatistics(),
      ]);

      if (mounted) {
        setState(() {
          _allInspections = results[0] as List<AdminInspectionModel>;
          _todayInspections = results[1] as List<AdminInspectionModel>;
          _statistics = results[2] as InspectionStatistics;
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

  @override
  Widget build(BuildContext context) {
    // ⭐ AuthProvider 감시
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 로그인 상태가 아니면 안내 메시지 표시
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

        // 관리자가 아니면 권한 없음 메시지
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
                  Icon(Icons.admin_panel_settings_outlined, size: 64, color: Colors.grey),
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

        // 정상 화면 표시
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

  // UI 빌드 메서드들
  Widget _buildAllInspectionsList() {
    if (_allInspections.isEmpty) {
      return Center(child: Text('점호 기록이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _allInspections.length,
        itemBuilder: (context, index) {
          return _buildInspectionCard(_allInspections[index]);
        },
      ),
    );
  }

  Widget _buildTodayInspectionsList() {
    if (_todayInspections.isEmpty) {
      return Center(child: Text('오늘 점호 기록이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
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
          Text('점호 통계', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
      ),
      child: Column(
        children: [
          _buildStatRow('전체 점호 수', _statistics!.totalInspections.toString()),
          _buildStatRow('통과한 점호', _statistics!.passedInspections.toString()),
          _buildStatRow('실패한 점호', _statistics!.failedInspections.toString()),
          _buildStatRow('재검 점호', _statistics!.reInspections.toString()),
          _buildStatRow('통과율', '${_statistics!.passRate.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildInspectionCard(AdminInspectionModel inspection) {
    final statusColor = inspection.status == 'PASS' ? Colors.green : Colors.red;
    final statusText = inspection.status == 'PASS' ? '통과' : '실패';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Text(
            inspection.score.toString(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('${inspection.userName} (${inspection.userId})'),
        subtitle: Text('방 번호: ${inspection.roomNumber} | $statusText'),
        trailing: Text(
          _formatDateTime(inspection.inspectionDate),
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}