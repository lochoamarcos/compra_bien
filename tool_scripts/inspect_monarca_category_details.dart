import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  await inspectCategoryDetails('leche');
}

Future<void> inspectCategoryDetails(String query) async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=1');
  print('Fetching Monarca search for "$query"...');
  
  try {
     final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         if (data.containsKey('categoryDetails')) {
             final cats = data['categoryDetails'];
             print('Category Details Structure:');
             // It might be a Map<Id, Name> or List
             if (cats is Map) {
                 cats.forEach((k, v) => print('ID: $k -> $v'));
             } else if (cats is List) {
                 for (var c in cats) {
                     print(c);
                 }
             } else {
                 print(cats);
             }
         } else {
             print('No categoryDetails found.');
         }
     }
  } catch (e) {
      print('Exception: $e');
  }
}
