import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/robot_provider.dart';
import 'components/camera_view.dart';
import 'components/slam_map_view.dart';
import 'components/native_joystick_view.dart';

enum ActiveView { map, camera }

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool _isLandscape = false;
  ActiveView _primaryView = ActiveView.map; // 默认大屏显示SLAM建图

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  void _swapViews() {
    setState(() {
      _primaryView = _primaryView == ActiveView.map ? ActiveView.camera : ActiveView.map;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RobotStateProvider>();

    if (!provider.isRosConnected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(
          child: Text(
            'ROS Data Stream Not Connected.\nLaunch nodes in SSH and connect in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    // 实例化两个核心渲染器
    final mapWidget = SlamMapView(
      scanData: provider.latestScanData,
      mapData: provider.latestMapData,
      scale: 45.0, // 主视角大比例尺
    );
    final cameraWidget = CameraView(robotIp: provider.targetIp);

    // 路由主副视图
    final largeWidget = _primaryView == ActiveView.map ? mapWidget : cameraWidget;
    final smallWidget = _primaryView == ActiveView.map ? cameraWidget : mapWidget;

    return Scaffold(
      // 隐藏原生AppBar，实现沉浸式全屏体验
      body: Stack(
        children:[
          // 1. 核心图层 Z=0：大屏沉浸显示
          Positioned.fill(
            child: largeWidget,
          ),

          // 2. 交互图层 Z=1：悬浮小窗 (PiP)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, // 避开手机状态栏
            left: 16,
            child: GestureDetector(
              onTap: _swapViews,
              child: Container(
                width: 160,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.blueAccent, width: 2.0),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: const[
                    BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  // 小窗强行缩小展示另一个流，忽略纵横比强制填充
                  child: AbsorbPointer(child: smallWidget), 
                ),
              ),
            ),
          ),

          // 3. 交互图层 Z=2：屏幕翻转按钮 (置于右上角)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: Icon(_isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape, color: Colors.white),
                onPressed: _toggleOrientation,
                tooltip: 'Toggle Orientation',
              ),
            ),
          ),

          // 4. 交互图层 Z=3：虚拟摇杆 (置于底部中心偏下处)
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Align(
                alignment: _isLandscape ? Alignment.bottomRight : Alignment.bottomCenter,
                child: Padding(
                  padding: _isLandscape ? const EdgeInsets.only(right: 48.0) : EdgeInsets.zero,
                  child: Opacity(
                    opacity: _primaryView == ActiveView.camera ? 0.6 : 0.85, // 在摄像头上叠加时透明度更高
                    child: NativeJoystickView(
                      onJoystickUpdate: provider.updateJoystick,
                      radius: _isLandscape ? 70.0 : 80.0, // 横屏时摇杆稍微变小
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}