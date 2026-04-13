// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ros_viewer/main.dart';
import 'package:ros_viewer/services/logger_service.dart';
import 'package:ros_viewer/services/robot_provider.dart';
import 'package:ros_viewer/services/storage_service.dart';
import 'package:ros_viewer/app_navigator.dart';

// Simple mock StorageService for testing
class TestStorageService extends StorageService {
  String? _ip;
  String? _user;
  String? _pass;
  
  @override
  Future<void> init() async {}
  
  @override
  String? getRobotIp() => _ip;
  
  @override
  Map<String, String>? getSshCredentials() {
    if (_user != null && _pass != null) {
      return {'user': _user!, 'pass': _pass!};
    }
    return null;
  }
  
  @override
  Future<void> saveRobotIp(String ip) async {
    _ip = ip;
  }
  
  @override
  Future<void> saveSshCredentials(String user, String pass) async {
    _user = user;
    _pass = pass;
  }
}

void main() {
  testWidgets('ROS Controller app loads correctly', (WidgetTester tester) async {
    final storageService = TestStorageService();
    final loggerService = LoggerService();
    
    // 手动创建RobotStateProvider，避免复杂的Provider依赖
    final robotProvider = RobotStateProvider(loggerService, storageService);
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LoggerService>.value(value: loggerService),
          ChangeNotifierProvider<StorageService>.value(value: storageService),
          ChangeNotifierProvider<RobotStateProvider>.value(value: robotProvider),
        ],
        child: const MaterialApp(
          title: 'ROS Controller',
          debugShowCheckedModeBanner: false,
          home: AppNavigator(),
        ),
      ),
    );

    // 等待一帧让Provider完全初始化
    await tester.pumpAndSettle();

    // Verify that navigation tabs are displayed (default is Settings tab)
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Control'), findsOneWidget);
    expect(find.text('SSH Term'), findsOneWidget);
    
    // Verify that settings view is displayed by default
    expect(find.text('System Configuration'), findsOneWidget);
    expect(find.text('Robot IP Address'), findsOneWidget);
    expect(find.text('SSH User'), findsOneWidget);
    expect(find.text('SSH Password'), findsOneWidget);
  });
}
