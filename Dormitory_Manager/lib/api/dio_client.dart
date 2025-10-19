import 'package:dio/dio.dart';
import '../utils/storage_helper.dart';
import 'api_config.dart';

/// DioClient를 앱의 기본 API 클라이언트로 사용합니다.
class DioClient {
  static late Dio _dio;
  static bool _isInitialized = false;

  /// 초기화 메서드 (앱 시작 시 한번만 호출)
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = Dio(options);

    // 저장된 토큰 로드 및 헤더 설정
    final token = await StorageHelper.getToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    // 인터셉터 추가
    _dio.interceptors.add(_createLogInterceptor());
    _dio.interceptors.add(_createAuthInterceptor());
    _dio.interceptors.add(_createErrorInterceptor());

    _isInitialized = true;
    print('[ApiClient] DioClient 초기화 완료');
  }

  /// 토큰 설정
  static Future<void> setToken(String token) async {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    await StorageHelper.saveToken(token);
    print('[DEBUG] 토큰 설정 완료');
  }

  /// 토큰 제거
  static Future<void> clearToken() async {
    _dio.options.headers.remove('Authorization');
    await StorageHelper.removeToken();
    print('[DEBUG] 토큰 제거 완료');
  }

  /// GET 요청
  static Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      print('[DEBUG] GET 요청: $path');
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST 요청
  static Future<Response> post(String path, {dynamic data}) async {
    try {
      print('[DEBUG] POST 요청: $path');
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT 요청
  static Future<Response> put(String path, {dynamic data}) async {
    try {
      print('[DEBUG] PUT 요청: $path');
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE 요청
  static Future<Response> delete(String path) async {
    try {
      print('[DEBUG] DELETE 요청: $path');
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 파일 업로드
  static Future<Response> uploadFile(
      String path,
      String filePath, {
        Map<String, String>? fields,
        String fieldName = 'file',
        ProgressCallback? onSendProgress,
      }) async {
    try {
      print('[DEBUG] 파일 업로드 요청: $path');

      final formData = FormData();

      // 파일 추가
      formData.files.add(MapEntry(
        fieldName,
        await MultipartFile.fromFile(filePath),
      ));

      // 추가 필드들 추가
      if (fields != null) {
        for (var entry in fields.entries) {
          formData.fields.add(MapEntry(entry.key, entry.value));
        }
      }

      return await _dio.post(
        path,
        data: formData,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 로그 인터셉터 생성
  static Interceptor _createLogInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        print('[API] *** Request ***');
        print('[API] uri: ${options.uri}');
        print('[API] method: ${options.method}');
        print('[API] headers:');
        options.headers.forEach((k, v) {
          if (k.toLowerCase() == 'authorization' && v.toString().startsWith('Bearer ')) {
            print('[API]  $k: Bearer ***');
          } else {
            print('[API]  $k: $v');
          }
        });
        if (options.data != null) {
          print('[API] data:');
          print('[API] ${options.data}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('[API] *** Response ***');
        print('[API] statusCode: ${response.statusCode}');
        print('[API] data: ${response.data}');
        handler.next(response);
      },
      onError: (DioException e, handler) {
        print('[API] *** DioException ***:');
        print('[API] uri: ${e.requestOptions.uri}');
        print('[API] ${e.message}');
        if (e.response != null) {
          print('[API] statusCode: ${e.response?.statusCode}');
          print('[API] data: ${e.response?.data}');
        }
        handler.next(e);
      },
    );
  }

  /// 인증 인터셉터 생성
  static Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 인증이 필요한 요청인지 확인
        if (!_isPublicEndpoint(options.path)) {
          final token = await StorageHelper.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        // 401 Unauthorized 에러 시에만 토큰 제거 (403은 권한 문제이므로 토큰 유지)
        if (e.response?.statusCode == 401) {
          print('[DEBUG] 401 인증 오류로 인한 토큰 제거');
          await clearToken();
        } else if (e.response?.statusCode == 403) {
          print('[DEBUG] 403 권한 오류 - 토큰 유지 (권한 부족)');
          // 403은 토큰은 유효하지만 권한이 없는 경우이므로 토큰을 삭제하지 않음
        }
        handler.next(e);
      },
    );
  }

  /// 에러 인터셉터 생성
  static Interceptor _createErrorInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException e, handler) {
        print('[ERROR] API 에러 발생:');
        print('[ERROR] 상태 코드: ${e.response?.statusCode}');
        print('[ERROR] 메시지: ${e.message}');
        print('[ERROR] 응답 데이터: ${e.response?.data}');
        handler.next(e);
      },
    );
  }

  /// 공개 엔드포인트인지 확인
  static bool _isPublicEndpoint(String path) {
    final publicPaths = [
      '/auth/login',
      '/auth/register',
      '/hello',
      '/actuator/health',
    ];
    return publicPaths.any((publicPath) => path.startsWith(publicPath));
  }

  /// 에러 처리
  static DioException _handleError(DioException e) {
    String message = '알 수 없는 오류가 발생했습니다.';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        message = '연결 시간이 초과되었습니다.';
        break;
      case DioExceptionType.receiveTimeout:
        message = '응답 시간이 초과되었습니다.';
        break;
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 400:
            message = '잘못된 요청입니다.';
            break;
          case 401:
            message = '인증이 필요합니다. 다시 로그인해주세요.';
            break;
          case 403:
            message = '접근 권한이 없습니다.';
            break;
          case 404:
            message = '요청한 리소스를 찾을 수 없습니다.';
            break;
          case 500:
            message = '서버 내부 오류가 발생했습니다.';
            break;
          default:
            if (e.response?.data != null && e.response?.data['message'] != null) {
              message = e.response?.data['message'];
            } else {
              message = 'HTTP ${statusCode ?? 'Unknown'} 오류가 발생했습니다.';
            }
        }
        break;
      case DioExceptionType.cancel:
        message = '요청이 취소되었습니다.';
        break;
      case DioExceptionType.unknown:
        message = '네트워크 연결을 확인해주세요.';
        break;
      default:
        message = e.message ?? '알 수 없는 오류가 발생했습니다.';
    }

    print('❌ API Error: $message');

    return DioException(
      requestOptions: e.requestOptions,
      response: e.response,
      type: e.type,
      error: message,
      message: message,
    );
  }

  /// 연결 상태 확인
  static Future<bool> checkConnection() async {
    try {
      final response = await _dio.get('/actuator/health');
      return response.statusCode == 200;
    } catch (e) {
      print('[ERROR] 연결 상태 확인 실패: $e');
      return false;
    }
  }

  /// 디버그 정보 출력
  static void printDebugInfo() {
    print('[DEBUG] === DioClient 디버그 정보 ===');
    print('[DEBUG] Base URL: ${_dio.options.baseUrl}');
    print('[DEBUG] Headers: ${_dio.options.headers}');
    print('[DEBUG] Connect Timeout: ${_dio.options.connectTimeout}');
    print('[DEBUG] Receive Timeout: ${_dio.options.receiveTimeout}');
    print('[DEBUG] 초기화 상태: $_isInitialized');
  }
}