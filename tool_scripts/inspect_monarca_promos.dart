import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=descuento&size=5');
  final res = await http.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  
  if (res.statusCode == 200) {
      final Map data = json.decode(res.body);
      final products = data['products']['content'] as List;
      for (var p in products) {
          print('--- Product: ${p['description']} ---');
          print('Price: ${p['price']}');
          print('Content: ${p['content']}');
          print('Promotions: ${p['promotions']}');
          print('Tags: ${p['tags']}');
      }
  }
}
