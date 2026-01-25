import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Checking Monarca "Coronados" ---');
  await checkMonarca('coronados');
  await checkMonarca('coronado');
  await checkMonarca('promociones');
  await checkMonarca('promo');
  
  // Also check if there's a category/filter for it?
  // Monarca usually returns "facets" or "filters" in the search response. Let's inspect that.
}

Future<void> checkMonarca(String k) async {
  final baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  print('\n[Monarca] Testing keyword: "$k"');
  
  try {
      final uri = Uri.parse('$baseUrl?query=$k&page=0&size=5');
      final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)'
      });
      
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        
        List<dynamic> content = [];
        if (data.containsKey('products')) {
             var productsVal = data['products'];
             if (productsVal is Map) {
                content = productsVal['content'] ?? [];
             } else if (productsVal is List) {
                content = productsVal;
             }
        } else if (data.containsKey('content')) {
            content = data['content']; // Sometimes root content
        }

        print('  Found ${content.length} items.');
        
        if (content.isNotEmpty) {
           print('    Sample: ${content[0]['description']}');
           // Check tags
           if (content[0]['tags'] != null) print('    Tags: ${content[0]['tags']}');
        } else {
             // Maybe it's a category? Checking facets if available (not printing full JSON to avoid spam)
        }

      } else {
        print('  Error ${res.statusCode}');
      }
    } catch (e) {
      print('  Exception $e');
    }
}
