import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Scanning Monarca for complex promos ---');
  final baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  // Attempt to find items with these texts by searching broad terms
  // "max" often appears in "max 6 unidades"
  // "especial" often appears in "precio especial"
  
  final keywords = ['max', 'especial', 'aprovecha'];
  
  for (var k in keywords) {
      print('\nScanning keyword: "$k"');
      try {
        final uri = Uri.parse('$baseUrl?query=$k&page=0&size=20');
        final res = await http.get(uri);
        if (res.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
            var list = [];
             if (data['products'] is Map) list = data['products']['content'] ?? [];
            else if (data['products'] is List) list = data['products'];
            else if (data['content'] is List) list = data['content'];

            for (var item in list) {
                String content = item['content'] ?? '';
                if (content.toLowerCase().contains(k)) {
                    print('  Found match!');
                    print('  Desc: ${item['description']}');
                    print('  Content: $content');
                    print('  Price: ${item['price']}');
                    if (item['promotions'] != null) print('  Promos: ${item['promotions']}');
                    print('---');
                }
            }
        }
      } catch (e) {
          print('Error $e');
      }
  }
}
