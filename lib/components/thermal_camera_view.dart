import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class ThermalCameraView extends StatelessWidget {
  final int port;

  const ThermalCameraView({
    Key? key,
    this.port = 8081, 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 【关键修复】：拉取由上位机 C++ (本地) 输出的融合并画了 YOLO 框的流
    final streamUrl = 'http://127.0.0.1:$port/';
    
    return Container(
      color: Colors.black,
      child: Mjpeg(
        isLive: true,
        stream: streamUrl,
        error: (context, error, stack) => const Center(
          child: Text('AI/THERMAL_STREAM_TIMEOUT\n未检测到上位机 AI 引擎流\n请在 Settings 中点击[编译执行]', 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red)),
        ),
        loading: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children:[
              CircularProgressIndicator(color: Colors.deepOrange),
              SizedBox(height: 16),
              Text('正在拉取 AI 引擎数据流...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
