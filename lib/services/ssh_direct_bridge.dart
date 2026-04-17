import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

class SshDirectBridge {
  SSHSession? _shell;
  RawDatagramSocket? _udpSocket;
  Timer? _mapPollingTimer;
  
  Function(Map<String, dynamic>)? onLidarData;
  Function(Map<String, dynamic>)? onMapData;

  Future<void> initBridge(SSHClient client, String targetIp) async {
    // 1. UDP 监听 
    // 【优化】允许复用端口，防止移动端切屏导致端口占用报错
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 9999, reuseAddress: true);
    _udpSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = _udpSocket!.receive();
        if (datagram != null && onLidarData != null) {
          try { onLidarData!(jsonDecode(utf8.decode(datagram.data))); } catch (e) {}
        }
      }
    });

    _shell = await client.shell();
    
    // 2. 注入包含微型 HTTP 服务器与 TF 解算的终极 Python 脚本
    const pythonScript = r'''
import rospy, socket, json, os, sys, base64, zlib, threading, tf
import array  
try:
    from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
except ImportError:
    from http.server import BaseHTTPRequestHandler, HTTPServer
from sensor_msgs.msg import LaserScan
from nav_msgs.msg import OccupancyGrid
from geometry_msgs.msg import Twist

ssh_client = os.environ.get('SSH_CLIENT')
if not ssh_client: sys.exit(1)
phone_ip = ssh_client.split()[0]

# 【修复】动态识别 IP 协议族。手机连局域网常被分配 IPv6 映射地址
# 若写死 AF_INET，会导致 Python 侧直接抛出异常崩溃，导致手机端再也收不到数据（黑屏）
try:
    if ':' in phone_ip:
        sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    else:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    TARGET = (phone_ip, 9999)
except Exception:
    sys.exit(1)

latest_map_payload = "{}"
tf_listener = None

def scan_cb(msg):
    clean_ranges =[-1.0 if r == float('inf') or r != r else round(r, 3) for r in msg.ranges]
    payload = json.dumps({'m': round(msg.angle_min, 4), 'i': round(msg.angle_increment, 4), 'r': clean_ranges})
    try: sock.sendto(payload.encode('utf-8'), TARGET)
    except: pass

def map_cb(msg):
    global latest_map_payload
    rx, ry, rth = 0.0, 0.0, 0.0
    if tf_listener:
        try:
            (trans, rot) = tf_listener.lookupTransform('/map', '/base_footprint', rospy.Time(0))
            rx, ry = trans[0], trans[1]
            # [新增] 提取航向角(Yaw)
            _, _, rth = tf.transformations.euler_from_quaternion(rot)
        except: pass

    info = msg.info
    arr = array.array('b', msg.data)
    raw_bytes = arr.tobytes() if hasattr(arr, 'tobytes') else arr.tostring()
    
    comp = zlib.compress(raw_bytes)
    b64 = base64.b64encode(comp).decode('utf-8')
    
    payload = {
        'res': info.resolution,
        'w': info.width,
        'h': info.height,
        'ox': info.origin.position.x,
        'oy': info.origin.position.y,
        'rx': rx,
        'ry': ry,
        'rth': rth, # [新增] 推送给前端
        'data': b64
    }
    latest_map_payload = json.dumps(payload)

class MapHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(latest_map_payload.encode('utf-8'))
    def log_message(self, format, *args): pass

def run_server():
    server = HTTPServer(('0.0.0.0', 8089), MapHandler)
    server.serve_forever()

rospy.init_node('flutter_direct_bridge', disable_signals=True)
tf_listener = tf.TransformListener()
rospy.Subscriber('/scan', LaserScan, scan_cb, queue_size=1)
rospy.Subscriber('/map', OccupancyGrid, map_cb, queue_size=1)

threading.Thread(target=run_server).start()

pub = rospy.Publisher('/cmd_vel', Twist, queue_size=1)
for line in iter(sys.stdin.readline, ''):
    try:
        v, w = map(float, line.strip().split(','))
        t = Twist()
        t.linear.x = v
        t.angular.z = w
        pub.publish(t)
    except: pass
''';
    
    final cmd = 'source /opt/ros/kinetic/setup.bash && source /home/xtark/ros_ws/devel/setup.bash && python -c "$pythonScript"\n';
    _shell!.write(utf8.encode(cmd));

    // 3. 按照您的建议：开启定时同步拉取 (Polling)
    // 修改定时器间隔，4秒同步一次建图结果，平衡带宽与刷新率
    _mapPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMap(targetIp));
  }

  // 定时向树莓派 8089 端口拉取压缩后的地图
  Future<void> _fetchMap(String ip) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('http://$ip:8089/'));
      final response = await request.close();
      final stringData = await response.transform(utf8.decoder).join();
      if (stringData.length > 10 && onMapData != null) {
        onMapData!(jsonDecode(stringData));
      }
    } catch (e) {
      // 网络波动时忽略
    } finally {
      // 【关键修复】移动端连接池资源极度有限(不像Linux有上万个fd)。
      // 每4秒创建一次Client如果不主动释放，1分钟内导致整机网络阻塞断开连接，出现黑屏失控。
      client?.close(force: true); 
    }
  }

  void sendVelocity(double linear, double angular) {
    if (_shell != null) _shell!.write(utf8.encode("$linear,$angular\n"));
  }

  void dispose() {
    _mapPollingTimer?.cancel();
    _shell?.close();
    _udpSocket?.close();
  }
}