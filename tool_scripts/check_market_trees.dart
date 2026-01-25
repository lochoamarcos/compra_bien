import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Checking Market Category Trees (Harmonization) ---');

  final markets = {
    'Carrefour': 'https://www.carrefour.com.ar',
    'Monarca': 'https://monarca.com.ar', // Check base URL
    'Vea': 'https://www.vea.com.ar',     // Check base URL
    'Coope': 'https://www.lacoopeencasa.coop' // Unknown tech stack
  };

  for (var entry in markets.entries) {
      final name = entry.key;
      final baseUrl = entry.value;
      print('\nTesting $name...');
      
      // Standard VTEX endpoint
      final vtexUrl = Uri.parse('$baseUrl/api/catalog_system/pub/category/tree/2');
      
      try {
          final res = await http.get(vtexUrl, headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          });
          
          if (res.statusCode == 200) {
              final data = json.decode(res.body);
              if (data is List && data.isNotEmpty) {
                  print('✅ $name is VTEX! Found ${data.length} categories.');
                  print('   Sample: ${data[0]['name']} (ID: ${data[0]['id']})');
              } else {
                  print('❌ $name returned 200 but invalid data format.');
              }
          } else {
              print('❌ $name is NOT standard VTEX or blocked (Status: ${res.statusCode})');
          }
      } catch (e) {
          print('❌ $name Error: $e');
      }
  }
}
