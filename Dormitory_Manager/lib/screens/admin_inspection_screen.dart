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
      // 재시도 시 토큰을 다시 설정
      try {
        await _initializeAuth();
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        setState(() {
          _errorMessage = '인증 실패: $e';
          _isLoading = false;
        });
        return;
      }
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
    if (!mounted) return;
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
    if (!mounted) return;
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
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ ================== 수정 기능 추가 ==================

  /// 점호 수정 다이얼로그
  Future<void> _showEditInspectionDialog(AdminInspectionModel inspection) async {
    // 폼 관리를 위한 컨트롤러 및 변수
    final _formKey = GlobalKey<FormState>();
    int _currentScore = inspection.score;
    String _currentStatus = inspection.status;
    bool _isReInspection = inspection.isReInspection;
    final TextEditingController _adminCommentController = TextEditingController(text: inspection.adminComment);
    final TextEditingController _geminiFeedbackController = TextEditingController(text: inspection.geminiFeedback);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // StatefulBuilder를 사용하여 다이얼로그 내부의 상태(점수, 상태)를 관리
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('점호 기록 수정'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('사용자: ${inspection.userName} (${inspection.roomNumber})',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 16),

                      // 점수 선택
                      DropdownButtonFormField<int>(
                        value: _currentScore,
                        decoration: InputDecoration(
                          labelText: '점수 (0-10)',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(11, (index) => index)
                            .map((score) => DropdownMenuItem(
                          value: score,
                          child: Text('$score점'),
                        ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              _currentScore = value;
                              // 점수에 따라 상태 자동 변경 (선택적)
                              // _currentStatus = value >= 6 ? 'PASS' : 'FAIL';
                            });
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // 상태 선택
                      DropdownButtonFormField<String>(
                        value: _currentStatus,
                        decoration: InputDecoration(
                          labelText: '상태',
                          border: OutlineInputBorder(),
                        ),
                        items: ['PASS', 'FAIL']
                            .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              _currentStatus = value;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 16),

                      // 재검 여부
                      SwitchListTile(
                        title: Text('재검 점호 여부'),
                        value: _isReInspection,
                        onChanged: (value) {
                          setDialogState(() {
                            _isReInspection = value;
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      // 관리자 코멘트
                      TextFormField(
                        controller: _adminCommentController,
                        decoration: InputDecoration(
                          labelText: '관리자 코멘트',
                          border: OutlineInputBorder(),
                          hintText: '수정 사항이나 피드백을 입력하세요.',
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16),

                      // AI 피드백 (수정 가능하게)
                      TextFormField(
                        controller: _geminiFeedbackController,
                        decoration: InputDecoration(
                          labelText: 'AI 피드백 (수정 가능)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // 1. UpdateRequest 객체 생성
                      final updateRequest = InspectionUpdateRequest(
                        score: _currentScore,
                        status: _currentStatus,
                        adminComment: _adminCommentController.text,
                        geminiFeedback: _geminiFeedbackController.text,
                        isReInspection: _isReInspection,
                      );

                      // 2. 저장 핸들러 호출
                      Navigator.of(context).pop();
                      _handleUpdateInspection(inspection.id, updateRequest);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 점호 기록 수정 실행
  Future<void> _handleUpdateInspection(int inspectionId, InspectionUpdateRequest request) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final updatedInspection = await _inspectionService.updateInspection(inspectionId, request);

      _showSuccessSnackBar('점호 기록(ID: ${updatedInspection.id})이 성공적으로 수정되었습니다.');
      _refreshData(); // 데이터 새로고침

    } catch (e) {
      _showErrorSnackBar('수정 중 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // ✅ ======================================================


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
              Tab(text: '전체 점호 (${_allInspections.length})'),
              Tab(text: '오늘 점호 (${_todayInspections.length})'),
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
                // ✅ 수정된 부분: 수정 버튼 추가
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 간격 조절
                  children: [
                    // 수정 버튼
                    ElevatedButton.icon(
                      onPressed: () => _showEditInspectionDialog(inspection),
                      icon: Icon(Icons.edit, size: 16),
                      label: Text('수정'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: Size(120, 36),
                      ),
                    ),
                    // 삭제 버튼
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