import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

class SshSessionManager {
  final SSHClient client;
  final SSHSession session;
  final Terminal terminal;

  SshSessionManager(this.client, this.session) 
      // 开启5000行历史记录缓冲，防止长时间运行导致内存溢出
      : terminal = Terminal(maxLines: 5000) {
    
    // 监听远程主机的标准输出流，解码并写入到本地终端引擎
    session.stdout.listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });
    
    // 监听错误输出流
    session.stderr.listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // 监听本地终端引擎的键盘输入事件，发送回远程主机
    terminal.onOutput = (output) {
      session.write(utf8.encode(output));
    };
  }

  // 供UI层快捷按钮与输入框调用的指令注入接口
  void writeCommand(String command) {
    // 模拟回车键以触发Shell指令执行
    session.write(utf8.encode('$command\n'));
  }

  void close() {
    session.close();
  }
}

class SshService {
  SSHClient? _client;
  final List<SshSessionManager> activeSessions = [];
  bool get isConnected => _client != null && !_client!.isClosed;
  SSHClient? get client => _client;

  Future<bool> connect(String host, String username, String password) async {
    try {
      final socket = await SSHSocket.connect(host, 22, timeout: const Duration(seconds: 5));
      _client = SSHClient(socket, username: username, onPasswordRequest: () => password);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<SshSessionManager> createShell() async {
    if (!isConnected) throw Exception('SSH_DISCONNECTED');
    // 创建包含伪终端(PTY)的Shell会话，确保远程Bash输出ANSI高亮
    final session = await _client!.shell();
    final manager = SshSessionManager(_client!, session);
    activeSessions.add(manager);
    return manager;
  }

  void disconnect() {
    for (var session in activeSessions) {
      session.close();
    }
    activeSessions.clear();
    _client?.close();
    _client = null;
  }
}