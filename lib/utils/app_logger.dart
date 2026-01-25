
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);
  
  void log(String message) {
     final timestamp = DateTime.now().toIso8601String().substring(11, 19);
     _logs.add('[$timestamp] $message');
     // Keep last 100 logs
     if (_logs.length > 100) {
        _logs.removeAt(0);
     }
     print(message); // Also print to console
  }
  
  void clear() {
      _logs.clear();
  }
}
