
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/utils/app_config.dart'; // To reuse keys if they are there, or hardcode for test

Future<void> main() async {
  print('--- Testing Supabase "feedback" Connection ---');

  // 1. Initialize Supabase
  // NOTE: If AppConfig keys are private, we might need to paste them here manually for the test script 
  // or ensure AppConfig is importable/valid in this CLI context.
  // Using generic placeholders in comments if AppConfig is not fully static.
  // Assuming AppConfig.supabaseUrl and AppConfig.supabaseAnonKey exist.
  
  try {
     await Supabase.initialize(
       url: AppConfig.supabaseUrl,
       anonKey: AppConfig.supabaseAnonKey,
     );
     print('✅ Supabase Initialized.');

     final client = Supabase.instance.client;

     // 2. Insert Test Row
     final testPayload = {
        'category': 'TEST_CLI',
        'message': 'This is a test message from verification script.',
        'user_id': 'TEST_USER_123',
        'metadata': {'source': 'verification_script'},
        'status': 'open'
     };

     print('Attempting INSERT...');
     await client.from('feedback').insert(testPayload);
     print('✅ INSERT success.');

     // 3. Read Verification
     print('Attempting SELECT (fetching last 1)...');
     final response = await client.from('feedback').select().order('created_at', ascending: false).limit(1);
     
     if (response.isNotEmpty) {
        print('✅ SELECT success. Last row:');
        print(response.first);
     } else {
        print('⚠️ SELECT returned empty list (Check RLS policies if insert worked but select failed).');
     }

  } catch (e) {
     print('❌ ERROR: $e');
  }
}
