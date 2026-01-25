import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final Map<String, List<String>> tests = {
      'Almacen': ['Almacen', 'Fideos', 'Arroz', 'Yerba', 'Aceite'],
      'Bebidas': ['Bebidas', 'Gaseosa', 'Cerveza', 'Vino', 'Agua'],
      'Limpieza': ['Limpieza', 'Detergente', 'Lavandina', 'Jabon'],
      'Perfumeria': ['Perfumeria', 'Shampoo', 'Desodorante'],
      'Bebes': ['Bebes', 'Pañales', 'Toallitas'],
      'Mascotas': ['Mascotas', 'Perro', 'Gato', 'Alimento'],
      'Hogar': ['Hogar', 'Rollo', 'Servilletas', 'Bazar'],
      'Congelados': ['Congelados', 'Hamburguesas', 'Helado'],
      'Panaderia': ['Panaderia', 'Pan', 'Facturas'],
      'Electro': ['Electro', 'Pava', 'Licuadora'],
  };
  
  print('=== Testing Monarca Check Keywords ===');
  
  for (var entry in tests.entries) {
      print('\n--- Category: ${entry.key} ---');
      for (var q in entry.value) {
           await testQuery(q);
      }
  }
}

Future<void> testQuery(String query) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=1');
  try {
     final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         List content = [];
         if (data.containsKey('products')) {
             if (data['products'] is Map && data['products'].containsKey('content')) {
                 content = data['products']['content'];
             } else if (data['products'] is List) {
                 content = data['products'];
             }
         } else if (data.containsKey('content')) {
             content = data['content'];
         }
         
         if (content.isNotEmpty) {
             print('[MATCH] "$query" -> Found ${content.length} items (Ex: ${content[0]['description']})');
         } else {
             print('[EMPTY] "$query"');
         }
     } else {
         print('[ERROR] "$query" -> HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('[EXCEPTION] "$query" -> $e');
  }
}
