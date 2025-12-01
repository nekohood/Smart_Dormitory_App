import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../services/inspection_service.dart';
import '../utils/auth_provider.dart';
import '../api/dio_client.dart';
import 'admin_building_config_screen.dart';

/// 관리자용 점호 관리 화면 (통합 버전)
/// - 리스트 뷰: 기존 스크롤 방식
/// - 테이블 뷰: 기숙사별 층/호실 매트릭스
/// ✅ 수정: 다인실 거주자 전체 명단 표시 개선
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
      } else {
        final message = response.data['message'] ?? '데이터를 불러올 수 없습니다.';
        _showSnackBar(message, isError: true);
        setState(() {
          _statusData = null;
        });
      }
    } catch (e) {
      print('[ERROR] 점호 현황 로드 실패: $e');

      String errorMsg = e.toString();
      if (errorMsg.contains('테이블 설정이 없습니다')) {
        _showSnackBar('$_selectedBuilding의 테이블 설정이 없습니다.\n설정 버튼을 눌러 추가해주세요.', isError: true);
      } else {
        _showSnackBar('점호 현황을 불러오는데 실패했습니다.', isError: true);
      }
      setState(() {
        _statusData = null;
      });
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
                  _selectedBuilding == null
                      ? '기숙사 동을 선택해주세요'
                      : '$_selectedBuilding의 테이블 설정이 없습니다',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_selectedBuilding != null)
                  Text(
                    '⚙️ 설정 버튼을 눌러 테이블을 추가해주세요',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                if (_buildings.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBuildings,
                    child: const Text('기숙사 목록 불러오기'),
                  ),
                ],
                if (_selectedBuilding != null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openTableConfigScreen,
                    icon: const Icon(Icons.settings),
                    label: const Text('테이블 설정하기'),
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
                      child: Text(building),
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
      _loadBuildings().then((_) {
        if (_selectedBuilding != null) {
          _loadBuildingStatus();
        }
      });
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

    // 기본값(예시 테이블) 여부 확인
    final tableConfig = _statusData!['tableConfig'] as Map<String, dynamic>?;
    final isDefault = tableConfig?['isDefault'] == true;

    return Column(
      children: [
        // 예시 테이블일 경우 안내 배너 표시
        if (isDefault)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ 예시 테이블입니다. 각 색상은 점호 상태를 나타냅니다. 설정 버튼(⚙️)을 눌러 실제 층/호실 범위를 설정해주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),

        // 테이블 본체
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 행 (호실 번호)
                    Row(
                      children: [
                        // 좌측 상단 코너 셀
                        Container(
                          width: 44,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            border: Border.all(color: Colors.blue[300]!),
                          ),
                          child: const Text(
                            '층\\호',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                        // 호실 번호 헤더
                        ...rooms.map((room) => Container(
                          width: 44,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            border: Border.all(color: Colors.blue[300]!),
                          ),
                          child: Text(
                            '$room',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        )),
                      ],
                    ),

                    // 데이터 행
                    ...floors.map((floor) {
                      // 백엔드 matrix 구조에 맞게 접근 (floor -> room -> data)
                      final floorData = matrix['$floor'] as Map<String, dynamic>? ?? {};

                      return Row(
                        children: [
                          // 층 번호 셀
                          Container(
                            width: 44,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Text(
                              '${floor}F',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          // 호실 데이터 셀
                          ...rooms.map((room) {
                            // floorData에서 room 데이터 가져오기
                            final cellData = floorData['$room'] as Map<String, dynamic>?;
                            final status = cellData?['status'] ?? 'EMPTY';
                            final userCount = cellData?['userCount'] ?? 0;

                            return _buildTableCell(floor, room, status, userCount, tableConfig);
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(int floor, int room, String status, int userCount, Map<String, dynamic>? tableConfig) {
    String roomNumber;
    final format = tableConfig?['roomNumberFormat'] ?? 'FLOOR_ROOM';

    if (format == 'FLOOR_ZERO_ROOM') {
      roomNumber = '${floor * 1000 + room}';
    } else {
      roomNumber = '${floor * 100 + room}';
    }

    return InkWell(
      onTap: () => _showRoomDetail(floor, room),
      child: Container(
        width: 44,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _getStatusColor(status),
          border: Border.all(color: Colors.grey[400]!, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              roomNumber,
              style: TextStyle(
                fontSize: userCount > 1 ? 9 : 10,
                fontWeight: FontWeight.w500,
                color: status == 'EMPTY' ? Colors.grey[600] : Colors.white,
              ),
            ),
            // 다인실인 경우 인원 수 표시
            if (userCount > 1)
              Text(
                '($userCount명)',
                style: TextStyle(
                  fontSize: 7,
                  color: status == 'EMPTY' ? Colors.grey[500] : Colors.white70,
                ),
              ),
          ],
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

  // ✅ 상태별 아이콘 반환
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PASS':
        return Icons.check_circle;
      case 'FAIL':
        return Icons.cancel;
      case 'REJECTED':
        return Icons.block;
      case 'PENDING':
        return Icons.hourglass_empty;
      case 'NOT_SUBMITTED':
        return Icons.schedule;
      case 'EMPTY':
        return Icons.meeting_room_outlined;
      default:
        return Icons.help_outline;
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

  /// ✅ 호실 상세 정보 표시
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

  /// ✅ 호실 상세 정보 다이얼로그 (다인실 거주자 전체 표시 개선)
  void _showRoomDetailDialog(Map<String, dynamic> roomData) {
    final roomNumber = roomData['roomNumber'] ?? '';
    final overallStatus = roomData['overallStatus'] ?? 'EMPTY';
    final users = roomData['users'] as List<dynamic>? ?? [];
    final userCount = roomData['userCount'] ?? users.length;

    // 예시 템플릿인지 확인
    final tableConfig = _statusData?['tableConfig'] as Map<String, dynamic>?;
    final isDefault = tableConfig?['isDefault'] == true;
    final displayBuilding = isDefault ? '예시 화면' : _selectedBuilding;

    // ✅ 예시 테이블일 때 호실별 설명 하드코딩
    String? exampleDescription;
    if (isDefault) {
      // 호실 번호에서 끝자리 추출 (예: 101 -> 1, 102 -> 2, 201 -> 1)
      final roomNum = int.tryParse(roomNumber) ?? 0;
      final roomSuffix = roomNum % 10;  // 끝자리

      switch (roomSuffix) {
        case 1:
          exampleDescription = '점호 통과';
          break;
        case 2:
          exampleDescription = '점호 실패';
          break;
        case 3:
          exampleDescription = '점호 미제출';
          break;
        case 4:
          exampleDescription = '점호 반려';
          break;
        case 5:
          exampleDescription = '빈 방';
          break;
        default:
        // 6호실 이상은 순환
          final cycleIndex = (roomSuffix - 1) % 5;
          switch (cycleIndex) {
            case 0:
              exampleDescription = '점호 통과';
              break;
            case 1:
              exampleDescription = '점호 실패';
              break;
            case 2:
              exampleDescription = '점호 미제출';
              break;
            case 3:
              exampleDescription = '점호 반려';
              break;
            case 4:
              exampleDescription = '빈 방';
              break;
          }
      }
    }

    // 거주 형태 판단
    String roomType;
    if (userCount == 0) {
      roomType = '빈 방';
    } else if (userCount == 1) {
      roomType = '1인실';
    } else if (userCount == 2) {
      roomType = '2인실';
    } else {
      roomType = '$userCount인실';
    }

    // 점호 상태별 카운트
    int passCount = 0;
    int failCount = 0;
    int notSubmittedCount = 0;

    for (var user in users) {
      final status = user['inspectionStatus'] ?? 'NOT_SUBMITTED';
      if (status == 'PASS') {
        passCount++;
      } else if (status == 'FAIL' || status == 'REJECTED') {
        failCount++;
      } else {
        notSubmittedCount++;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusColor(overallStatus).withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 호실 정보
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(overallStatus),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    '$displayBuilding $roomNumber호',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // 거주 형태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: userCount >= 6
                          ? Colors.purple.withOpacity(0.2)
                          : userCount >= 2
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: userCount >= 6
                            ? Colors.purple
                            : userCount >= 2
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                    child: Text(
                      roomType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: userCount >= 6
                            ? Colors.purple
                            : userCount >= 2
                            ? Colors.blue
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),

              // ✅ 예시 테이블 상태 설명 (isDefault일 때만 표시)
              if (isDefault && exampleDescription != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(overallStatus).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(overallStatus).withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStatusIcon(overallStatus),
                        size: 24,
                        color: _getStatusColor(overallStatus),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        exampleDescription,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(overallStatus),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 점호 현황 요약 (거주자가 있을 때만)
              if (users.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRoomStatusBadge('통과', passCount, Colors.green),
                    const SizedBox(width: 8),
                    _buildRoomStatusBadge('실패', failCount, Colors.red),
                    const SizedBox(width: 8),
                    _buildRoomStatusBadge('미제출', notSubmittedCount, Colors.amber),
                  ],
                ),
              ],
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: users.isEmpty
              ? 100
              : (users.length <= 2 ? 200 : (users.length <= 4 ? 300 : 400)),
          child: users.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  isDefault
                      ? '빈 방 예시입니다.\n해당 호실에 거주자가 없는 상태를 나타냅니다.'
                      : '해당 호실에 거주자가 없습니다.',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 거주자 목록 헤더
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      isDefault ? Icons.school : Icons.people,
                      size: 18,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isDefault
                          ? '예시 거주자 정보'
                          : '거주자 명단 (${users.length}명)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // 거주자 리스트
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index] as Map<String, dynamic>;
                    return _buildUserDetailCard(user, index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isDefault)
            TextButton.icon(
              onPressed: _openTableConfigScreen,
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('테이블 설정'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// ✅ 상태 요약 배지 위젯 (호실 상세용)
  Widget _buildRoomStatusBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: count > 0 ? color : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: count > 0 ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ 사용자 상세 정보 카드 (순번 표시 추가, 레이아웃 개선)
  Widget _buildUserDetailCard(Map<String, dynamic> user, int index) {
    final userId = user['userId'] ?? '';
    final userName = user['userName'] ?? '이름 없음';
    final status = user['inspectionStatus'] ?? 'NOT_SUBMITTED';
    final statusText = user['statusText'] ?? '미제출';
    final inspection = user['inspection'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사용자 기본 정보
          Row(
            children: [
              // 순번
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 이름 & 학번
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      userId,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 점호 상태 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
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

          // 점호 상세 정보 (제출한 경우)
          if (inspection != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 점수 & 제출 시간
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${inspection['score'] ?? 0}점',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (inspection['inspectionDate'] != null) ...[
                        Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatInspectionDateTime(inspection['inspectionDate']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // AI 피드백 (있는 경우)
                  if (inspection['geminiFeedback'] != null &&
                      inspection['geminiFeedback'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.smart_toy, size: 14, color: Colors.blue[300]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            inspection['geminiFeedback'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ✅ 날짜/시간 포맷 헬퍼 (호실 상세용)
  String _formatInspectionDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      if (dateTime is String) {
        final dt = DateTime.parse(dateTime);
        return DateFormat('MM/dd HH:mm').format(dt);
      }
      return dateTime.toString();
    } catch (e) {
      return dateTime.toString();
    }
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
            Text(
              DateFormat('MM/dd HH:mm').format(inspection.inspectionDate),
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
              _buildDetailRow('제출 시간',
                  DateFormat('yyyy-MM-dd HH:mm').format(inspection.inspectionDate)),
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