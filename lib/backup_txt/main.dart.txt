import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/logger_service.dart';
import 'services/robot_provider.dart';
import 'services/storage_service.dart';
import 'app_navigator.dart';

void main() async {
  // 【修复】必须确保 Flutter 引擎完成绑定，否则移动端调用 SharedPreferences 必现白屏/闪退
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // 初始化StorageService
  final storageService = StorageService();
  await storageService.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoggerService()),
        ChangeNotifierProvider(create: (_) => storageService),
        ChangeNotifierProxyProvider<StorageService, RobotStateProvider>(
          create: (context) => RobotStateProvider(
            context.read<LoggerService>(),
            context.read<StorageService>(),
          ),
          update: (context, storage, previous) => previous ?? RobotStateProvider(
            context.read<LoggerService>(),
            storage,
          ),
        ),
      ],
      child: const MaterialApp(
        title: 'ROS Controller',
        debugShowCheckedModeBanner: false,
        home: AppNavigator(), // 启动层变更为导航器
      ),
    ),
  );
}
