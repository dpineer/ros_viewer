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