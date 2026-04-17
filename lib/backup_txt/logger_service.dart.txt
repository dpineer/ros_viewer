import 'package:flutter/material.dart';

class LoggerService extends ChangeNotifier {
  final List<String> _logs = [];
  List<String> get logs => _logs;

  void info(String message) {
    _logs.add('[INFO] ${DateTime.now().toString().substring(11, 19)} - $message');
    notifyListeners();
  }

  void error(String message) {
    _logs.add('[ERROR] ${DateTime.now().toString().substring(11, 19)} - $message');
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}