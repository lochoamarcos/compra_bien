import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final markets = {
    'Carrefour': 'https://www.carrefour.com.ar/api/catalog_system/pub/category/tree/2',
    'Vea': 'https://www.vea.com.ar/api/catalog_system/pub/category/tree/2',
  };

  final patterns = ['almacen', 'fresco', 'lacteo', 'bebida', 'limpieza', 'perfumeria', 'personal', 'desayuno', 'merienda'];

  for (var entry in markets.entries) {
    print('\n=== MATCHES FOR ${entry.key} ===');
    final res = await http.get(Uri.parse(entry.value), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    });
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _searchMatches(data, patterns);
    }
  }
}

void _searchMatches(List categories, List<String> patterns) {
  for (var c in categories) {
    final name = c['name'].toString().toLowerCase();
    if (patterns.any((p) => name.contains(p))) {
      print('FOUND: ${c['name']} (ID: ${c['id']})');
    }
    if (c['children'] != null) {
      _searchMatches(c['children'], patterns);
    }
  }
}
