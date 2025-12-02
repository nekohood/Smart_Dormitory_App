import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../models/inspection.dart';
import '../api/dio_client.dart';
import '../api/api_config.dart';

/// 점호 관련 API 서비스 (DioClient 기반)
/// ✅ 상세 조회 및 반려 기능 추가
/// ✅ 파일 업로드 timeout 개선
class InspectionService {
  /// ⭐ 기존 코드와의 호환성을 위해 남겨둠 (실제로는 사용되지 않음)
  /// DioClient가 자동으로 토큰을 관리하므로 이 메서드는 아무 동작도 하지 않음
  void setAuthToken(String token) {
    print('[DEBUG] InspectionService.setAuthToken() 호출됨 (DioClient가 자동 관리)');
  }

  /// 점호 제출 (Uint8List를 MultipartFile로 변환하여 업로드)
  Future<InspectionResponse> submitInspection(
      String roomNumber, Uint8List imageBytes, String fileName) async {
    try {
      print('[DEBUG] 점호 제출 시작 - 방번호: $roomNumber, 파일명: $fileName');
      print('[DEBUG] 이미지 크기: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');

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

      print('[DEBUG] 서버로 요청 전송 중... (timeout: ${ApiConfig.uploadTimeout.inSeconds}초)');

      // ✅ 파일 업로드용 긴 timeout 적용
      final response = await DioClient.postWithTimeout(
        '/inspections/submit',
        data: formData,
        timeout: ApiConfig.uploadTimeout,
      );

      print('[DEBUG] 서버 응답: ${response.data}');

      return InspectionResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 점호 제출 중 예외 발생: $e');

      // ✅ timeout 에러 메시지 개선
      String errorMessage = '점호 제출 중 오류가 발생했습니다';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = '서버 연결 시간이 초과되었습니다. 네트워크 상태를 확인해주세요.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'AI 분석 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
        } else if (e.type == DioExceptionType.sendTimeout) {
          errorMessage = '이미지 업로드 시간이 초과되었습니다. 네트워크 상태를 확인해주세요.';
        } else if (e.message != null) {
          errorMessage = e.message!;
        }
      }

      return InspectionResponse(
        success: false,
        error: errorMessage,
      );
    }
  }

  /// 내 점호 기록 조회
  Future<InspectionListResponse> getMyInspections() async {
    try {
      print('[DEBUG] 내 점호 기록 조회');
      final response = await DioClient.get('/inspections/my');

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
      print('[DEBUG] 이미지 크기: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');

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

      print('[DEBUG] 서버로 재검 요청 전송 중... (timeout: ${ApiConfig.uploadTimeout.inSeconds}초)');

      // ✅ 파일 업로드용 긴 timeout 적용
      final response = await DioClient.postWithTimeout(
        '/inspections/resubmit',
        data: formData,
        timeout: ApiConfig.uploadTimeout,
      );

      return InspectionResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 재검 점호 제출 실패: $e');

      String errorMessage = '재검 점호 제출 실패';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = '서버 연결 시간이 초과되었습니다. 네트워크 상태를 확인해주세요.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'AI 분석 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
        } else if (e.type == DioExceptionType.sendTimeout) {
          errorMessage = '이미지 업로드 시간이 초과되었습니다. 네트워크 상태를 확인해주세요.';
        } else if (e.message != null) {
          errorMessage = e.message!;
        }
      }

      return InspectionResponse(
        success: false,
        error: errorMessage,
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

  /// ✅ 점호 상세 조회 (관리자)
  Future<AdminInspectionDetailResponse> getInspectionDetail(int inspectionId) async {
    try {
      print('[DEBUG] 점호 상세 조회: ID $inspectionId');

      final response = await DioClient.get('/inspections/admin/$inspectionId');
      final data = response.data;

      if (data['success'] == true) {
        final inspectionData = data['data'];
        if (inspectionData != null) {
          return AdminInspectionDetailResponse(
            success: true,
            inspection: AdminInspectionModel.fromJson(inspectionData),
            message: data['message'],
          );
        }
      }

      return AdminInspectionDetailResponse(
        success: false,
        message: data['message'] ?? '점호 상세 조회 실패',
      );

    } catch (e) {
      print('[ERROR] 점호 상세 조회 실패: $e');
      return AdminInspectionDetailResponse(
        success: false,
        message: '점호 상세 조회 실패: $e',
      );
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

  /// ✅ 점호 반려 (관리자)
  Future<InspectionRejectResponse> rejectInspection(
      int inspectionId, String rejectReason) async {
    try {
      print('[DEBUG] 점호 반려: ID $inspectionId, 사유: $rejectReason');

      final response = await DioClient.post(
        '/inspections/admin/$inspectionId/reject',
        data: {'rejectReason': rejectReason},
      );

      final data = response.data;

      return InspectionRejectResponse(
        success: data['success'] == true,
        message: data['message'],
        inspectionId: inspectionId,
        rejectReason: rejectReason,
      );

    } catch (e) {
      print('[ERROR] 점호 반려 실패: $e');
      return InspectionRejectResponse(
        success: false,
        message: '점호 반려 실패: $e',
        inspectionId: inspectionId,
        rejectReason: rejectReason,
      );
    }
  }

  /// ✅ 점호 통계 조회 (관리자) - getInspectionStatistics
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

      return InspectionStatisticsResponse.fromJson(response.data);

    } catch (e) {
      print('[ERROR] 점호 통계 조회 실패: $e');
      rethrow;
    }
  }

  /// ✅ 기숙사별 점호 현황 조회 (관리자)
  Future<Map<String, dynamic>> getBuildingInspectionStatus(
      String building, {DateTime? date}) async {
    try {
      String endpoint = '/inspections/admin/building-status/$building';
      if (date != null) {
        String dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        endpoint += '?date=$dateStr';
      }

      print('[DEBUG] 기숙사별 점호 현황 조회: $endpoint');
      final response = await DioClient.get(endpoint);

      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data'];
      }

      return {};

    } catch (e) {
      print('[ERROR] 기숙사별 점호 현황 조회 실패: $e');
      return {};
    }
  }

  /// ✅ 기숙사 동 목록 조회 (관리자)
  Future<List<String>> getBuildings() async {
    try {
      print('[DEBUG] 기숙사 동 목록 조회');
      final response = await DioClient.get('/inspections/admin/buildings');

      if (response.data['success'] == true && response.data['data'] != null) {
        final data = response.data['data'];
        if (data['buildings'] != null && data['buildings'] is List) {
          return List<String>.from(data['buildings']);
        }
      }

      return [];

    } catch (e) {
      print('[ERROR] 기숙사 동 목록 조회 실패: $e');
      return [];
    }
  }
}

/// ✅ 점호 상세 조회 응답 모델
class AdminInspectionDetailResponse {
  final bool success;
  final AdminInspectionModel? inspection;
  final String? message;

  AdminInspectionDetailResponse({
    required this.success,
    this.inspection,
    this.message,
  });
}

/// ✅ 점호 반려 응답 모델
class InspectionRejectResponse {
  final bool success;
  final String? message;
  final int inspectionId;
  final String rejectReason;

  InspectionRejectResponse({
    required this.success,
    this.message,
    required this.inspectionId,
    required this.rejectReason,
  });
}