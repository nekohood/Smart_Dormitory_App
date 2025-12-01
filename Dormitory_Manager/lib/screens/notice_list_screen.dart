import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../data/notice_repository.dart';
import '../utils/auth_provider.dart';
import 'notice_detail_screen.dart';
import 'notice_write_screen.dart';

class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  List<Notice> notices = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final loadedNotices = await NoticeRepository.getAllNotices();
      setState(() {
        notices = loadedNotices;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '공지사항을 불러오는데 실패했습니다.';
        isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _getTimeAgo(DateTime date) {
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
    // ✅ AuthProvider에서 관리자 여부 확인 (UserRepository 대신)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin;

    print('[DEBUG] NoticeListScreen - isAdmin: $isAdmin');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text(
          '공지사항',
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
            onPressed: _loadNotices,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: '공지사항 검색',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                // 검색 기능 구현 예정
              },
            ),
          ),

          // 공지사항 목록
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadNotices,
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            )
                : notices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 공지사항이 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadNotices,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notices.length,
                itemBuilder: (context, index) {
                  final notice = notices[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  NoticeDetailScreen(notice: notice),
                            ),
                          ).then((_) => _loadNotices());
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // 고정 아이콘
                              if (notice.isPinned)
                                Container(
                                  margin:
                                  const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius:
                                    BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.push_pin,
                                    size: 20,
                                    color: Colors.orange,
                                  ),
                                ),

                              // 공지사항 정보
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    // 제목
                                    Text(
                                      notice.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // 날짜 및 시간
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(
                                              notice.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                            Colors.grey[500],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${_getTimeAgo(notice.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                            Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // 화살표 아이콘
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // 관리자인 경우에만 작성 버튼 표시
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        heroTag: 'fab_notice_list',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NoticeWriteScreen(),
            ),
          ).then((_) => _loadNotices());
        },
        backgroundColor: Colors.blue,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      )
          : null,
    );
  }
}