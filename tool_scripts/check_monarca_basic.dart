import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final queries = [
    'azucar', // Known good
    'aceite', // Lowercase
    'ACEITE', // Uppercase
    'yerba',
  ];
  
  print('=== Check Monarca Basic ===');
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
