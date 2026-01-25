import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final Map<String, String> coopeCategories = {
    'Almacen': '2',
    'Frescos': '3',
    'Bebidas': '4',
    'Perfumeria': '5',
    'Limpieza': '6',
  };
  
  print('=== Testing La Coope Categories (Corrected) ===\n');
  
  for (var entry in coopeCategories.entries) {
      await testCategory(entry.key, entry.value);
  }
  
  // Also test some new categories if they exist
  print('\n=== Testing Additional Categories ===\n');
  final additionalTests = {
    'Electro': '7',
    'Bebés': '8',
    'Mascotas': '9',
    'Hogar': '10',
  };
  
  for (var entry in additionalTests.entries) {
      await testCategory(entry.key, entry.value);
  }
}

Future<void> testCategory(String name, String id) async {
  // Correct endpoint from CoopeRepository
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  
  final payload = {
    "id_busqueda": id,
    "pagina": 0,
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
    }
  };
  
  try {
     final res = await http.post(
       url, 
       headers: {
         'Content-Type': 'application/json',
         'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
       },
       body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         // Check structure - might be data['articulos'] or data['results']
         List items = [];
         if (data is Map) {
             items = data['articulos'] ?? data['results'] ?? data['items'] ?? [];
         } else if (data is List) {
             items = data;
         }
         
         if (items.isNotEmpty) {
             print('[✅ SUCCESS] $name (ID: $id) -> Found ${items.length} items');
             print('   Example: ${items[0]['descripcion'] ?? items[0]['nombre'] ?? 'N/A'}');
         } else {
             print('[⚠️ EMPTY] $name (ID: $id) -> 0 results');
         }
     } else {
         print('[❌ ERROR] $name (ID: $id) -> HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('[❌ EXCEPTION] $name (ID: $id) -> ${e.toString().substring(0, 80)}...');
  }
  print('');
}
