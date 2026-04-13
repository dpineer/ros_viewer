import 'dart:math';
import 'package:flutter/material.dart';

class NativeJoystickView extends StatefulWidget {
  final Function(double linear, double angular) onJoystickUpdate;
  final double maxLinearSpeed;
  final double maxAngularSpeed;
  final double radius;

  const NativeJoystickView({
    Key? key,
    required this.onJoystickUpdate,
    this.maxLinearSpeed = 0.5,
    this.maxAngularSpeed = 1.0,
    this.radius = 80.0,
  }) : super(key: key);

  @override
  State<NativeJoystickView> createState() => _NativeJoystickViewState();
}

class _NativeJoystickViewState extends State<NativeJoystickView> {
  Offset _currentPos = Offset.zero;

  void _updatePosition(Offset localPosition) {
    // 将坐标原点移至摇杆中心
    final center = Offset(widget.radius, widget.radius);
    final delta = localPosition - center;
    
    // 计算极坐标参数
    double distance = delta.distance;
    double angle = delta.direction;

    // 限制摇杆范围在半径内
    if (distance > widget.radius) {
      distance = widget.radius;
    }

    // 计算实际位置与归一化向量
    setState(() {
      _currentPos = Offset(distance * cos(angle), distance * sin(angle));
    });

    // 映射至ROS机体坐标系:
    // UI Y轴负向 = 机体前进 (X线速度)
    // UI X轴负向 = 机体左转 (Z角速度)
    final normalizedX = _currentPos.dx / widget.radius;
    final normalizedY = _currentPos.dy / widget.radius;
    
    final linearX = -normalizedY * widget.maxLinearSpeed;
    final angularZ = -normalizedX * widget.maxAngularSpeed;
    
    widget.onJoystickUpdate(linearX, angularZ);
  }

  void _resetPosition() {
    setState(() {
      _currentPos = Offset.zero;
    });
    widget.onJoystickUpdate(0.0, 0.0); // 松手归零停止运动
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    
    return GestureDetector(
      onPanStart: (details) => _updatePosition(details.localPosition),
      onPanUpdate: (details) => _updatePosition(details.localPosition),
      onPanEnd: (_) => _resetPosition(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.withOpacity(0.3),
        ),
        child: Center(
          child: Transform.translate(
            offset: _currentPos,
            child: Container(
              width: widget.radius,
              height: widget.radius,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.8),
                boxShadow: const[
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}