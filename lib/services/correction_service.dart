import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:async'; // Added for TimeoutException
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/app_config.dart';

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
          .select()
          .eq('project_id', 'comprabien'); // NEW: Multi-tenancy

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
    String? imageUrl, // NEW: Link to the uploaded image
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
        'image_url': imageUrl, // NEW: Store in DB
        'user_id': userId,
        'metadata': {
            'device': deviceInfo,
            'original_name': originalName ?? 'unknown',
            'platform': kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : 'ios'),
        },
        'project_id': 'comprabien', // NEW: Multi-tenancy
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
        if (kIsWeb) return "Web Browser";
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
        String plat = kIsWeb ? 'web' : (Platform.isAndroid ? 'and' : 'ios');
        id = DateTime.now().millisecondsSinceEpoch.toString() + "_" + plat; 
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

  /// Checks image safety via Vercel Backend (NSFWJS)
  /// Returns a map with 'isSafe' (bool) and 'status' (String)
  static Future<Map<String, dynamic>> checkNsfw(String imageUrl) async {
      try {
          final response = await http.post(
              Uri.parse('${AppConfig.upzBackendUrl}/api/helpers/image/nsfw'),
              headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${AppConfig.nsfwApiKey}',
              },
              body: jsonEncode({'imageUrl': imageUrl}),
          ).timeout(const Duration(seconds: 8)); // 8s timeout as requested for "revision" fallback

          if (response.statusCode == 200) {
              final List<dynamic> predictions = jsonDecode(response.body);
              
              // Search for 'Porn', 'Hentai', 'Sexy' categories
              // nsfwjs default categories are: 'Drawing', 'Hentai', 'Neutral', 'Porn', 'Sexy'
              bool isSafe = true;
              double riskScore = 0.0;

              for (var p in predictions) {
                  final className = p['className'] as String;
                  final probability = p['probability'] as double;

                  if (['Porn', 'Hentai'].contains(className) && probability > 0.3) {
                      isSafe = false;
                      riskScore = probability;
                      break;
                  }
                  if (className == 'Sexy' && probability > 0.6) {
                      isSafe = false;
                      riskScore = probability;
                      break;
                  }
              }

              return {
                  'isSafe': isSafe,
                  'status': isSafe ? 'safe' : 'NSFW detected ($riskScore)',
              };
          } else if (response.statusCode == 401) {
              return {'isSafe': true, 'status': 'auth_error_skipped'}; // Safety fallback: if API key fails, don't block user but log it
          }
          
          return {'isSafe': true, 'status': 'error_skipped'};
      } on TimeoutException {
          return {'isSafe': true, 'status': 'timeout_pending_review'};
      } catch (e) {
          print('NSFW Check Error: $e');
          return {'isSafe': true, 'status': 'exception_skipped'};
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
