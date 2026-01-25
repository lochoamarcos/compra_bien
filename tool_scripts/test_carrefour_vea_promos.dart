import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Checking Carrefour & Vea Promos ---');
  await checkMarket('Carrefour', 'https://www.carrefour.com.ar/api/catalog_system/pub/products/search');
  await checkMarket('Vea', 'https://www.vea.com.ar/api/catalog_system/pub/products/search');
}

Future<void> checkMarket(String name, String baseUrl) async {
  print('\n[$name] Testing keywords: oferta, descuento');
  final keywords = ['oferta', 'descuento'];
  
  for (final k in keywords) {
    try {
      // Using a limit of 5 items
      final uri = Uri.parse('$baseUrl?ft=$k&_from=0&_to=4');
      final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)'
      });
      
      if (res.statusCode == 200 || res.statusCode == 206) {
        final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        print('  Keyword "$k": Found ${data.length} items.');
        
        // Analyze if they have actual discounts
        int withDiscount = 0;
        for (var item in data) {
           final comm = item['items'][0]['sellers'][0]['commertialOffer'];
           final price = (comm['Price'] ?? 0).toDouble();
           final listPrice = (comm['ListPrice'] ?? 0).toDouble();
           if (listPrice > price) withDiscount++;
        }
        print('    -> Items with ListPrice > Price: $withDiscount / ${data.length}');
        
      } else {
        print('  Keyword "$k": Error ${res.statusCode}');
      }
    } catch (e) {
      print('  Keyword "$k": Exception $e');
    }
  }
}
