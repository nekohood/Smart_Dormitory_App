import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../models/notice.dart';
import '../api/dio_client.dart';

class NoticeService {
  // 모든 공지사항 조회
  static Future<List<Notice>> getAllNotices() async {
    try {
      final response = await DioClient.get('/notices');
      final responseData = response.data;
      if (responseData['success'] == true) {
        final List<dynamic> noticeData = responseData['notices'];
        return noticeData.map((data) => Notice.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('공지사항 목록 조회 실패: $e');
    }
  }

  // 최신 공지사항 조회
  static Future<Notice?> getLatestNotice() async {
    try {
      final response = await DioClient.get('/notices/latest');
      final responseData = response.data;
      if (responseData['success'] == true && responseData['notice'] != null) {
        return Notice.fromJson(responseData['notice']);
      }
      return null;
    } catch (e) {
      throw Exception('최신 공지사항 조회 실패: $e');
    }
  }

  // 특정 공지사항 조회 (ID 기반)
  static Future<Notice> getNoticeById(int noticeId) async {
    try {
      final response = await DioClient.get('/notices/$noticeId');
      final responseData = response.data;
      if (responseData['success'] == true && responseData['notice'] != null) {
        return Notice.fromJson(responseData['notice']);
      } else {
        throw Exception(responseData['message'] ?? '공지사항을 찾을 수 없습니다.');
      }
    } catch (e) {
      throw Exception('공지사항 조회 실패: $e');
    }
  }

  // ✅ 공지사항 작성 (관리자용) - 웹/앱 모두 지원
  static Future<Notice> createNotice({
    required String title,
    required String content,
    XFile? imageFile,
    Uint8List? imageBytes,
  }) async {
    try {
      print('[DEBUG] NoticeService.createNotice 시작');
      print('[DEBUG] 이미지 파일: ${imageFile != null}, 이미지 바이트: ${imageBytes != null}');

      // 이미지가 있는 경우 multipart 요청
      if (imageFile != null || imageBytes != null) {
        final formData = FormData();

        // 기본 필드 추가
        formData.fields.addAll([
          MapEntry('title', title),
          MapEntry('content', content),
          MapEntry('author', '관리자'),  // ✅ 기본값 사용
          MapEntry('isPinned', 'false'),
        ]);

        // ✅ 이미지 파일 추가 (웹/앱 모두 지원)
        if (imageBytes != null && imageFile != null) {
          final fileName = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
          formData.files.add(
            MapEntry(
              'file',
              MultipartFile.fromBytes(
                imageBytes,
                filename: fileName,
                contentType: DioMediaType('image', _getImageExtension(fileName)),
              ),
            ),
          );
        }

        print('[DEBUG] FormData 필드: ${formData.fields}');
        print('[DEBUG] FormData 파일: ${formData.files.length}개');

        final response = await DioClient.post('/notices', data: formData);
        final responseData = response.data;

        print('[DEBUG] 서버 응답: $responseData');

        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 작성에 실패했습니다.');
        }
      } else {
        // 파일이 없는 경우 FormData로 전송 (서버가 multipart 기대)
        final formData = FormData();
        formData.fields.addAll([
          MapEntry('title', title),
          MapEntry('content', content),
          MapEntry('author', '관리자'),
          MapEntry('isPinned', 'false'),
        ]);

        final response = await DioClient.post('/notices', data: formData);
        final responseData = response.data;

        print('[DEBUG] 서버 응답 (이미지 없음): $responseData');

        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 작성에 실패했습니다.');
        }
      }
    } catch (e) {
      print('[ERROR] 공지사항 작성 실패: $e');
      throw Exception('공지사항 작성 실패: $e');
    }
  }

  // ✅ 공지사항 수정 (관리자용) - 웹/앱 모두 지원
  static Future<Notice> updateNotice({
    required int noticeId,
    required String title,
    required String content,
    XFile? imageFile,
    Uint8List? imageBytes,
  }) async {
    try {
      print('[DEBUG] NoticeService.updateNotice 시작 - ID: $noticeId');

      // 이미지가 있는 경우 multipart 요청
      if (imageFile != null || imageBytes != null) {
        final formData = FormData();

        formData.fields.addAll([
          MapEntry('title', title),
          MapEntry('content', content),
          MapEntry('isPinned', 'false'),
        ]);

        // ✅ 이미지 파일 추가 (웹/앱 모두 지원)
        if (imageBytes != null && imageFile != null) {
          final fileName = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
          formData.files.add(
            MapEntry(
              'file',
              MultipartFile.fromBytes(
                imageBytes,
                filename: fileName,
                contentType: DioMediaType('image', _getImageExtension(fileName)),
              ),
            ),
          );
        }

        // ✅ PUT 대신 POST + _method 사용 (multipart와 호환)
        formData.fields.add(MapEntry('_method', 'PUT'));

        final response = await DioClient.post('/notices/$noticeId', data: formData);
        final responseData = response.data;

        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 수정에 실패했습니다.');
        }
      } else {
        // 파일이 없는 경우 FormData로 전송
        final formData = FormData();
        formData.fields.addAll([
          MapEntry('title', title),
          MapEntry('content', content),
          MapEntry('isPinned', 'false'),
        ]);

        final response = await DioClient.put('/notices/$noticeId', data: formData);
        final responseData = response.data;

        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 수정에 실패했습니다.');
        }
      }
    } catch (e) {
      print('[ERROR] 공지사항 수정 실패: $e');
      throw Exception('공지사항 수정 실패: $e');
    }
  }

  // 공지사항 삭제 (관리자용)
  static Future<void> deleteNotice(int noticeId) async {
    try {
      final response = await DioClient.delete('/notices/$noticeId');
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '공지사항 삭제에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('공지사항 삭제 실패: $e');
    }
  }

  // 공지사항 고정/해제 (관리자용)
  static Future<Notice> togglePinNotice(int noticeId, bool isPinned) async {
    try {
      final response = await DioClient.put('/notices/$noticeId/pin', data: {
        'isPinned': isPinned,
      });

      final responseData = response.data;
      if (responseData['success'] == true) {
        return Notice.fromJson(responseData['notice']);
      } else {
        throw Exception(responseData['message'] ?? '공지사항 고정 상태 변경에 실패했습니다.');
      }
    } catch (e) {
      throw Exception('공지사항 고정 상태 변경 실패: $e');
    }
  }

  // ✅ 이미지 확장자 추출 헬퍼
  static String _getImageExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      case 'bmp':
        return 'bmp';
      default:
        return 'jpeg';
    }
  }
}