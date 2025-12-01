import 'package:image_picker/image_picker.dart';
import '../models/notice.dart';
import '../services/notice_service.dart';

/// 공지사항 Repository
/// ✅ XFile 지원으로 웹 호환성 확보
class NoticeRepository {
  static List<Notice> _notices = [];

  // 캐시된 공지사항 목록 반환
  static List<Notice> get notices => _notices;

  // 모든 공지사항 조회
  static Future<List<Notice>> getAllNotices() async {
    try {
      _notices = await NoticeService.getAllNotices();
      return _notices;
    } catch (e) {
      rethrow;
    }
  }

  // 최신 공지사항 조회
  static Future<Notice?> getLatestNotice() async {
    try {
      return await NoticeService.getLatestNotice();
    } catch (e) {
      rethrow;
    }
  }

  /// 공지사항 작성 (관리자용)
  /// ✅ XFile 지원
  static Future<Notice> createNotice({
    required String title,
    required String content,
    XFile? imageFile,
  }) async {
    try {
      final newNotice = await NoticeService.createNotice(
        title: title,
        content: content,
        imageFile: imageFile,
      );

      // 캐시에 추가 (맨 앞에)
      _notices.insert(0, newNotice);

      return newNotice;
    } catch (e) {
      rethrow;
    }
  }

  /// 공지사항 수정 (관리자용)
  /// ✅ XFile 지원
  static Future<Notice> updateNotice({
    required int noticeId,
    required String title,
    required String content,
    XFile? imageFile,
  }) async {
    try {
      final updatedNotice = await NoticeService.updateNotice(
        noticeId: noticeId,
        title: title,
        content: content,
        imageFile: imageFile,
      );

      // 캐시 업데이트
      final index = _notices.indexWhere((notice) => notice.id == noticeId);
      if (index != -1) {
        _notices[index] = updatedNotice;
      }

      return updatedNotice;
    } catch (e) {
      rethrow;
    }
  }

  // 공지사항 삭제 (관리자용)
  static Future<void> deleteNotice(int noticeId) async {
    try {
      await NoticeService.deleteNotice(noticeId);

      // 캐시에서 제거
      _notices.removeWhere((notice) => notice.id == noticeId);
    } catch (e) {
      rethrow;
    }
  }

  // 특정 공지사항 조회
  static Future<Notice> getNoticeById(int noticeId) async {
    try {
      return await NoticeService.getNoticeById(noticeId);
    } catch (e) {
      rethrow;
    }
  }

  // 캐시 초기화
  static void clearCache() {
    _notices.clear();
  }

  // ID로 공지사항 찾기
  static Notice? findById(int id) {
    try {
      return _notices.firstWhere((notice) => notice.id == id);
    } catch (e) {
      return null;
    }
  }
}