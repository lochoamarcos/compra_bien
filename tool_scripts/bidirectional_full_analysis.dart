import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test bidireccional completo: todas las combinaciones de supermercados

void main() async {
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║     ANÁLISIS BIDIRECCIONAL COMPLETO - TODOS LOS SÚPER    ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');
  
  // FASE 1: Monarca → Otros
  print('═══ FASE 1: Productos MONARCA (Coronados) ═══\n');
  final monarcaProducts = await getMonarcaCoronados(size: 20);
  await analyzeSource('Monarca', monarcaProducts);
  
  // FASE 2: Vea → Otros
  print('\n\n═══ FASE 2: Productos VEA (Primeros 20 en oferta) ═══\n');
  final veaProducts = await getVeaPromotions(limit: 20);
  await analyzeSource('Vea', veaProducts);
  
  // FASE 3: Carrefour → Otros
  print('\n\n═══ FASE 3: Productos CARREFOUR (Primeros 20 en oferta) ═══\n');
  final carrefourProducts = await getCarrefourPromotions(limit: 20);
  await analyzeSource('Carrefour', carrefourProducts);
  
  // FASE 4: La Coope → Otros
  print('\n\n═══ FASE 4: Productos LA COOPE (Gran Barata) ═══\n');
  final coopeProducts = await getCoopePromotions(limit: 20);
  await analyzeSource('La Coope', coopeProducts);
  
  print('\n\n╔═══════════════════════════════════════════════════════════╗');
  print('║                  ANÁLISIS COMPLETADO                      ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');
}

Future<void> analyzeSource(String sourceName, List<Map<String, dynamic>> products) async {
  if (products.isEmpty) {
    print('⚠️  No se encontraron productos en $sourceName\n');
    return;
  }
  
  print('Productos de $sourceName: ${products.length}\n');
  
  // Contadores
  Map<String, int> matchCounts = {
    'Monarca': 0,
    'Vea': 0,
    'Carrefour': 0,
    'La Coope': 0,
  };
  
  for (var i = 0; i < products.length; i++) {
    final product = products[i];
    final name = product['name'] as String;
    final brand = product['brand'] as String?;
    
    print('${i + 1}. $name');
    
    // Buscar en todos los demás (excepto el source)
    if (sourceName != 'Monarca') {
      final monarcaResults = await searchInMonarca(name, brand);
      if (monarcaResults.isNotEmpty) {
        matchCounts['Monarca'] = matchCounts['Monarca']! + 1;
        print('   ✓ Monarca');
      }
    }
    
    if (sourceName != 'Vea') {
      final veaResults = await searchInVea(name, brand);
      if (veaResults.isNotEmpty) {
        matchCounts['Vea'] = matchCounts['Vea']! + 1;
        print('   ✓ Vea');
      }
    }
    
    if (sourceName != 'Carrefour') {
      final carrefourResults = await searchInCarrefour(name, brand);
      if (carrefourResults.isNotEmpty) {
        matchCounts['Carrefour'] = matchCounts['Carrefour']! + 1;
        print('   ✓ Carrefour');
      }
    }
    
    if (sourceName != 'La Coope') {
      final coopeResults = await searchInCoope(name, brand);
      if (coopeResults.isNotEmpty) {
        matchCounts['La Coope'] = matchCounts['La Coope']! + 1;
        print('   ✓ La Coope');
      }
    }
    
    await Future.delayed(Duration(milliseconds: 200));
  }
  
  // Resumen
  print('\n─── RESUMEN $sourceName → Otros ───');
  matchCounts.forEach((target, count) {
    if (target != sourceName) {
      final percentage = (count / products.length * 100).toStringAsFixed(1);
      print('$sourceName → $target: $count/${products.length} ($percentage%)');
    }
  });
}

// === OBTENCIÓN DE PRODUCTOS ===

Future<List<Map<String, dynamic>>> getMonarcaCoronados({int size = 20}) async {
  try {
    final url = 'https://api.monarcadigital.com.ar/products/search?query=coronados&page=0&size=$size';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'});
    
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
      
      return content.map((e) => {
        'name': e['description'] as String,
        'brand': e['brand'] as String?,
      }).toList();
    }
  } catch (e) {}
  return [];
}

