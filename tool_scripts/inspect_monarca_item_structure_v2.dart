import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  await inspectItem('Aceite', 'Almacen');
  await inspectItem('Pañales', 'Bebes');
}

Future<void> inspectItem(String query, String expectedCategory) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=1');
  print('\n=== Inspecting Item for "$query" (Expected: $expectedCategory) ===');
  
  try {
     final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         if (data.containsKey('content')) {
             final items = data['content'] as List; // This was map in repo code, check type?
             // Checking repo code: content = data['content'] or products['content']
             // This endpoint returns top-level content list usually? No repo says `data | data['products']['content'] | data['content']`
             
             List itemList = [];
             if (data['content'] is List) itemList = data['content'];
             else if (data['products'] != null && data['products']['content'] is List) itemList = data['products']['content'];
             
             if (itemList.isNotEmpty) {
                 final item = itemList[0];
                 print('Item Name: ${item['description']}');
                 print('Item ID: ${item['id']}');
                 
                 item.forEach((k, v) {
                     if (v is! List && v is! Map) {
                        print('  $k: $v');
                     } else if (k == 'tags' || k.toLowerCase().contains('categ') || k.toLowerCase().contains('rubro')) {
                        print('  $k: $v');
                     }
                 });
             } else {
                 print('No items found.');
             }
         }
     }
  } catch (e) {
      print('Exception: $e');
  }
}
