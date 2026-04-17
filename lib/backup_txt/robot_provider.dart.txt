import 'dart:async';
import 'package:flutter/material.dart';
import 'ros_service.dart';
import 'ssh_service.dart';
import 'ssh_direct_bridge.dart';
import 'logger_service.dart';
import 'storage_service.dart';

class RobotStateProvider extends ChangeNotifier {
  final RosService rosService = RosService();
  final SshService sshService = SshService();
  final SshDirectBridge sshBridge = SshDirectBridge();
  final LoggerService logger;
  final StorageService storageService;

  bool isSshConnected = false;
  bool isRosConnected = false;
  
  String targetIp = '192.168.1.100';
  String sshUser = 'xtark';
  String sshPass = 'xtark';
  
  Map<String, dynamic>? latestScanData;
  Map<String, dynamic>? latestMapData;

  // 运动学看门狗状态机
  Timer? _watchdogTimer;
  double _currentLinear = 0.0;
  double _currentAngular = 0.0;

  RobotStateProvider(this.logger, this.storageService) {
    // 从持久化存储加载IP地址
    _loadStoredIp();
    // 从持久化存储加载SSH凭证
    _loadStoredSshCredentials();
  }

  // 从持久化存储加载IP地址
  void _loadStoredIp() {
    final storedIp = storageService.getRobotIp();
    if (storedIp != null && storedIp.isNotEmpty) {
      targetIp = storedIp;
    }
  }

  // 从持久化存储加载SSH凭证
  void _loadStoredSshCredentials() {
    final credentials = storageService.getSshCredentials();
    if (credentials != null) {
      sshUser = credentials['user'] ?? sshUser;
      sshPass = credentials['pass'] ?? sshPass;
    }
  }

  // 保存IP地址到持久化存储
  Future<void> saveTargetIp(String ip) async {
    targetIp = ip;
    await storageService.saveRobotIp(ip);
    notifyListeners();
  }

  // 保存SSH凭证到持久化存储
  Future<void> saveSshCredentials(String user, String pass) async {
    sshUser = user;
    sshPass = pass;
    await storageService.saveSshCredentials(user, pass);
    notifyListeners();
  }

  // 1. 独立连接SSH (配置阶段调用)
  Future<void> connectSsh() async {
    logger.info('Attempting SSH Connection to $targetIp...');
    try {
      isSshConnected = await sshService.connect(targetIp, sshUser, sshPass);
      if (isSshConnected) {
        logger.info('SSH Connected Successfully.');
        
        // 绑定 Lidar 与 Map 回调
        sshBridge.onLidarData = (data) {
          latestScanData = data;
          notifyListeners();
        };
        sshBridge.onMapData = (data) {
          latestMapData = data;
          notifyListeners(); // 触发底图重绘
        };

        await sshBridge.initBridge(sshService.client!, targetIp);
        
      } else {
        logger.error('SSH Connection Failed.');
      }
      notifyListeners();
    } catch (e) {
      logger.error('SSH Exception: $e');
      isSshConnected = false;
      notifyListeners();
    }
  }

  // 2. 独立连接ROS (业务阶段调用)
  Future<void> connectRos() async {
    logger.info('Attempting ROS Connection via WebSocket (9090)...');
    try {
      // 绑定雷达与地图的回调
      rosService.onLidarDataReceived = (msg) {
        latestScanData = msg;
        notifyListeners();
      };
      rosService.onMapDataReceived = (msg) {
        latestMapData = msg;
        notifyListeners();
      };
      
      await rosService.connectDataStream(targetIp);
      isRosConnected = true;
      logger.info('ROS WebSocket Connected.');
      
      // 启动 10Hz 看门狗保活循环 (参考 RobotCA 逻辑)
      _watchdogTimer?.cancel();
      _watchdogTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (isRosConnected) {
          rosService.publishVelocity(_currentLinear, _currentAngular);
        }
      });
      
      notifyListeners();
    } catch (e) {
      isRosConnected = false;
      logger.error('ROS Connect Failed. Did you start rosbridge via SSH? Error: $e');
      notifyListeners();
    }
  }

  void updateJoystick(double linear, double angular) {
    sshBridge.sendVelocity(linear, angular);
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    sshBridge.dispose();
    super.dispose();
  }
}
