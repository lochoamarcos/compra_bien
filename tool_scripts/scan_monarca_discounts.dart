import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Scanning Monarca Items for Discount Patterns ---');
  final baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  
  // Search for "coronados" and generic "promo" to see different types
  List<String> queries = ['coronados', 'promo', 'descuento'];
  
  for (var q in queries) {
      print('\nQuery: "$q"');
      try {
          final uri = Uri.parse('$baseUrl?query=$q&page=0&size=20');
          final res = await http.get(uri);
          
          if (res.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
            var list = [];
            if (data['products'] is Map) list = data['products']['content'];
            else if (data['products'] is List) list = data['products'];
            else if (data['content'] is List) list = data['content'];

            for (var item in list) {
                String desc = item['description'];
                String content = item['content'] ?? '';
                String tags = (item['tags'] ?? []).toString();
                
                // Filter for interesting content
                if (content.isNotEmpty || tags.contains('promo')) {
                    print('  Item: $desc');
                    print('    Content: $content');
                    print('    Tags: $tags');
                    print('    Price: ${item['price']}');
                }
            }
          }
      } catch (e) {
          print('  Error: $e');
      }
  }
}
