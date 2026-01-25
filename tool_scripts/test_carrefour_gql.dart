import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Testing Carrefour Almacen Search ---');
  
  // 1. REST Search (Standard)
  final restUrl = Uri.parse('https://www.carrefour.com.ar/api/catalog_system/pub/products/search?ft=almacen&_from=0&_to=5');
  try {
      final res = await http.get(restUrl, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      });
      print('REST Status: ${res.statusCode}');
      if (res.statusCode == 200) {
          final data = json.decode(res.body);
          print('REST Found ${data.length} items');
          if (data.isNotEmpty) {
               print('First Item Name: ${data[0]['productName']}');
               print('Categories: ${data[0]['categories']}');
          }
      }
  } catch (e) {
      print('REST Error: $e');
  }

  // 2. GraphQL (User provided)
  // URL encoded variables
  String variables = json.encode({
      "hideUnavailableItems": true,
      "behavior": "Static",
      "categoryTreeBehavior": "default",
      "query": "almacen",
      "map": "c", // Map 'c' usually means Category.
      "from": 0,
      "to": 10,
      "selectedFacets": [{"key": "c", "value": "almacen"}],
      "initialAttributes": "c",
      "variant": "null-null" // ?
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
  
  // Actually the URL user provided had 'variables' as a query param which was base64 encoded string of the variables json?
  // Let's decode what user provided to be sure.
  // User provided: variables=%7B%7D (Empty object)
  // BUT extensions has "variables": "eyJ..." which is the base64 string.
  
  final gqlUrl = Uri.parse('https://www.carrefour.com.ar/_v/segment/graphql/v1?'
      'workspace=master&maxAge=medium&appsEtag=remove&domain=store&locale=es-AR'
      '&__bindingId=ecd0c46c-3b2a-4fe1-aae0-6080b7240f9b'
      '&operationName=facetsV2'
      '&variables={}'
      '&extensions=$extensions');
      
  print('GraphQL Endpoint: $gqlUrl');
  
  try {
      final res = await http.get(gqlUrl, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
      });
      print('GraphQL Status: ${res.statusCode}');
       if (res.statusCode == 200) {
          // print(res.body.substring(0, 500)); // Print start
          final body = json.decode(res.body);
          if (body['data'] != null && body['data']['facets'] != null) {
              final facets = body['data']['facets'];
              if (facets['breadcrumb'] != null) print('Breadcrumb: ${facets['breadcrumb']}');
              // Check for subcategories
              // The user said "devuelve los productos asi" but showed FacetValue. 
              // FacetValue usually implies we need to query THAT facet value to get products.
              // e.g. "almacen/arroz-doble?map=tipo-de-producto"
          }
      }
  } catch (e) {
      print('GQL Error: $e');
  }
}