Future<List<Map<String, dynamic>>> getVeaPromotions({int limit = 20}) async {
  try {
    // Usar búsqueda genérica de productos en oferta
    final url = 'https://www.vea.com.ar/ofertas?_q=ofertas&map=ft';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final regex = RegExp(r'"products":\s*(\[.*?\])', multiLine: true, dotAll: true);
      final match = regex.firstMatch(response.body);
      
      if (match != null) {
        final jsonStr = match.group(1)!;
        final products = json.decode(jsonStr) as List;
        
        return products.take(limit).map((e) => {
          'name': e['productName'] as String? ?? '',
          'brand': e['brand'] as String?,
        }).toList();
      }
    }
  } catch (e) {}
  return [];
}

Future<List<Map<String, dynamic>>> getCarrefourPromotions({int limit = 20}) async {
  try {
    final url = 'https://www.carrefour.com.ar/ofertas?_q=ofertas&map=ft';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final regex = RegExp(r'"products":\s*(\[.*?\])', multiLine: true, dotAll: true);
      final match = regex.firstMatch(response.body);
      
      if (match != null) {
        final jsonStr = match.group(1)!;
        final products = json.decode(jsonStr) as List;
        
        return products.take(limit).map((e) => {
          'name': e['productName'] as String? ?? '',
          'brand': e['brand'] as String?,
        }).toList();
      }
    }
  } catch (e) {}
  return [];
}

Future<List<Map<String, dynamic>>> getCoopePromotions({int limit = 20}) async {
  try {
    final response = await http.get(
      Uri.parse('https://api.lacoopeencasa.coop/api/contenido/articulos_sector?tag=articulos_destacados&id_template=117'),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final articulos = data['datos'] as List;
        return articulos.take(limit).map((e) => {
          'name': e['descripcion'] as String,
          'brand': e['marca_desc'] as String?,
        }).toList();
      }
    }
  } catch (e) {}
  return [];
}

// === BÚSQUEDAS ===

Future<List<Map<String, dynamic>>> searchInMonarca(String name, String? brand) async {
  try {
    List<String> keywords = [];
    if (brand != null && brand.isNotEmpty) keywords.add(brand);
    
    final cleanName = name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .take(3);
    
    keywords.addAll(cleanName);
    final query = keywords.join(' ');
    
    final url = 'https://api.monarcadigital.com.ar/products/search?query=$query&page=0&size=5';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(Duration(seconds: 8));
    
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
  } catch (e) {}
  return [];
}

Future<List<Map<String, dynamic>>> searchInVea(String name, String? brand) async {
  try {
    List<String> keywords = [];
    if (brand != null && brand.isNotEmpty) keywords.add(brand);
    
    final cleanName = name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .take(3);
    
    keywords.addAll(cleanName);
    final query = keywords.join(' ');
    
    final url = 'https://www.vea.com.ar/$query?_q=$query&map=ft';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(Duration(seconds: 8));
    
    if (response.statusCode == 200) {
      final regex = RegExp(r'"products":\s*(\[.*?\])', multiLine: true, dotAll: true);
      final match = regex.firstMatch(response.body);
      if (match != null) {
        final jsonStr = match.group(1)!;
        final products = json.decode(jsonStr) as List;
        return products.map((e) => e as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {}
  return [];
}

Future<List<Map<String, dynamic>>> searchInCarrefour(String name, String? brand) async {
  try {
    List<String> keywords = [];
    if (brand != null && brand.isNotEmpty) keywords.add(brand);
    
    final cleanName = name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .take(3);
    
    keywords.addAll(cleanName);
    final query = keywords.join(' ');
    
    final url = 'https://www.carrefour.com.ar/$query?_q=$query&map=ft';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(Duration(seconds: 8));
    
    if (response.statusCode == 200) {
      final regex = RegExp(r'"products":\s*(\[.*?\])', multiLine: true, dotAll: true);
      final match = regex.firstMatch(response.body);
      if (match != null) {
        final jsonStr = match.group(1)!;
        final products = json.decode(jsonStr) as List;
        return products.map((e) => e as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {}
  return [];
}

Future<List<Map<String, dynamic>>> searchInCoope(String name, String? brand) async {
  try {
    final stopWords = ['con', 'para', 'sin', 'los', 'las', 'del', 'de', 'la', 'el', 'en'];
    
    List<String> words = name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    
    if (brand != null && brand.isNotEmpty) {
      words.insert(0, brand.toLowerCase());
    }
    
    final query = words.take(3).join('_').toUpperCase();
    
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
    ).timeout(Duration(seconds: 8));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final articulos = data['datos']['articulos'] as List?;
        if (articulos != null) {
          return articulos.map((e) => e as Map<String, dynamic>).toList();
        }
      }
    }
  } catch (e) {}
  return [];
}
