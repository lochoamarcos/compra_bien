import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Inspecting Vea Tree ---');
  // Vea often uses specific headers or cookies? Let's try basic first with User-Agent
  final res = await http.get(Uri.parse('https://www.vea.com.ar/api/catalog_system/pub/category/tree/2'), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  
  if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      print('Total Root Categories: ${data.length}');
      // We want to map: Desayuno, Almacen, Frescos, Bebidas, Limpieza, Perfumeria
      final targets = ['desayuno', 'merienda', 'almacen', 'bebidas', 'frescos', 'lacteos', 'limpieza', 'perfumeria'];
      
      for (var c in data) {
          String name = c['name'].toString().toLowerCase();
          if (targets.any((t) => name.contains(t))) {
             print('MATCH ($name): ${c['name']} (ID: ${c['id']})');
          }
      }
  } else {
      print('Error parsing Vea: ${res.statusCode}');
  }
}
