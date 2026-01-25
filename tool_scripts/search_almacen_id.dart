import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final categoryId = '161';
  final url = 'https://www.carrefour.com.ar/api/catalog_system/pub/products/search?fq=C:$categoryId&_from=0&_to=5';
  
  print('Fetching: $url');
  
  final res = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  });
  
  if (res.statusCode == 200) {
      try {
           final List data = json.decode(res.body);
           print('Found ${data.length} products.');
           if (data.isNotEmpty) {
               print('First Item: ${data[0]['productName']}');
               print('SUCCESS: ID 161 Works.');
           } else {
               print('FAILURE: Empty list.');
           }
      } catch (e) {
          print('Error parsing JSON: $e');
      }
  } else {
      print('HTTP Error: ${res.statusCode}');
  }
}
