import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../api/dio_client.dart';
import '../models/room_template.dart';

/// 방 템플릿 관리 서비스 (관리자용)
class RoomTemplateService {

  /// 전체 템플릿 목록 조회
  static Future<List<RoomTemplate>> getAllTemplates() async {
    try {
      print('[DEBUG] 전체 템플릿 목록 조회');

      final response = await DioClient.get('/admin/room-templates');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> dataList = response.data['data'];
        return dataList.map((json) => RoomTemplate.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('[ERROR] 템플릿 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// 활성화된 템플릿 목록 조회
  static Future<List<RoomTemplate>> getActiveTemplates() async {
    try {
      print('[DEBUG] 활성 템플릿 목록 조회');

      final response = await DioClient.get('/admin/room-templates/active');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> dataList = response.data['data'];
        return dataList.map((json) => RoomTemplate.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('[ERROR] 활성 템플릿 목록 조회 실패: $e');
      rethrow;
    }
  }

  /// 방 타입별 템플릿 조회
  static Future<List<RoomTemplate>> getTemplatesByType(String roomType) async {
    try {
      print('[DEBUG] 방 타입별 템플릿 조회: $roomType');

      final response = await DioClient.get('/admin/room-templates/type/$roomType');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> dataList = response.data['data'];
        return dataList.map((json) => RoomTemplate.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      print('[ERROR] 타입별 템플릿 조회 실패: $e');
      rethrow;
    }
  }

  /// 특정 템플릿 조회
  static Future<RoomTemplate?> getTemplateById(int id) async {
    try {
      print('[DEBUG] 템플릿 조회: ID=$id');

      final response = await DioClient.get('/admin/room-templates/$id');

      if (response.data['success'] == true && response.data['data'] != null) {
        return RoomTemplate.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 템플릿 조회 실패: $e');
      rethrow;
    }
  }

  /// 템플릿 등록
  static Future<RoomTemplate?> createTemplate({
    required String templateName,
    required String roomType,
    required XFile imageFile,
    String? description,
    String? buildingName,
    bool isDefault = false,
  }) async {
    try {
      print('[DEBUG] 템플릿 등록: $templateName, 타입: $roomType');

      // XFile에서 바이트 데이터 읽기
      final bytes = await imageFile.readAsBytes();
      final filename = imageFile.name;

      FormData formData = FormData.fromMap({
        'templateName': templateName,
        'roomType': roomType,
        'image': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
        if (description != null) 'description': description,
        if (buildingName != null) 'buildingName': buildingName,
        'isDefault': isDefault.toString(),
      });

      final response = await DioClient.post(
        '/admin/room-templates',
        data: formData,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return RoomTemplate.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 템플릿 등록 실패: $e');
      rethrow;
    }
  }

  /// 템플릿 수정
  static Future<RoomTemplate?> updateTemplate({
    required int id,
    String? templateName,
    String? roomType,
    XFile? imageFile,
    String? description,
    String? buildingName,
    bool? isDefault,
  }) async {
    try {
      print('[DEBUG] 템플릿 수정: ID=$id');

      Map<String, dynamic> formDataMap = {};

      if (templateName != null) formDataMap['templateName'] = templateName;
      if (roomType != null) formDataMap['roomType'] = roomType;
      if (description != null) formDataMap['description'] = description;
      if (buildingName != null) formDataMap['buildingName'] = buildingName;
      if (isDefault != null) formDataMap['isDefault'] = isDefault.toString();

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        formDataMap['image'] = MultipartFile.fromBytes(
          bytes,
          filename: imageFile.name,
        );
      }

      FormData formData = FormData.fromMap(formDataMap);

      final response = await DioClient.put(
        '/admin/room-templates/$id',
        data: formData,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return RoomTemplate.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 템플릿 수정 실패: $e');
      rethrow;
    }
  }

  /// 템플릿 삭제
  static Future<bool> deleteTemplate(int id) async {
    try {
      print('[DEBUG] 템플릿 삭제: ID=$id');

      final response = await DioClient.delete('/admin/room-templates/$id');

      return response.data['success'] == true;
    } catch (e) {
      print('[ERROR] 템플릿 삭제 실패: $e');
      rethrow;
    }
  }

  /// 템플릿 활성화 토글
  static Future<RoomTemplate?> toggleTemplate(int id) async {
    try {
      print('[DEBUG] 템플릿 토글: ID=$id');

      final response = await DioClient.patch('/admin/room-templates/$id/toggle');

      if (response.data['success'] == true && response.data['data'] != null) {
        return RoomTemplate.fromJson(response.data['data']);
      }

      return null;
    } catch (e) {
      print('[ERROR] 템플릿 토글 실패: $e');
      rethrow;
    }
  }

  /// 방 타입 목록 조회
  static Future<List<Map<String, String>>> getRoomTypes() async {
    try {
      final response = await DioClient.get('/admin/room-templates/room-types');

      if (response.data['success'] == true && response.data['data'] != null) {
        final List<dynamic> dataList = response.data['data'];
        return dataList.map((item) => {
          'value': item['value'].toString(),
          'label': item['label'].toString(),
        }).toList();
      }

      // 기본값 반환
      return [
        {'value': 'SINGLE', 'label': '1인실'},
        {'value': 'DOUBLE', 'label': '2인실'},
        {'value': 'MULTI', 'label': '다인실'},
      ];
    } catch (e) {
      print('[ERROR] 방 타입 조회 실패: $e');
      return [
        {'value': 'SINGLE', 'label': '1인실'},
        {'value': 'DOUBLE', 'label': '2인실'},
        {'value': 'MULTI', 'label': '다인실'},
      ];
    }
  }
}