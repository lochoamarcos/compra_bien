import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final queries = [
    'Almacen', 
    'Bebes y niños', // Note: User typo "ninños" in prompt, I'll try correct one.
    'Bebes y ninños', // Try typo too just in case
    'bebidas con alcohol', 
    'bebidas sin alcohol', 
    'carniceria', 
    'desayuno', // User typo "desauyno"?
    'fiambreria', 
    'frutas y verduras', 
    'kiosco', 
    'lacteos', 
    'limpieza', 
    'mascota', 
    'panaderia', 
    'papeles', 
    'perfumeria', 
    'productos frescos'
  ];
  
  print('=== Testing Monarca Queries ===');
  for (var q in queries) {
      await testQuery(q);
  }
}

Future<void> testQuery(String query) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=1');
  try {
     final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         final total = data['page']?['totalElements'] ?? 0;
         print('Query: "$query" -> Total: $total');
     } else {
         print('Query: "$query" -> HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('Query: "$query" -> Error: $e');
  }
}
