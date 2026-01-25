import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final markets = {
    'Carrefour': 'https://www.carrefour.com.ar/api/catalog_system/pub/category/tree/2',
    'Vea': 'https://www.vea.com.ar/api/catalog_system/pub/category/tree/2',
  };

  for (var entry in markets.entries) {
    print('\n=== ROOT CATEGORIES FOR ${entry.key} ===');
    final res = await http.get(Uri.parse(entry.value), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      for (var c in data) {
        print('${c['name']} (ID: ${c['id']})');
      }
    }
  }
}
