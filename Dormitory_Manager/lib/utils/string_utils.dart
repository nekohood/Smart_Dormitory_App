// lib/utils/string_utils.dart
class StringUtils {
  /// 안전한 substring - RangeError 방지
  static String safeSubstring(String? str, int start, [int? end]) {
    if (str == null || str.isEmpty) {
      return '';
    }

    int safeStart = start.clamp(0, str.length);
    int safeEnd = (end ?? str.length).clamp(safeStart, str.length);

    return str.substring(safeStart, safeEnd);
  }

  /// 토큰 마스킹을 위한 안전한 메서드
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) {
      return '토큰 없음';
    }

    if (token.length <= 20) {
      // 20자 이하면 앞 10자만 보이기
      return '${safeSubstring(token, 0, 10)}...';
    }

    // 20자 초과면 앞 20자 보이기
    return '${safeSubstring(token, 0, 20)}...';
  }

  /// 이메일 마스킹
  static String maskEmail(String? email) {
    if (email == null || email.isEmpty || !email.contains('@')) {
      return '***@***.***';
    }

    List<String> parts = email.split('@');
    String username = parts[0];
    String domain = parts[1];

    String maskedUsername = username.length > 2
        ? '${username.substring(0, 2)}***'
        : '***';

    String maskedDomain = domain.length > 4
        ? '${domain.substring(0, 2)}***${domain.substring(domain.length - 2)}'
        : '***.***.***';

    return '$maskedUsername@$maskedDomain';
  }

  /// 전화번호 마스킹
  static String maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return '***-****-****';
    }

    String numbers = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (numbers.length == 11) {
      return '${numbers.substring(0, 3)}-****-${numbers.substring(7)}';
    } else if (numbers.length == 10) {
      return '${numbers.substring(0, 3)}-***-${numbers.substring(6)}';
    }

    return '***-****-****';
  }
}