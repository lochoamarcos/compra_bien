import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class CorrectionService {
  static const String _reportsTable = 'reports';
  static const String _correctionsView = 'active_corrections';
  static const String _lastReportKey = 'last_report_timestamp';
  static const Duration _cooldown = Duration(minutes: 2); // Anti-spam cooldown

  /// Initializes Supabase (call in main.dart)
  static Future<void> initialize({required String url, required String anonKey}) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// Fetches approved corrections (consensus reached)
  static Future<Map<String, dynamic>> fetchCorrections() async {
    try {
      final response = await Supabase.instance.client
          .from(_correctionsView)
          .select();

      final corrections = <String, dynamic>{};
      
      // Convert list to a Map keyed by composite ID or just iterate easily
      // Structure: { "EAN_Market": { ...details... } }
      for (var row in response) {
         final key = "${row['ean']}_${row['market']}";
         corrections[key] = row;
      }
      return corrections;

    } catch (e) {
      print('Error fetching corrections: $e');
      return {};
    }
  }

  /// Submits a correction report with Anti-Spam check
  static Future<bool> submitReport({
    required String ean,
    required String market,
    double? suggestedPrice,
    String? suggestedOffer,
    String? originalName, // Just for metadata
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Anti-Spam Check (Local)
    final lastTime = prefs.getInt(_lastReportKey);
    if (lastTime != null) {
       final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
       if (diff < _cooldown.inMilliseconds) {
          print("Spam check: PLEASE WAIT");
          return false; // Too fast
       }
    }

    // 2. Metadata (Simplified)
    final deviceInfo = await _getDeviceInfo();
    
    // 3. Insert to Supabase
    try {
      await Supabase.instance.client.from(_reportsTable).insert({
        'ean': ean,
        'market': market,
        'suggested_price': suggestedPrice,
        'suggested_offer': suggestedOffer,
        'metadata': {
            'device': deviceInfo,
            'original_name': originalName ?? 'unknown',
            'platform': Platform.isAndroid ? 'android' : 'ios',
        }
      });

      // Update timestamp on success
      await prefs.setInt(_lastReportKey, DateTime.now().millisecondsSinceEpoch);
      return true;

    } catch (e) {
      print('Error submitting report to Supabase: $e');
      return false;
    }
  }

  static Future<String> _getDeviceInfo() async {
     try {
        final info = DeviceInfoPlugin();
        if (Platform.isAndroid) {
           final android = await info.androidInfo;
           return "${android.brand} ${android.model} (SDK ${android.version.sdkInt})";
        } else if (Platform.isIOS) {
           final ios = await info.iosInfo;
           return "${ios.name} ${ios.systemName}";
        }
        return "Unknown Device";
     } catch (_) {
        return "Unknown";
     }
  }
}
