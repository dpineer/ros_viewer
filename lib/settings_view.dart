import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/robot_provider.dart';
import 'services/logger_service.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RobotStateProvider>();
    final logger = context.watch<LoggerService>();

    return Scaffold(
      appBar: AppBar(title: const Text('System Configuration')),
      body: Column(
        children: [
          // 参数配置表单
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                     TextFormField(
                       initialValue: provider.targetIp,
                       decoration: const InputDecoration(labelText: 'Robot IP Address'),
                       onChanged: (val) => provider.saveTargetIp(val),
                     ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: provider.sshUser,
                            decoration: const InputDecoration(labelText: 'SSH User'),
                            onChanged: (val) {
                              provider.sshUser = val;
                              provider.saveSshCredentials(val, provider.sshPass);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: provider.sshPass,
                            decoration: const InputDecoration(labelText: 'SSH Password'),
                            obscureText: true,
                            onChanged: (val) {
                              provider.sshPass = val;
                              provider.saveSshCredentials(provider.sshUser, val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.security),
                          label: Text(provider.isSshConnected ? 'SSH 建立' : 'SSH连接'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: provider.isSshConnected ? Colors.green : Colors.blue,
                          ),
                          onPressed: () => provider.connectSsh(),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.hub),
                          label: Text(provider.isRosConnected ? 'ROS 建立连接' : 'ROS连接'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: provider.isRosConnected ? Colors.green : Colors.blue,
                          ),
                          onPressed: () => provider.connectRos(),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // ================= 新增：一键环境部署控制台 =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              color: Colors.blueGrey[50],
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.rocket_launch, color: Colors.blue),
                    title: Text('Environment Deployment Console', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('1. 配置下位机环境 (Inject to Robot)'),
                    subtitle: const Text('自动写入 lidar_follower.py 并拉取 explore_lite'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.install_desktop, size: 18),
                      label: const Text('一键注入'),
                      onPressed: provider.isSshConnected ? () => provider.injectRobotEnvironment() : null,
                    ),
                  ),
                  ListTile(
                    title: const Text('2. 启动上位机 AI 引擎 (Compile Host C++)'),
                    subtitle: const Text('自动编译本地 C++ 代码并挂载 YOLO 算力'),
                    trailing: ElevatedButton.icon(
                      icon: const Icon(Icons.memory, size: 18),
                      label: const Text('编译执行'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      onPressed: () => provider.compileAndRunHostAI(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 系统日志输出
          const Divider(),
          const Text('System Logs', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Container(
              color: Colors.black87,
              margin: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: logger.logs.length,
                itemBuilder: (context, index) {
                  final log = logger.logs[index];
                  final isError = log.contains('[ERROR]');
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: isError ? Colors.redAccent : Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace'
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}