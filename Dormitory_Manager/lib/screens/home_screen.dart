import 'package:flutter/material.dart';
import 'package:dormitory_manager/models/schedule.dart';
import 'package:dormitory_manager/services/schedule_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../data/user_repository.dart';
import '../data/complaint_repository.dart';
import '../data/document_repository.dart';
import '../models/notice.dart';
import '../data/notice_repository.dart';
import '../utils/storage_helper.dart';
import 'admin_complaint_screen.dart';
import 'admin_document_screen.dart';
import 'user_complaint_screen.dart';
import 'user_document_screen.dart';
import 'notice_list_screen.dart';
import 'my_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 공지사항
  Notice? latestNotice;
  bool isLoadingNotice = true;

  // 캘린더/D-Day 상태
  final ScheduleService _scheduleService = ScheduleService();
  Map<DateTime, List<Schedule>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Schedule? _nearestEvent;
  int _dDay = 0;
  bool _isLoadingSchedule = true;

  // ✅ 민원/서류 통계
  int _complaintTotalCount = 0;
  int _complaintCompletedCount = 0;
  int _documentTotalCount = 0;
  int _documentApprovedCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadLatestNotice(),
      _loadSchedules(),
      _loadComplaintStats(),
      _loadDocumentStats(),
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

  // 캘린더 및 D-Day 로직
  Future<void> _loadSchedules() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSchedule = true;
    });

    try {
      final schedules = await _scheduleService.getSchedules();
      final Map<DateTime, List<Schedule>> events = {};
      Schedule? nearest;
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      int minDiff = -1;

      for (var schedule in schedules) {
        // startDate를 로컬 시간으로 변환
        final localStartDate = schedule.startDate.toLocal();
        final eventDate = DateTime(
          localStartDate.year,
          localStartDate.month,
          localStartDate.day,
        );
        events.putIfAbsent(eventDate, () => []).add(schedule);

        // D-Day 계산 (오늘이거나 오늘 이후의 일정만 대상)
        if (!eventDate.isBefore(today)) {
          final diff = eventDate.difference(today).inDays;
          if (minDiff == -1 || diff < minDiff) {
            minDiff = diff;
            nearest = schedule;
          }
        }
      }

      if (mounted) {
        setState(() {
          _events = events;
          _nearestEvent = nearest;
          _dDay = minDiff;
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      print('[ERROR] 스케줄 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingSchedule = false;
        });
      }
    }
  }

  // ✅ 민원 통계 로드
  Future<void> _loadComplaintStats() async {
    try {
      final user = await StorageHelper.getUser();
      if (user != null && !user.isAdmin) {
        final complaints = await ComplaintRepository.getUserComplaints(user.id);
        if (mounted) {
          setState(() {
            _complaintTotalCount = complaints.length;
            _complaintCompletedCount = complaints.where((c) => c.status == '완료').length;
          });
        }
      }
    } catch (e) {
      print('[ERROR] 민원 통계 로드 실패: $e');
    }
  }

  // ✅ 서류 통계 로드
  Future<void> _loadDocumentStats() async {
    try {
      final user = await StorageHelper.getUser();
      if (user != null && !user.isAdmin) {
        final documents = await DocumentRepository.getUserDocuments(user.id);
        if (mounted) {
          setState(() {
            _documentTotalCount = documents.length;
            _documentApprovedCount = documents.where((d) => d.status == '승인').length;
          });
        }
      }
    } catch (e) {
      print('[ERROR] 서류 통계 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserRepository.currentUser;
    final userName = user?.name ?? '사용자';
    final userStatus = user?.isAdmin == true ? '관리자' : '입사';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 헤더
                  _buildHeader(userName, userStatus),

                  // 공지사항 배너
                  _buildNoticeBanner(),

                  // D-Day 위젯
                  _buildDDayCard(),

                  const SizedBox(height: 20),

                  // 상태 통계 - ✅ 실제 통계 반영
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusCard(
                          '신고',
                          '$_complaintCompletedCount/$_complaintTotalCount',
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatusCard(
                          '문서',
                          '$_documentApprovedCount/$_documentTotalCount',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 중요 일정 (캘린더)
                  _buildCalendarCard(),
                ],
              ),
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
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$userName님',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyPageScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NoticeListScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '공지사항',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoadingNotice
                        ? '불러오는 중...'
                        : latestNotice?.title ?? '공지사항이 없습니다',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDDayCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.event, color: Colors.orange, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _isLoadingSchedule
                ? const Text('일정 불러오는 중...')
                : _nearestEvent != null
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nearestEvent!.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy.MM.dd').format(_nearestEvent!.startDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
                : const Text(
              '예정된 일정이 없습니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          if (_nearestEvent != null && !_isLoadingSchedule)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _dDay == 0 ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _dDay == 0 ? 'D-Day' : 'D-$_dDay',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ 수정된 _buildStatusCard - 클릭 시 목록 화면으로 이동
  Widget _buildStatusCard(String title, String count, Color color) {
    final isAdmin = UserRepository.currentUser?.isAdmin ?? false;

    return GestureDetector(
      onTap: () async {
        if (title == '신고') {
          if (isAdmin) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminComplaintScreen(),
              ),
            );
          } else {
            // ✅ 사용자는 민원 목록 화면으로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserComplaintScreen(),
              ),
            );
            // 돌아오면 통계 새로고침
            _loadComplaintStats();
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
            // ✅ 사용자는 서류 목록 화면으로 이동
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserDocumentScreen(),
              ),
            );
            // 돌아오면 통계 새로고침
            _loadDocumentStats();
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
                  title == '신고' ? Icons.report_problem : Icons.description,
                  color: color,
                  size: 24,
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ✅ 상태 설명 추가
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title == '신고' ? '처리완료/전체' : '승인/전체',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                '이번 달 일정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TableCalendar<Schedule>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final normalizedDay = DateTime(day.year, day.month, day.day);
              return _events[normalizedDay] ?? [];
            },
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey[600]),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey[600]),
            ),
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
              markersMaxCount: 3,
              outsideDaysVisible: false,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });

              // 선택된 날짜의 이벤트 표시
              final normalizedDay = DateTime(
                selectedDay.year,
                selectedDay.month,
                selectedDay.day,
              );
              final dayEvents = _events[normalizedDay] ?? [];
              if (dayEvents.isNotEmpty) {
                _showEventsDialog(selectedDay, dayEvents);
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            locale: 'ko_KR',
          ),
        ],
      ),
    );
  }

  void _showEventsDialog(DateTime date, List<Schedule> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          DateFormat('yyyy년 MM월 dd일').format(date),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: event.content != null && event.content!.isNotEmpty
                    ? Text(
                  event.content!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
                    : null,
              );
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
}