import 'dart:io';
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

  // 공지사항 작성 (관리자용)
  static Future<Notice> createNotice({
    required String title,
    required String content,
    File? imageFile,
  }) async {
    try {
      if (imageFile != null) {
        // 파일이 있는 경우 multipart 요청
        final response = await DioClient.uploadFile(
          '/notices',
          imageFile.path,
          fieldName: 'file',
          fields: {
            'title': title,
            'content': content,
            'author': 'admin',
            'isPinned': 'false',
          },
        );

        final responseData = response.data;
        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 작성에 실패했습니다.');
        }
      } else {
        // 파일이 없는 경우 일반 POST 요청
        final response = await DioClient.post('/notices', data: {
          'title': title,
          'content': content,
          'author': 'admin',
          'isPinned': false,
        });

        final responseData = response.data;
        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 작성에 실패했습니다.');
        }
      }
    } catch (e) {
      throw Exception('공지사항 작성 실패: $e');
    }
  }

  // 공지사항 수정 (관리자용)
  static Future<Notice> updateNotice({
    required int noticeId,
    required String title,
    required String content,
    File? imageFile,
  }) async {
    try {
      if (imageFile != null) {
        // 파일이 있는 경우 - PUT은 파일 업로드에 적합하지 않으므로 POST로 처리
        final response = await DioClient.uploadFile(
          '/notices/$noticeId',
          imageFile.path,
          fieldName: 'file',
          fields: {
            'title': title,
            'content': content,
            'isPinned': 'false',
            '_method': 'PUT', // 서버에서 PUT으로 인식하도록
          },
        );

        final responseData = response.data;
        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 수정에 실패했습니다.');
        }
      } else {
        // 파일이 없는 경우 일반 PUT 요청
        final response = await DioClient.put('/notices/$noticeId', data: {
          'title': title,
          'content': content,
          'isPinned': false,
        });

        final responseData = response.data;
        if (responseData['success'] == true) {
          return Notice.fromJson(responseData['notice']);
        } else {
          throw Exception(responseData['message'] ?? '공지사항 수정에 실패했습니다.');
        }
      }
    } catch (e) {
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