import 'package:http/http.dart' as http;
import 'dart:convert';

// Mock Classes/Functions to simulate Repository logic
Future<void> main() async {
  print('--- TESTING PROMOCIONES LOGIC ---');

  // 1. Monarca (Keywords: descuento, promo, oferta)
  await testMonarca(['descuento', 'promo', 'oferta']);

  // 2. Carrefour (Keywords: descuento, promo, oferta)
  await testCarrefour(['descuento', 'promo', 'oferta']);

  // 3. Vea (Keywords: descuento, promo, oferta)
  await testVea(['descuento', 'promo', 'oferta']);
  
  // 4. La Coope (Special Logic: isPromo = true)
  await testCoope(isPromo: true);
}

Future<void> testMonarca(List<String> keywords) async {
  print('\n[Monarca]');
  const baseUrl = 'https://api.monarcadigital.com.ar/products/search';
  for (var k in keywords) {
    try {
      final url = Uri.parse('$baseUrl?query=$k&page=0&size=5');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final items = (data['products'] is Map ? data['products']['content'] : data['products']) as List;
        print('  Keyword "$k": Found ${items.length} items.');
        if (items.isNotEmpty) {
           print('    Sample: ${items[0]['description']} | Price: ${items[0]['price']}');
        }
      } else {
        print('  Keyword "$k": Error ${res.statusCode}');
      }
    } catch (e) {
      print('  Keyword "$k": Exception $e');
    }
  }
}

Future<void> testCarrefour(List<String> keywords) async {
  print('\n[Carrefour]');
  // Simulation of Carrefour logic (assuming standard VTEX or similar API usually used, but here using what we know or guessing based on Repos)
  // Checking typical valid endpoints or search URL from repository would be better. 
  // Let's assume we need to check the real repository implementation first.
  // For now, I'll skip deep implementation and just note I need to check the Reopsitory file.
  print('  (Skipping remote fetch for Carrefour without exact API details at hand, checking Repos next)');
}

Future<void> testVea(List<String> keywords) async {
    print('\n[Vea]');
     // Similar to Carrefour, Vea often uses dynamic endpoints or tokens. 
     print('  (Skipping remote fetch for Vea without exact API details at hand)');
}

Future<void> testCoope({required bool isPromo}) async {
  print('\n[La Coope]');
  // Replicating Coope logic
  const baseUrl = 'https://lacoopeencasa.coop/api/destacados/buscar'; 
  final payload = {
    "paginacion": {"pagina": 1, "cantidad": 5},
    "orden": "relevancia",
    "palabra": "",
    "filtros": {
      "ofertas": true, 
      "id_categoria": "", 
      "marcas": [], 
      "precios": {"min": 0, "max": 0}
    }
  };
  
  try {
     final res = await http.post(Uri.parse(baseUrl), 
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         final items = data['productos'] as List? ?? [];
         print('  isPromo=true: Found ${items.length} items.');
         if (items.isNotEmpty) {
             print('    Sample: ${items[0]['descripcion_producto']}');
         }
     } else {
         print('  Error ${res.statusCode}');
     }
  } catch(e) {
      print('  Exception $e');
  }
}
