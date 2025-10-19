import 'package:flutter/material.dart';
import '../data/user_repository.dart';
import '../models/notice.dart';
import '../data/notice_repository.dart';
import 'admin_complaint_screen.dart';
import 'admin_document_screen.dart';
import 'complaint_submit_screen.dart';
import 'document_submit_screen.dart';
import 'notice_list_screen.dart'; // 새로운 공지사항 목록 화면
import 'my_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Notice? latestNotice;
  bool isLoadingNotice = true;

  @override
  void initState() {
    super.initState();
    _loadLatestNotice();
  }

  Future<void> _loadLatestNotice() async {
    try {
      final notice = await NoticeRepository.getLatestNotice();
      setState(() {
        latestNotice = notice;
        isLoadingNotice = false;
      });
    } catch (e) {
      setState(() {
        isLoadingNotice = false;
      });
    }
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
    final userName = user?.id ?? '사용자';  // name 대신 id 사용
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
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      // 사용자 정보
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
                                    user?.isAdmin == true
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
                      // 프로필 버튼
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
                ),

                // 공지사항 배너 - 새로운 공지사항 목록 화면으로 연결
                if (isLoadingNotice)
                  Container(
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
                  )
                else
                  GestureDetector(
                    onTap: () {
                      // 공지사항 목록 화면으로 이동
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
                  ),

                // 입사 체크인
                Container(
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
                        '입사 체크인',
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
                          const Text(
                            '9.4',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'D+441',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '6.20',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

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

                // 중요 일정
                Container(
                  width: double.infinity,
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
                        '중요 일정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // 달력
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                children: [
                                  Text(
                                    'May 2023',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // 간단한 달력 표시
                                  Text(
                                    '1  2  3  4  5  6  7\n8  9  10 11 12 13 14',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 일정 정보
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '5',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'May',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '20일 수축축',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.yellow,
                                    ),
                                  ),
                                  Text(
                                    '23일 기숙사 소독',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.yellow,
                                    ),
                                  ),
                                  Text(
                                    '24일 시설 점검',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String count, Color color) {
    return GestureDetector(
      onTap: () {
        final isAdmin = UserRepository.currentUser?.isAdmin ?? false;

        if (title == '신고') {
          // 신고 버튼 클릭 시 사용자/관리자 구분
          if (isAdmin) {
            // 관리자인 경우 민원 관리 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminComplaintScreen(),
              ),
            );
          } else {
            // 사용자인 경우 민원 신고 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ComplaintSubmitScreen(),
              ),
            );
          }
        } else if (title == '문서') {
          // 문서 버튼 클릭 시 사용자/관리자 구분
          if (isAdmin) {
            // 관리자인 경우 서류 관리 화면으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDocumentScreen(),
              ),
            );
          } else {
            // 사용자인 경우 서류 제출 화면으로 이동
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
}