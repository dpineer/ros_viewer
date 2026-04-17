# ROS Viewer - 机器人远程控制平台

一个基于Flutter的多平台ROS机器人远程控制应用，支持实时摄像头流、SLAM地图显示、虚拟摇杆控制和SSH终端访问。

## ✨ 功能特性

### 🎮 核心控制
- **虚拟摇杆控制**：通过触摸屏控制机器人移动（线速度和角速度）
- **ROS连接**：支持ROS 1 (rosjava) 的11311端口XML-RPC和9090端口WebSocket连接
- **实时数据流**：订阅激光雷达扫描数据(`/scan`)和地图数据(`/map`)

### 📹 视觉监控
- **摄像头流**：支持MJPG流媒体，实时查看机器人摄像头画面
- **SLAM地图**：实时显示机器人SLAM建图过程和当前位置
- **画中画模式**：支持摄像头和地图视图的快速切换

### 🔧 系统管理
- **SSH终端**：内置完整的SSH终端，支持ANSI颜色和命令执行
- **配置管理**：保存机器人IP、SSH凭据等设置
- **系统日志**：实时显示连接状态和错误信息

### 📱 用户体验
- **响应式布局**：自适应横屏/竖屏显示
- **多平台支持**：Android、iOS、Web、Windows、macOS、Linux
- **沉浸式界面**：全屏显示，画中画小窗，直观的操作界面

## 🚀 快速开始

### 前提条件
1. **Flutter SDK**：确保已安装Flutter 3.10.8或更高版本
2. **ROS环境**：目标机器人需要运行ROS 1 (Melodic或Noetic)
3. **网络连接**：移动设备与机器人在同一局域网

### 安装步骤

1. **克隆项目**
   ```bash
   git clone <repository-url>
   cd ros_viewer
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **运行应用**
   ```bash
   # Android
   flutter run -d android
   
   # iOS
   flutter run -d ios
   
   # Web
   flutter run -d chrome
   
   # Desktop
   flutter run -d windows  # 或 -d macos, -d linux
   ```

### 机器人端配置

确保机器人运行以下ROS节点：

1. **ROS Master**：默认运行在11311端口
2. **rosbridge_server**：运行在9090端口用于WebSocket通信
   ```bash
   roslaunch rosbridge_server rosbridge_websocket.launch
   ```

3. **摄像头流**：运行MJPG流媒体服务器
   ```bash
   rosrun mjpeg_server mjpeg_server _port:=8080
   ```

4. **SLAM节点**：运行gmapping或cartographer等SLAM算法
   ```bash
   roslaunch turtlebot3_slam turtlebot3_slam.launch
   ```

## 📱 使用指南

### 1. 初始设置
1. 打开应用，进入**Settings**页面
2. 配置机器人IP地址（如：`192.168.1.100`）
3. 配置SSH用户名和密码（可选）
4. 点击**SSH连接**和**ROS连接**按钮建立连接

### 2. 主控制面板
- **Control页面**：显示SLAM地图和摄像头流
  - 点击画中画小窗切换主视图
  - 使用底部虚拟摇杆控制机器人移动
  - 点击右上角按钮切换横屏/竖屏

- **SSH Term页面**：访问机器人终端
  - 执行ROS启动命令
  - 查看系统状态
  - 调试机器人软件

### 3. 控制功能
- **虚拟摇杆**：拖动摇杆控制机器人移动方向
- **速度控制**：摇杆距离中心越远，速度越快
- **急停**：松开摇杆或点击中心位置停止机器人

## 🏗️ 项目结构

```
ros_viewer/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app_navigator.dart           # 底部导航
│   ├── main_dashboard.dart          # 主控制面板
│   ├── settings_view.dart           # 设置页面
│   ├── ssh_terminal_view.dart       # SSH终端页面
│   ├── components/                  # UI组件
│   │   ├── camera_view.dart         # 摄像头视图
│   │   ├── slam_map_view.dart       # SLAM地图视图
│   │   ├── native_joystick_view.dart # 虚拟摇杆
│   │   └── joystick_view.dart       # 传统摇杆视图
│   └── services/                    # 业务逻辑
│       ├── ros_service.dart         # ROS通信服务
│       ├── ssh_service.dart         # SSH连接服务
│       ├── robot_provider.dart      # 状态管理
│       ├── storage_service.dart     # 本地存储
│       └── logger_service.dart      # 日志服务
├── pubspec.yaml                     # 依赖配置
└── README.md                        # 本文档
```

## 🔌 技术栈

### 核心依赖
- **Flutter**：跨平台UI框架
- **Provider**：状态管理
- **dartssh2**：SSH客户端
- **xml_rpc**：ROS XML-RPC通信
- **web_socket_channel**：ROS WebSocket通信
- **flutter_mjpeg**：摄像头流媒体
- **xterm**：终端模拟器
- **shared_preferences**：本地存储

### ROS协议支持
- **XML-RPC**：11311端口，用于ROS Master通信
- **WebSocket**：9090端口，用于实时数据流
- **Topic订阅**：`/scan`、`/map`、`/cmd_vel`
- **消息类型**：`sensor_msgs/LaserScan`、`nav_msgs/OccupancyGrid`、`geometry_msgs/Twist`

## ⚙️ 配置说明

### 机器人IP配置
应用会自动保存上次连接的机器人IP地址，支持以下格式：
- `192.168.1.100`
- `robot.local` (mDNS)
- `10.0.0.5`

### SSH配置（可选）
如果需要通过SSH启动ROS节点，需要配置：
- SSH用户名（默认：`pi` 或 `ubuntu`）
- SSH密码
- 端口号（默认：22）

### 摄像头流配置
默认使用以下配置：
- 端口：8080
- Topic：`/usb_cam/image_raw`
- 协议：MJPG流媒体

## 🐛 故障排除

### 常见问题

1. **ROS连接失败**
   - 检查机器人IP是否正确
   - 确认rosbridge_server正在运行：`rosnode list | grep rosbridge`
   - 检查防火墙设置：`sudo ufw allow 9090`

2. **摄像头流无法显示**
   - 确认MJPG流媒体服务器正在运行
   - 检查摄像头Topic是否正确
   - 尝试在浏览器中访问：`http://<robot-ip>:8080/stream?topic=/usb_cam/image_raw`

3. **SSH连接失败**
   - 确认SSH服务已启用：`sudo systemctl status ssh`
   - 检查用户名和密码
   - 确认网络可达性

4. **虚拟摇杆无响应**
   - 检查ROS连接状态
   - 确认`/cmd_vel` Topic已正确发布
   - 检查机器人底盘控制器是否运行

### 日志查看
应用内置日志系统，所有连接状态和错误信息都会显示在Settings页面的日志区域。

## 📄 许可证

本项目采用MIT许可证。详见LICENSE文件。

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📞 支持与反馈

如有问题或建议，请：
1. 查看[Issues](https://github.com/your-repo/issues)页面
2. 提交新的Issue
3. 或通过邮件联系维护者

---

**提示**：首次使用建议先在Settings页面完成所有连接测试，确保ROS和SSH连接正常后再进入Control页面进行操作。