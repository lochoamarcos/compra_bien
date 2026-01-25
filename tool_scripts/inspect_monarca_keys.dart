import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=Coca&page=0&size=1');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      var item;
      if (data['products'] is Map) item = data['products']['content'][0];
      else item = data['products'][0];

      print('KEYS: ${item.keys.toList()}');
      if (item.containsKey('tags')) print('TAGS: ${item['tags']}');
      if (item.containsKey('prices')) print('PRICES: ${item['prices']}');
      if (item.containsKey('offer')) print('OFFER: ${item['offer']}');
      
      // key-value dump for small keys
      item.forEach((k, v) {
        if (k.contains('price') || k.contains('promo') || k.contains('offer')) {
             print('$k: $v');
        }
      });
    }
  } catch (e) {
    print('Error: $e');
  }
}
