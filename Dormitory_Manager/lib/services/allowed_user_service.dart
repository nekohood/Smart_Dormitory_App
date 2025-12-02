import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../api/dio_client.dart';
import '../models/allowed_user.dart';
import '../utils/storage_helper.dart';

/// 허용 사용자 관리 서비스
/// ✅ 수정: CRUD 완전 지원 (Update 기능 추가)
/// ✅ 수정: 등록된 사용자도 수정/삭제 가능
class AllowedUserService {
  String? _authToken;

  /// 인증 토큰 설정
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// 요청 헤더 생성
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// 엑셀 파일 업로드
  Future<UploadExcelResponse> uploadExcelFile(PlatformFile file) async {
    try {
      print('[DEBUG] 엑셀 파일 업로드 요청 - 파일명: ${file.name}');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      FormData formData;

      if (file.bytes != null) {
        // 웹 환경
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
          ),
        });
      } else if (file.path != null) {
        // 모바일/데스크톱 환경
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
          ),
        });
      } else {
        throw Exception('파일 데이터를 읽을 수 없습니다');
      }

      final response = await DioClient.post(
        '/allowed-users/upload-excel',
        data: formData,
      );

      print('[DEBUG] 엑셀 파일 업로드 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return UploadExcelResponse.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '엑셀 파일 업로드 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 엑셀 파일 업로드 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '엑셀 파일 업로드 실패');
      }
      throw Exception('엑셀 파일 업로드 중 오류가 발생했습니다');
    }
  }

  /// 개별 사용자 추가
  Future<AllowedUser> addAllowedUser({
    required String userId,
    required String name,
    required String dormitoryBuilding,
    required String roomNumber,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      print('[DEBUG] 허용 사용자 추가 요청 - 학번: $userId');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final requestData = {
        'userId': userId,
        'name': name,
        'dormitoryBuilding': dormitoryBuilding,
        'roomNumber': roomNumber,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
        if (email != null && email.isNotEmpty) 'email': email,
      };

      final response = await DioClient.post(
        '/allowed-users/add',
        data: requestData,
      );

      print('[DEBUG] 허용 사용자 추가 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AllowedUser.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '허용 사용자 추가 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 허용 사용자 추가 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '허용 사용자 추가 실패');
      }
      throw Exception('허용 사용자 추가 중 오류가 발생했습니다');
    }
  }

  /// ✅ 허용 사용자 정보 수정
  /// ✅ 등록된 사용자도 수정 가능
  Future<AllowedUser> updateAllowedUser({
    required String userId,
    String? name,
    String? dormitoryBuilding,
    String? roomNumber,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      print('[DEBUG] 허용 사용자 수정 요청 - 학번: $userId');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final requestData = <String, dynamic>{};
      if (name != null && name.isNotEmpty) requestData['name'] = name;
      if (dormitoryBuilding != null && dormitoryBuilding.isNotEmpty) {
        requestData['dormitoryBuilding'] = dormitoryBuilding;
      }
      if (roomNumber != null && roomNumber.isNotEmpty) {
        requestData['roomNumber'] = roomNumber;
      }
      // phoneNumber와 email은 빈 문자열도 전송 (삭제 용도)
      if (phoneNumber != null) requestData['phoneNumber'] = phoneNumber;
      if (email != null) requestData['email'] = email;

      final response = await DioClient.put(
        '/allowed-users/$userId',
        data: requestData,
      );

      print('[DEBUG] 허용 사용자 수정 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AllowedUser.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '허용 사용자 수정 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 허용 사용자 수정 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '허용 사용자 수정 실패');
      }
      throw Exception('허용 사용자 수정 중 오류가 발생했습니다');
    }
  }

  /// 허용 사용자 목록 조회
  Future<AllowedUserListResponse> getAllAllowedUsers() async {
    try {
      print('[DEBUG] 허용 사용자 목록 조회 요청');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final response = await DioClient.get('/allowed-users/list');

      print('[DEBUG] 허용 사용자 목록 조회 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AllowedUserListResponse.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '허용 사용자 목록 조회 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 허용 사용자 목록 조회 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '허용 사용자 목록 조회 실패');
      }
      throw Exception('허용 사용자 목록 조회 중 오류가 발생했습니다');
    }
  }

  /// 특정 학번 조회
  Future<AllowedUser> getAllowedUser(String userId) async {
    try {
      print('[DEBUG] 허용 사용자 조회 요청 - 학번: $userId');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final response = await DioClient.get('/allowed-users/$userId');

      print('[DEBUG] 허용 사용자 조회 성공');

      if (response.data['success'] == true && response.data['data'] != null) {
        return AllowedUser.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? '허용 사용자 조회 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 허용 사용자 조회 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '허용 사용자 조회 실패');
      }
      throw Exception('허용 사용자 조회 중 오류가 발생했습니다');
    }
  }

  /// 학번 허용 여부 확인 (회원가입 시 사용)
  Future<bool> checkUserAllowed(String userId) async {
    try {
      print('[DEBUG] 학번 허용 여부 확인 - 학번: $userId');

      final response = await DioClient.get('/allowed-users/check/$userId');

      print('[DEBUG] 학번 허용 여부 확인 완료');

      if (response.data['success'] == true) {
        return response.data['data'] == true;
      } else {
        return false;
      }
    } on DioException catch (e) {
      print('[ERROR] 학번 허용 여부 확인 실패: ${e.message}');
      return false;
    }
  }

  /// ✅ 허용 사용자 삭제
  /// ✅ 등록된 사용자도 삭제 가능
  Future<void> deleteAllowedUser(String userId) async {
    try {
      print('[DEBUG] 허용 사용자 삭제 요청 - 학번: $userId');

      // 토큰 확인
      _authToken ??= await StorageHelper.getToken();

      final response = await DioClient.delete('/allowed-users/$userId');

      print('[DEBUG] 허용 사용자 삭제 성공');

      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? '허용 사용자 삭제 실패');
      }
    } on DioException catch (e) {
      print('[ERROR] 허용 사용자 삭제 실패: ${e.message}');
      if (e.response?.data != null) {
        throw Exception(e.response!.data['message'] ?? '허용 사용자 삭제 실패');
      }
      throw Exception('허용 사용자 삭제 중 오류가 발생했습니다');
    }
  }
}