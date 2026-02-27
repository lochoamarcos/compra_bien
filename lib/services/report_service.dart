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
  final String userName; 
  final String? productName; // NEW
  final DateTime timestamp;

  PendingReport({
    required this.category,
    required this.message,
    this.userName = '',
    this.productName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'message': message,
    'userName': userName,
    'productName': productName,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PendingReport.fromJson(Map<String, dynamic> json) => PendingReport(
    category: json['category'],
    message: json['message'],
    userName: json['userName'] ?? '',
    productName: json['productName'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class ReportService {
  static const String _queueKey = 'pending_reports_queue';
  // static const String _baseUrl = AppConfig.reportsUrl; // Deprecated for Supabase

  // Horario: 11:30 AM (11:30) hasta 12:00 AM (00:00 del dÃ­a siguiente)
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
  static Future<bool> submitReport(String category, String message, {String userName = '', String? productName}) async {
    // 0. Gather Metadata (IP & Device Info)
    String metadata = await _gatherMetadata();
    String fullMessage = "$message\n\n[METADATA]\n$metadata";

    // 1. Always attempt submission first
    bool success = await _attemptWithRetries(category, fullMessage, userName, productName: productName, retries: 1);
    
    if (success) {
      return true;
    }

    // 2. If it fails, save to queue
    print('No se pudo enviar al instante. Guardando en cola.');
    await _addToQueue(category, message, userName, productName: productName);
    return false;
  }

  static Future<bool> _attemptWithRetries(String category, String message, String userName, {String? productName, int retries = 3}) async {
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
            final insertData = {
                'category': category,
                'message': message,
                'user_id': uid,
                'metadata': {
                    'username': userName,
                    'device': deviceInfo,
                    'ota_logs': otaLogs ?? '', 
                    'original_name': productName ?? 'unknown',
                    'timestamp': DateTime.now().toIso8601String()
                },
                'status': 'open',
                'project_id': 'comprabien',
            };

            print('DEBUG: Enviando a feedback -> $insertData');
            await Supabase.instance.client.from('feedback').insert(insertData);

            return true; 

        } catch (e) {
             print('CRITICAL: Fallo al insertar en FEEDBACK -> $e');
        }
      
        if (i < retries - 1) {
          await Future.delayed(const Duration(seconds: 2)); // Espera entre reintentos
        }
    }
    return false;
  }

  static Future<void> _addToQueue(String category, String message, String userName, {String? productName}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    final report = PendingReport(
      category: category,
      message: message,
      userName: userName,
      productName: productName,
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
      print('Ya se estÃ¡ procesando la cola. Omitiendo.');
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
        // Intentamos enviar
        bool success = await _attemptWithRetries(report.category, report.message, report.userName, productName: report.productName, retries: 1);
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
        if (!kIsWeb) {
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
        } else {
          sb.writeln("Platform: Web");
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

  static Future<List<Map<String, dynamic>>> fetchMyReports() async {
      final uid = await CorrectionService.getUniqueUserId();
      return fetchReports(specificUserId: uid);
  }

  static Future<List<Map<String, dynamic>>> fetchReports({String? specificUserId}) async {
      try {
        // 1. Fetch Product Corrections (Prices/Offers)
        var correctionsQuery = Supabase.instance.client
            .from('reports') 
            .select()
            .eq('project_id', 'comprabien');

        if (specificUserId != null) {
            correctionsQuery = correctionsQuery.eq('user_id', specificUserId);
        }

        final correctionsResponse = await correctionsQuery
            .order('created_at', ascending: false) // Restoring order for latest results
            .limit(50);


        List<Map<String, dynamic>> combined = [];

        // Map Corrections
        for (var item in correctionsResponse) {
           final market = item['market'] ?? 'Unknown';
           final ean = item['ean'] ?? 'Unknown';
           final price = item['suggested_price'];
           final offer = item['suggested_offer'];
           
           String productName = 'Producto';
           if (item['metadata'] is Map) {
              productName = item['metadata']['original_name'] ?? 'Producto';
           }

           String msg = "Ajuste en $market.";
           if (price != null) msg += " Nuevo precio: \$$price.";
           if (offer != null) msg += " Oferta: $offer.";

           // NEW: Extra note from dedicated column OR metadata
           final String? note = item['message'] ?? (item['metadata'] is Map ? item['metadata']['message'] : null);
           if (note != null && note.isNotEmpty) {
              msg += "\nNota: $note";
           }

           combined.add({
             'type': 'correction',
             'category': 'Corrección de Precio',
             'product_name': productName,
             'message': msg,
             'user': (item['metadata'] is Map ? item['metadata']['username'] : null) ?? (specificUserId != null ? 'Yo' : 'Anónimo'),
             'id': item['id'].toString(),
             'timestamp': item['created_at'] ?? item['timestamp'] ?? item['metadata']?['timestamp'],
             'image_url': item['image_url'],
             'market': market,
             'ean': ean,
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
