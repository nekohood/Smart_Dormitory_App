import 'dart:io';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class ComplaintRepository {
  static List<Complaint> _userComplaints = [];
  static List<Complaint> _allComplaints = [];

  // 캐시된 사용자 민원 목록 반환
  static List<Complaint> get userComplaints => _userComplaints;

  // 캐시된 전체 민원 목록 반환 (관리자용)
  static List<Complaint> get allComplaints => _allComplaints;

  // 민원 신고 제출
  static Future<Complaint> submitComplaint({
    required String title,
    required String content,
    required String category,
    required String writerId,
    File? imageFile,
  }) async {
    try {
      final newComplaint = await ComplaintService.submitComplaint(
        title: title,
        content: content,
        category: category,
        writerId: writerId,
        imageFile: imageFile,
      );

      // 사용자 캐시에 추가 (맨 앞에)
      _userComplaints.insert(0, newComplaint);

      // 전체 캐시에도 추가 (관리자용)
      _allComplaints.insert(0, newComplaint);

      return newComplaint;
    } catch (e) {
      rethrow;
    }
  }

  // 사용자별 민원 목록 조회
  static Future<List<Complaint>> getUserComplaints(String writerId) async {
    try {
      _userComplaints = await ComplaintService.getUserComplaints(writerId);
      return _userComplaints;
    } catch (e) {
      rethrow;
    }
  }

  // 모든 민원 목록 조회 (관리자용)
  static Future<List<Complaint>> getAllComplaints() async {
    try {
      _allComplaints = await ComplaintService.getAllComplaints();
      return _allComplaints;
    } catch (e) {
      rethrow;
    }
  }

  // 특정 민원 조회
  static Future<Complaint> getComplaintById(int complaintId) async {
    try {
      return await ComplaintService.getComplaintById(complaintId);
    } catch (e) {
      rethrow;
    }
  }

  // 민원 상태 업데이트 (관리자용)
  static Future<Complaint> updateComplaintStatus({
    required int complaintId,
    required String status,
    String? adminComment,
  }) async {
    try {
      final updatedComplaint = await ComplaintService.updateComplaintStatus(
        complaintId: complaintId,
        status: status,
        adminComment: adminComment,
      );

      // 전체 캐시 업데이트
      final allIndex = _allComplaints.indexWhere((c) => c.id == complaintId);
      if (allIndex != -1) {
        _allComplaints[allIndex] = updatedComplaint;
      }

      // 사용자 캐시 업데이트
      final userIndex = _userComplaints.indexWhere((c) => c.id == complaintId);
      if (userIndex != -1) {
        _userComplaints[userIndex] = updatedComplaint;
      }

      return updatedComplaint;
    } catch (e) {
      rethrow;
    }
  }

  // 민원 삭제 (관리자용)
  static Future<void> deleteComplaint(int complaintId) async {
    try {
      await ComplaintService.deleteComplaint(complaintId);

      // 캐시에서 제거
      _allComplaints.removeWhere((c) => c.id == complaintId);
      _userComplaints.removeWhere((c) => c.id == complaintId);
    } catch (e) {
      rethrow;
    }
  }

  // 민원 통계 조회 (관리자용)
  static Future<Map<String, dynamic>> getComplaintStatistics() async {
    try {
      return await ComplaintService.getComplaintStatistics();
    } catch (e) {
      rethrow;
    }
  }

  // ID로 민원 찾기
  static Complaint? findById(int id) {
    try {
      return _allComplaints.firstWhere((complaint) => complaint.id == id);
    } catch (e) {
      try {
        return _userComplaints.firstWhere((complaint) => complaint.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  // 사용자 캐시 초기화
  static void clearUserCache() {
    _userComplaints.clear();
  }

  // 전체 캐시 초기화
  static void clearAllCache() {
    _allComplaints.clear();
  }

  // 모든 캐시 초기화
  static void clearCache() {
    _userComplaints.clear();
    _allComplaints.clear();
  }

  // 민원 카테고리 목록
  static List<String> getComplaintCategories() {
    return ComplaintService.getComplaintCategories();
  }

  // 상태 목록 (관리자용)
  static List<String> getStatusList() {
    return ComplaintService.getStatusList();
  }

  // 상태별 민원 개수 (관리자용)
  static Map<String, int> getStatusCounts() {
    final counts = <String, int>{};
    for (final status in getStatusList()) {
      counts[status] = _allComplaints.where((c) => c.status == status).length;
    }
    return counts;
  }

  // 최근 민원 개수 (관리자용)
  static int getRecentComplaintsCount(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _allComplaints.where((c) => c.submittedAt.isAfter(cutoffDate)).length;
  }
}