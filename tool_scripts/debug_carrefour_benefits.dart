
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Investigando Beneficios de Carrefour...');
  
  // Test specific product IDs for benefits
  // We'll try to find products with known promos first
  final testProductIds = ['123', '456']; // IDs to test
  
  // Actually, let's search for "ofertas" and then get benefits for those
  final searchUrl = Uri.parse('https://www.carrefour.com.ar/api/catalog_system/pub/products/search?ft=oferta&_from=0&_to=5');
  
  try {
    final searchRes = await http.get(searchUrl, headers: {'User-Agent': 'Mozilla/5.0'});
    if (searchRes.statusCode == 200) {
      final products = json.decode(searchRes.body) as List;
      for (var p in products) {
        final id = p['productId'];
        final slug = p['linkText'];
        final name = p['productName'];
        print('\nProducto: $name (ID: $id, Slug: $slug)');
        
        final benefits = await fetchBenefits(id, slug);
        print('Beneficios: $benefits');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

Future<String?> fetchBenefits(String id, String? slug) async {
  final baseUrl = 'https://www.carrefour.com.ar';
  final url = Uri.parse('$baseUrl/_v/segment/graphql/v1?workspace=master&maxAge=short&appsEtag=remove&domain=store&locale=es-AR');
  final operationName = 'ProductBenefits';
  final sha256 = '07791ce6321bdbc77b77eaf67350988d3c71cec0738f46a1cbd16fb7884c4dd1';
  
  final variables = {
      "slug": slug ?? "",
      "identifier": {"field": "id", "value": id}
  };
  
  final extensions = {
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
      'variables': '{}',
      'extensions': json.encode(extensions)
  });

  try {
    final res = await http.get(fullUrl, headers: {
       'User-Agent': 'Mozilla/5.0',
    });
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return json.encode(data['data']?['product']?['benefits'] ?? []);
    }
  } catch (e) {
    return 'Error: $e';
  }
  return null;
}
