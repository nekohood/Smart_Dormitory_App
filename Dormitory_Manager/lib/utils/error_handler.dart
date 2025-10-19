import 'package:dio/dio.dart'; // DioException을 가져오기 위해 추가

class ErrorHandler {
  /// 에러를 사용자 친화적인 메시지로 변환
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      // DioClient의 _handleError에서 이미 처리된 메시지를 사용
      return error.message ?? '네트워크 오류가 발생했습니다.';
    }

    if (error is Exception) {
      String message = error.toString();
      // "Exception: " 접두사 제거
      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }
      return message;
    }

    // 기본 에러 메시지
    return '알 수 없는 오류가 발생했습니다: ${error.toString()}';
  }

  /// 에러 로깅
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    print('[ERROR] $context: $error');
    if (stackTrace != null) {
      print('[STACK TRACE] $stackTrace');
    }
  }

  /// 네트워크 에러인지 확인
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError;
    }
    return false;
  }

  /// 인증 에러인지 확인
  static bool isAuthError(dynamic error) {
    if (error is DioException) {
      return error.response?.statusCode == 401 || error.response?.statusCode == 403;
    }
    return false;
  }

  /// 서버 에러인지 확인
  static bool isServerError(dynamic error) {
    if (error is DioException) {
      return error.response?.statusCode != null && error.response!.statusCode! >= 500;
    }
    return false;
  }

  /// 에러 타입에 따른 처리 제안
  static String getErrorSuggestion(dynamic error) {
    if (isNetworkError(error)) {
      return '네트워크 연결을 확인하고 다시 시도해주세요.';
    }

    if (isAuthError(error)) {
      return '로그아웃 후 다시 로그인해주세요.';
    }

    if (isServerError(error)) {
      return '잠시 후 다시 시도해주세요. 문제가 지속되면 관리자에게 문의하세요.';
    }

    return '다시 시도해주세요. 문제가 지속되면 관리자에게 문의하세요.';
  }
}