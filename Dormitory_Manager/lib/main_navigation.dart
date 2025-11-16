import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/admin_home_screen.dart';
import 'screens/admin_inspection_screen.dart';
import 'screens/admin_complaint_screen.dart';
import 'screens/admin_schedule_screen.dart'; // ✅ 1. 새 스크린 임포트
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

  // ✅ 1. 'late final' 키워드를 제거합니다. (build 메서드에서 초기화)
  List<Widget> _navScreens = [];
  List<BottomNavigationBarItem> _navItems = [];

  // ❌ 2. initState() 메서드를 삭제합니다.
  // @override
  // void initState() {
  //   super.initState();
  //   // ... (이 코드가 에러의 원인입니다)
  // }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3. build 메서드 안에서 AuthProvider를 호출합니다.
    // 이 시점의 context는 AuthProvider에 안전하게 접근할 수 있습니다.
    final bool isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;

    // ✅ 4. 관리자 여부에 따라 내비게이션 아이템과 스크린을 설정합니다.
    if (isAdmin) {
      // --- 관리자용 내비게이션 ---
      _navItems = [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_work),
          label: '관리자 홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: '일정 관리',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.checklist),
          label: '점호 관리',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: '민원 관리',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '마이페이지',
        ),
      ];
      _navScreens = [
        AdminHomeScreen(),
        AdminScheduleScreen(), // '일정 관리' 스크린 연결
        AdminInspectionScreen(),
        AdminComplaintScreen(),
        MyPageScreen(), // 관리자도 마이페이지 공통 사용
      ];
    } else {
      // --- 일반 사용자용 내비게이션 ---
      _navItems = [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: '점호',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: '공지',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '마이페이지',
        ),
      ];
      _navScreens = [
        HomeScreen(),
        InspectionScreen(),
        NoticeScreen(),
        MyPageScreen(),
      ];
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _navScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey, // 선택되지 않은 아이템 색상
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // 4개 이상일 때 fixed 필요
      ),
    );
  }
}