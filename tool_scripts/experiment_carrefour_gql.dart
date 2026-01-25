import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Carrefour GraphQL & REST Experiment ---');
  
  final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Origin': 'https://www.carrefour.com.ar',
      'Referer': 'https://www.carrefour.com.ar/',
      'Content-Type': 'application/json',
  };

  // 1. VS: Raw REST Category Tree (Standard VTEX)
  // This is often the easiest way to get ALL categories.
  print('\n[REST] Fetching Category Tree (Depth 2)...');
  try {
      final res = await http.get(Uri.parse('https://www.carrefour.com.ar/api/catalog_system/pub/category/tree/2'), headers: headers);
      print('Status: ${res.statusCode}');
      if (res.statusCode == 200) {
          final List data = json.decode(res.body);
          print('Found ${data.length} root categories.');
          for (var c in data.take(3)) {
              print(' - ${c['name']} (ID: ${c['id']})');
              if (c['children'] != null) {
                  print('   Sub: ${(c['children'] as List).take(3).map((sub) => sub['name']).join(', ')}...');
              }
          }
      }
  } catch (e) {
      print('REST Tree Error: $e');
  }

  // 2. The User's "facetsV2" GraphQL Query (Persisted)
  // This helps find "what filters are available" for a search term.
  print('\n[GQL] Executing facetsV2 for "almacen"...');
  String variables = json.encode({
      "hideUnavailableItems": true,
      "behavior": "Static",
      "categoryTreeBehavior": "default",
      "query": "almacen",
      "map": "c", 
      "from": 0, "to": 10,
      "selectedFacets": [{"key": "c", "value": "almacen"}],
      "variant": "null-null"
  });
  
  String extensions = json.encode({
      "persistedQuery": {
          "version": 1,
          "sha256Hash": "f58a719cabfc9839cc0b48ab2eb46a946c4219acd45e691650eed193f3f31bdf",
          "sender": "vtex.store-resources@0.x",
          "provider": "vtex.search-graphql@0.x"
      },
      "variables": base64Encode(utf8.encode(variables))
  });
  
  final gqlUrl = Uri.parse('https://www.carrefour.com.ar/_v/segment/graphql/v1?extensions=$extensions');
  try {
      final res = await http.get(gqlUrl, headers: headers);
      if (res.statusCode == 200) {
          final body = json.decode(res.body);
          if (body['data'] != null && body['data']['facets'] != null) {
               final facets = body['data']['facets']['facets'] as List;
               print('Facets Found: ${facets.length}');
               // Find "Category" facet
               final catFacet = facets.firstWhere((f) => f['name'] == 'Categoría' || f['name'] == 'Categorías', orElse: () => null);
               if (catFacet != null) {
                   print('Category Facets for "Almacen":');
                   for (var val in (catFacet['values'] as List).take(5)) {
                       print(' - ${val['name']} (Count: ${val['quantity']}) -> Key: ${val['key']} | Value: ${val['value']}');
                   }
               }
          }
      } else {
          print('Status: ${res.statusCode}');
      }
  } catch (e) {
      print('GQL Facets Error: $e');
  }

  // 3. Attempt RAW GQL Product Search (No Hash)
  // If this works, we can get ANY data we want without hash.
  print('\n[GQL] Attempting Raw productSearch...');
  final rawQuery = '''
  query {
    productSearch(query: "almacen", map: "c", from: 0, to: 3) {
      products {
        productName
        brand
        priceRange {
          sellingPrice { highPrice }
        }
      }
    }
  }
  ''';
  
  try {
      final rawRes = await http.post(
          Uri.parse('https://www.carrefour.com.ar/_v/segment/graphql/v1'), 
          headers: headers,
          body: json.encode({'query': rawQuery})
      );
      print('Raw Query Status: ${rawRes.statusCode}');
      print('Body Preview: ${rawRes.body.substring(0, rawRes.body.length > 200 ? 200 : rawRes.body.length)}');
  } catch (e) {
      print('Raw GQL Error: $e');
  }
}
