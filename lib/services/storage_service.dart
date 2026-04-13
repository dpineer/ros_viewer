import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService extends ChangeNotifier {
  static const String _keyIp = 'robot_ip';
  static const String _keySshUser = 'ssh_user';
  static const String _keySshPass = 'ssh_pass';

  late SharedPreferences _prefs;

  // 初始化服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  // IP地址存取
  Future<void> saveRobotIp(String ip) async {
    await _prefs.setString(_keyIp, ip);
    notifyListeners();
  }
  
  String? getRobotIp() => _prefs.getString(_keyIp);

  // SSH凭证存取 (明文存储示例，生产环境建议接入flutter_secure_storage)
  Future<void> saveSshCredentials(String user, String pass) async {
    await _prefs.setString(_keySshUser, user);
    await _prefs.setString(_keySshPass, pass);
    notifyListeners();
  }
  
  Map<String, String>? getSshCredentials() {
    final user = _prefs.getString(_keySshUser);
    final pass = _prefs.getString(_keySshPass);
    if (user != null && pass != null) {
      return {'user': user, 'pass': pass};
    }
    return null;
  }
}
