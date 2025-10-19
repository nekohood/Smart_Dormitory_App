import 'dart:convert';
import 'package:http/http.dart' as http;

class NoticeApi {
  static const String baseUrl = 'http://10.0.2.2:8080/api/notices';

  static Future<List<dynamic>> fetchNotices() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('공지 불러오기 실패');
    }
  }

  static Future<bool> createNotice(String title, String content, String author) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'content': content,
        'author': author,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteNotice(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/$id'));
    return response.statusCode == 200;
  }

  static Future<bool> updateNotice({
    required int id,
    required String title,
    required String content,
    required String author,
  }) async {
    final url = Uri.parse('$baseUrl/$id');
    print('🟡 PUT URL: $url'); // 추가
    print('🟡 Payload: title=$title, content=$content, author=$author');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'content': content,
        'author': author,
      }),
    );

    print('🔴 Status: ${response.statusCode}');
    print('🔴 Body: ${response.body}');

    return response.statusCode == 200;
  }

}
