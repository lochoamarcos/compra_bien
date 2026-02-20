
import 'package:supabase/supabase.dart';

Future<void> main() async {
  print('\n--- Verifying Supabase Data API Access ---');

  // Hardcoded keys from AppConfig to ensure standalone execution
  const supabaseUrl = 'https://wqxghiwfudhzdiyyyick.supabase.co';
  const supabaseKey = 'sb_publishable_Dz3a3QTRxUYYvXBWRhspXg_iR7EVhfS';

  final client = SupabaseClient(supabaseUrl, supabaseKey);

  // 1. Test FEEDBACK table
  try {
    print('\n[1/2] Fetching "feedback" table...');
    final feedback = await client
        .from('feedback')
        .select()
        .limit(3)
        .order('created_at', ascending: false);
    
    print('  ✅ Success. Found ${feedback.length} rows.');
    for (var row in feedback) {
       // Safe access
       final msg = row['message']?.toString() ?? 'No message';
       final shortMsg = msg.length > 30 ? msg.substring(0, 30) + '...' : msg;
       print('    - ID: ${row['id']}, Msg: $shortMsg');
    }
  } catch (e) {
    print('  ❌ Error fetching feedback: $e');
  }

  // 2. Test REPORTS table
  try {
    print('\n[2/2] Fetching "reports" table...');
    final reports = await client
        .from('reports')
        .select()
        .limit(3)
        .order('created_at', ascending: false);
    
    print('  ✅ Success. Found ${reports.length} rows.');
     for (var row in reports) {
       print('    - ID: ${row['id']}, EAN: ${row['ean']}, Market: ${row['market']}');
    }
  } catch (e) {
    print('  ❌ Error fetching reports: $e');
  }
  
  print('\n--- End Verification ---');
}
