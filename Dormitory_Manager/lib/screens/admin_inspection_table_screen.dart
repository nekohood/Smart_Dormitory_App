import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/dio_client.dart';

/// 기숙사별 점호 현황 테이블 화면
/// - 층/호실 매트릭스 형태로 점호 상태 표시
/// - 기숙사 동별 탭 또는 드롭다운으로 전환
class AdminInspectionTableScreen extends StatefulWidget {
  const AdminInspectionTableScreen({super.key});

  @override
  State<AdminInspectionTableScreen> createState() => _AdminInspectionTableScreenState();
}

class _AdminInspectionTableScreenState extends State<AdminInspectionTableScreen> {
  List<String> _buildings = [];
  String? _selectedBuilding;
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _statusData;
  bool _isLoading = true;
  String? _errorMessage;

  // ✅ 표의 모든 셀(헤더 포함) 크기를 50x50 정사각형으로 통일
  final double _cellSize = 50.0;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  /// 기숙사 이름 포맷팅 헬퍼 ("동" 중복 방지)
  /// 예: "인재동" -> "인재동", "인재" -> "인재동"
  String _getFormattedBuildingName(String name) {
    if (name.endsWith('동')) {
      return name;
    }
    return '$name동';
  }

  /// 기숙사 동 목록 로드
  Future<void> _loadBuildings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await DioClient.get('/inspections/admin/buildings');

