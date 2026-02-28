import 'package:flutter/foundation.dart';

class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://wqxghiwfudhzdiyyyick.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_Dz3a3QTRxUYYvXBWRhspXg_iR7EVhfS'; // <--- ¡Asegurate de poner tu Key real aquí!

  // Supabase Storage URLs for Serverless Updates (Old)
  // static const String updatesUrl = 'https://wqxghiwfudhzdiyyyick.storage.supabase.co/storage/v1/object/public/app-releases/app-arm64-v8a-release.apk';
  // static const String updatesInfoUrl = 'https://wqxghiwfudhzdiyyyick.storage.supabase.co/storage/v1/object/public/app-releases/version.json';

  // New Vercel Redirector (Points to GitHub dynamically)
  static const String updatesUrl = '$upzBackendUrl/projects/comprabien/updates/latest-apk.js';
  static const String updatesInfoUrl = '$upzBackendUrl/projects/comprabien/updates/version.js';

  // UPZ Backend (Vercel)
  static const String upzBackendUrl = 'https://upzbackend.vercel.app'; 
  static const String nsfwApiKey = 'upz_nsfw_prod_2024_x92k!';

  // Vercel Internal CORS Proxies (Defined in vercel.json)
  static const String carrefourProxy = '/api/super/carrefour';
  static const String veaProxy = '/api/super/vea';
  static const String monarcaProxy = '/api/super/monarca';
  static const String coopeProxy = '/api/super/coope';

  /// Wraps an API request with the correct CORS proxy depending on the environment.
  static String getProxiedUrl(String originalUrl, String rewritePrefix) {
    if (!kIsWeb) return originalUrl;
    
    // Always use the UPZ backend proxy to bypass WAFs and CORS.
    // Vercel native rewrites forward the browser's Origin and Referer headers
    // which causes supermarkets (Carrefour, La Coope, Vea) to block the requests (404/403).
    final proxied = '$upzBackendUrl/api/proxy?url=${Uri.encodeComponent(originalUrl)}';
    debugPrint('🌐 PROXY (Custom Backend): Using UPZ Backend for $originalUrl');
    return proxied;
  }

  // Legacy/Reference (Deprecated)
  // static const String serverBaseUrl = 'https://yolanda-metapsychological-consentaneously.ngrok-free.dev';
  // static const String reportsUrl = '$serverBaseUrl/api/public/reports/compraBien';
}
