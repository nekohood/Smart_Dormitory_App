import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/dio_client.dart';
import '../utils/time_utils.dart'; // ✅ 추가: KST 시간 변환 유틸리티

/// 기숙사별 점호 현황 테이블 화면
/// - 층/호실 매트릭스 형태로 점호 상태 표시
/// - 기숙사 동별 탭 또는 드롭다운으로 전환
/// ✅ 수정: KST 시간대 적용
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

  // 표의 모든 셀(헤더 포함) 크기를 50x50 정사각형으로 통일
  final double _cellSize = 50.0;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  /// 기숙사 이름 포맷팅 헬퍼 ("동" 중복 방지)
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
          _isLoading = false;
        });
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

      Navigator.pop(context);

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

  /// ✅ 호실 상세 정보 다이얼로그 (다인실 거주자 전체 표시 개선)
  void _showRoomDetailDialog(Map<String, dynamic> roomData) {
    final roomNumber = roomData['roomNumber'] ?? '';
    final overallStatus = roomData['overallStatus'] ?? 'EMPTY';
    final users = roomData['users'] as List<dynamic>? ?? [];
    final userCount = roomData['userCount'] ?? users.length;

    // 기숙사 이름 포맷팅
    final buildingName = _getFormattedBuildingName(_selectedBuilding ?? '');

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
                    '$buildingName $roomNumber호',
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
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              // 다인실 통계
              if (userCount >= 2) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRoomStatChip('통과', passCount, Colors.green),
                    const SizedBox(width: 8),
                    _buildRoomStatChip('실패', failCount, Colors.red),
                    const SizedBox(width: 8),
                    _buildRoomStatChip('미제출', notSubmittedCount, Colors.amber),
                  ],
                ),
              ],
            ],
          ),
        ),
        content: users.isEmpty
            ? const Padding(
          padding: EdgeInsets.all(16),
          child: Text('이 호실에 거주자가 없습니다.'),
        )
            : SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              return _buildUserDetailCard(users[index], index);
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

  Widget _buildRoomStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0 ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 순번, 이름, 상태
            Row(
              children: [
                // 순번 표시
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 사용자 이름
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        userId,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // 상태 배지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 14,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 점호 정보 (있는 경우)
            if (inspection != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTimeFull(inspection['inspectionDate']),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    // AI 피드백 (있는 경우)
                    if (inspection['geminiFeedback'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        inspection['geminiFeedback'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  /// ✅ 수정: UTC → KST 변환 적용
  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      DateTime dt;
      if (dateTime is String) {
        // time_utils의 parseToKST 함수 사용하여 KST로 변환
        dt = parseToKST(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        return dateTime.toString();
      }
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return dateTime.toString();
    }
  }

  /// ✅ 수정: UTC → KST 변환 적용 (날짜/시간 전체 포맷)
  String _formatDateTimeFull(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      DateTime dt;
      if (dateTime is String) {
        // time_utils의 parseToKST 함수 사용하여 KST로 변환
        dt = parseToKST(dateTime);
      } else if (dateTime is DateTime) {
        dt = dateTime;
      } else {
        return dateTime.toString();
      }
      return DateFormat('MM/dd HH:mm').format(dt);
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
          _buildControlPanel(),
          _buildLegend(),

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

  /// 점호 현황 테이블 위젯
  Widget _buildInspectionTable() {
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
    final tableConfig = _statusData!['tableConfig'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 행
              Row(
                children: [
                  Container(
                    width: _cellSize,
                    height: _cellSize,
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
                  ...rooms.map((room) => Container(
                    width: _cellSize,
                    height: _cellSize,
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
                // ✅ 수정: 백엔드 matrix 구조에 맞게 접근 (floor -> room -> data)
                final floorData = matrix['$floor'] as Map<String, dynamic>? ?? {};

                return Row(
                  children: [
                    Container(
                      width: _cellSize,
                      height: _cellSize,
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
                    ...rooms.map((room) {
                      // ✅ 수정: floorData에서 room 데이터 가져오기
                      final cellData = floorData['$room'] as Map<String, dynamic>?;
                      final status = cellData?['status'] ?? 'EMPTY';
                      final userCount = cellData?['userCount'] ?? 0;

                      // 방 번호 형식
                      String roomNumber;
                      final format = tableConfig?['roomNumberFormat'] ?? 'FLOOR_ROOM';
                      if (format == 'FLOOR_ZERO_ROOM') {
                        roomNumber = '${floor * 1000 + room}';
                      } else {
                        roomNumber = '${floor * 100 + room}';
                      }

                      return GestureDetector(
                        onTap: () => _showRoomDetail(floor, room),
                        child: Container(
                          width: _cellSize,
                          height: _cellSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                roomNumber,
                                style: TextStyle(
                                  fontSize: userCount > 1 ? 9 : 10,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'EMPTY' ? Colors.grey[600] : Colors.white,
                                ),
                              ),
                              if (userCount > 1)
                                Text(
                                  '($userCount명)',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: status == 'EMPTY' ? Colors.grey[600] : Colors.white70,
                                  ),
                                ),
                            ],
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

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('거주', stats['occupiedRooms'] ?? 0, Colors.blue),
            _buildStatItem('통과', stats['passCount'] ?? 0, Colors.green),
            _buildStatItem('실패', stats['failCount'] ?? 0, Colors.red),
            _buildStatItem('미제출', stats['notSubmittedCount'] ?? 0, Colors.amber),
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}