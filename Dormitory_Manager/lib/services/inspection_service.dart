import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/inspection.dart';
import '../api/dio_client.dart';

/// 점호 관련 API 서비스 (DioClient 기반)
class InspectionService {
  /// ⭐ 기존 코드와의 호환성을 위해 남겨둠 (실제로는 사용되지 않음)
  /// DioClient가 자동으로 토큰을 관리하므로 이 메서드는 아무 동작도 하지 않음
  void setAuthToken(String token) {
    print('[DEBUG] InspectionService.setAuthToken() 호출됨 (DioClient가 자동 관리)');
    // DioClient가 자동으로 토큰을 헤더에 포함하므로 별도 설정 불필요
  }

  /// 점호 제출 (Uint8List를 MultipartFile로 변환하여 업로드)
  Future<InspectionResponse> submitInspection(
      String roomNumber, Uint8List imageBytes, String fileName) async {
    try {
      print('[DEBUG] 점호 제출 시작 - 방번호: $roomNumber, 파일명: $fileName');

      // Uint8List를 MultipartFile로 변환
      final multipartFile = MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
        contentType: DioMediaType('image', 'jpeg'),
      );

      // FormData 생성
      final formData = FormData.fromMap({
        'roomNumber': roomNumber,
        'image': multipartFile,
      });

      print('[DEBUG] 서버로 요청 전송 중...');

      // ✅ DioClient.post 사용 (uploadFile은 파일 경로가 필요하므로 직접 post 사용)
      final response = await DioClient.post(
        '/inspections/submit',
        data: formData,
      );

      print('[DEBUG] 서버 응답: ${response.data}');

      // InspectionResponse.fromJson이 알아서 파싱
      return InspectionResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 점호 제출 중 예외 발생: $e');
      return InspectionResponse(
        success: false,
        error: '점호 제출 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 내 점호 기록 조회
  Future<InspectionListResponse> getMyInspections() async {
    try {
      print('[DEBUG] 내 점호 기록 조회');
      final response = await DioClient.get('/inspections/my');

      // InspectionListResponse.fromJson이 ApiResponse 구조 처리
      return InspectionListResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 내 점호 기록 조회 실패: $e');
      rethrow;
    }
  }

  /// 오늘 점호 상태 확인
  Future<TodayInspectionResponse> getTodayInspection() async {
    try {
      print('[DEBUG] 오늘 점호 상태 확인');
      final response = await DioClient.get('/inspections/today');

      // TodayInspectionResponse.fromJson이 ApiResponse 구조 처리
      return TodayInspectionResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 오늘 점호 상태 확인 실패: $e');
      rethrow;
    }
  }

  /// 재검 점호 제출
  Future<InspectionResponse> submitReInspection(
      String roomNumber, Uint8List imageBytes, String fileName) async {
    try {
      print('[DEBUG] 재검 점호 제출 - 방번호: $roomNumber');

      // Uint8List를 MultipartFile로 변환
      final multipartFile = MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
        contentType: DioMediaType('image', 'jpeg'),
      );

      // FormData 생성
      final formData = FormData.fromMap({
        'roomNumber': roomNumber,
        'image': multipartFile,
      });

      final response = await DioClient.post(
        '/inspections/reinspect',
        data: formData,
      );

      return InspectionResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 재검 점호 제출 실패: $e');
      return InspectionResponse(
        success: false,
        error: '재검 점호 제출 실패: $e',
      );
    }
  }

  // ==========================================================================
  // 관리자용 메서드들
  // ==========================================================================

  /// 모든 점호 기록 조회 (관리자)
  Future<InspectionListResponse> getAllInspections() async {
    try {
      print('[DEBUG] 전체 점호 기록 조회 (관리자)');
      final response = await DioClient.get('/inspections/admin/all');

      return InspectionListResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 전체 점호 기록 조회 실패: $e');
      rethrow;
    }
  }

  /// 특정 날짜의 점호 기록 조회 (관리자)
  Future<InspectionListResponse> getInspectionsByDate(DateTime date) async {
    try {
      String dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      print('[DEBUG] 날짜별 점호 기록 조회: $dateStr');

      final response = await DioClient.get('/inspections/admin/date/$dateStr');

      return InspectionListResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 날짜별 점호 기록 조회 실패: $e');
      rethrow;
    }
  }

  /// 점호 기록 수정 (관리자)
  Future<AdminInspectionModel> updateInspection(
      int inspectionId, InspectionUpdateRequest updateRequest) async {
    try {
      print('[DEBUG] 점호 기록 수정: ID $inspectionId');

      final response = await DioClient.put(
        '/inspections/admin/$inspectionId',
        data: updateRequest.toJson(),
      );

      final data = response.data;
      if (data['success'] == true) {
        // data 필드 또는 inspection 필드에서 추출
        final inspectionData = data['data'] ?? data['inspection'];
        if (inspectionData != null) {
          return AdminInspectionModel.fromJson(inspectionData);
        }
      }

      throw Exception(data['message'] ?? '점호 기록 수정 실패');

    } catch (e) {
      print('[ERROR] 점호 기록 수정 실패: $e');
      rethrow;
    }
  }

  /// 점호 기록 삭제 (관리자)
  Future<bool> deleteInspection(int inspectionId) async {
    try {
      print('[DEBUG] 점호 기록 삭제: ID $inspectionId');

      final response = await DioClient.delete('/inspections/admin/$inspectionId');
      final data = response.data;

      return data['success'] == true;

    } catch (e) {
      print('[ERROR] 점호 기록 삭제 실패: $e');
      return false;
    }
  }

  /// 점호 통계 조회 (관리자)
  Future<InspectionStatisticsResponse> getInspectionStatistics({DateTime? date}) async {
    try {
      String endpoint = '/inspections/statistics';
      if (date != null) {
        String dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        endpoint += '?date=$dateStr';
      }

      print('[DEBUG] 점호 통계 조회: $endpoint');
      final response = await DioClient.get(endpoint);

      // InspectionStatisticsResponse.fromJson이 ApiResponse 구조 처리
      return InspectionStatisticsResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 점호 통계 조회 실패: $e');
      rethrow;
    }
  }
}