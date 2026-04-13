import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

class SshJoystickService {
  SSHSession? _shell;

  // 初始化并向 SSH 注入挂载本地 ROS 的 Python 脚本
  Future<void> initSshTeleop(SSHClient client) async {
    _shell = await client.shell();
    
    // 注入的 Python 脚本：从 stdin 读取 "线速度,角速度\n" 并发布至 /cmd_vel
    const pythonScript = """
import rospy, sys
from geometry_msgs.msg import Twist
rospy.init_node('flutter_ssh_teleop', disable_signals=True)
pub = rospy.Publisher('/cmd_vel', Twist, queue_size=1)
for line in iter(sys.stdin.readline, ''):
    try:
        v, w = map(float, line.strip().split(','))
        t = Twist()
        t.linear.x = v
        t.angular.z = w
        pub.publish(t)
    except Exception:
        pass
""";
    
    // 激活 ROS 环境变量并执行注入
    final cmd = "source /opt/ros/kinetic/setup.bash && source /home/xtark/ros_ws/devel/setup.bash && python -c \"$pythonScript\"\n";
    _shell!.write(utf8.encode(cmd));
  }

  // 高频下发控制指令 (由摇杆组件调用)
  void sendVelocity(double linear, double angular) {
    if (_shell != null) {
      // 通过 SSH Stdin 管道流式传输数据
      _shell!.write(utf8.encode("$linear,$angular\n"));
    }
  }

  void dispose() {
    _shell?.close();
  }
}