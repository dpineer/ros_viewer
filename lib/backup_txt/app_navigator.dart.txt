import 'package:flutter/material.dart';
import 'main_dashboard.dart';
import 'ssh_terminal_view.dart';
import 'settings_view.dart';

class AppNavigator extends StatefulWidget {
  const AppNavigator({Key? key}) : super(key: key);

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _currentIndex = 2; // 默认启动时显示设置界面以便确认IP

  final List<Widget> _pages = [
    const MainDashboard(),
    const SshTerminalView(),
    const SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Control'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'SSH Term'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}