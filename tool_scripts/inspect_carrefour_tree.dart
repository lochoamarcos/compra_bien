import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Inspecting Carrefour Tree ---');
  final res = await http.get(Uri.parse('https://www.carrefour.com.ar/api/catalog_system/pub/category/tree/2'), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  
  if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      print('Total Root Categories: ${data.length}');
      for (var c in data) {
          if (['almacen', 'bebidas', 'frescos', 'limpieza', 'desayuno'].any((k) => c['name'].toString().toLowerCase().contains(k))) {
             print('MATCH: ${c['name']} (ID: ${c['id']})');
          } else {
             // Print some others to see structure
             // print('Other: ${c['name']} (ID: ${c['id']})');
          }
      }
  }
}
