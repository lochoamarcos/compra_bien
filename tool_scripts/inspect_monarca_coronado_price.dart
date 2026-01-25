import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Inspecting Monarca "Coronados" Item ---');
  final baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  try {
      final uri = Uri.parse('$baseUrl?query=coronados&page=0&size=1');
      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        var item;
        if (data['products'] is Map) item = data['products']['content'][0];
        else item = data['products'][0];

        print('Item: ${item['description']}');
        print('Price: ${item['price']}');
        
        // Print all keys to find hidden price info
        print('\n--- ALL KEYS & VALUES ---');
        item.forEach((k, v) => print('$k: $v'));
        
        // Check inside tags or specific objects
        if (item['tags'] != null) print('\nTags: ${item['tags']}');
        
      } else {
        print('Error ${res.statusCode}');
      }
    } catch (e) {
      print('Exception $e');
    }
}
