import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Search for "azucar" as a common item to see facets
  await inspectMetadata('azucar');
  // Search for "shampoo" for perfumeria
  await inspectMetadata('shampoo');
}

Future<void> inspectMetadata(String query) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=1');
  print('\nFetching Monarca search for "$query"...');
  
  try {
     final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         if (data.containsKey('categoryDetails')) {
             print('--- Category Details (Sample) ---');
             var cats = data['categoryDetails'];
             if (cats is List) {
                 for (var c in cats.take(10)) print(c);
             } else if (cats is Map) {
                 cats.keys.take(10).forEach((k) => print('$k: ${cats[k]}'));
             }
         }
         
         if (data.containsKey('tagsDetails')) {
             print('--- Tags Details (Sample) ---');
             var tags = data['tagsDetails'];
             // inspect structure
             if (tags is List) {
                 for (var t in tags.take(10)) print(t);
             }
         }
         
         // Are there other keys?
         print('Top Keys: ${data.keys.toList()}');
         
         // Can we find "Almacén" string anywhere?
         if (res.body.contains('Almacen') || res.body.contains('ALMACEN')) {
             print('FOUND "ALMACEN" in response body!');
         } else {
             print('"Almacen" NOT found in response body.');
         }

     }
  } catch (e) {
      print('Exception: $e');
  }
}
