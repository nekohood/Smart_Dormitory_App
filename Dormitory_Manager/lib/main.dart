import 'package:dormitory_manager/screens/inspection_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notice_screen.dart';
import 'screens/document_submit_screen.dart';

import 'screens/admin_inspection_screen.dart';
import 'main_navigation.dart';
import 'api/dio_client.dart';
import 'utils/auth_provider.dart';

// ⭐ [수정] intl 패키지 임포트
import 'package:intl/date_symbol_data_local.dart';

// main 함수를 Future로 변경하고 async 키워드를 추가합니다.
Future<void> main() async {
  // runApp을 실행하기 전에 Flutter 엔진과 위젯 바인딩이 준비되었는지 확인합니다.
  // 비동기 작업을 main에서 실행하려면 이 코드가 꼭 필요해요.
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ [수정] 캘린더/D-Day용 한국어 로케일 초기화
  await initializeDateFormatting('ko_KR', null);

  // 앱이 시작될 때 DioClient를 초기화합니다.
  await DioClient.initialize();

  runApp(DormitoryManagerApp());
}

class DormitoryManagerApp extends StatelessWidget {
  const DormitoryManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ⭐ [핵심 수정] MultiProvider로 AuthProvider를 앱 전체에 제공
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: '기숙사 관리 시스템',
        debugShowCheckedModeBanner: false, // ⭐ 디버그 배너 제거
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),

        // 로컬라이제이션 설정
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('ko', 'KR'), // 한국어
          Locale('en', 'US'), // 영어 (fallback)
        ],
        locale: Locale('ko', 'KR'),

        home: LoginScreen(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => HomeScreen(),
          '/main': (context) => MainNavigation(), // ⭐ MainNavigation 사용
          '/admin_main': (context) => MainNavigation(), // ⭐ 동일하게 MainNavigation 사용
          '/notices': (context) => NoticeScreen(),
          '/documents/submit': (context) => DocumentSubmitScreen(),
          '/inspection': (context) => InspectionScreen(),
          '/admin/inspection': (context) => AdminInspectionScreen(),
        },

        // 알 수 없는 라우트 처리
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text('오류')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('페이지를 찾을 수 없습니다.'),
                    Text('라우트: ${settings.name}'),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: Text('로그인으로 돌아가기'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}