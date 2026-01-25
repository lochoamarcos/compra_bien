import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== Testing La Coope with CORRECT Endpoint ===\n');
  
  final categories = {
    'Almacen': '2',
    'Frescos': '3',
    'Bebidas': '4',
    'Perfumeria': '5',
    'Limpieza': '6',
  };
  
  for (var entry in categories.entries) {
      await testCategory(entry.key, entry.value);
  }
  
  // Test promotions
  print('\n=== Testing Promotions ===\n');
  await testPromotions();
}

Future<void> testCategory(String name, String id) async {
  // CORRECTED: /api/articulos/pagina (NOT /pagina_busqueda)
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina');
  
  final payload = {
    "id_busqueda": id,
    "pagina": 0,
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
      "tipo_seleccion": "categoria",
      "cant_articulos": 0,
      "filtros_gramaje": [],
      "modificado": false,
      "ofertas": false,
      "primer_filtro": "",
      "tipo_seleccion": "categoria", // Ensure this is set
    }
  };
  
  try {
     final res = await http.post(
       url, 
       headers: {
         'Content-Type': 'application/json',
         'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
         'Referer': 'https://www.lacoopeencasa.coop/',
         'Origin': 'https://www.lacoopeencasa.coop',
       },
       body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         print('[RESPONSE] $name (ID: $id)');
         print('  Estado: ${data['estado']}');
         print('  Mensaje: ${data['mensaje']}');
         
         if (data['datos'] != null) {
             final datos = data['datos'];
             final total = datos['cantidad_articulos'] ?? 0;
             List articulos = datos['articulos'] ?? [];
             
             print('  Total articles: $total');
             print('  Returned in page: ${articulos.length}');
             
             if (articulos.isNotEmpty) {
                 final firstItem = articulos[0];
                 print('  ✅ Example: ${firstItem['descripcion']}');
                 print('     Price: \$${firstItem['precio']}');
                 
                 // Check promotion
                 if (firstItem['existe_promo'] == '1') {
                     print('     🎁 HAS PROMO: ${firstItem['precio_promo']} (was ${firstItem['precio_anterior']})');
                     print('     Promo type: ${firstItem['tipo_promo']}');
                     print('     Valid until: ${firstItem['vigencia_promo']}');
                 }
             }
         }
     } else {
         print('[❌ ERROR] $name (ID: $id) -> HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('[❌ EXCEPTION] $name (ID: $id) -> $e');
  }
  print('');
}

Future<void> testPromotions() async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina');
  
  final payload = {
    "pagina": 0,
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
      "tipo_seleccion": "busqueda",
      "cant_articulos": 0,
      "filtros_gramaje": [],
      "modificado": false,
      "ofertas": true, // KEY: Request only promotions
      "primer_filtro": "",
      "termino": "",
      "tipo_relacion": "busqueda"
    }
  };
  
  try {
     final res = await http.post(url, 
       headers: {
         'Content-Type': 'application/json',
         'User-Agent': 'Mozilla/5.0',
         'Referer': 'https://www.lacoopeencasa.coop/',
       },
       body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         if (data['datos'] != null) {
             final total = data['datos']['cantidad_articulos'] ?? 0;
             List articulos = data['datos']['articulos'] ?? [];
             
             print('[✅ PROMOTIONS] Found $total total promotional items');
             print('  Returned in page: ${articulos.length}');
             
             if (articulos.isNotEmpty) {
                 print('\nFirst 3 promotional items:');
                 for (var item in articulos.take(3)) {
                     print('  - ${item['descripcion']}');
                     print('    Price: \$${item['precio_promo']} (was ${item['precio_anterior']})');
                 }
             }
         }
     }
  } catch (e) {
      print('[❌ EXCEPTION] -> $e');
  }
}
