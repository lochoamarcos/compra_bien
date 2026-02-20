import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/ota_logger.dart';
import '../utils/app_config.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'correction_service.dart';


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
  // static const String _baseUrl = AppConfig.reportsUrl; // Deprecated for Supabase

  // Horario: 11:30 AM (11:30) hasta 12:00 AM (00:00 del día siguiente)
  static bool get isServerOnline {
    // Supabase is always online (24/7). Legacy schedule removed.
    return true;
  }

  /// Checks if server (Supabase) is reachable 
  /// In this serverless model, we assume generic connectivity.
  /// Ideally, use connectivity_plus, but for now we return true
  /// or check google.com.
  static Future<bool> checkServerStatus() async {
       // Supabase SDK handles offline sync usually, but we can do a simple ping if needed.
       // For now, assume true to allow submitting to queue/sdk.
       return true; 
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

    // Attach User ID to message or metadata? 
    // We can use Supabase Metadata column
    final deviceInfo = await _gatherMetadata();
    final uid = await CorrectionService.getUniqueUserId();

    for (int i = 0; i < retries; i++) {
        try {
            // Supabase Insert to 'feedback' table
            await Supabase.instance.client.from('feedback').insert({
                'category': category,
                'message': message,
                'user_id': uid, // Persistent ID
                'metadata': {
                    'username': userName,
                    'device': deviceInfo,
                    'ota_logs': otaLogs ?? '', 
                    'timestamp': DateTime.now().toIso8601String()
                },
                'status': 'open',
                'project_id': 'comprabien', // NEW: Multi-tenancy
            });

            return true; // Success

        } catch (e) {
             print('Intento ${i + 1} fallido (Supabase): $e');
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
    
    // always online with Supabase
    // if (!isServerOnline) return; 

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
    
    // Attach Persistent Silent ID
    try {
       String uid = await CorrectionService.getUniqueUserId();
       sb.writeln("UID: $uid");
    } catch (_) {}

    return sb.toString();
  }

  static Future<List<Map<String, dynamic>>> fetchCorrectionsRaw() async {
      try {
         final response = await Supabase.instance.client
            .from('reports') // Table defined in CorrectionService
            .select()
            .eq('project_id', 'comprabien')
            .order('created_at', ascending: false)
            .limit(50);
         return List<Map<String, dynamic>>.from(response);
      } catch (e) {
         debugPrint('Error fetching raw corrections: $e');
         return [];
      }
  }

  static Future<List<Map<String, dynamic>>> fetchReports() async {
      try {
        // 1. Fetch General Feedback
        final feedbackResponse = await Supabase.instance.client
            .from('feedback')
            .select()
            .eq('project_id', 'comprabien') // NEW: Multi-tenancy
            .order('timestamp', ascending: false)
            .limit(25);

        // 2. Fetch Product Corrections
        final correctionsResponse = await Supabase.instance.client
            .from('reports') // Table defined in CorrectionService
            .select()
            .eq('project_id', 'comprabien') // NEW: Multi-tenancy
            .order('created_at', ascending: false)
            .limit(25);

        List<Map<String, dynamic>> combined = [];

        // Map Feedback
        for (var item in feedbackResponse) {
           combined.add({
             'type': 'feedback',
             'category': item['category'] ?? 'General',
             'message': item['message'] ?? '',
             'user': (item['metadata'] is Map ? item['metadata']['username'] : null) ?? 'Anónimo',
             'id': item['id'].toString(),
             'timestamp': item['timestamp'],
             'details': item['metadata'],
           });
        }

        // Map Corrections
        for (var item in correctionsResponse) {
           final market = item['market'] ?? 'Unknown';
           final ean = item['ean'] ?? 'Unknown';
           final price = item['suggested_price'];
           final offer = item['suggested_offer'];
           
           String msg = "Corrección de Producto ($ean) en $market.";
           if (price != null) msg += " Precio: \$$price.";
           if (offer != null) msg += " Oferta: $offer.";

           combined.add({
             'type': 'correction',
             'category': 'Corrección de Precio/Prod',
             'message': msg,
             'user': 'Community User', // Corrections typically don't store username in metadata like feedback
             'id': item['id'].toString(),
             'timestamp': item['created_at'], // Supabase default timestamp col
             'details': item,
           });
        }

        // Sort by timestamp descending
        combined.sort((a, b) {
           DateTime tA = DateTime.tryParse(a['timestamp'].toString()) ?? DateTime(1900);
           DateTime tB = DateTime.tryParse(b['timestamp'].toString()) ?? DateTime(1900);
           return tB.compareTo(tA);
        });

        return combined;

      } catch (e) {
        debugPrint('Error fetching reports: $e');
        return [];
      }
  }
}
