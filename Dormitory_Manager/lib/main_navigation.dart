import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/admin_home_screen.dart';
import 'screens/admin_inspection_screen.dart';
import 'screens/admin_schedule_screen.dart';
import 'screens/admin_room_template_screen.dart';  // 관리자 홈에서 기준 사진 관리 접근용 (유지)
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
    // AuthProvider에서 관리자 여부 확인
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
        // ✅ 기준 사진 → 공지 화면으로 변경
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
        const NoticeScreen(),  // ✅ 기준 사진 → 공지 화면으로 변경
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

    // 안전성 체크: 선택된 인덱스가 화면 개수를 초과하지 않도록
    if (_selectedIndex >= _navScreens.length) {
      print('[WARNING] 선택된 인덱스($_selectedIndex)가 화면 개수(${_navScreens.length})를 초과하여 0으로 리셋');
      _selectedIndex = 0;
    }

    print('[DEBUG] 현재 표시할 화면: ${_navScreens[_selectedIndex].runtimeType}');
    print('[DEBUG] ==============================');

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _navScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}