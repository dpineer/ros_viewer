import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xml_rpc/client.dart' as xml_rpc;

class RosService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onLidarDataReceived;
  Function(Map<String, dynamic>)? onMapDataReceived;

  // 严格对齐 ROS 1 (rosjava android_apps) 的 Topic 与 Frame 规范
  static const String frameMap = 'map';
  static const String frameRobot = 'base_footprint'; // 兼容差速小车底盘
  
  static const String topicCmdVel = '/cmd_vel';
  static const String topicScan = '/scan';
  static const String topicMap = '/map';
  static const String topicInitialPose = '/initialpose';
  static const String topicGoal = '/move_base_simple/goal';

  // 1. 验证 11311 ROS Master 连接 (兼容 rosjava 的 Master 握手逻辑)
  Future<List<dynamic>> getSystemState(String ip) async {
    final uri = Uri.parse('http://$ip:11311/');
    final result = await xml_rpc.call(uri, 'getSystemState',['/flutter_mobile_client']);
    if (result[0] == 1) return result[2];
    throw Exception('ROS_MASTER_RPC_ERROR: ${result[1]}');
  }

  // 2. 建立 WebSocket 数据代理 (替代 Java 原生的 Socket TCPROS)
  Future<void> connectDataStream(String ip) async {
    final wsUrl = Uri.parse('ws://$ip:9090');
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['op'] == 'publish') {
        if (data['topic'] == topicScan && onLidarDataReceived != null) {
          onLidarDataReceived!(data['msg']);
        } else if (data['topic'] == topicMap && onMapDataReceived != null) {
          onMapDataReceived!(data['msg']);
        }
      }
    });

    // 握手协议声明
    _sendWsMessage({'op': 'advertise', 'topic': topicCmdVel, 'type': 'geometry_msgs/Twist'});
    _sendWsMessage({'op': 'subscribe', 'topic': topicScan, 'type': 'sensor_msgs/LaserScan'});
    _sendWsMessage({'op': 'subscribe', 'topic': topicMap, 'type': 'nav_msgs/OccupancyGrid'});
    // 预留发布导航目标的接口声明
    _sendWsMessage({'op': 'advertise', 'topic': topicGoal, 'type': 'geometry_msgs/PoseStamped'});
  }

  void publishVelocity(double linearX, double angularZ) {
    if (_channel == null) return;
    _sendWsMessage({
      'op': 'publish',
      'topic': topicCmdVel,
      'msg': {
        'linear': {'x': linearX, 'y': 0.0, 'z': 0.0},
        'angular': {'x': 0.0, 'y': 0.0, 'z': angularZ}
      }
    });
  }

  void publishGoal(double x, double y) {
    if (_channel == null) return;
    _sendWsMessage({
      'op': 'publish',
      'topic': topicGoal,
      'msg': {
        'header': {'frame_id': 'map'},
        'pose': {
          'position': {'x': x, 'y': y, 'z': 0.0},
          'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0} // 忽略方向，由导航包自动接管
        }
      }
    });
  }

  void _sendWsMessage(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }
}
