import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/admin_home_screen.dart';
import 'screens/admin_inspection_screen.dart';
import 'screens/admin_schedule_screen.dart';
import 'screens/home_screen.dart';
import 'screens/inspection_screen.dart';
import 'screens/notice_screen.dart';
import 'screens/my_page_screen.dart';
import 'utils/auth_provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  List<Widget> _navScreens = [];
  List<BottomNavigationBarItem> _navItems = [];

  void _onItemTapped(int index) {
    print('[DEBUG] 네비게이션 탭 선택: $index');
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ AuthProvider에서 관리자 여부 및 인증 상태 확인
    final authProvider = Provider.of<AuthProvider>(context);

    // ✅ 로그인되어 있지 않으면 로그인 화면으로 리다이렉트
    if (!authProvider.isAuthenticated) {
      print('[DEBUG] MainNavigation: 인증되지 않음 - 로그인 화면으로 이동');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bool isAdmin = authProvider.isAdmin;

    print('[DEBUG] === MainNavigation build ===');
    print('[DEBUG] 관리자 여부: $isAdmin');
    print('[DEBUG] 현재 선택된 인덱스: $_selectedIndex');

    if (isAdmin) {
      print('[DEBUG] 관리자 모드로 네비게이션 구성');
      // --- 관리자용 내비게이션 ---
      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_work),
          label: '관리자 홈',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: '일정 관리',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.checklist),
          label: '점호 관리',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: '공지',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '마이페이지',
        ),
      ];

      _navScreens = [
        const AdminHomeScreen(),
        const AdminScheduleScreen(),
        const AdminInspectionScreen(),
        const NoticeScreen(),
        const MyPageScreen(),
      ];

      print('[DEBUG] 관리자 화면 개수: ${_navScreens.length}');
    } else {
      print('[DEBUG] 사용자 모드로 네비게이션 구성');
      // --- 일반 사용자용 내비게이션 ---
      _navItems = [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '홈',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: '점호',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: '공지',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '마이페이지',
        ),
      ];

      _navScreens = [
        const HomeScreen(),
        const InspectionScreen(),
        const NoticeScreen(),
        const MyPageScreen(),
      ];

      print('[DEBUG] 사용자 화면 개수: ${_navScreens.length}');
    }

    // ✅ 인덱스 범위 체크
    if (_selectedIndex >= _navScreens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _navScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: _navItems,
      ),
    );
  }
}