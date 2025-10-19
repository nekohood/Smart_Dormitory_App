import 'package:flutter/material.dart';
import '../api/notice_api.dart'; // 서버 연동 API
import '../data/user_repository.dart'; // 사용자 정보 확인용
import 'notice_detail_screen.dart';
import 'notice_write_screen.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  late Future<List<dynamic>> _noticesFuture;

  @override
  void initState() {
    super.initState();
    _noticesFuture = NoticeApi.fetchNotices();
  }

  void _refreshNotices() {
    setState(() {
      _noticesFuture = NoticeApi.fetchNotices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = UserRepository.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotices,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _noticesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('에러 발생: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('등록된 공지사항이 없습니다.'));
          }

          final notices = snapshot.data!;
          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              final notice = notices[index];
              return ListTile(
                leading: notice['imagePath'] != null && notice['imagePath'].toString().isNotEmpty
                    ? Image.network(
                  'http://10.0.2.2:8080/uploads/${notice['imagePath'].split('\\').last}',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image),
                )
                    : const Icon(Icons.image_not_supported), // 이미지 없을 경우 대체 아이콘
                title: Text(notice['title']),
                subtitle: Text(notice['content'], maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoticeDetailScreen(notice: notice),
                    ),
                  ).then((_) => _refreshNotices());
                },
              );
            },
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoticeWriteScreen()),
          );
          if (result == true) {
            _refreshNotices();
          }
        },
      )
          : null,
    );
  }
}
