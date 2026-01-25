import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // First, test a general search to see the response structure
  await testGeneralSearch('leche');
  await testGeneralSearch('coca');
  
  // Test Promociones endpoint
  await testPromotions();
}

Future<void> testGeneralSearch(String query) async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  
  final payload = {
    "palabraclave": query.toUpperCase().replaceAll(' ', '_'),
    "pagina": 0,
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
    }
  };
  
  print('\n=== Testing General Search: "$query" ===');
  
  try {
     final res = await http.post(
       url, 
       headers: {
         'Content-Type': 'application/json',
         'User-Agent': 'Mozilla/5.0',
       },
       body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         print('Response Keys: ${data.keys.toList()}');
         
         // Check for articles
         if (data['articulos'] != null) {
             List items = data['articulos'];
             print('Found ${items.length} items');
             if (items.isNotEmpty) {
                 print('First item: ${items[0]['descripcion']}');
                 
                 // Check if categories are embedded in items
                 if (items[0]['categoria'] != null) {
                     print('Item category field: ${items[0]['categoria']}');
                 }
                 if (items[0]['id_categoria'] != null) {
                     print('Item category ID: ${items[0]['id_categoria']}');
                 }
             }
         }
         
         // Check for category metadata
         if (data['categorias'] != null) {
             print('Available categories: ${data['categorias']}');
         }
         if (data['filtros'] != null && data['filtros']['categoria'] != null) {
             print('Category filters: ${data['filtros']['categoria']}');
         }
     } else {
         print('HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('Exception: $e');
  }
}

Future<void> testPromotions() async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  
  final payload = {
    "promocion": true,
    "pagina": 0,
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
    }
  };
  
  print('\n=== Testing Promotions ===');
  
  try {
     final res = await http.post(
       url, 
       headers: {
         'Content-Type': 'application/json',
         'User-Agent': 'Mozilla/5.0',
       },
       body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         List items = data['articulos'] ?? [];
         print('Found ${items.length} promotional items');
     } else {
         print('HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('Exception: $e');
  }
}
