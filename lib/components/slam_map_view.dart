import 'dart:convert';
import 'dart:io'; // 引入 zlib 解压库
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class SlamMapView extends StatelessWidget {
  final Map<String, dynamic>? scanData;
  final Map<String, dynamic>? mapData;
  final double scale;
  final Function(double x, double y)? onMapTap; // [新增] 点击回调

  const SlamMapView({Key? key, this.scanData, this.mapData, this.scale = 30.0, this.onMapTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (mapData == null || onMapTap == null) return;
        // 触控反向解算逻辑
        final center = Offset(context.size!.width / 2, context.size!.height / 2);
        final double rth = (mapData!['rth'] as num?)?.toDouble() ?? 0.0;
        final double rx = (mapData!['rx'] as num).toDouble();
        final double ry = (mapData!['ry'] as num).toDouble();

        // 还原物理屏幕到相对坐标系
        double rotY = (center.dx - details.localPosition.dx) / scale;
        double rotX = (center.dy - details.localPosition.dy) / scale;

        // 逆向旋转矩阵 + 加上小车本体坐标
        double relX = rotX * cos(rth) - rotY * sin(rth);
        double relY = rotX * sin(rth) + rotY * cos(rth);
        
        onMapTap!(rx + relX, ry + relY);
      },
      child: Container(
        color: const Color(0xFF1E1E1E),
        child: CustomPaint(
          painter: SlamPainter(scanData, mapData, scale),
          size: const Size(double.infinity, double.infinity),
        ),
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
      final double rth = (mapData!['rth'] as num?)?.toDouble() ?? 0.0; // [新增]
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
            
            // [新增] 2D 旋转矩阵，使地图围绕小车转动
            double rotatedX = relX * cos(-rth) - relY * sin(-rth);
            double rotatedY = relX * sin(-rth) + relY * cos(-rth);
            
            double px = center.dx - (rotatedY * scale);
            double py = center.dy - (rotatedX * scale);
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
