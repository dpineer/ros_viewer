import 'package:flutter/material.dart';

class JoystickView extends StatefulWidget {
  final Function(double linear, double angular) onJoystickUpdate;
  final double maxLinearSpeed;
  final double maxAngularSpeed;

  const JoystickView({
    super.key,
    required this.onJoystickUpdate,
    this.maxLinearSpeed = 0.5,   // m/s
    this.maxAngularSpeed = 1.0,  // rad/s
  });

  @override
  State<JoystickView> createState() => _JoystickViewState();
}

class _JoystickViewState extends State<JoystickView> {
  Offset _joystickPosition = Offset.zero;
  bool _isDragging = false;

  void _updateJoystick(Offset localPosition, Size joystickSize) {
    // 计算相对于中心的位置（范围：-1 到 1）
    final center = joystickSize.center(Offset.zero);
    final relativeX = (localPosition.dx - center.dx) / (joystickSize.width / 2);
    final relativeY = (localPosition.dy - center.dy) / (joystickSize.height / 2);
    
    // 限制在单位圆内
    final distance = Offset(relativeX, relativeY).distance;
    final clampedX = distance > 1.0 ? relativeX / distance : relativeX;
    final clampedY = distance > 1.0 ? relativeY / distance : relativeY;
    
    setState(() {
      _joystickPosition = Offset(clampedX, clampedY);
    });
    
    // 坐标系转换：
    // Joystick Y负向对应机器人X正向（前进）
    // Joystick X负向对应机器人Z正向（左转）
    final linearX = -clampedY * widget.maxLinearSpeed;
    final angularZ = -clampedX * widget.maxAngularSpeed;
    
    widget.onJoystickUpdate(linearX, angularZ);
  }

  void _resetJoystick() {
    setState(() {
      _joystickPosition = Offset.zero;
      _isDragging = false;
    });
    widget.onJoystickUpdate(0.0, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
        });
        _updateJoystick(details.localPosition, _getJoystickSize(context));
      },
      onPanUpdate: (details) {
        _updateJoystick(details.localPosition, _getJoystickSize(context));
      },
      onPanEnd: (_) => _resetJoystick(),
      onPanCancel: () => _resetJoystick(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: Stack(
          children: [
            // 十字线
            Center(
              child: Container(
                width: 2,
                height: double.infinity,
                color: Colors.grey[400],
              ),
            ),
            Center(
              child: Container(
                width: double.infinity,
                height: 2,
                color: Colors.grey[400],
              ),
            ),
            // 摇杆手柄
            Positioned(
              left: (_joystickPosition.dx + 1) * (_getJoystickSize(context).width / 2) - 30,
              top: (_joystickPosition.dy + 1) * (_getJoystickSize(context).height / 2) - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _isDragging ? Colors.blue : Colors.blue[300],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.circle,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Size _getJoystickSize(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }
}
