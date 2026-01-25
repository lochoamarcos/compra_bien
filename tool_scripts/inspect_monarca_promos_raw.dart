import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Inspecting Monarca "oferta" items for patterns ---');
  final baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  
  // We use the same logic as the app: 'oferta' keyword for promotions
  final uri = Uri.parse('$baseUrl?query=coronados&page=0&size=50');
  
  try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
          var list = [];
          if (data['products'] is Map) list = data['products']['content'] ?? [];
          else if (data['products'] is List) list = data['products'];

          int count = 0;
          for (var item in list) {
              if (count >= 5) break; 
              count++;
              String content = item['content'] ?? '';
              String desc = item['description'] ?? '';
              
              print('Item: ${item['name']}');
              print('  Store ID: ${item['id']}');
              print('  List Price: ${item['list_price'] ?? item['listPrice']}');
              print('  Price: ${item['price']}');
              print('  Content: $content');
              print('  Description: $desc');
              print('  Tags: ${item['tags']}');
              print('---');
          }
      }
  } catch (e) {
      print('Error $e');
  }
}
