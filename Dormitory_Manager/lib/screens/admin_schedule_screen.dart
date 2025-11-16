import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  // 캘린더 상태 관리
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 일정 데이터 관리
  Map<DateTime, List<Schedule>> _events = {};
  List<Schedule> _selectedEvents = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] AdminScheduleScreen - initState 시작');
    _selectedDay = _focusedDay;
    _loadSchedules();
  }

  /// 서버에서 모든 일정을 불러옵니다
  Future<void> _loadSchedules() async {
    print('[DEBUG] AdminScheduleScreen - 일정 로딩 시작');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schedules = await _scheduleService.getSchedules();
      print('[DEBUG] AdminScheduleScreen - 불러온 일정 개수: ${schedules.length}');

      final Map<DateTime, List<Schedule>> events = {};

      for (final schedule in schedules) {
        DateTime date = schedule.startDate.toLocal();
        DateTime normalizedDate = DateTime(date.year, date.month, date.day);

        if (events[normalizedDate] == null) {
          events[normalizedDate] = [];
        }
        events[normalizedDate]!.add(schedule);
      }

      if (mounted) {
        setState(() {
          _events = events;
          if (_selectedDay != null) {
            _selectedEvents = _getEventsForDay(_selectedDay!);
          }
          _isLoading = false;
        });
      }
      print('[DEBUG] AdminScheduleScreen - 일정 로딩 완료');
    } catch (e) {
      print('[ERROR] AdminScheduleScreen - 일정 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '일정을 불러오는데 실패했습니다: $e';
        });
      }
    }
  }

  /// 특정 날짜의 이벤트 목록을 반환합니다
  List<Schedule> _getEventsForDay(DateTime day) {
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  /// 날짜가 선택되었을 때 호출됩니다
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] AdminScheduleScreen - build 호출됨');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          '일정 관리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: '일정 추가',
      ),
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
            Text('일정을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSchedules,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 캘린더
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            locale: 'ko_KR',
            eventLoader: _getEventsForDay,
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // 선택된 날짜의 일정 목록
        Expanded(
          child: _buildEventsList(),
        ),
      ],
    );
  }

  Widget _buildEventsList() {
    if (_selectedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '선택한 날짜에 일정이 없습니다.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event, color: Colors.blue),
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.content != null && event.content!.isNotEmpty)
                  Text(event.content!),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(event.startDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditScheduleDialog(event);
                } else if (value == 'delete') {
                  _deleteSchedule(event.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('수정'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 일정 추가 다이얼로그
  void _showAddScheduleDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: '내용',
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
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                try {
                  // Schedule 객체 생성
                  final newSchedule = Schedule(
                    id: 0, // 새 일정이므로 ID는 0
                    title: titleController.text,
                    content: contentController.text.isEmpty ? null : contentController.text,
                    startDate: selectedDate,
                    endDate: selectedDate,
                    category: 'GENERAL',
                  );

                  await _scheduleService.createSchedule(newSchedule);

                  if (mounted) {
                    Navigator.pop(context);
                    _loadSchedules();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('일정이 추가되었습니다')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('일정 추가 실패: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  /// 일정 수정 다이얼로그
  void _showEditScheduleDialog(Schedule schedule) {
    final titleController = TextEditingController(text: schedule.title);
    final contentController = TextEditingController(text: schedule.content ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: '내용',
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
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                try {
                  // Schedule 객체 생성 (기존 일정 정보 유지)
                  final updatedSchedule = Schedule(
                    id: schedule.id,
                    title: titleController.text,
                    content: contentController.text.isEmpty ? null : contentController.text,
                    startDate: schedule.startDate,
                    endDate: schedule.endDate,
                    category: schedule.category,
                  );

                  await _scheduleService.updateSchedule(schedule.id, updatedSchedule);

                  if (mounted) {
                    Navigator.pop(context);
                    _loadSchedules();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('일정이 수정되었습니다')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('일정 수정 실패: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  /// 일정 삭제
  Future<void> _deleteSchedule(int scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _scheduleService.deleteSchedule(scheduleId);
        if (mounted) {
          _loadSchedules();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정 삭제 실패: $e')),
          );
        }
      }
    }
  }
}