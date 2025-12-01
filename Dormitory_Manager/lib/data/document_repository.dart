import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../models/document.dart';
import '../services/document_service.dart';

/// 서류 Repository
/// ✅ 수정: XFile + Uint8List 지원으로 웹/앱 호환성 확보
class DocumentRepository {
  static List<Document> _userDocuments = [];
  static List<Document> _allDocuments = [];

  // 캐시된 사용자 서류 목록 반환
  static List<Document> get userDocuments => _userDocuments;

  // 캐시된 전체 서류 목록 반환 (관리자용)
  static List<Document> get allDocuments => _allDocuments;

  /// 서류 제출
  /// ✅ 수정: XFile + imageBytes 지원
  static Future<Document> submitDocument({
    required String title,
    required String content,
    required String category,
    required String writerId,
    XFile? imageFile,
    Uint8List? imageBytes,
    String? fileName,
  }) async {
    try {
      final newDocument = await DocumentService.submitDocument(
        title: title,
        content: content,
        category: category,
        writerId: writerId,
        imageFile: imageFile,
        imageBytes: imageBytes,
        fileName: fileName,
      );

      // 사용자 캐시에 추가 (맨 앞에)
      _userDocuments.insert(0, newDocument);

      // 전체 캐시에도 추가 (관리자용)
      _allDocuments.insert(0, newDocument);

      return newDocument;
    } catch (e) {
      rethrow;
    }
  }

  // 사용자별 서류 목록 조회
  static Future<List<Document>> getUserDocuments(String writerId) async {
    try {
      _userDocuments = await DocumentService.getUserDocuments(writerId);
      return _userDocuments;
    } catch (e) {
      rethrow;
    }
  }

  // 모든 서류 목록 조회 (관리자용)
  static Future<List<Document>> getAllDocuments() async {
    try {
      _allDocuments = await DocumentService.getAllDocuments();
      return _allDocuments;
    } catch (e) {
      rethrow;
    }
  }

  // 특정 서류 조회
  static Future<Document> getDocumentById(int documentId) async {
    try {
      return await DocumentService.getDocumentById(documentId);
    } catch (e) {
      rethrow;
    }
  }

  // 서류 상태 업데이트 (관리자용)
  static Future<Document> updateDocumentStatus({
    required int documentId,
    required String status,
    String? adminComment,
  }) async {
    try {
      final updatedDocument = await DocumentService.updateDocumentStatus(
        documentId: documentId,
        status: status,
        adminComment: adminComment,
      );

      // 캐시 업데이트
      final userIndex = _userDocuments.indexWhere((d) => d.id == documentId);
      if (userIndex != -1) {
        _userDocuments[userIndex] = updatedDocument;
      }

      final allIndex = _allDocuments.indexWhere((d) => d.id == documentId);
      if (allIndex != -1) {
        _allDocuments[allIndex] = updatedDocument;
      }

      return updatedDocument;
    } catch (e) {
      rethrow;
    }
  }

  // 서류 삭제 (관리자용)
  static Future<void> deleteDocument(int documentId) async {
    try {
      await DocumentService.deleteDocument(documentId);

      // 캐시에서 제거
      _userDocuments.removeWhere((d) => d.id == documentId);
      _allDocuments.removeWhere((d) => d.id == documentId);
    } catch (e) {
      rethrow;
    }
  }

  // 캐시 초기화
  static void clearCache() {
    _userDocuments.clear();
    _allDocuments.clear();
  }

  // ID로 캐시된 서류 찾기
  static Document? findById(int id) {
    try {
      return _allDocuments.firstWhere((d) => d.id == id);
    } catch (e) {
      try {
        return _userDocuments.firstWhere((d) => d.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  // 사용자 캐시 초기화
  static void clearUserCache() {
    _userDocuments.clear();
  }

  // 전체 캐시 초기화
  static void clearAllCache() {
    _allDocuments.clear();
  }

  // 서류 카테고리 목록
  static List<String> getDocumentCategories() {
    return DocumentService.getDocumentCategories();
  }

  // ✅ 상태 목록 (관리자용)
  static List<String> getStatusList() {
    return DocumentService.getStatusList();
  }

  // ✅ 서류 통계 조회 (관리자용)
  static Future<Map<String, dynamic>> getDocumentStatistics() async {
    try {
      return await DocumentService.getDocumentStatistics();
    } catch (e) {
      rethrow;
    }
  }

  // 상태별 서류 개수 (관리자용)
  static Map<String, int> getStatusCounts() {
    final counts = <String, int>{};
    for (final status in getStatusList()) {
      counts[status] = _allDocuments.where((d) => d.status == status).length;
    }
    return counts;
  }

  // 최근 서류 개수 (관리자용)
  static int getRecentDocumentsCount(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return _allDocuments.where((d) => d.submittedAt.isAfter(cutoffDate)).length;
  }
}