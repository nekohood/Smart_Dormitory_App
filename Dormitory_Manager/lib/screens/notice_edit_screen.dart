import 'package:flutter/material.dart';
import '../api/notice_api.dart';
import '../data/user_repository.dart'; // author용 정보 추출을 위한 임포트

class NoticeEditScreen extends StatefulWidget {
  final Map<String, dynamic> notice;
  const NoticeEditScreen({super.key, required this.notice});

  @override
  State<NoticeEditScreen> createState() => _NoticeEditScreenState();
}

class _NoticeEditScreenState extends State<NoticeEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice['title']);
    _contentController = TextEditingController(text: widget.notice['content']);
  }

  Future<void> _submitEdit() async {
    final updated = await NoticeApi.updateNotice(
      id: widget.notice['id'] as int, // ← 꼭 타입 맞추기
      title: _titleController.text,
      content: _contentController.text,
      author: UserRepository.currentUser?.id ?? '관리자',
    );

    if (updated) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공지 수정 실패')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지 수정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: '내용'),
              maxLines: 6,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitEdit,
              child: const Text('수정 완료'),
            ),
          ],
        ),
      ),
    );
  }
}
