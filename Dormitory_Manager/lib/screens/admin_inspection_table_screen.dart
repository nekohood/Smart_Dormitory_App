import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/inspection_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBuildings();
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
      await _loadBuildingStatus();
    }
  }

  /// 호실 클릭 시 상세 정보 표시
  Future<void> _showRoomDetail(int floor, int room) async {
    if (_selectedBuilding == null) return;

    try {
      // 로딩 다이얼로그 표시
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

      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (response.data['success'] == true) {
        final roomData = response.data['data'];
        _showRoomDetailDialog(roomData);
      }
    } catch (e) {
      Navigator.pop(context); // 로딩 다이얼로그 닫기
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

  /// 상태별 색상
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
        return Colors.grey[400]!;
      default:
        return Colors.grey;
    }
  }

  /// 날짜 포맷
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
            onPressed: _loadBuildingStatus,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 컨트롤 영역
          _buildControlPanel(),

          // 범례
          _buildLegend(),

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
                : _buildInspectionTable(),
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

  /// 범례
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

  /// 점호 현황 테이블
  Widget _buildInspectionTable() {
    if (_statusData == null) {
      return const Center(child: Text('기숙사 동을 선택해주세요.'));
    }

    final matrix = _statusData!['matrix'] as Map<String, dynamic>? ?? {};
    final floors = (_statusData!['floors'] as List<dynamic>?)?.cast<int>() ?? List.generate(12, (i) => i + 2);
    final rooms = (_statusData!['rooms'] as List<dynamic>?)?.cast<int>() ?? List.generate(20, (i) => i + 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 행 (호실 번호)
              Row(
                children: [
                  // 빈 코너 셀
                  Container(
                    width: 50,
                    height: 40,
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
                  // 호실 헤더
                  ...rooms.map((room) => Container(
                    width: 40,
                    height: 40,
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

              // 데이터 행 (각 층)
              ...floors.map((floor) {
                final floorData = matrix[floor.toString()] as Map<String, dynamic>? ?? {};

                return Row(
                  children: [
                    // 층 헤더
                    Container(
                      width: 50,
                      height: 40,
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
                    // 각 호실 셀
                    ...rooms.map((room) {
                      final roomData = floorData[room.toString()] as Map<String, dynamic>?;
                      final status = roomData?['status'] ?? 'EMPTY';

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