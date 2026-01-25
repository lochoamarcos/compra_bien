import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('=== Testing La Coope Categories (Final) ===\n');
  
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
  
  // Test a keyword search
  print('\n=== Testing Keyword Search ===\n');
  await testKeywordSearch('coca');
}

Future<void> testCategory(String name, String id) async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  
  // Format exactly as CoopeRepository does for category search
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
      "termino": "",
      "tipo_relacion": "busqueda"
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
         
         if (data['datos'] != null && data['datos']['articulos'] != null) {
             List items = data['datos']['articulos'];
             if (items.isNotEmpty) {
                 print('[✅ SUCCESS] $name (ID: $id) -> Found ${items.length} items');
                 print('   Example: ${items[0]['descripcion']}');
             } else {
                 print('[⚠️ EMPTY] $name (ID: $id) -> 0 results');
             }
         } else {
             print('[❌ ERROR] $name (ID: $id) -> No datos.articulos in response');
         }
     } else {
         print('[❌ ERROR] $name (ID: $id) -> HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('[❌ EXCEPTION] $name (ID: $id) -> ${e.toString().substring(0, 100)}');
  }
  print('');
}

Future<void> testKeywordSearch(String query) async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  
  final normalized = query.toUpperCase().replaceAll(' ', '_');
  final payload = {
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
      "tipo_seleccion": "busqueda",
      "cant_articulos": 0,
      "filtros_gramaje": [],
      "modificado": false,
      "ofertas": false,
      "primer_filtro": "",
      "termino": normalized,
      "tipo_relacion": "busqueda"
    },
    "pagina": 0
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
         if (data['datos'] != null && data['datos']['articulos'] != null) {
             List items = data['datos']['articulos'];
             print('[✅ SUCCESS] Keyword "$query" -> Found ${items.length} items');
           if (items.isNotEmpty) {
                 print('   Example: ${items[0]['descripcion']}');
             }
         }
     }
  } catch (e) {
      print('[❌ EXCEPTION] -> $e');
  }
}
