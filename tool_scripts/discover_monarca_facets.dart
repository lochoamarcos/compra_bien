import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Try searching for a broad term to see if categories are returned in metadata
  await inspectQuery('leche');
  await inspectQuery('almacen');
}

Future<void> inspectQuery(String query) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=1');
  print('\nFetching Monarca search for "$query"...');
  
  try {
     final res = await http.get(url, headers: {
         'User-Agent': 'Mozilla/5.0'
     });
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         print('Top Level Keys: ${data.keys.toList()}');
         
         if (data.containsKey('filters')) {
             print('Types of filters found: ${(data['filters'] as List).map((f) => f['name']).toList()}');
             
             // Inspect generic filter
             final filters = data['filters'] as List;
             for (var f in filters) {
                 if (f['name'] == 'Rubro' || f['name'] == 'Categoria' || f['name'] == 'Categoría') {
                     print('Values for ${f['name']}:');
                     // Usually list of {id, name, count}
                     if (f['values'] != null) {
                         for (var val in f['values'].take(5)) {
                             print(' - ${val['name']} (ID: ${val['id']})');
                         }
                     }
                 }
             }
         }
         
         if (data.containsKey('facets')) {
             print('Facets found: $data["facets"]');
         }
     } else {
         print('Error: ${res.statusCode}');
     }
  } catch (e) {
      print('Exception: $e');
  }
}
