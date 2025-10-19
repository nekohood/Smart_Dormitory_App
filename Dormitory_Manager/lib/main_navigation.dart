import 'package:flutter/material.dart';
import '../data/user_repository.dart';
import 'screens/home_screen.dart';
import 'screens/notice_screen.dart';
import 'screens/document_submit_screen.dart';
import 'screens/inspection_screen.dart';
import 'screens/admin_inspection_screen.dart';
import 'screens/my_page_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = UserRepository.currentUser?.isAdmin ?? false;

    // 일반 사용자 화면 구성
    final List<Widget> userScreens = [
      HomeScreen(),
      InspectionScreen(),
      DocumentSubmitScreen(),
      NoticeScreen(),
      MyPageScreen(),
    ];

    // 일반 사용자 네비게이션 아이템
    final List<BottomNavigationBarItem> userNavItems = const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
      BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: '점호'),
      BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: '서류'),
      BottomNavigationBarItem(icon: Icon(Icons.announcement), label: '공지'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이페이지'),
    ];

    // 관리자 전용 화면 구성
    final List<Widget> adminScreens = [
      HomeScreen(),
      AdminInspectionScreen(),
      DocumentSubmitScreen(), // 서류 관리 화면으로 교체해야 할 수 있음
      NoticeScreen(), // 공지 관리 화면으로 교체해야 할 수 있음
      MyPageScreen(),
    ];

    // 관리자 네비게이션 아이템
    final List<BottomNavigationBarItem> adminNavItems = const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
      BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in), label: '점호관리'),
      BottomNavigationBarItem(icon: Icon(Icons.folder_open), label: '서류관리'),
      BottomNavigationBarItem(icon: Icon(Icons.notifications), label: '공지관리'),
      BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: '관리자'),
    ];

    final screens = isAdmin ? adminScreens : userScreens;
    final navItems = isAdmin ? adminNavItems : userNavItems;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: navItems,
        selectedFontSize: 12,
        unselectedFontSize: 10,
      ),
    );
  }
}