      if (response.data['success'] == true) {
        final List<dynamic> buildingList = response.data['data']['buildings'] ?? [];
        setState(() {
          _buildings = buildingList.cast<String>();

          // ✅ 수정됨: 초기 진입 시 자동으로 건물을 선택하지 않음 (null 유지)
          // _selectedBuilding = null;

          _isLoading = false;
        });

        // 선택된 건물이 없으므로 데이터를 로드하지 않음
      }
    } catch (e) {
      print('[ERROR] 기숙사 동 목록 로드 실패: $e');
      setState(() {
        _errorMessage = '기숙사 동 목록을 불러오는데 실패했습니다.';
        _isLoading = false;
      });
    }
  }

  /// 선택된 기숙사의 점호 현황 로드
  Future<void> _loadBuildingStatus() async {
    if (_selectedBuilding == null) return;

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await DioClient.get(
        '/inspections/admin/building-status/$_selectedBuilding',
        queryParameters: {'date': dateStr},
      );

      if (response.data['success'] == true) {
        setState(() {
          _statusData = response.data['data'];
          _isLoading = false;
        });
      } else {
        throw Exception(response.data['message'] ?? '데이터 로드 실패');
      }
    } catch (e) {
      print('[ERROR] 점호 현황 로드 실패: $e');
      setState(() {
        _errorMessage = '점호 현황을 불러오는데 실패했습니다.';
        _isLoading = false;
      });
    }
  }

  /// 날짜 선택
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
      // 건물이 선택된 상태라면 데이터 갱신
      if (_selectedBuilding != null) {
        await _loadBuildingStatus();
      }
    }
  }

  /// 호실 클릭 시 상세 정보 표시
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

      Navigator.pop(context); // 로딩 닫기

      if (response.data['success'] == true) {
        final roomData = response.data['data'];
        _showRoomDetailDialog(roomData);
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('호실 정보를 불러오는데 실패했습니다: $e')),
      );
    }
  }

  /// 호실 상세 정보 다이얼로그
  void _showRoomDetailDialog(Map<String, dynamic> roomData) {
    final roomNumber = roomData['roomNumber'] ?? '';
    final overallStatus = roomData['overallStatus'] ?? 'EMPTY';
    final users = roomData['users'] as List<dynamic>? ?? [];

    // ✅ 수정됨: 헬퍼 함수를 사용하여 "동" 중복 방지
    final buildingName = _getFormattedBuildingName(_selectedBuilding ?? '');

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
            Text('$buildingName $roomNumber호'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: users.isEmpty
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('해당 호실에 거주자가 없습니다.'),
            ),
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

  /// 사용자 상세 정보 카드
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
                Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('점수: ${inspection['score'] ?? 0}점'),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_formatDateTime(inspection['inspectionDate'])),
                ],
              ),
              if (inspection['geminiFeedback'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inspection['geminiFeedback'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
              if (inspection['adminComment'] != null && inspection['adminComment'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.comment, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '관리자: ${inspection['adminComment']}',
                          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PASS': return Colors.green;
      case 'FAIL': return Colors.red;
      case 'REJECTED': return Colors.red[700]!;
      case 'PENDING': return Colors.orange;
      case 'NOT_SUBMITTED': return Colors.amber;
      case 'EMPTY': return Colors.grey[400]!;
      default: return Colors.grey;
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      if (dateTime is String) {
        final dt = DateTime.parse(dateTime);
        return DateFormat('HH:mm').format(dt);
      }
      return dateTime.toString();
    } catch (e) {
      return dateTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('점호 현황 테이블'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '날짜 선택',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedBuilding != null ? _loadBuildingStatus : null,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlPanel(), // 상단 컨트롤 (드롭다운, 날짜)
          _buildLegend(),       // 범례

          // 테이블 영역
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red[300])),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadBuildings,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
                : _buildInspectionTable(), // 테이블 생성 위젯
          ),

          // 하단 통계
          if (_statusData != null) _buildStatisticsBar(),
        ],
      ),
    );
  }

  /// 상단 컨트롤 패널
  Widget _buildControlPanel() {
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
                    // ✅ 수정됨: 헬퍼 함수를 사용하여 드롭다운 메뉴 텍스트 "동" 중복 방지
                    return DropdownMenuItem(
                      value: building,
                      child: Text(_getFormattedBuildingName(building)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBuilding = value;
                    });
                    _loadBuildingStatus(); // 선택 시 데이터 로드
                  },
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 날짜 표시/선택
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM/dd (E)', 'ko_KR').format(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 범례 위젯
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

  /// 점호 현황 테이블 위젯
  Widget _buildInspectionTable() {
    // ✅ 수정됨: 기숙사가 선택되지 않았을 때는 빈 화면(안내 메시지) 표시
    if (_selectedBuilding == null || _statusData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('점호 현황을 조회할 기숙사 동을 선택해주세요.',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final matrix = _statusData!['matrix'] as Map<String, dynamic>? ?? {};
    final floors = (_statusData!['floors'] as List<dynamic>?)?.cast<int>() ?? List.generate(12, (i) => i + 2);
    final rooms = (_statusData!['rooms'] as List<dynamic>?)?.cast<int>() ?? List.generate(20, (i) => i + 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 헤더 행 (호실 번호)
              Row(
                children: [
                  // 좌측 상단 코너 셀 (층/호)
                  Container(
                    width: _cellSize, // ✅ 가로 고정 (50)
                    height: _cellSize, // ✅ 세로 고정 (50)
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
                    width: _cellSize, // ✅ 가로 고정 (50)
                    height: _cellSize, // ✅ 세로 고정 (50)
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Text(
                      '$room호',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  )),
                ],
              ),

              // 2. 데이터 행 (각 층)
              ...floors.map((floor) {
                final floorData = matrix[floor.toString()] as Map<String, dynamic>? ?? {};

                return Row(
                  children: [
                    // 층 번호 헤더
                    Container(
                      width: _cellSize, // ✅ 가로 고정 (50)
                      height: _cellSize, // ✅ 세로 고정 (50)
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Text(
                        '$floor층',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    // 각 호실 상태 데이터 셀
                    ...rooms.map((room) {
                      final roomData = floorData[room.toString()] as Map<String, dynamic>?;
                      final status = roomData?['status'] ?? 'EMPTY';

                      return InkWell(
                        onTap: () => _showRoomDetail(floor, room),
                        child: Container(
                          width: _cellSize, // ✅ 가로 고정 (50)
                          height: _cellSize, // ✅ 세로 고정 (50)
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Text(
                            '${floor * 100 + room}',
                            style: TextStyle(
                              fontSize: 10, // ✅ 칸 크기에 맞춰 폰트 사이즈 조정
                              fontWeight: FontWeight.bold,
                              color: status == 'EMPTY' ? Colors.grey[600] : Colors.white,
                            ),
                          ),
                        ),
                      );
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

  /// 하단 통계 바
  Widget _buildStatisticsBar() {
    final stats = _statusData!['statistics'] as Map<String, dynamic>? ?? {};

    final totalRooms = stats['occupiedRooms'] ?? 0;
    final passCount = stats['passCount'] ?? 0;
    final failCount = stats['failCount'] ?? 0;
    final rejectedCount = stats['rejectedCount'] ?? 0;
    final notSubmittedCount = stats['notSubmittedCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('전체', totalRooms, Colors.blue),
            _buildStatItem('통과', passCount, Colors.green),
            _buildStatItem('실패', failCount, Colors.red),
            _buildStatItem('반려', rejectedCount, Colors.red[700]!),
            _buildStatItem('미제출', notSubmittedCount, Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}