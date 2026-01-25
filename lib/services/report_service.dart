import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ota_logger.dart';
import '../utils/app_config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';


class PendingReport {
  final String category;
  final String message;
  final String userName; // Added userName
  final DateTime timestamp;

  PendingReport({
    required this.category,
    required this.message,
    this.userName = '', // Default to empty
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'message': message,
    'userName': userName,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PendingReport.fromJson(Map<String, dynamic> json) => PendingReport(
    category: json['category'],
    message: json['message'],
    userName: json['userName'] ?? '',
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class ReportService {
  static const String _queueKey = 'pending_reports_queue';
  static const String _baseUrl = AppConfig.reportsUrl;

  // Horario: 11:30 AM (11:30) hasta 12:00 AM (00:00 del día siguiente)
  static bool get isServerOnline {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 11, 30);
    final end = DateTime(now.year, now.month, now.day, 18, 0); // Aligned to 18:00
    
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Checks if server is reachable (Ping)
  static Future<bool> checkServerStatus() async {
      try {
          final res = await http.get(Uri.parse('$_baseUrl/health')).timeout(const Duration(seconds: 3));
          return res.statusCode == 200;
      } catch (e) {
          return false; 
      }
  }

  /// Tries to submit a report.
  /// If fails 3 times or outside hours, it gets queued.
  static Future<bool> submitReport(String category, String message, {String userName = ''}) async {
    // 0. Gather Metadata (IP & Device Info)
    String metadata = await _gatherMetadata();
    String fullMessage = "$message\n\n[METADATA]\n$metadata";

    // 1. Always attempt submission first (even if potentially outside hours)
    // We use a single retry here for quick UI feedback
    bool success = await _attemptWithRetries(category, fullMessage, userName, retries: 1);
    
    if (success) {
      return true;
    }

    // 2. If it fails, save to queue
    print('No se pudo enviar al instante. Guardando en cola.');
    await _addToQueue(category, message, userName);
    return false;
  }

  static Future<bool> _attemptWithRetries(String category, String message, String userName, {int retries = 3}) async {
    // Read OTA logs if they exist (for bug reports)
    String? otaLogs;
    // Read OTA logs if they exist (attach to ANY report for better debugging context)
    otaLogs = await OTALogger.readLogs();

    for (int i = 0; i < retries; i++) {
        try {
            final body = {
                'categoria': category, 
                'mensaje': message, 
                'usuario': userName, // Sending user name
                'timestamp': DateTime.now().toIso8601String(),
                'otaLogs': otaLogs ?? '', // Always send otaLogs, even if empty string
            };

            final response = await http.post(
                Uri.parse(_baseUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(body),
            ).timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
                 return true;
            }
        } catch (e) {
             print('Intento ${i + 1} fallido: $e');
        }
      
        if (i < retries - 1) {
          await Future.delayed(const Duration(seconds: 2)); // Espera entre reintentos
        }
    }
    return false;
  }

  static Future<void> _addToQueue(String category, String message, String userName) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    final report = PendingReport(
      category: category,
      message: message,
      userName: userName,
      timestamp: DateTime.now(),
    );
    
    queue.add(jsonEncode(report.toJson()));
    await prefs.setStringList(_queueKey, queue);
  }

  static bool _isProcessing = false;

  /// Attempts to send all queued reports. 
  /// Usually called on App start or Resumed.
  static Future<void> processQueue() async {
    if (_isProcessing) {
      print('Ya se está procesando la cola. Omitiendo.');
      return;
    }
    
    if (!isServerOnline) return;

    _isProcessing = true; // Bloqueo anti-bucle / concurrencia

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue = prefs.getStringList(_queueKey) ?? [];
      if (queue.isEmpty) return;

      print('Procesando cola de reportes (${queue.length} pendientes)...');
      List<String> remaining = [];
      bool anySuccess = false;

      for (String item in queue) {
        final report = PendingReport.fromJson(jsonDecode(item));
        // Intentamos enviar (1 solo intento para cada uno al procesar cola para no bloquear mucho tiempo)
        bool success = await _attemptWithRetries(report.category, report.message, report.userName, retries: 1);
        if (!success) {
          remaining.add(item);
        } else {
          anySuccess = true;
        }
      }

      // Solo escribimos si hubo cambios para evitar escrituras innecesarias
      if (anySuccess || remaining.length != queue.length) {
         await prefs.setStringList(_queueKey, remaining);
      }
      print('Proceso de cola terminado. Quedan ${remaining.length} pendientes.');

    } catch (e) {
      print('Error procesando cola: $e');
    } finally {
      _isProcessing = false; // Liberar bloqueo
    }
  }
  static Future<String> _gatherMetadata() async {
    StringBuffer sb = StringBuffer();
    
    // IP Address
    try {
       final ipRes = await http.get(Uri.parse('https://api.ipify.org')).timeout(const Duration(seconds: 2));
       if (ipRes.statusCode == 200) sb.writeln("IP: ${ipRes.body}");
    } catch (_) {
       sb.writeln("IP: Unknown (Unavailable)");
    }

    // Device Info
    try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          sb.writeln("Device: ${androidInfo.manufacturer} ${androidInfo.model}");
          sb.writeln("OS: Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})");
          sb.writeln("ID: ${androidInfo.id}");
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          sb.writeln("Device: ${iosInfo.utsname.machine}");
          sb.writeln("OS: iOS ${iosInfo.systemVersion}");
        }
    } catch (e) {
        sb.writeln("Device Info: Unavailable ($e)");
    }
    
    return sb.toString();
  }
}
