import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/notice.dart';
import '../api/dio_client.dart';

/// 공지사항 API 서비스
/// ✅ 수정: 모든 작성/수정 요청을 multipart/form-data로 통일
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

  /// 공지사항 작성 (관리자용)
  /// ✅ 파일 유무에 관계없이 항상 multipart/form-data로 요청
  static Future<Notice> createNotice({
    required String title,
    required String content,
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      print('[NoticeService] 공지사항 작성 시작 - 제목: $title');

      final formData = FormData.fromMap({
        'title': title,
        'content': content,
        'author': 'admin',
        'isPinned': 'false',
      });

      // 파일 추가 (File 또는 Uint8List)
      if (imageFile != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(imageFile.path),
        ));
      } else if (imageBytes != null) {
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            imageBytes,
            filename: fileName ?? 'image.jpg',
          ),
        ));
      }

      final response = await DioClient.post('/notices', data: formData);

      final responseData = response.data;
      if (responseData['success'] == true) {
        print('[NoticeService] 공지사항 작성 성공');
        return Notice.fromJson(responseData['notice']);
      } else {
        throw Exception(responseData['message'] ?? '공지사항 작성에 실패했습니다.');
      }
    } catch (e) {
      print('[NoticeService] 공지사항 작성 실패: $e');
      throw Exception('공지사항 작성 실패: $e');
    }
  }

  /// 공지사항 수정 (관리자용)
  /// ✅ 파일 유무에 관계없이 항상 POST로 multipart/form-data 요청
  /// 서버에서 POST /notices/{id} 엔드포인트로 수정 처리
  static Future<Notice> updateNotice({
    required int noticeId,
    required String title,
    required String content,
    File? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      print('[NoticeService] 공지사항 수정 시작 - ID: $noticeId, 제목: $title');

      final formData = FormData.fromMap({
        'title': title,
        'content': content,
        'isPinned': 'false',
      });

      // 파일 추가 (File 또는 Uint8List)
      if (imageFile != null) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(imageFile.path),
        ));
      } else if (imageBytes != null) {
        formData.files.add(MapEntry(
          'file',
          MultipartFile.fromBytes(
            imageBytes,
            filename: fileName ?? 'image.jpg',
          ),
        ));
      }

      // ✅ POST /notices/{id}로 수정 요청 (서버에서 PUT 대체 엔드포인트 제공)
      final response = await DioClient.post('/notices/$noticeId', data: formData);

      final responseData = response.data;
      if (responseData['success'] == true) {
        print('[NoticeService] 공지사항 수정 성공');
        return Notice.fromJson(responseData['notice']);
      } else {
        throw Exception(responseData['message'] ?? '공지사항 수정에 실패했습니다.');
      }
    } catch (e) {
      print('[NoticeService] 공지사항 수정 실패: $e');
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

  // 중요 공지사항 조회
  static Future<List<Notice>> getImportantNotices() async {
    try {
      final response = await DioClient.get('/notices/important');
      final responseData = response.data;
      if (responseData['success'] == true) {
        final List<dynamic> noticeData = responseData['notices'];
        return noticeData.map((data) => Notice.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('중요 공지사항 조회 실패: $e');
    }
  }

  // 공지사항 검색
  static Future<List<Notice>> searchNotices(String keyword) async {
    try {
      final response = await DioClient.get('/notices/search', queryParameters: {
        'keyword': keyword,
      });

      final responseData = response.data;
      if (responseData['success'] == true) {
        final List<dynamic> noticeData = responseData['notices'];
        return noticeData.map((data) => Notice.fromJson(data)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('공지사항 검색 실패: $e');
    }
  }
}