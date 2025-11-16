import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // 날짜 포맷을 위해
import 'package:intl/date_symbol_data_local.dart'; // 한글 로케일
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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR', null); // 한글 로케일 초기화
    _selectedDay = _focusedDay;
    _loadSchedules();
  }

  /// 서버에서 모든 일정을 불러와 캘린더 이벤트 맵에 채웁니다.
  Future<void> _loadSchedules() async {
    setState(() { _isLoading = true; });
    try {
      final schedules = await _scheduleService.getSchedules();
      final Map<DateTime, List<Schedule>> events = {};

      for (final schedule in schedules) {
        // DB의 날짜(DateTime)는 UTC 기준이므로, .toLocal()로 변환
        DateTime date = schedule.startDate.toLocal();
        // 날짜 부분만 (YYYY-MM-DD)을 키로 사용하기 위해 정규화
        DateTime normalizedDate = DateTime(date.year, date.month, date.day);

        if (events[normalizedDate] == null) {
          events[normalizedDate] = [];
        }
        events[normalizedDate]!.add(schedule);
      }

      setState(() {
        _events = events;
        // 선택된 날짜의 이벤트 목록도 새로고침
        if (_selectedDay != null) {
          _selectedEvents = _getEventsForDay(_selectedDay!);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 로드 실패: $e')),
        );
      }
    }
  }

  /// 특정 날짜의 이벤트 목록을 반환합니다.
  List<Schedule> _getEventsForDay(DateTime day) {
    // 날짜 정규화 (시간, 분, 초 제거)
    DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  /// 날짜가 선택되었을 때 호출됩니다.
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay; // 포커스도 선택된 날짜로 이동
        _selectedEvents = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('학사 일정 관리'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Schedule>(
            locale: 'ko_KR', // 한글 설정
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            // 캘린더 헤더 스타일
            headerStyle: HeaderStyle(
              formatButtonVisible: false, // '2주', '월' 버튼 숨기기
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            // 캘린더 본체 스타일
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.shade200,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            // 선택된 날짜 강조
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() { _calendarFormat = format; });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // 페이지 넘길 때 포커스 이동
            },
            // 캘린더에 이벤트 마커(점) 표시
            eventLoader: _getEventsForDay,
          ),
          const SizedBox(height: 8.0),
          // 선택된 날짜의 이벤트 목록
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _buildEventList(),
          ),
        ],
      ),
      // 새 일정 추가 버튼
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: '새 일정 추가',
        onPressed: () {
          // 새 일정을 위해 null 전달 (선택된 날짜를 기본값으로 함)
          _showScheduleDialog(null, _selectedDay ?? DateTime.now());
        },
      ),
    );
  }

  /// 선택된 날짜의 이벤트 리스트를 빌드합니다.
  Widget _buildEventList() {
    if (_selectedEvents.isEmpty) {
      return Center(child: Text('선택된 날짜(${DateFormat('M월 d일').format(_selectedDay!)})에 일정이 없습니다.'));
    }
    return ListView.builder(
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final schedule = _selectedEvents[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: ListTile(
            title: Text(schedule.title),
            subtitle: schedule.content != null && schedule.content!.isNotEmpty
                ? Text(schedule.content!)
                : null,
            trailing: Icon(Icons.edit, color: Colors.blue),
            onTap: () => _showScheduleDialog(schedule, schedule.startDate), // 수정
          ),
        );
      },
    );
  }

  /// 일정 생성 또는 수정을 위한 다이얼로그
  Future<void> _showScheduleDialog(Schedule? schedule, DateTime defaultDate) async {
    final _formKey = GlobalKey<FormState>();
    final _titleController = TextEditingController(text: schedule?.title);
    final _contentController = TextEditingController(text: schedule?.content);

    // 날짜 상태는 StatefulBuilder 내부에서 관리
    DateTime _startDate = schedule?.startDate.toLocal() ?? defaultDate;
    DateTime _endDate = schedule?.endDate?.toLocal() ?? _startDate;

    await showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder를 사용해야 다이얼로그 내부의 날짜가 setState로 변경됨
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {

            // 날짜 선택기 헬퍼 함수
            Future<DateTime?> _pickDate(DateTime initialDate) async {
              return await showDatePicker(
                context: context, // 메인 context 사용
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
            }

            return AlertDialog(
              title: Text(schedule == null ? '새 일정 추가' : '일정 수정'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(labelText: '제목'),
                        validator: (value) => (value?.isEmpty ?? true) ? '제목을 입력하세요.' : null,
                      ),
                      TextFormField(
                        controller: _contentController,
                        decoration: InputDecoration(labelText: '내용 (선택)'),
                      ),
                      SizedBox(height: 16),
                      // 시작 날짜
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('시작: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                          IconButton(
                            icon: Icon(Icons.calendar_today, color: Colors.blue),
                            onPressed: () async {
                              final date = await _pickDate(_startDate);
                              if (date != null) {
                                setDialogState(() { _startDate = date; });
                              }
                            },
                          ),
                        ],
                      ),
                      // 종료 날짜 (시작 날짜와 같을 수 있음)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('종료: ${DateFormat('yyyy-MM-dd').format(_endDate)}'),
                          IconButton(
                            icon: Icon(Icons.calendar_today, color: Colors.blue),
                            onPressed: () async {
                              final date = await _pickDate(_endDate);
                              if (date != null) {
                                setDialogState(() { _endDate = date; });
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (schedule != null) // 수정 시에만 삭제 버튼 표시
                  TextButton(
                    child: Text('삭제', style: TextStyle(color: Colors.red)),
                    onPressed: () => _handleDeleteSchedule(schedule.id, dialogContext),
                  ),
                Spacer(), // 버튼을 양쪽으로 밀기
                TextButton(
                  child: Text('취소'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: Text('저장'),
                  onPressed: () => _handleSaveSchedule(
                      _formKey, schedule,
                      _titleController.text, _contentController.text,
                      _startDate, _endDate, dialogContext
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// [저장] 버튼 처리 (생성/수정)
  Future<void> _handleSaveSchedule(
      GlobalKey<FormState> formKey,
      Schedule? existingSchedule,
      String title, String content,
      DateTime startDate, DateTime endDate,
      BuildContext dialogContext // 다이얼로그의 context
      ) async {
    if (!formKey.currentState!.validate()) return; // 유효성 검사

    // 날짜를 UTC로 변환하여 서버에 저장
    final newSchedule = Schedule(
      id: existingSchedule?.id ?? 0, // id가 0이거나 null이면 새 일정 (id는 서버가 생성)
      title: title,
      content: content.isNotEmpty ? content : null,
      startDate: startDate, // DatePicker는 Local Time을 반환
      endDate: endDate,     // Service에서 .toUtc() 처리
      category: 'GENERAL', // 카테고리 (필요시 UI 추가)
    );

    try {
      if (existingSchedule == null) {
        // 생성
        await _scheduleService.createSchedule(newSchedule);
      } else {
        // 수정
        await _scheduleService.updateSchedule(existingSchedule.id, newSchedule);
      }

      Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
      _loadSchedules(); // 목록 새로고침

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 저장 실패: $e')),
        );
      }
    }
  }

  /// [삭제] 버튼 처리
  Future<void> _handleDeleteSchedule(int id, BuildContext dialogContext) async {
    try {
      await _scheduleService.deleteSchedule(id);
      Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
      _loadSchedules(); // 목록 새로고침
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 삭제 실패: $e')),
        );
      }
    }
  }
}