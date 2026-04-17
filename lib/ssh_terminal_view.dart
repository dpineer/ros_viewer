import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart'; // 包含Terminal和TerminalView
import 'services/robot_provider.dart';
import 'services/ssh_service.dart';

class SshTerminalView extends StatefulWidget {
  const SshTerminalView({Key? key}) : super(key: key);

  @override
  State<SshTerminalView> createState() => _SshTerminalViewState();
}

class _SshTerminalViewState extends State<SshTerminalView> {
  final List<SshSessionManager> _sessions =[];
  final TextEditingController _cmdController = TextEditingController();

  final Map<String, String> _quickCommands = {
    '1. 核心启动': 'source /opt/ros/kinetic/setup.bash && roscore',
    '2. 驱动模块': 'source /home/xtark/ros_ws/devel/setup.bash && roslaunch xtark_driver xtark_driver.launch',
    '3. SLAM建图': 'source /home/xtark/ros_ws/devel/setup.bash && roslaunch xtark_nav xtark_slam.launch',
    '4. 导航模式': 'source /home/xtark/ros_ws/devel/setup.bash && roslaunch xtark_nav xtark_nav.launch',
    '5. 自动补图': 'source /home/xtark/ros_ws/devel/setup.bash && roslaunch explore_lite explore.launch',
    '6. 雷达跟随': 'source /home/xtark/ros_ws/devel/setup.bash && python /home/xtark/ros_ws/lidar_follower.py',
  };

  Future<void> _addTerminal() async {
    final provider = context.read<RobotStateProvider>();
    if (!provider.isSshConnected) return;
    try {
      final session = await provider.sshService.createShell();
      setState(() => _sessions.add(session));
    } catch (e) {
      provider.logger.error('Failed to create terminal shell');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RobotStateProvider>();
    if (!provider.isSshConnected) {
      return const Center(child: Text('SSH Not Connected. Go to Settings.', style: TextStyle(color: Colors.red)));
    }

    return DefaultTabController(
      length: _sessions.isEmpty ? 1 : _sessions.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SSH Terminals'),
          actions:[
            IconButton(icon: const Icon(Icons.add), onPressed: _addTerminal),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _sessions.isEmpty 
              ? [const Tab(text: 'No Sessions')] 
              : List.generate(_sessions.length, (i) => Tab(text: 'Term ${i + 1}')),
          ),
        ),
        body: _sessions.isEmpty
            ? const Center(child: Text('Click + to open a new terminal session'))
            : TabBarView(
                children: _sessions.map((s) => _buildTerminalInstance(s)).toList(),
              ),
      ),
    );
  }

  Widget _buildTerminalInstance(SshSessionManager session) {
    return Column(
      children:[
        // 上方：水平滑动的快捷指令区
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _quickCommands.entries.map((e) => Padding(
              padding: const EdgeInsets.all(4.0),
              child: ElevatedButton(
                onPressed: () => session.writeCommand(e.value),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                child: Text(e.key),
              ),
            )).toList(),
          ),
        ),
        
        // 中间：全功能硬件抽象终端视图 (自动处理颜色高亮、历史滚动)
        Expanded(
          child: Container(
            color: Colors.black, // 强制给深色底，确保ROS终端的浅色字体可见
            child: SafeArea(
              child: TerminalView(
                session.terminal,
                readOnly: false, // 允许用户点击视图唤出虚拟键盘直接输入
              ),
            ),
          ),
        ),
        
        // 下方：防遮挡的手动输入交互栏
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children:[
              Expanded(
                child: TextField(
                  controller: _cmdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Enter command...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (val) {
                    session.writeCommand(val);
                    _cmdController.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                child: const Icon(Icons.send),
                onPressed: () {
                  if (_cmdController.text.isNotEmpty) {
                    session.writeCommand(_cmdController.text);
                    _cmdController.clear();
                  }
                },
              )
            ],
          ),
        )
      ],
    );
  }
}