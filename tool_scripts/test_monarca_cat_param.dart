import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  // Try different category parameter names
  final params = ['categoryId', 'category_id', 'category', 'cat'];
  
  for (var p in params) {
    final url = Uri.parse('$baseUrl?$p=18500&size=5');
    print('Testing parameter: $p');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final Map data = json.decode(res.body);
        final count = data['products']['totalElements'];
        print('✅ Success! Found $count elements with this parameter.');
        if (count > 0) {
           final first = data['products']['content'][0]['name'];
           print('Sample: $first');
        }
      } else {
        print('❌ Failed with ${res.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
