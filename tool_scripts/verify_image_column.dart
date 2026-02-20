import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/utils/app_config.dart';

void main() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  final client = Supabase.instance.client;
  
  try {
     // Check columns of 'reports' table
     final response = await client.from('reports').select().limit(1);
     if (response.isNotEmpty) {
        final first = response.first as Map<String, dynamic>;
        print('Columns in reports: ${first.keys.join(", ")}');
        if (first.containsKey('image_url')) {
           print('SUCCESS: image_url column found.');
        } else {
           print('WARNING: image_url column MISSING.');
        }
     } else {
        print('Table reports is empty, cannot check columns easily via select.');
     }
  } catch (e) {
     print('Error checking table: $e');
  }
}
