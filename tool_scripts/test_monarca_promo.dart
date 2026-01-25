import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://api.monarcadigital.com.ar';
  
  // Test 1: Empty query (Home page items?)
  print('\n--- TEST 1: Empty Query (Default Sort) ---');
  await search(baseUrl, '', inspect: true);
  
  // Test 2: Search for "Coca" to get standard items and look for price/offer fields
  print('\n--- TEST 2: Query "Coca" ---');
  await search(baseUrl, 'Coca', inspect: true);
}

Future<void> search(String baseUrl, String query, {bool inspect = false}) async {
  final url = Uri.parse('$baseUrl/products/search?query=$query&page=0&size=5');
  try {
    final response = await http.get(url, headers: {
       'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
       'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      
      List<dynamic> content = [];
      if (data.containsKey('products')) {
           var productsVal = data['products'];
           if (productsVal is Map) {
              content = productsVal['content'] ?? [];
           } else if (productsVal is List) {
              content = productsVal;
           }
      } else if (data.containsKey('content')) {
          content = data['content'];
      }

      print('Found ${content.length} results.');
      
      if (content.isNotEmpty && inspect) {
        // Inspect first 3 items
        for (var i = 0; i < (content.length > 3 ? 3 : content.length); i++) {
          final p = content[i];
          print('\n[Item $i] Name: ${p['description'] ?? p['name']}');
          // Print potential signals
          final keys = p.keys.toList();
          final interest = ['price', 'list_price', 'offer', 'promo', 'discount', 'special', 'old_price'];
          
          for (var k in keys) {
            String ls = k.toLowerCase();
             // Print if interesting or value is boolean/complex
            if (interest.any((i) => ls.contains(i))) {
               print('  -> $k: ${p[k]}');
            }
          }
          // Just print all keys to be sure
          print('  (All keys): $keys');
        }
      }
    } else {
      print('Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
