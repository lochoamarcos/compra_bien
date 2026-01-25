import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Script para PROBAR el nuevo endpoint de La Coope /api/articulos/pagina_busqueda

void main() async {
  print('=== PRUEBA DEL ENDPOINT CORRECTO DE LA COOPE ===\n');
  
  // Probar búsquedas básicas
  await testSearch('COCA_COLA');
  await testSearch('LECHE');
  await testSearch('VINO');
  await testSearch('FIDEOS');
  
  print('\n=== PRUEBA DE PROMOCIONES/OFERTAS ===\n');
  await testPromotions();
  
  print('\n=== PRUEBA DE CATEGORÍAS ===\n');
  await testCategories();
}

Future<void> testSearch(String term) async {
  print('Buscando: "$term"');
  
  try {
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
        "ofertas": false,
        "primer_filtro": "",
        "termino": term,  // Ya viene con underscores
        "tipo_relacion": "busqueda"
      }
    };
    
    final response = await http.post(
      Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N)',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
        'Accept': 'application/json, text/plain, */*',
      },
      body: json.encode(payload),
    ).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final datos = data['datos'];
        final articulos = datos['articulos'] as List?;
        
        if (articulos != null && articulos.isNotEmpty) {
          print('  ✅ Encontrados ${articulos.length} productos');
          print('  Total en catálogo: ${datos['cantidad_articulos']}');
          
          // Mostrar primeros 3
          for (var i = 0; i < articulos.length && i < 3; i++) {
            final art = articulos[i];
            print('    ${i + 1}. ${art['descripcion']}');
            print('       \$${art['precio']} - ${art['marca_desc']}');
            if (art['existe_promo'] == '1') {
              print('       🎯 EN PROMO');
            }
          }
        } else {
          print('  ⚠️  Sin resultados');
        }
      } else {
        print('  ❌ Estado: ${data['estado']} - ${data['mensaje']}');
      }
    } else {
      print('  ❌ HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
  
  print('');
}

Future<void> testPromotions() async {
  print('Obteniendo productos destacados (Gran Barata)...');
  
  try {
    final response = await http.get(
      Uri.parse('https://api.lacoopeencasa.coop/api/contenido/articulos_sector?tag=articulos_destacados&id_template=117'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
      },
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final articulos = data['datos'] as List;
        print('  ✅ Encontrados ${articulos.length} productos en oferta');
        
        for (var i = 0; i < articulos.length && i < 5; i++) {
          final art = articulos[i];
          print('    ${i + 1}. ${art['descripcion']}');
          print('       Antes: \$${art['precio_anterior']} → Ahora: \$${art['precio_promo']}');
          if (art['descuento_porcentaje_promo'] != null) {
            print('       📍 ${art['descuento_porcentaje_promo']}% OFF');
          }
        }
      }
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
  
  print('');
}

Future<void> testCategories() async {
  print('Obteniendo árbol de categorías...');
  
  try {
    final response = await http.get(
      Uri.parse('https://api.lacoopeencasa.coop/api/categorias/arbol'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.lacoopeencasa.coop/',
      },
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final categorias = data['datos'] as List;
        print('  ✅ ${categorias.length} categorías principales');
        
        for (var i = 0; i < categorias.length && i < 5; i++) {
          final cat = categorias[i];
          final hijos = cat['hijos'] as List? ?? [];
          print('    ${i + 1}. ${cat['descripcion']} (${hijos.length} subcategorías)');
        }
      }
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
}
