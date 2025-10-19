import 'package:flutter/material.dart';
import '../services/inspection_service.dart';
import '../models/inspection.dart';
import '../data/user_repository.dart';

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
  bool _isInitialized = false; // 초기화 상태 추가
  String _errorMessage = '';


  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  /// 초기화 및 데이터 로드 (순차적 처리)
  Future<void> _initializeAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // 1. 토큰 초기화를 먼저 수행
      await _initializeAuth();

      // 2. 토큰 설정 후 잠깐 대기 (비동기 처리 완료 보장)
      await Future.delayed(Duration(milliseconds: 100));

      // 3. 데이터 로드
      await _loadData();

      setState(() {
        _isInitialized = true;
      });

    } catch (e) {
      print('[ERROR] 초기화 및 데이터 로드 실패: $e');
      setState(() {
        _errorMessage = '데이터 로드 실패: $e';
        _isLoading = false;
      });
    }
  }

  /// 인증 토큰 초기화
  Future<void> _initializeAuth() async {
    try {
      final currentUser = UserRepository.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 저장된 토큰이 있는지 확인
      final token = await UserRepository.getStoredToken();

      if (token != null && token.isNotEmpty) {
        print('[DEBUG] 관리자 화면 토큰 확인: 토큰 존재');
        print('[DEBUG] 토큰 앞 20자: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');

        // InspectionService에 토큰 설정
        _inspectionService.setAuthToken(token);
        print('[DEBUG] 관리자 토큰 설정 완료');
      } else {
        throw Exception('인증 토큰이 없습니다');
      }

    } catch (e) {
      print('[ERROR] 인증 초기화 실패: $e');
      rethrow;
    }
  }

  /// 데이터 로드
  Future<void> _loadData() async {
    if (!_isInitialized) {
      await _initializeAuth();
      await Future.delayed(Duration(milliseconds: 100));
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // 모든 API 호출을 순차적으로 처리
      await Future.wait([
        _loadAllInspections(),
        _loadTodayInspections(),
        _loadStatistics(),
      ]);

    } catch (e) {
      print('[ERROR] 데이터 로드 실패: $e');
      setState(() {
        _errorMessage = '데이터 로드 실패: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 전체 점호 기록 로드
  Future<void> _loadAllInspections() async {
    try {
      final response = await _inspectionService.getAllInspections();
      if (response.success) {
        setState(() {
          _allInspections = response.inspections;
        });
      } else {
        throw Exception('전체 점호 기록 조회 실패: ${response.message}');
      }
    } catch (e) {
      print('[ERROR] 전체 점호 기록 로드 실패: $e');
      rethrow;
    }
  }

  /// 오늘 점호 기록 로드
  Future<void> _loadTodayInspections() async {
    try {

      final response = await _inspectionService.getInspectionsByDate(DateTime.now());

      if (response.success) {
        setState(() {
          _todayInspections = response.inspections;
        });
      } else {
        throw Exception('오늘 점호 기록 조회 실패: ${response.message}');
      }
    } catch (e) {
      print('[ERROR] 오늘 점호 기록 로드 실패: $e');
      rethrow;
    }
  }

  /// 통계 로드
  Future<void> _loadStatistics() async {
    try {
      final response = await _inspectionService.getInspectionStatistics();
      setState(() {
        _statistics = response.statistics; // InspectionStatisticsResponse에서 statistics 필드 추출
      });
    } catch (e) {
      print('[ERROR] 통계 로드 실패: $e');
      rethrow;
    }
  }

  /// 새로고침
  Future<void> _refreshData() async {
    await _loadData();
  }

  /// 성공 스낵바
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 에러 스낵바
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// 점호 삭제 확인 다이얼로그
  Future<void> _showDeleteConfirmDialog(AdminInspectionModel inspection) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('점호 기록 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음 점호 기록을 삭제하시겠습니까?'),
              SizedBox(height: 8),
              Text('사용자: ${inspection.userName}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('방번호: ${inspection.roomNumber}'),
              Text('점수: ${inspection.score}점'),
              SizedBox(height: 8),
              Text('삭제된 기록은 복구할 수 없으며, 해당 학생은 다시 점호를 제출할 수 있습니다.',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteInspection(inspection.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  /// 점호 기록 삭제 실행
  Future<void> _deleteInspection(int inspectionId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      bool success = await _inspectionService.deleteInspection(inspectionId);

      if (success) {
        _showSuccessSnackBar('점호 기록이 성공적으로 삭제되었습니다.');
        _refreshData(); // 데이터 새로고침
      } else {
        _showErrorSnackBar('점호 기록 삭제에 실패했습니다.');
      }
    } catch (e) {
      _showErrorSnackBar('삭제 중 오류가 발생했습니다: $e');
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
        title: Text('점호 관리'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 로딩 상태
    if (_isLoading && !_isInitialized) {
      return Center(
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

    // 에러 상태
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeAndLoadData,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // 정상 상태 - 탭 기반 UI
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // 통계 카드
          if (_statistics != null) _buildStatisticsCard(),

          // 탭 헤더
          TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: '전체 점호'),
              Tab(text: '오늘 점호'),
              Tab(text: '통계'),
            ],
          ),

          // 탭 내용
          Expanded(
            child: TabBarView(
              children: [
                _buildAllInspectionsList(),
                _buildTodayInspectionsList(),
                _buildStatisticsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 통계 카드
  Widget _buildStatisticsCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('전체', _statistics!.totalInspections.toString(), Colors.blue),
          _buildStatItem('통과', _statistics!.passedInspections.toString(), Colors.green),
          _buildStatItem('실패', _statistics!.failedInspections.toString(), Colors.red),
          _buildStatItem('통과율', '${_statistics!.passRate.toStringAsFixed(1)}%', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
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
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// 전체 점호 목록
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

  /// 오늘 점호 목록
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

  /// 점호 카드
  Widget _buildInspectionCard(AdminInspectionModel inspection) {
    final statusColor = inspection.status == 'PASS' ? Colors.green : Colors.red;
    final statusText = inspection.status == 'PASS' ? '통과' : '실패';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${inspection.userName} (${inspection.roomNumber})',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                border: Border.all(color: statusColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ),
          ],
        ),
        subtitle: Text('점수: ${inspection.score}점 • ${_formatDateTime(inspection.createdAt)}'),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inspection.geminiFeedback != null) ...[
                  Text('AI 피드백:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(inspection.geminiFeedback!),
                  SizedBox(height: 8),
                ],
                if (inspection.adminComment != null) ...[
                  Text('관리자 코멘트:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(inspection.adminComment!),
                  SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showDeleteConfirmDialog(inspection),
                      icon: Icon(Icons.delete, size: 16),
                      label: Text('삭제'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(120, 36),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 통계 뷰
  Widget _buildStatisticsView() {
    if (_statistics == null) {
      return Center(child: Text('통계 데이터를 불러올 수 없습니다.'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '점호 통계',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _buildDetailedStatistics(),
        ],
      ),
    );
  }

  /// 상세 통계
  Widget _buildDetailedStatistics() {
    return Column(
      children: [
        _buildStatRow('전체 점호 수', _statistics!.totalInspections.toString()),
        _buildStatRow('통과한 점호', _statistics!.passedInspections.toString()),
        _buildStatRow('실패한 점호', _statistics!.failedInspections.toString()),
        _buildStatRow('재검 점호', _statistics!.reInspections.toString()),
        _buildStatRow('통과율', '${_statistics!.passRate.toStringAsFixed(2)}%'),
      ],
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

  /// 날짜 시간 포맷
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}