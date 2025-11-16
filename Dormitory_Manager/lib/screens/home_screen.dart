import 'package:flutter/material.dart';
import 'package:dormitory_manager/models/schedule.dart'; // ⭐ [신규]
import 'package:dormitory_manager/services/schedule_service.dart'; // ⭐ [신규]
import 'package:table_calendar/table_calendar.dart'; // ⭐ [신규]
import 'package:intl/intl.dart'; // ⭐ [신규]

import '../data/user_repository.dart';
import '../models/notice.dart';
import '../data/notice_repository.dart';
import 'admin_complaint_screen.dart';
import 'admin_document_screen.dart';
import 'complaint_submit_screen.dart';
import 'document_submit_screen.dart';
import 'notice_list_screen.dart';
import 'my_page_screen.dart';

// ⭐ [수정] StatefulWidget으로 변경
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 공지사항
  Notice? latestNotice;
  bool isLoadingNotice = true;

  // ⭐ [신규] 캘린더/D-Day 상태
  final ScheduleService _scheduleService = ScheduleService();
  Map<DateTime, List<Schedule>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Schedule? _nearestEvent;
  int _dDay = 0;
  bool _isLoadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllData();
  }

  // ⭐ [신규] 모든 데이터 로드
  Future<void> _loadAllData() async {
    await Future.wait([
      _loadLatestNotice(),
      _loadSchedules(),
      _loadDDay(),
    ]);
  }

  Future<void> _loadLatestNotice() async {
    if (!mounted) return;
    try {
      final notice = await NoticeRepository.getLatestNotice();
      if (mounted) {
        setState(() {
          latestNotice = notice;
          isLoadingNotice = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingNotice = false;
        });
      }
    }
  }

  // ⭐ [신규] 캘린더용 일정 로드
  Future<void> _loadSchedules() async {
    if (!mounted) return;
    final schedules = await _scheduleService.getAllSchedules();
    final Map<DateTime, List<Schedule>> events = {};

    for (var schedule in schedules) {
      final date = DateTime(schedule.eventDate.year, schedule.eventDate.month, schedule.eventDate.day);
      if (events[date] == null) {
        events[date] = [];
      }
      events[date]!.add(schedule);
    }

    if (mounted) {
      setState(() {
        _events = events;
      });
    }
  }

  // ⭐ [신규] D-Day용 일정 로드
  Future<void> _loadDDay() async {
    if (!mounted) return;
    setState(() { _isLoadingSchedule = true; });

    final upcoming = await _scheduleService.getUpcomingSchedules();
    if (upcoming.isNotEmpty && mounted) {
      final nearest = upcoming.first; // 이미 서비스에서 정렬됨
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final eventDate = DateTime(nearest.eventDate.year, nearest.eventDate.month, nearest.eventDate.day);

      setState(() {
        _nearestEvent = nearest;
        _dDay = eventDate.difference(today).inDays;
        _isLoadingSchedule = false;
      });
    } else if (mounted) {
      setState(() {
        _isLoadingSchedule = false;
      });
    }
  }

  // ⭐ [신규] 캘린더 이벤트 로더
  List<Schedule> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  String _getTimeDifference(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserRepository.currentUser;
    final userName = user?.id ?? '사용자';
    final userStatus = user?.isAdmin == true ? '관리자' : '입사';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 헤더
                _buildHeader(userName, userStatus),

                // 공지사항 배너
                _buildNoticeBanner(),

                // ⭐ [수정] D-Day 위젯
                _buildDDayCard(),

                const SizedBox(height: 20),

                // 상태 통계
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusCard('신고', '0', Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatusCard('문서', '0', Colors.green),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ⭐ [수정] 중요 일정 (캘린더)
                _buildCalendarCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 위젯 빌더 분리 ---

  Widget _buildHeader(String userName, String userStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        UserRepository.currentUser?.isAdmin == true
                            ? Icons.admin_panel_settings
                            : Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userStatus,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyPageScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    if (isLoadingNotice) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withOpacity(0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.schedule,
              color: Colors.orange,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              '공지사항 로딩 중...',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NoticeListScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: latestNotice != null
              ? Colors.orange.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: latestNotice != null
                ? Colors.orange.withOpacity(0.3)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              latestNotice != null
                  ? Icons.campaign
                  : Icons.notifications_off,
              color: latestNotice != null
                  ? Colors.orange
                  : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latestNotice != null
                        ? '새로운 공지사항이 있습니다'
                        : '등록된 공지사항이 없습니다',
                    style: TextStyle(
                      color: latestNotice != null
                          ? Colors.orange
                          : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (latestNotice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      latestNotice!.title,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getTimeDifference(latestNotice!.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: latestNotice != null
                  ? Colors.orange
                  : Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ [신규] D-Day 위젯
  Widget _buildDDayCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다가오는 일정',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 일정 제목
              Flexible(
                child: Text(
                  _isLoadingSchedule
                      ? '로딩 중...'
                      : _nearestEvent?.title ?? '예정된 일정이 없습니다.',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // D-Day
              if (!_isLoadingSchedule && _nearestEvent != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _dDay == 0 ? Colors.redAccent : Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _dDay == 0 ? 'D-DAY' : 'D-$_dDay',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 일정 날짜
          if (!_isLoadingSchedule && _nearestEvent != null)
            Text(
              DateFormat('yyyy년 MM월 dd일').format(_nearestEvent!.eventDate),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, String count, Color color) {
    return GestureDetector(
      onTap: () {
        final isAdmin = UserRepository.currentUser?.isAdmin ?? false;

        if (title == '신고') {
          if (isAdmin) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminComplaintScreen(),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ComplaintSubmitScreen(),
              ),
            );
          }
        } else if (title == '문서') {
          if (isAdmin) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDocumentScreen(),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DocumentSubmitScreen(),
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  title == '신고' ? Icons.warning : Icons.description,
                  color: color,
                  size: 20,
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ [신규] 캘린더 위젯
  Widget _buildCalendarCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12), // 패딩 조정
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 8.0),
            child: const Text(
              '중요 일정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          TableCalendar<Schedule>(
            locale: 'ko_KR', // 한글
            focusedDay: _focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay, // 이벤트 로더 연결
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              // 일정 마커
              markerDecoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false, // '2주' 버튼 숨기기
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          // 선택된 날짜의 일정 목록 (선택 사항)
          if (_selectedDay != null && _getEventsForDay(_selectedDay!).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay!),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ..._getEventsForDay(_selectedDay!).map(
                        (event) => Text(' • ${event.title}'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}