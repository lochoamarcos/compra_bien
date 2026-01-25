import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final queries = [
    'azucar', // Known good
    'aceite', 
    'Almacen', // The goal
    'Comestibles',
    'Despensa',
  ];
  
  print('=== Check Monarca Corrected ===');
  for (var q in queries) {
      await testQuery(q);
  }
}

Future<void> testQuery(String query) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=5');
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
         
         print('Query: "$query" -> Found ${content.length} items (First: ${content.isNotEmpty ? content[0]['description'] : "None"})');
     } else {
         print('Query: "$query" -> HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('Query: "$query" -> Error: $e');
  }
}
