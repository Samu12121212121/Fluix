// lib/services/logger.dart

import 'dart:io';

final logger = _Logger();

class _Logger {
  void info(String msg)                          => stdout.writeln('[INFO]  ${_ts()} $msg');
  void warn(String msg)                          => stdout.writeln('[WARN]  ${_ts()} $msg');
  void error(String msg, [StackTrace? st]) {
    stderr.writeln('[ERROR] ${_ts()} $msg');
    if (st != null) stderr.writeln(st);
  }

  String _ts() => DateTime.now().toIso8601String();
}

