import 'package:flutter/material.dart';
import '../features/scan/screens/home_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/settings/screens/settings_screen.dart';

class BottomNavShell extends StatefulWidget {
  /// Which tab should be selected when this shell opens.
  /// 0 = Home, 1 = History, 2 = Settings
  final int initialIndex;

  const BottomNavShell({
    super.key,
    this.initialIndex = 0, // default to Home
  });

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  late int _index;

  final _pages = const [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Clamp just in case someone passes an out-of-range index
    _index = widget.initialIndex.clamp(0, 2);
  }

  void _onTabSelected(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTabSelected,
        items: [
          BottomNavigationBarItem(
            label: 'Home',
            icon: Image.asset(
              _index == 0
                  ? 'assets/icons/bottom_nav_icons/home_active.png'
                  : 'assets/icons/bottom_nav_icons/home_inactive.png',
              width: 18,
              height: 18,
            ),
          ),
          BottomNavigationBarItem(
            label: 'History',
            icon: Image.asset(
              _index == 1
                  ? 'assets/icons/bottom_nav_icons/history_active.png'
                  : 'assets/icons/bottom_nav_icons/history_inactive.png',
              width: 18,
              height: 18,
            ),
          ),
          BottomNavigationBarItem(
            label: 'Settings',
            icon: Image.asset(
              _index == 2
                  ? 'assets/icons/bottom_nav_icons/settings_active.png'
                  : 'assets/icons/bottom_nav_icons/settings_inactive.png',
              width: 18,
              height: 18,
            ),
          ),
        ],
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}