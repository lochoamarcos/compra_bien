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

    // 3. Metadata (Simplified)
    final deviceInfo = await _getDeviceInfo();
    final userId = await getUniqueUserId(); // To prevent double-voting

    // 4. Insert to Supabase
    try {
      await Supabase.instance.client.from(_reportsTable).insert({
        'ean': ean,
        'market': market,
        'suggested_price': suggestedPrice,
        'suggested_offer': suggestedOffer,
        'user_id': userId,
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

  static Future<String> getUniqueUserId() async {
     final prefs = await SharedPreferences.getInstance();
     String? id = prefs.getString('supabase_user_id');
     if (id == null) {
        id = DateTime.now().millisecondsSinceEpoch.toString() + "_" + (Platform.isAndroid ? 'and' : 'ios'); 
        await prefs.setString('supabase_user_id', id);
     }
     return id;
  }

  /// Uploads an image to Supabase Storage and returns the Public URL
  static Future<String?> uploadImage(File imageFile, String fileName) async {
     try {
        final String path = 'reports/$fileName';
        await Supabase.instance.client.storage
            .from('product-reports')
            .upload(path, imageFile);

        final String publicUrl = Supabase.instance.client.storage
            .from('product-reports')
            .getPublicUrl(path);

        return publicUrl;
     } catch (e) {
        print('Error uploading image to Supabase: $e');
        return null;
     }
  }

  /// Fetches pending reports from other users for this EAN
  /// (To show in Social Voting UI)
  static Future<List<Map<String, dynamic>>> fetchPendingReports(String ean) async {
     try {
        final userId = await getUniqueUserId();
        final response = await Supabase.instance.client
            .from('pending_voted_reports') 
            .select()
            .eq('ean', ean)
            .neq('user_id', userId); // Don't show my own reports to me

        return List<Map<String, dynamic>>.from(response);
     } catch (e) {
        print('Error fetching pending reports: $e');
        return [];
     }
  }

  /// Votes for a report
  static Future<bool> voteReport(String reportId, bool isUpvote) async {
     try {
        await Supabase.instance.client.rpc('vote_report', params: {
           'report_id': reportId,
           'is_upvote': isUpvote
        });
        return true;
     } catch (e) {
        print('Error voting for report: $e');
        return false;
     }
  }
}
