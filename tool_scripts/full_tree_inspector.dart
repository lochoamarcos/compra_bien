import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final markets = {
    'Carrefour': 'https://www.carrefour.com.ar/api/catalog_system/pub/category/tree/2',
    'Vea': 'https://www.vea.com.ar/api/catalog_system/pub/category/tree/2',
  };

  final headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  };

  for (var entry in markets.entries) {
    print('\n=== FULL TREE FOR ${entry.key} ===');
    try {
      final res = await http.get(Uri.parse(entry.value), headers: headers);
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        _printTree(data, '');
      } else {
        print('Error: ${res.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}

void _printTree(List categories, String indent) {
  for (var c in categories) {
    print('$indent- ${c['name']} (ID: ${c['id']})');
    if (c['children'] != null && (c['children'] as List).isNotEmpty) {
      _printTree(c['children'], '$indent  ');
    }
  }
}
