class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://wqxghiwfudhzdiyyyick.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_Dz3a3QTRxUYYvXBWRhspXg_iR7EVhfS'; // <--- ¡Asegurate de poner tu Key real aquí!

  // Supabase Storage URLs for Serverless Updates (Old)
  // static const String updatesUrl = 'https://wqxghiwfudhzdiyyyick.storage.supabase.co/storage/v1/object/public/app-releases/app-arm64-v8a-release.apk';
  // static const String updatesInfoUrl = 'https://wqxghiwfudhzdiyyyick.storage.supabase.co/storage/v1/object/public/app-releases/version.json';

  // New Vercel Redirector (Points to GitHub dynamically)
  static const String updatesUrl = '$upzBackendUrl/api/updates/latest-apk';
  static const String updatesInfoUrl = '$upzBackendUrl/api/updates/version';

  // UPZ Backend (Vercel)
  static const String upzBackendUrl = 'https://upzbackend.vercel.app'; // <--- Ajustar si usaste otro nombre
  static const String nsfwApiKey = 'upz_nsfw_prod_2024_x92k!';

  // Legacy/Reference (Deprecated)
  // static const String serverBaseUrl = 'https://yolanda-metapsychological-consentaneously.ngrok-free.dev';
  // static const String reportsUrl = '$serverBaseUrl/api/public/reports/compraBien';
}
