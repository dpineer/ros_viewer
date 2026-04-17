import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/robot_provider.dart';
import 'components/camera_view.dart';
import 'components/thermal_camera_view.dart'; // 引入新增的热成像组件
import 'components/slam_map_view.dart';
import 'components/native_joystick_view.dart';

enum ActiveView { map, camera }
enum CameraChannel { rgb, thermal } // 新增：摄像头通道枚举

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool _isLandscape = false;
  ActiveView _primaryView = ActiveView.map; 
  CameraChannel _currentCameraChannel = CameraChannel.rgb; // 默认使用原厂可见光相机

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

  void _toggleCameraChannel() {
    setState(() {
      _currentCameraChannel = _currentCameraChannel == CameraChannel.rgb 
          ? CameraChannel.thermal 
          : CameraChannel.rgb;
    });
  }

  // 渲染热成像算法调节面板
  void _showThermalSettings(BuildContext context, RobotStateProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:[
                  const Text('热成像滤镜调优 (Thermal Tuning)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  _buildSlider('Brightness', provider.thermalBrightness.toDouble(), 0, 255, (v) {
                    provider.updateThermalParams(b: v.toInt());
                    setModalState(() {});
                  }),
                  _buildSlider('Contrast', provider.thermalContrast.toDouble(), 0, 100, (v) {
                    provider.updateThermalParams(c: v.toInt());
                    setModalState(() {});
                  }),
                  _buildSlider('Saturation', provider.thermalSaturation.toDouble(), 0, 128, (v) {
                    provider.updateThermalParams(s: v.toInt());
                    setModalState(() {});
                  }),
                  _buildSlider('Gamma', provider.thermalGamma.toDouble(), 10, 240, (v) {
                    provider.updateThermalParams(g: v.toInt());
                    setModalState(() {});
                  }),
                ],
              ),
            );
          }
        );
      }
    );
  }

  // 新增：构建调参底部面板
  void _showCameraSettings(BuildContext context, RobotStateProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:[
                  const Text('Image Algorithm Tuning', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  // B: 0~255 (默认 128)
                  _buildSlider('Brightness', provider.cameraBrightness.toDouble(), 0, 255, (v) {
                    provider.updateCameraParams(b: v.toInt());
                    setModalState(() {});
                  }),
                  // C: 0~100 (默认 32)
                  _buildSlider('Contrast', provider.cameraContrast.toDouble(), 0, 100, (v) {
                    provider.updateCameraParams(c: v.toInt());
                    setModalState(() {});
                  }),
                  // S: 0~128 (默认 64)
                  _buildSlider('Saturation', provider.cameraSaturation.toDouble(), 0, 128, (v) {
                    provider.updateCameraParams(s: v.toInt());
                    setModalState(() {});
                  }),
                  // G: 10~240 (默认 120，防零除)
                  _buildSlider('Gamma', provider.cameraGamma.toDouble(), 10, 240, (v) {
                    provider.updateCameraParams(g: v.toInt());
                    setModalState(() {});
                  }),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged) {
    return Row(
      children:[
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 32, child: Text(value.toInt().toString(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
      ],
    );
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

    // 1. 地图引擎
    final mapWidget = SlamMapView(
      scanData: provider.latestScanData,
      mapData: provider.latestMapData,
      scale: 45.0, 
      onMapTap: (x, y) => provider.sendNavGoal(x, y), // 挂载触控事件
    );
    
    // 2. 动态路由相机视图 (判断当前处于 可见光 还是 热成像)
    final Widget activeCameraWidget = _currentCameraChannel == CameraChannel.rgb
        ? CameraView(robotIp: provider.targetIp)
        : ThermalCameraView();

    // 主副视图装载
    final largeWidget = _primaryView == ActiveView.map ? mapWidget : activeCameraWidget;
    final smallWidget = _primaryView == ActiveView.map ? activeCameraWidget : mapWidget;

    return Scaffold(
      // 隐藏原生AppBar，实现沉浸式全屏体验
      body: Stack(
        children:[
          // 1. 核心图层 Z=0：大屏沉浸显示
          Positioned.fill(
            child: largeWidget,
          ),

          // 交互图层 Z=1：悬浮小窗 (PiP)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: _swapViews,
              child: Container(
                width: 160,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black,
                  // 边框颜色随摄像头类型变化以作提示
                  border: Border.all(
                    color: _currentCameraChannel == CameraChannel.thermal 
                        ? Colors.deepOrange 
                        : Colors.blueAccent, 
                    width: 2.0
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: const[
                    BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(2, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: AbsorbPointer(child: smallWidget), 
                ),
              ),
            ),
          ),

          // 交互图层 Z=2.1：屏幕翻转按钮 (置于右上角)
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

          // 交互图层 Z=2.2：双摄切换按钮 (位于翻转按钮左侧)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 72, 
            child: Material(
              color: _currentCameraChannel == CameraChannel.thermal ? Colors.deepOrange : Colors.blueAccent,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.cameraswitch, color: Colors.white),
                onPressed: _toggleCameraChannel,
                tooltip: '切换摄像头通道',
              ),
            ),
          ),

          // 交互图层 Z=2.3：YOLO Toggle 按钮 (Z层级同双摄切换按钮，位置再向左错开)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 184, 
            child: Material(
              color: provider.isYoloEnabled ? Colors.green : Colors.grey,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.psychology, color: Colors.white),
                onPressed: provider.toggleYolo,
                tooltip: 'YOLO 目标检测',
              ),
            ),
          ),

          // 交互图层 Z=2.4：热成像参数调节按钮 (仅在热成像模式下可见)
          if (_currentCameraChannel == CameraChannel.thermal)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 128,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white),
                  onPressed: () => _showThermalSettings(context, provider),
                  tooltip: 'Thermal Filter Tuning',
                ),
              ),
            ),

          // 交互图层 Z=2.5：可见光相机参数调节按钮 (仅在可见光模式下可见)
          if (_currentCameraChannel == CameraChannel.rgb)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 128,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white),
                  onPressed: () => _showCameraSettings(context, provider),
                  tooltip: 'Camera Tuning',
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