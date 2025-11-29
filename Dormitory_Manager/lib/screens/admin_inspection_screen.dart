import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';
import '../utils/auth_provider.dart';
import '../api/dio_client.dart';
import 'admin_building_config_screen.dart';  // ✅ 테이블 설정 화면 추가

/// 관리자용 점호 관리 화면 (통합 버전)
/// - 리스트 뷰: 기존 스크롤 방식
/// - 테이블 뷰: 기숙사별 층/호실 매트릭스
class AdminInspectionScreen extends StatefulWidget {
  const AdminInspectionScreen({super.key});

  @override
  State<AdminInspectionScreen> createState() => _AdminInspectionScreenState();
}

class _AdminInspectionScreenState extends State<AdminInspectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 공통
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // 리스트 뷰용
  final InspectionService _inspectionService = InspectionService();
  List<AdminInspectionModel> _allInspections = [];
  List<AdminInspectionModel> _todayInspections = [];
  InspectionStatistics? _statistics;

  // 테이블 뷰용
  List<String> _buildings = [];
  String? _selectedBuilding;
  Map<String, dynamic>? _statusData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    // 테이블 탭 선택 시 건물 목록 로드
    if (_tabController.index == 3 && _buildings.isEmpty) {
      _loadBuildings();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadAllInspections(),
        _loadTodayInspections(),
        _loadStatistics(),
      ]);
    } catch (e) {
      print('[ERROR] 초기 데이터 로드 실패: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadAllInspections() async {
    try {
      final response = await _inspectionService.getAllInspections();
      if (response.success && mounted) {
        setState(() {
          _allInspections = response.inspections;
        });
      }
    } catch (e) {
      print('[ERROR] 전체 점호 기록 로드 실패: $e');
    }
  }

  Future<void> _loadTodayInspections() async {
    try {
      final response = await _inspectionService.getInspectionsByDate(_selectedDate);
      if (response.success && mounted) {
        setState(() {
          _todayInspections = response.inspections;
        });
      }
    } catch (e) {
      print('[ERROR] 오늘 점호 기록 로드 실패: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final response = await _inspectionService.getInspectionStatistics(date: _selectedDate);
      if (response.success && mounted) {
        setState(() {
          _statistics = response.statistics;
        });
      }
    } catch (e) {
      print('[ERROR] 통계 로드 실패: $e');
    }
  }

  /// 기숙사 동 목록 로드
  Future<void> _loadBuildings() async {
    try {
      setState(() => _isLoading = true);

      final response = await DioClient.get('/inspections/admin/buildings');

      if (response.data['success'] == true) {
        final List<dynamic> buildingList = response.data['data']['buildings'] ?? [];
        setState(() {
          _buildings = buildingList.cast<String>();
          if (_buildings.isNotEmpty && _selectedBuilding == null) {
            _selectedBuilding = _buildings.first;
          }
        });

        if (_selectedBuilding != null) {
          await _loadBuildingStatus();
        }
      }
    } catch (e) {
      print('[ERROR] 기숙사 동 목록 로드 실패: $e');
      _showSnackBar('기숙사 동 목록을 불러오는데 실패했습니다.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 선택된 기숙사의 점호 현황 로드
  Future<void> _loadBuildingStatus() async {
    if (_selectedBuilding == null) return;

    try {
      setState(() => _isLoading = true);

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await DioClient.get(
        '/inspections/admin/building-status/$_selectedBuilding',
        queryParameters: {'date': dateStr},
      );

      if (response.data['success'] == true) {
        setState(() {
          _statusData = response.data['data'];
        });
      }
    } catch (e) {
      print('[ERROR] 점호 현황 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });

      await Future.wait([
        _loadTodayInspections(),
        _loadStatistics(),
        if (_selectedBuilding != null) _loadBuildingStatus(),
      ]);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('점호 관리')),
        body: const Center(child: Text('관리자 권한이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('점호 관리'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '날짜 선택',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInitialData,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '오늘'),
            Tab(text: '통계'),
            Tab(icon: Icon(Icons.grid_view), text: '테이블'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllInspectionsTab(),
          _buildTodayInspectionsTab(),
          _buildStatisticsTab(),
          _buildTableViewTab(),
        ],
      ),
    );
  }

  // ==================== 전체 점호 기록 탭 ====================
  Widget _buildAllInspectionsTab() {
    if (_isLoading && _allInspections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allInspections.isEmpty) {
      return const Center(child: Text('점호 기록이 없습니다.'));
    }

    return RefreshIndicator(
      onRefresh: _loadAllInspections,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allInspections.length,
        itemBuilder: (context, index) {
          return _buildInspectionCard(_allInspections[index]);
        },
      ),
    );
  }

  // ==================== 오늘 점호 기록 탭 ====================
  Widget _buildTodayInspectionsTab() {
    if (_isLoading && _todayInspections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 날짜 표시
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),

        Expanded(
          child: _todayInspections.isEmpty
              ? const Center(child: Text('오늘 점호 기록이 없습니다.'))
              : RefreshIndicator(
            onRefresh: _loadTodayInspections,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _todayInspections.length,
              itemBuilder: (context, index) {
                return _buildInspectionCard(_todayInspections[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 통계 탭 ====================
  Widget _buildStatisticsTab() {
    if (_statistics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 요약 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    DateFormat('yyyy년 MM월 dd일').format(_selectedDate),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('전체', _statistics!.totalInspections, Colors.blue),
                      _buildStatColumn('통과', _statistics!.passedInspections, Colors.green),
                      _buildStatColumn('실패', _statistics!.failedInspections, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _statistics!.totalInspections > 0
                        ? _statistics!.passedInspections.toDouble() / _statistics!.totalInspections.toDouble()
                        : 0,
                    backgroundColor: Colors.red[100],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '통과율: ${_statistics!.passRate.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 재검 횟수 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: Colors.orange, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    '재검 횟수: ${_statistics!.reInspections}회',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  // ==================== 테이블 뷰 탭 ====================
  Widget _buildTableViewTab() {
    return Column(
      children: [
        // 컨트롤 패널
        _buildTableControlPanel(),

        // 범례
        _buildLegend(),

        // 테이블
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _statusData == null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '기숙사 동을 선택해주세요',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                if (_buildings.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBuildings,
                    child: const Text('기숙사 목록 불러오기'),
                  ),
                ],
              ],
            ),
          )
              : _buildInspectionTable(),
        ),

        // 통계 바
        if (_statusData != null) _buildTableStatisticsBar(),
      ],
    );
  }

  Widget _buildTableControlPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          // 기숙사 동 선택
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBuilding,
                  hint: const Text('기숙사 동 선택'),
                  isExpanded: true,
                  items: _buildings.map((building) {
                    return DropdownMenuItem(
                      value: building,
                      child: Text('$building동'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBuilding = value;
                    });
                    _loadBuildingStatus();
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 테이블 설정 버튼
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openTableConfigScreen,
            tooltip: '테이블 설정',
            color: Colors.blue,
          ),

          // 날짜 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              DateFormat('MM/dd').format(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 테이블 설정 화면으로 이동
  void _openTableConfigScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminBuildingConfigScreen(),
      ),
    ).then((_) {
      // 설정 화면에서 돌아오면 데이터 새로고침
      if (_selectedBuilding != null) {
        _loadBuildingStatus();
      }
    });
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildLegendItem('통과', Colors.green),
            _buildLegendItem('실패', Colors.red),
            _buildLegendItem('반려', Colors.red[700]!),
            _buildLegendItem('미제출', Colors.amber),
            _buildLegendItem('빈 방', Colors.grey[400]!),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInspectionTable() {
    final matrix = _statusData!['matrix'] as Map<String, dynamic>? ?? {};
    final floors = (_statusData!['floors'] as List<dynamic>?)?.cast<int>() ??
        List.generate(12, (i) => i + 2);
    final rooms = (_statusData!['rooms'] as List<dynamic>?)?.cast<int>() ??
        List.generate(20, (i) => i + 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 행
              Row(
                children: [
                  _buildHeaderCell('층\\호', isCorner: true),
                  ...rooms.map((room) => _buildHeaderCell('$room호')),
                ],
              ),

              // 데이터 행
              ...floors.map((floor) {
                final floorData = matrix[floor.toString()] as Map<String, dynamic>? ?? {};

                return Row(
                  children: [
                    _buildHeaderCell('$floor층'),
                    ...rooms.map((room) {
                      final roomData = floorData[room.toString()] as Map<String, dynamic>?;
                      final status = roomData?['status'] ?? 'EMPTY';

                      return _buildRoomCell(floor, room, status);
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {bool isCorner = false}) {
    return Container(
      width: isCorner ? 50 : 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.blue[100],
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isCorner ? 10 : 10,
        ),
      ),
    );
  }

  Widget _buildRoomCell(int floor, int room, String status) {
    return InkWell(
      onTap: () => _showRoomDetail(floor, room),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _getStatusColor(status),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Text(
          '${floor * 100 + room}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: status == 'EMPTY' ? Colors.grey[600] : Colors.white,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PASS':
        return Colors.green;
      case 'FAIL':
        return Colors.red;
      case 'REJECTED':
        return Colors.red[700]!;
      case 'PENDING':
        return Colors.orange;
      case 'NOT_SUBMITTED':
        return Colors.amber;
      case 'EMPTY':
        return Colors.grey[300]!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTableStatisticsBar() {
    final stats = _statusData!['statistics'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTableStatItem('거주', stats['occupiedRooms'] ?? 0, Colors.blue),
            _buildTableStatItem('통과', stats['passCount'] ?? 0, Colors.green),
            _buildTableStatItem('실패', stats['failCount'] ?? 0, Colors.red),
            _buildTableStatItem('미제출', stats['notSubmittedCount'] ?? 0, Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildTableStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  /// 호실 상세 정보 표시
  Future<void> _showRoomDetail(int floor, int room) async {
    if (_selectedBuilding == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await DioClient.get(
        '/inspections/admin/room-status/$_selectedBuilding/$floor/$room',
        queryParameters: {'date': dateStr},
      );

      Navigator.pop(context);

      if (response.data['success'] == true) {
        final roomData = response.data['data'];
        _showRoomDetailDialog(roomData);
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('호실 정보를 불러오는데 실패했습니다.', isError: true);
    }
  }

  void _showRoomDetailDialog(Map<String, dynamic> roomData) {
    final roomNumber = roomData['roomNumber'] ?? '';
    final overallStatus = roomData['overallStatus'] ?? 'EMPTY';
    final users = roomData['users'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(overallStatus),
                shape: BoxShape.circle,
              ),
            ),
            Text('$_selectedBuilding동 $roomNumber호'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: users.isEmpty
              ? const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('해당 호실에 거주자가 없습니다.')),
          )
              : ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index] as Map<String, dynamic>;
              return _buildUserDetailCard(user);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailCard(Map<String, dynamic> user) {
    final userName = user['userName'] ?? '이름 없음';
    final status = user['inspectionStatus'] ?? 'NOT_SUBMITTED';
    final statusText = user['statusText'] ?? '미제출';
    final inspection = user['inspection'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (inspection != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(' ${inspection['score'] ?? 0}점'),
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  Text(' ${_formatTime(inspection['inspectionDate'])}'),
                ],
              ),
              if (inspection['geminiFeedback'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  inspection['geminiFeedback'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return '';
    }
  }

  // ==================== 점호 카드 (리스트 뷰용) ====================
  Widget _buildInspectionCard(AdminInspectionModel inspection) {
    final statusColor = inspection.status == 'PASS' ? Colors.green : Colors.red;
    final statusText = inspection.status == 'PASS' ? '통과' : '실패';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            inspection.status == 'PASS' ? Icons.check : Icons.close,
            color: statusColor,
          ),
        ),
        title: Text(
          inspection.userName ?? inspection.userId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${inspection.roomNumber}호 • ${inspection.score}점'),
            if (inspection.inspectionDate != null)
              Text(
                DateFormat('MM/dd HH:mm').format(inspection.inspectionDate!),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () => _showInspectionDetail(inspection),
      ),
    );
  }

  void _showInspectionDetail(AdminInspectionModel inspection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${inspection.userName ?? inspection.userId}님의 점호'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('방 번호', '${inspection.roomNumber}호'),
              _buildDetailRow('점수', '${inspection.score}점'),
              _buildDetailRow('상태', inspection.status == 'PASS' ? '통과' : '실패'),
              if (inspection.inspectionDate != null)
                _buildDetailRow('제출 시간',
                    DateFormat('yyyy-MM-dd HH:mm').format(inspection.inspectionDate!)),
              if (inspection.geminiFeedback != null) ...[
                const SizedBox(height: 12),
                const Text('AI 피드백:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(inspection.geminiFeedback!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}