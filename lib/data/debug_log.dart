import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum LogLevel { info, warn, error, nfc }

class LogEntry {
  final DateTime ts;
  final LogLevel level;
  final String message;
  LogEntry(this.ts, this.level, this.message);

  String get timeStr => DateFormat('HH:mm:ss.SSS').format(ts);

  String get levelTag => switch (level) {
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERR ',
        LogLevel.nfc => 'NFC ',
      };

  String get formatted => '[$timeStr][$levelTag] $message';
}

class DebugLog extends ChangeNotifier {
  static final DebugLog instance = DebugLog._();
  DebugLog._();

  final List<LogEntry> _entries = [];
  static const int _maxEntries = 500;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void _add(LogLevel level, String message) {
    _entries.insert(0, LogEntry(DateTime.now(), level, message));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }
    notifyListeners();
    if (kDebugMode) debugPrint('[$level] $message');
  }

  void info(String msg) => _add(LogLevel.info, msg);
  void warn(String msg) => _add(LogLevel.warn, msg);
  void error(String msg) => _add(LogLevel.error, msg);
  void nfc(String msg) => _add(LogLevel.nfc, msg);

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String dump() => _entries.reversed.map((e) => e.formatted).join('\n');
}