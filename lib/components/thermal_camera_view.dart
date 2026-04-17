// 文件: lib/components/thermal_camera_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class ThermalCameraView extends StatelessWidget {
  final String robotIp;
  final int port;

  const ThermalCameraView({
    Key? key,
    required this.robotIp,
    this.port = 8081, // C++ 后端独立视频流端口
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final streamUrl = 'http://$robotIp:$port/';
    
    return Container(
      color: Colors.black,
      child: Mjpeg(
        isLive: true,
        stream: streamUrl,
        error: (context, error, stack) => const Center(
          child: Text('THERMAL_STREAM_TIMEOUT\n未检测到热成像流 (8081端口)', 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red)),
        ),
        loading: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              CircularProgressIndicator(color: Colors.deepOrange),
              SizedBox(height: 16),
              Text('正在连接热成像...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}