import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../data/notice_repository.dart';
import '../utils/auth_provider.dart';
import 'notice_write_screen.dart';

class NoticeDetailScreen extends StatefulWidget {
  final Notice notice;

  const NoticeDetailScreen({
    super.key,
    required this.notice,
  });

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late Notice currentNotice;
  bool isLoading = true;  // ✅ 초기 로딩 상태 true로 변경

  @override
  void initState() {
    super.initState();
    currentNotice = widget.notice;
    // ✅ 화면 진입 시 서버에서 공지사항 조회 (조회수 증가)
    _loadNoticeDetail();
  }

  // ✅ 서버에서 공지사항 상세 조회 (조회수 증가 포함)
  Future<void> _loadNoticeDetail() async {
    try {
      print('[DEBUG] 공지사항 상세 조회 시작 - ID: ${widget.notice.id}');
      final updatedNotice = await NoticeRepository.getNoticeById(widget.notice.id);

      if (mounted) {
        setState(() {
          currentNotice = updatedNotice;
          isLoading = false;
        });
        print('[DEBUG] 공지사항 상세 조회 완료 - 조회수: ${updatedNotice.viewCount}');
      }
    } catch (e) {
      print('[ERROR] 공지사항 상세 조회 실패: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        // 실패해도 기존 데이터로 표시
      }
    }
  }

  Future<void> _deleteNotice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: const Text('이 공지사항을 삭제하시겠습니까?\n삭제된 공지사항은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isLoading = true;
      });

      try {
        await NoticeRepository.deleteNotice(currentNotice.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('공지사항이 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ✅ 날짜/시간 포맷팅 헬퍼 메서드
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ AuthProvider에서 관리자 여부 확인
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin;

    print('[DEBUG] NoticeDetailScreen - isAdmin: $isAdmin');

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
        actions: isAdmin
            ? [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoticeWriteScreen(
                        notice: currentNotice,
                      ),
                    ),
                  ).then((updatedNotice) {
                    if (updatedNotice != null && updatedNotice is Notice) {
                      setState(() {
                        currentNotice = updatedNotice;
                      });
                    }
                  });
                  break;
                case 'delete':
                  _deleteNotice();
                  break;
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
        ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 섹션
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // 고정 배지
                  if (currentNotice.isPinned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '고정됨',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 제목
                  Text(
                    currentNotice.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ 메타 정보 (작성자)
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentNotice.author,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ✅ 작성일
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '작성일: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _formatDateTime(currentNotice.createdAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // ✅ 수정일 (수정된 경우에만 표시)
                  if (currentNotice.updatedAt != null &&
                      currentNotice.updatedAt!.isAfter(currentNotice.createdAt.add(const Duration(seconds: 1)))) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.edit_calendar,
                          size: 16,
                          color: Colors.orange[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '수정일: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[600],
                          ),
                        ),
                        Text(
                          _formatDateTime(currentNotice.updatedAt!),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),

                  // ✅ 조회수
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '조회수 ${currentNotice.viewCount}회',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 이미지 섹션
            if (currentNotice.imageUrl != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    currentNotice.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[100],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '이미지를 불러올 수 없습니다',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // 본문 섹션
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
              child: Text(
                currentNotice.content,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.7,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}