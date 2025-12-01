import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/notice.dart';
import '../data/notice_repository.dart';
import '../utils/auth_provider.dart';

class NoticeWriteScreen extends StatefulWidget {
  final Notice? notice; // 수정할 공지사항 (null이면 새 작성)

  const NoticeWriteScreen({
    super.key,
    this.notice,
  });

  @override
  State<NoticeWriteScreen> createState() => _NoticeWriteScreenState();
}

class _NoticeWriteScreenState extends State<NoticeWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  // ✅ 웹/앱 모두 지원하기 위해 XFile과 Uint8List 사용
  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  final ImagePicker _imagePicker = ImagePicker();

  bool get isEditing => widget.notice != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleController.text = widget.notice!.title;
      _contentController.text = widget.notice!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // ✅ 웹/앱 모두 지원: bytes로 읽기
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageFile = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      // ✅ 웹에서는 카메라 사용 불가
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('웹 환경에서는 카메라를 사용할 수 없습니다. 갤러리에서 선택해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _selectedImageFile = photo;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('사진 촬영 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ AuthProvider에서 관리자 정보 확인 (권한 체크 제거 - 무조건 허용)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      // ✅ 작성자 이름 설정 (사용자 정보가 없어도 기본값 사용)
      final authorName = currentUser?.name ?? '관리자';

      print('[DEBUG] 공지사항 작성 시도 - 작성자: $authorName');

      Notice resultNotice;

      if (isEditing) {
        // 수정
        resultNotice = await NoticeRepository.updateNotice(
          noticeId: widget.notice!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageFile: _selectedImageFile,
          imageBytes: _selectedImageBytes,
        );
      } else {
        // 새 작성
        resultNotice = await NoticeRepository.createNotice(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageFile: _selectedImageFile,
          imageBytes: _selectedImageBytes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? '공지사항이 수정되었습니다.' : '공지사항이 작성되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, resultNotice);
      }
    } catch (e) {
      print('[ERROR] 공지사항 작성 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isEditing ? '수정' : '작성'} 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(
          isEditing ? '공지사항 수정' : '공지사항 작성',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(
              isEditing ? '수정' : '작성',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목/내용 입력 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    // 제목 입력
                    const Text(
                      '제목',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: '공지사항 제목을 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '제목을 입력해주세요';
                        }
                        if (value.trim().length < 2) {
                          return '제목은 2글자 이상 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // 내용 입력
                    const Text(
                      '내용',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: '공지사항 내용을 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      maxLines: 8,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '내용을 입력해주세요';
                        }
                        if (value.trim().length < 10) {
                          return '내용은 10글자 이상 입력해주세요';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 이미지 첨부 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.image,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '이미지 첨부',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        // 갤러리 버튼
                        IconButton(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          color: Colors.blue,
                          tooltip: '갤러리에서 선택',
                        ),
                        // 카메라 버튼 (웹이 아닌 경우에만)
                        if (!kIsWeb)
                          IconButton(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            color: Colors.blue,
                            tooltip: '카메라로 촬영',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 선택된 이미지 또는 기존 이미지 표시
                    if (_selectedImageBytes != null) ...[
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 300),
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
                              // ✅ Image.memory 사용 (웹/앱 모두 지원)
                              child: Image.memory(
                                _selectedImageBytes!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isEditing && widget.notice!.imageUrl != null) ...[
                      // 기존 이미지 표시 (수정 모드)
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxHeight: 300),
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
                                widget.notice!.imageUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
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
                                            '기존 이미지를 불러올 수 없습니다',
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
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '기존 이미지',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // 이미지 없음 플레이스홀더
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '이미지를 첨부해주세요 (선택)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    isEditing ? '수정 완료' : '작성 완료',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}