import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../models/attendance.dart';

/// 관리자 - 출석 테이블 관리 화면
class AdminAttendanceTableScreen extends StatefulWidget {
  const AdminAttendanceTableScreen({super.key});

  @override
  State<AdminAttendanceTableScreen> createState() => _AdminAttendanceTableScreenState();
}

class _AdminAttendanceTableScreenState extends State<AdminAttendanceTableScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  
  DateTime _selectedDate = DateTime.now();
  AttendanceTableResponse? _tableData;
  bool _isLoading = false;
  bool _tableExists = false;

  @override
  void initState() {
    super.initState();
    _loadAttendanceTable();
  }

  /// 출석 테이블 로드
  Future<void> _loadAttendanceTable() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _attendanceService.getAttendanceTable(_selectedDate);
      
      setState(() {
        _tableData = response;
        _tableExists = response.entries.isNotEmpty;
      });
    } catch (e) {
      print('[ERROR] 출석 테이블 로드 실패: $e');
      setState(() {
        _tableExists = false;
        _tableData = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 출석 테이블 생성
  Future<void> _createAttendanceTable() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('출석 테이블 생성'),
        content: Text(
          '${DateFormat('yyyy년 MM월 dd일').format(_selectedDate)}의\n출석 테이블을 생성하시겠습니까?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('생성'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _attendanceService.createAttendanceTable(_selectedDate);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 테이블이 생성되었습니다.')),
      );

      await _loadAttendanceTable();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 테이블 생성 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 출석 테이블 삭제
  Future<void> _deleteAttendanceTable() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('출석 테이블 삭제'),
        content: Text(
          '${DateFormat('yyyy년 MM월 dd일').format(_selectedDate)}의\n출석 테이블을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _attendanceService.deleteAttendanceTable(_selectedDate);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 테이블이 삭제되었습니다.')),
      );

      await _loadAttendanceTable();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 테이블 삭제 실패: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 날짜 선택
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadAttendanceTable();
    }
  }

  /// 출석 항목 수정 다이얼로그
  Future<void> _showEditDialog(AttendanceEntry entry) async {
    final notesController = TextEditingController(text: entry.notes ?? '');
    String selectedStatus = entry.status;
    int selectedScore = entry.score ?? 0;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('출석 항목 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('호실: ${entry.roomNumber}'),
                Text('학번: ${entry.userId}'),
                Text('이름: ${entry.userName}'),
                SizedBox(height: 16),
                
                // 점수 선택
                Text('점수', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: selectedScore.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: selectedScore.toString(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedScore = value.toInt();
                    });
                  },
                ),
                Text('현재 점수: $selectedScore점'),
                SizedBox(height: 16),
                
                // 상태 선택
                Text('상태', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  items: ['PENDING', 'PASS', 'FAIL'].map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedStatus = value;
                      });
                    }
                  },
                ),
                SizedBox(height: 16),
                
                // 노트
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: '관리자 노트',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'score': selectedScore,
                  'status': selectedStatus,
                  'notes': notesController.text,
                });
              },
              child: Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _updateEntry(entry.id, result);
    }

    notesController.dispose();
  }

  /// 출석 항목 업데이트
  Future<void> _updateEntry(int entryId, Map<String, dynamic> data) async {
    try {
      await _attendanceService.updateAttendanceEntry(
        entryId,
        score: data['score'],
        status: data['status'],
        notes: data['notes'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 항목이 수정되었습니다.')),
      );

      await _loadAttendanceTable();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('출석 항목 수정 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('출석 테이블 관리'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAttendanceTable,
            tooltip: '새로고침',
          ),
          if (_tableExists)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteAttendanceTable,
              tooltip: '테이블 삭제',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: !_tableExists
          ? FloatingActionButton.extended(
        heroTag: 'fab_attendance_table',  // ✅ heroTag 추가
        onPressed: _createAttendanceTable,
        icon: Icon(Icons.add),
        label: Text('테이블 생성'),
        backgroundColor: Colors.purple,
      )
          : null,
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // 날짜 선택 헤더
        _buildDateHeader(),
        
        // 통계
        if (_tableData != null) _buildStatistics(),
        
        // 출석 테이블
        Expanded(
          child: _tableExists && _tableData != null
              ? _buildAttendanceTable()
              : _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.purple.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('yyyy년 MM월 dd일 EEEE', 'ko_KR').format(_selectedDate),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _selectDate,
            icon: Icon(Icons.calendar_today),
            label: Text('날짜 변경'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _tableData!.statistics;
    
    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('전체', stats.totalRooms.toString(), Colors.blue),
          _buildStatItem('제출', stats.submittedRooms.toString(), Colors.green),
          _buildStatItem('미제출', stats.pendingRooms.toString(), Colors.orange),
          _buildStatItem(
            '제출률', 
            '${stats.submissionRate.toStringAsFixed(1)}%', 
            Colors.purple,
          ),
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
            fontSize: 24,
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

  Widget _buildAttendanceTable() {
    final entries = _tableData!.entries;

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildAttendanceCard(entry);
      },
    );
  }

  Widget _buildAttendanceCard(AttendanceEntry entry) {
    Color statusColor;
    IconData statusIcon;
    
    if (entry.isSubmitted) {
      statusColor = entry.status == 'PASS' ? Colors.green : Colors.red;
      statusIcon = entry.status == 'PASS' ? Icons.check_circle : Icons.cancel;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Text(
              '${entry.roomNumber}호',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Text(entry.userName),
            SizedBox(width: 8),
            Text(
              entry.userId,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            if (entry.isSubmitted) ...[
              Text('점수: ${entry.score}점 | 상태: ${entry.status}'),
              if (entry.submissionTime != null)
                Text(
                  '제출: ${DateFormat('HH:mm').format(entry.submissionTime!)}',
                  style: TextStyle(fontSize: 12),
                ),
            ] else
              Text('미제출', style: TextStyle(color: Colors.orange)),
            if (entry.notes != null && entry.notes!.isNotEmpty)
              Text(
                '노트: ${entry.notes}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit),
          onPressed: () => _showEditDialog(entry),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_chart,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            '출석 테이블이 존재하지 않습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '하단의 버튼을 눌러 테이블을 생성하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
