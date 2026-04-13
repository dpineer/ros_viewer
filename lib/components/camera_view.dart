import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class CameraView extends StatelessWidget {
  final String robotIp;
  final int port;
  final String topic;

  const CameraView({
    Key? key,
    required this.robotIp,
    this.port = 8080,
    this.topic = '/usb_cam/image_raw',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final streamUrl = 'http://$robotIp:$port/stream?topic=$topic';
    
    return Container(
      color: Colors.black,
      child: Mjpeg(
        isLive: true,
        stream: streamUrl,
        error: (context, error, stack) => const Center(
          child: Text('CAMERA_STREAM_TIMEOUT', style: TextStyle(color: Colors.red)),
        ),
        loading: (context) => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}