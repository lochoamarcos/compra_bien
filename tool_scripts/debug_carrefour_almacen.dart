import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== Testing Carrefour Almacen GQL ===');
  // Test 1: Capitalized "Almacen" (As used in Prod)
  await testGQL('Almacen', 'c');
  
  // Test 2: Lowercase "almacen"
  await testGQL('almacen', 'c');
  
  // Test 3: With Accent "almacén"
  await testGQL('almacén', 'c');

  // Test 4: Link Text "almacen" (standard slug)
  await testGQL('almacen-y-despensa', 'c'); // Guessing?
}

Future<void> testGQL(String query, String map) async {
    print('\nChecking query: "$query", map: "$map"');
    
    final baseUrl = 'https://www.carrefour.com.ar';
    final from = 0;
    final to = 9;
    
    final rawQuery = '''
     query {
       productSearch(query: "$query", map: "$map", from: $from, to: $to, hideUnavailableItems: true) {
         products {
           productName
         }
       }
     }
    ''';
    
    final url = Uri.parse('$baseUrl/_v/segment/graphql/v1');
    final headers = {
       'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
       'Content-Type': 'application/json',
       'Origin': baseUrl,
       'Referer': '$baseUrl/',
    };
    
    try {
        final res = await http.post(url, headers: headers, body: json.encode({'query': rawQuery}));
        if (res.statusCode == 200) {
            final data = json.decode(res.body);
            final products = data['data']?['productSearch']?['products'] as List?;
            if (products != null && products.isNotEmpty) {
                print('✅ SUCCESS - Found ${products.length} items (First: ${products[0]['productName']})');
            } else {
                print('❌ EMPTY Result');
            }
        } else {
            print('❌ ERROR ${res.statusCode}');
        }
    } catch (e) {
        print('Exception: $e');
    }
}
