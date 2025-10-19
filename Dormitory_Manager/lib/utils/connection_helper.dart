import 'package:flutter/material.dart';
import '../services/network_service.dart';

class ConnectionHelper {
  /// 연결 문제 진단 다이얼로그 표시
  static Future<void> showConnectionDiagnostic(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('연결 진단'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: NetworkService.getDiagnosticInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('연결 상태를 확인하고 있습니다...'),
                ],
              );
            }

            if (snapshot.hasError) {
              return Text('진단 중 오류가 발생했습니다: ${snapshot.error}');
            }

            final info = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('환경: ${info['environment']}'),
                Text('서버 URL: ${info['baseUrl']}'),
                Text('서버 연결: ${info['serverConnected'] ? '성공' : '실패'}'),
                if (info['error'] != null) ...[
                  SizedBox(height: 8),
                  Text('오류: ${info['error']}', style: TextStyle(color: Colors.red)),
                ],
                SizedBox(height: 16),
                _buildTroubleshootingTips(),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  static Widget _buildTroubleshootingTips() {
    return ExpansionTile(
      title: Text('문제 해결 방법'),
      children: [
        ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('백엔드 서버 실행 확인'),
          subtitle: Text('IntelliJ에서 SpringBoot 애플리케이션이 8080 포트에서 실행 중인지 확인'),
        ),
        ListTile(
          leading: Icon(Icons.wifi, color: Colors.blue),
          title: Text('네트워크 연결 확인'),
          subtitle: Text('에뮬레이터와 개발 서버가 같은 네트워크에 있는지 확인'),
        ),
        ListTile(
          leading: Icon(Icons.security, color: Colors.orange),
          title: Text('방화벽 설정 확인'),
          subtitle: Text('8080 포트가 방화벽에 의해 차단되지 않았는지 확인'),
        ),
        ListTile(
          leading: Icon(Icons.settings, color: Colors.purple),
          title: Text('URL 설정 확인'),
          subtitle: Text('ApiConfig에서 올바른 baseUrl이 설정되었는지 확인'),
        ),
      ],
    );
  }
}