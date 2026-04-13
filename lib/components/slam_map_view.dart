import 'dart:convert';
import 'dart:io'; // 引入 zlib 解压库
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class SlamMapView extends StatelessWidget {
  final Map<String, dynamic>? scanData;
  final Map<String, dynamic>? mapData;
  final double scale;

  const SlamMapView({Key? key, this.scanData, this.mapData, this.scale = 30.0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E), // 更深的背景提升对比度
      child: CustomPaint(
        painter: SlamPainter(scanData, mapData, scale),
        size: const Size(double.infinity, double.infinity),
      ),
    );
  }
}

class SlamPainter extends CustomPainter {
  final Map<String, dynamic>? scanData;
  final Map<String, dynamic>? mapData;
  final double scale;

  SlamPainter(this.scanData, this.mapData, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. 渲染优化后的 SLAM 地图
    if (mapData != null && mapData!.containsKey('data')) {
      final double resolution = (mapData!['res'] as num).toDouble();
      final int width = mapData!['w'] as int;
      final double originX = (mapData!['ox'] as num).toDouble();
      final double originY = (mapData!['oy'] as num).toDouble();
      final double rx = (mapData!['rx'] as num?)?.toDouble() ?? 0.0;
      final double ry = (mapData!['ry'] as num?)?.toDouble() ?? 0.0;
      final String b64Data = mapData!['data'];

      try {
        final List<int> cells = zlib.decode(base64.decode(b64Data));

        final obstaclePaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0; // 加粗画笔确保在移动端高分屏可见
        List<Offset> obstacles =[];

        for (int i = 0; i < cells.length; i++) {
          int cell = cells[i];
          // Dart 解压后是无符号(0~255)。ROS中障碍物是100，未知是-1(即255)，空闲是0
          // 我们只渲染真实的障碍物墙壁 (cell 介于 50 到 100 之间)
          if (cell > 50 && cell <= 100) {
            int gridX = i % width;
            int gridY = i ~/ width;
            
            // 栅格在物理世界中的绝对坐标
            double wx = originX + gridX * resolution;
            double wy = originY + gridY * resolution;
            
            // 相对机器人的物理偏移
            double relX = wx - rx;
            double relY = wy - ry;
            
            // 【关键数学修复】：统一雷达映射！
            // ROS X(前方) 映射屏幕 -Y(上方)
            // ROS Y(左方) 映射屏幕 -X(左方)
            double px = center.dx - (relY * scale);
            double py = center.dy - (relX * scale);
            
            obstacles.add(Offset(px, py));
          }
        }
        // 使用高性能批处理渲染
        canvas.drawPoints(PointMode.points, obstacles, obstaclePaint);
      } catch (e) {
        debugPrint("Map Render Error: $e");
      }
    }

    // 2. 渲染高速 UDP 激光雷达点云 (继承自第11轮的完美代码)
    if (scanData != null && scanData!.containsKey('r')) {
      final double angleMin = (scanData!['m'] as num).toDouble();
      final double angleInc = (scanData!['i'] as num).toDouble();
      final List<dynamic> ranges = scanData!['r'];

      final laserPaint = Paint()
        ..color = Colors.greenAccent
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      List<Offset> laserPoints =[];

      for (int idx = 0; idx < ranges.length; idx++) {
        double range = (ranges[idx] as num).toDouble();
        if (range > 0.1 && range < 12.0) {
          double angle = angleMin + (idx * angleInc);
          double px = center.dx - (range * scale * sin(angle));
          double py = center.dy - (range * scale * cos(angle));
          laserPoints.add(Offset(px, py));
        }
      }
      canvas.drawPoints(PointMode.points, laserPoints, laserPaint);
    }
    
    // 绘制机身红点
    canvas.drawCircle(center, 4.0, Paint()..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(covariant SlamPainter oldDelegate) => true;
}
