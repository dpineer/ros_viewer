import 'dart:async';
import 'dart:io';
import 'dart:convert'; // 新增
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

  // ================= 可见光相机算法控制状态 =================
  int cameraBrightness = 128;
  int cameraContrast = 32;
  int cameraSaturation = 64;
  int cameraGamma = 120;

  Timer? _cameraApiDebouncer; // HTTP 请求防抖动定时器

  // ================= 红外热成像专属算法控制状态 =================
  int thermalBrightness = 128;
  int thermalContrast = 32;
  int thermalSaturation = 64;
  int thermalGamma = 120;

  Timer? _thermalApiDebouncer; // HTTP 请求防抖动定时器

  // ================= YOLO 与导航状态 =================
  bool isYoloEnabled = false; // 新增状态

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

  // ================= 图像算法控制方法 =================
  void updateCameraParams({int? b, int? c, int? s, int? g}) {
    if (b != null) cameraBrightness = b;
    if (c != null) cameraContrast = c;
    if (s != null) cameraSaturation = s;
    if (g != null) cameraGamma = g;
    notifyListeners(); // 触发 UI 更新滑动条数值

    // 50 毫秒防抖，避免滑动时瞬间打爆后端 8082 端口
    _cameraApiDebouncer?.cancel();
    _cameraApiDebouncer = Timer(const Duration(milliseconds: 50), () {
      _sendCameraConfig();
    });
  }

  Future<void> _sendCameraConfig() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      // 【关键修复】：C++ 后端现在运行在 Debian 主机（也就是本地），所以必须发给 127.0.0.1
      final url = Uri.parse(
          'http://127.0.0.1:8082/set?b=$cameraBrightness&c=$cameraContrast&s=$cameraSaturation&g=$cameraGamma');
      final request = await client.getUrl(url);
      final response = await request.close();
      await response.drain(); // 必须排空流以释放套接字资源
    } catch (e) {
      // 忽略短暂的网络波动或打印日志
      logger.error('Camera Tuning API Error: $e');
    } finally {
      client?.close(force: true);
    }
  }

  // ================= 红外热成像算法控制方法 =================
  void updateThermalParams({int? b, int? c, int? s, int? g}) {
    if (b != null) thermalBrightness = b;
    if (c != null) thermalContrast = c;
    if (s != null) thermalSaturation = s;
    if (g != null) thermalGamma = g;
    notifyListeners(); // 触发 UI 更新滑动条

    // 50 毫秒防抖，避免滑动时瞬间打爆 C++ 后端 8082 端口
    _thermalApiDebouncer?.cancel();
    _thermalApiDebouncer = Timer(const Duration(milliseconds: 50), () {
      _sendThermalConfig();
    });
  }

  Future<void> _sendThermalConfig() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      // 【关键修复】：同样改为 127.0.0.1
      final url = Uri.parse(
          'http://127.0.0.1:8082/set?b=$thermalBrightness&c=$thermalContrast&s=$thermalSaturation&g=$thermalGamma');
      final request = await client.getUrl(url);
      final response = await request.close();
      await response.drain(); // 必须排空流以释放套接字资源
    } catch (e) {
      logger.error('Thermal Tuning API Error: $e');
    } finally {
      client?.close(force: true);
    }
  }

  // ================= YOLO 与导航控制方法 =================
  void sendNavGoal(double x, double y) {
    rosService.publishGoal(x, y);
    logger.info('Send Navigation Goal -> X: ${x.toStringAsFixed(2)}, Y: ${y.toStringAsFixed(2)}');
  }

  void toggleYolo() {
    isYoloEnabled = !isYoloEnabled;
    notifyListeners();
    // 【关键修复】：C++ 后端现在运行在 Debian 主机（也就是本地），所以必须发给 127.0.0.1
    HttpClient().getUrl(Uri.parse('http://127.0.0.1:8082/set?yolo=${isYoloEnabled ? 1 : 0}'))
      .then((request) => request.close()).then((response) => response.drain());
  }

  Process? _hostAiProcess; // 记录上位机 C++ 引擎的进程实例

  // ================= 自动化部署 1：下位机环境一键注入 =================
  Future<void> injectRobotEnvironment() async {
    if (!isSshConnected || sshService.client == null) {
      logger.error('[部署] 失败：SSH 未连接');
      return;
    }
    logger.info('[部署] 开始向小车注入自动化环境...');
    try {
      // 1. 生成雷达跟随 Python 脚本并转为 Base64 以防转义错误
      const pythonScript = '''#!/usr/bin/env python
import rospy
from sensor_msgs.msg import LaserScan
from geometry_msgs.msg import Twist

def scan_cb(msg):
    pub = rospy.Publisher('/cmd_vel', Twist, queue_size=1)
    t = Twist()
    mid = len(msg.ranges) // 2
    sector = msg.ranges[mid-30 : mid+30]
    valid_ranges = [r for r in sector if 0.1 < r < 3.0]
    if not valid_ranges:
        pub.publish(t)
        return
    min_dist = min(valid_ranges)
    min_index = sector.index(min_dist)
    angle_offset = (min_index - 30)
    
    if min_dist > 0.6:
        t.linear.x = 0.25 * (min_dist - 0.6)
        t.angular.z = -0.015 * angle_offset
    else:
        t.linear.x = 0
        t.angular.z = 0
    pub.publish(t)

if __name__ == '__main__':
    rospy.init_node('lidar_follower')
    rospy.Subscriber('/scan', LaserScan, scan_cb)
    rospy.spin()
''';
      final base64Script = base64Encode(utf8.encode(pythonScript));
      
      // 使用 SSH 写入文件并赋予执行权限
      final cmdWrite = 'echo $base64Script | base64 -d > /home/xtark/ros_ws/lidar_follower.py && chmod +x /home/xtark/ros_ws/lidar_follower.py';
      await sshService.client!.execute(cmdWrite);
      logger.info('[部署] lidar_follower.py 注入成功');

      // 2. 自动注入密码执行 sudo apt-get 安装缺失的 explore_lite
      logger.info('[部署] 正在拉取 apt 依赖 explore_lite，请稍候...');
      final cmdApt = 'echo "$sshPass" | sudo -S apt-get update && echo "$sshPass" | sudo -S apt-get install ros-kinetic-explore-lite -y';
      await sshService.client!.execute(cmdApt);
      logger.info('[部署] ROS 依赖包安装检测完毕');

    } catch (e) {
      logger.error('[部署] 注入报错: $e');
    }
  }

  // ================= 自动化部署 2：上位机(本地)一键编译运行 AI 引擎 =================
  Future<void> compileAndRunHostAI() async {
    logger.info('[AI引擎] 开始在 Debian 上位机编译 C++ 源码...');
    try {
      // 1. 调用系统 gcc/g++ 自动编译
      final compileResult = await Process.run('g++',[
        'ai_engine.cpp', '-o', 'ai_engine',
        '-pthread' // 先给基础线程库
      ]..addAll(
        // 通过 shell 获取 pkg-config OpenCV4 参数
        (await Process.run('pkg-config',['--cflags', '--libs', 'opencv4'])).stdout.toString().trim().split(' ')
      ));
      
      if (compileResult.exitCode != 0) {
        logger.error('[AI引擎] 编译失败: ${compileResult.stderr}');
        return;
      }
      logger.info('[AI引擎] 编译成功。正在启动并连接下位机...');

      // 2. 终止旧进程，启动新进程，并将小车 IP 作为参数传入
      _hostAiProcess?.kill();
      _hostAiProcess = await Process.start('./ai_engine', [targetIp]);
      logger.info('[AI引擎] 已在后台运行 (PID: ${_hostAiProcess!.pid})');

      // (可选) 读取引擎 stdout 并转发到日志
      _hostAiProcess!.stdout.transform(utf8.decoder).listen((data) {
         if(data.trim().isNotEmpty) logger.info('[C++] ${data.trim()}');
      });

    } catch (e) {
      logger.error('[AI引擎] 编译/运行异常: $e');
    }
  }

  @override
  void dispose() {
    _hostAiProcess?.kill(); // 随应用关闭时销毁 C++ 引擎
    _thermalApiDebouncer?.cancel();
    _cameraApiDebouncer?.cancel();
    _watchdogTimer?.cancel();
    sshBridge.dispose();
    super.dispose();
  }
}
