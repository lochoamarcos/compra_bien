import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Helper class to manage OTA update logs
class OTALogger {
  static const String _logFileName = 'ota_update_log.txt';
  
  /// Appends a log entry with timestamp
  static Future<void> log(String message) async {
    try {
      final file = await _getLogFile();
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString(
        '[$timestamp] $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      print('Error writing OTA log: $e');
    }
  }

  /// Reads the entire log file as a string
  static Future<String?> readLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      print('Error reading OTA log: $e');
      return null;
    }
  }

  /// Clears the log file
  static Future<void> clearLogs() async {
    try {
      final file = await _getLogFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing OTA log: $e');
    }
  }

  static Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_logFileName');
  }
}
