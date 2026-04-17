import 'dart:math';
import 'package:flutter/material.dart';

class LidarMapView extends StatelessWidget {
  final Map<String, dynamic>? scanData;

  const LidarMapView({Key? key, this.scanData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: scanData == null
            ? const Text(
                '等待雷达数据...',
                style: TextStyle(color: Colors.white70),
              )
            : CustomPaint(
                size: const Size(300, 300),
                painter: _LidarPainter(scanData!),
              ),
      ),
    );
  }
}

class _LidarPainter extends CustomPainter {
  final Map<String, dynamic> scanData;

  _LidarPainter(this.scanData);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // 绘制背景网格
    final gridPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制同心圆
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, gridPaint);
    }

    // 绘制角度线
    for (int angle = 0; angle < 360; angle += 30) {
      final radians = angle * pi / 180;
      final end = Offset(
        center.dx + radius * cos(radians),
        center.dy + radius * sin(radians),
      );
      canvas.drawLine(center, end, gridPaint);
    }

    // 绘制雷达点
    if (scanData.containsKey('ranges')) {
      final ranges = List<double>.from(scanData['ranges'] as List);
      final angleMin = scanData['angle_min'] as double? ?? 0;
      final angleIncrement = scanData['angle_increment'] as double? ?? 0.0174533;

      final pointPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.fill;

      for (int i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        if (range.isFinite && range > 0) {
          final angle = angleMin + i * angleIncrement;
          final pointRadius = (range / 10.0).clamp(0.0, radius); // 假设最大范围10米
          final point = Offset(
            center.dx + pointRadius * cos(angle),
            center.dy + pointRadius * sin(angle),
          );
          canvas.drawCircle(point, 2, pointPaint);
        }
      }
    }

    // 绘制中心点
    final centerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
