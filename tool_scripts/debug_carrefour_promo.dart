import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final baseUrl = 'https://www.carrefour.com.ar';
  
  // 1. Current API Call (Search)
  // We'll search for the specific EAN or text to see standard results
  print('\n=== 1. Standard Search API ===');
  await _testStandardSearch('cerveza blanca quilmes sin alcohol');

  // 2. User Suggested GraphQL Query (ProductBenefits)
  print('\n=== 2. ProductBenefits GQL ===');
  // ID retrieved from URL/User: 665462
  await _testProductBenefitsGQL('cerveza-blanca-quilmes-sin-alcohol-473-ml-665462', '665462');
}

Future<void> _testStandardSearch(String query) async {
  final url = Uri.parse('https://www.carrefour.com.ar/api/catalog_system/pub/products/search?ft=$query');
  final res = await http.get(url, headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
  });
  
  if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      if (data.isNotEmpty) {
          final item = data[0];
          print('Found: ${item['productName']} (ID: ${item['productId']})');
          print('Cluster Highlights: ${item['clusterHighlights']}');
          
          final sku = item['items'][0];
          final comm = sku['sellers'][0]['commertialOffer'];
          print('Price: ${comm['Price']}');
          print('ListPrice: ${comm['ListPrice']}');
          print('Promo Content: N/A (Standard REST usually lacks specific benefit text unless in clusterHighlights)');
      } else {
          print('No items found with standard search.');
      }
  } else {
      print('Standard search failed: ${res.statusCode}');
  }
}

Future<void> _testProductBenefitsGQL(String slug, String id) async {
    final url = Uri.parse('https://www.carrefour.com.ar/_v/segment/graphql/v1?workspace=master&maxAge=short&appsEtag=remove&domain=store&locale=es-AR');
    
    // User provided query params
    final operationName = 'ProductBenefits';
    final sha256 = '07791ce6321bdbc77b77eaf67350988d3c71cec0738f46a1cbd16fb7884c4dd1';
    
    final variables = {
        "slug": slug,
        "identifier": {"field": "id", "value": id}
    };
    
    // Extensions
    final finalExtensions = {
        "persistedQuery": {
            "version": 1,
            "sha256Hash": sha256,
            "sender": "vtex.store-resources@0.x",
            "provider": "vtex.search-graphql@0.x"
        },
        "variables": base64Encode(utf8.encode(json.encode(variables)))
    };

    final fullUrl = url.replace(queryParameters: {
        ...url.queryParameters,
        'operationName': operationName,
        'variables': '{}', // Variables are sent in extensions block encoded
        'extensions': json.encode(finalExtensions)
    });
    
    // Re-check sending logic. Usually GET handles variables in query string if encoded properly.
    // The user url had `variables=%7B%7D` (empty object) in QP, and variables inside extensions.
    
    final res = await http.get(fullUrl, headers: {
       'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
       'Referer': 'https://www.carrefour.com.ar/$slug/p'
    });
    
    if (res.statusCode == 200) {
        final Map data = json.decode(res.body);
        print(JsonEncoder.withIndent('  ').convert(data));
    } else {
        print('GQL Failed: ${res.statusCode} ${res.body}');
    }
}
