import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('=== DIAGNÓSTICO PROFUNDO LA COOPE ===\n');
  
  // Probar diferentes endpoints
  print('1. Probando endpoint /api/catalog/search (viejo)...');
  await testOldEndpoint();
  
  print('\n2. Probando endpoint /api/articulos/pagina (nuevo) con diferentes queries...');
  await testNewEndpoint('VINO');
  await testNewEndpoint('');  // Empty query
  
  print('\n3. Probando con ofertas=true...');
  await testNewEndpointWithPromos();
  
  print('\n4. Probando endpoint de categorías...');
  await testCategories();
}

Future<void> testOldEndpoint() async {
  try {
    final response = await http.get(
      Uri.parse('https://www.lacoopeencasa.coop/api/catalog/search?q=vino&page=1&pageSize=5'),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    print('   Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print('   Keys: ${data.keys}');
      if (data['items'] != null) {
        print('   ✓ Encontrados ${(data['items'] as List).length} items');
      }
    }
  } catch (e) {
    print('   ✗ Error: $e');
  }
}

Future<void> testNewEndpoint(String term) async {
  print('\n   Query: "$term"');
  try {
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
        "termino": term,
        "tipo_relacion": "busqueda"
      },
      "pagina": 0
    };
    
    final response = await http.post(
      Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
      },
      body: json.encode(payload),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      print('   Estado: ${data['estado']}');
      print('   Mensaje: ${data['mensaje'] ?? 'N/A'}');
      
      if (data['datos'] != null) {
        print('   Keys en datos: ${(data['datos'] as Map).keys}');
        if (data['datos']['articulos'] != null) {
          print('   Artículos: ${(data['datos']['articulos'] as List).length}');
        }
      }
    } else {
      print('   HTTP Status: ${response.statusCode}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> testNewEndpointWithPromos() async {
  try {
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
        "ofertas": true,  // OFERTAS
        "primer_filtro": "",
        "termino": "",
        "tipo_relacion": "busqueda"
      },
      "pagina": 0
    };
    
    final response = await http.post(
      Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
      },
      body: json.encode(payload),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      print('   Estado: ${data['estado']}');
      
      if (data['datos'] != null && data['datos']['articulos'] != null) {
        final articulos = data['datos']['articulos'] as List;
        print('   ✓ Encontrados ${articulos.length} productos en oferta');
        if (articulos.isNotEmpty) {
          print('   Ejemplo: ${articulos[0]['descripcion']}');
        }
      }
    }
  } catch (e) {
    print('   Error: $e');
  }
}

Future<void> testCategories() async {
  try {
    final response = await http.get(
      Uri.parse('https://api.lacoopeencasa.coop/api/categorias'),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print('   ✓ Categorías obtenidas');
      print('   Keys: ${data.keys}');
    } else {
      print('   Status: ${response.statusCode}');
    }
  } catch (e) {
    print('   Error: $e');
  }
}
