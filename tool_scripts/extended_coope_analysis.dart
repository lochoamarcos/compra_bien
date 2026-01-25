import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test EXTENDIDO de La Coope - más productos para entender el 60%

void main() async {
  print('=== ANÁLISIS EXTENDIDO LA COOPE ===\n');
  print('Objetivo: Entender por qué solo 60% de matching\n');
  
  // Obtener MÁS productos Coronados
  final monarcaProducts = await getMonarcaCoronados(size: 50);
  print('Productos Coronados totales: ${monarcaProducts.length}\n');
  
  if (monarcaProducts.isEmpty) {
    print('No se encontraron productos');
    return;
  }
  
  int found = 0;
  int notFound = 0;
  List<String> notFoundNames = [];
  List<String> foundNames = [];
  
  print('Probando con ${monarcaProducts.length} productos...\n');
  
  for (var i = 0; i < monarcaProducts.length; i++) {
    final product = monarcaProducts[i];
    final name = product['description'] as String;
    final brand = product['brand'] as String?;
    
    final coopeResults = await searchInCoope(name, brand);
    
    if (coopeResults.isNotEmpty) {
      found++;
      foundNames.add(name);
      print('✅ ${i + 1}. $name → ${coopeResults[0]['descripcion']}');
    } else {
      notFound++;
      notFoundNames.add(name);
      print('❌ ${i + 1}. $name → NO ENCONTRADO');
    }
    
    // Delay para no saturar API
    if (i < monarcaProducts.length - 1) {
      await Future.delayed(Duration(milliseconds: 200));
    }
  }
  
  print('\n═══════════════════════════════════════════════');
  print('RESULTADOS FINALES');
  print('═══════════════════════════════════════════════');
  print('Total analizados: ${monarcaProducts.length}');
  print('Encontrados: $found (${((found / monarcaProducts.length) * 100).toStringAsFixed(1)}%)');
  print('No encontrados: $notFound (${((notFound / monarcaProducts.length) * 100).toStringAsFixed(1)}%)');
  
  if (notFoundNames.isNotEmpty) {
    print('\n--- PRODUCTOS NO ENCONTRADOS ---');
    for (var name in notFoundNames.take(10)) {
      print('  • $name');
    }
    if (notFoundNames.length > 10) {
      print('  ... y ${notFoundNames.length - 10} más');
    }
  }
  
  print('\n═══════════════════════════════════════════════\n');
  
  // Analizar patrones
  print('📊 ANÁLISIS DE PATRONES:\n');
  
  // Categorías de productos no encontrados
  final categorias = {
    'Bebidas': 0,
    'Limpieza': 0,
    'Alimentos': 0,
    'Otros': 0,
  };
  
  for (var name in notFoundNames) {
    final lower = name.toLowerCase();
    if (lower.contains('cerveza') || lower.contains('vino') || lower.contains('gaseosa')) {
      categorias['Bebidas'] = categorias['Bebidas']! + 1;
    } else if (lower.contains('detergente') || lower.contains('lavandina') || lower.contains('jabon')) {
      categorias['Limpieza'] = categorias['Limpieza']! + 1;
    } else if (lower.contains('fideos') || lower.contains('aceite') || lower.contains('sal')) {
      categorias['Alimentos'] = categorias['Alimentos']! + 1;
    } else {
      categorias['Otros'] = categorias['Otros']! + 1;
    }
  }
  
  print('Categorías de productos NO encontrados:');
  categorias.forEach((cat, count) {
    if (count > 0) {
      print('  $cat: $count');
    }
  });
}

Future<List<Map<String, dynamic>>> getMonarcaCoronados({int size = 50}) async {
  try {
    final url = 'https://api.monarcadigital.com.ar/products/search?query=coronados&page=0&size=$size';
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      List<dynamic> content = [];
      if (data.containsKey('products')) {
        var productsVal = data['products'];
        if (productsVal is Map) {
          content = productsVal['content'] ?? [];
        } else if (productsVal is List) {
          content = productsVal;
        }
      } else if (data.containsKey('content')) {
        content = data['content'];
      }
      
      return content.map((e) => e as Map<String, dynamic>).toList();
    }
  } catch (e) {
    print('Error en Monarca: $e');
  }
  return [];
}

Future<List<Map<String, dynamic>>> searchInCoope(String productName, String? brand) async {
  try {
    List<String> keywords = [];
    if (brand != null && brand.isNotEmpty) {
      keywords.add(brand);
    }
    
    final cleanName = productName
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .toLowerCase()
        .split(' ')
        .where((w) => w.length > 2 && !['con', 'para', 'sin', 'los', 'las', 'del'].contains(w))
        .toList();
    
    keywords.addAll(cleanName.take(3));
    final query = keywords.join('_').toUpperCase();
    
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
        "termino": query,
        "tipo_relacion": "busqueda"
      }
    };
    
    final response = await http.post(
      Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5) AppleWebKit/537.36',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
        'Accept': 'application/json, text/plain, */*',
      },
      body: json.encode(payload),
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final articulos = data['datos']['articulos'] as List?;
        if (articulos != null) {
          return articulos.map((e) => e as Map<String, dynamic>).toList();
        }
      }
    }
  } catch (e) {
    // Silenciar timeouts
  }
  return [];
}
