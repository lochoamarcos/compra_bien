import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test para comparar versión original vs mejorada de La Coope

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('  COMPARACIÓN: La Coope Original vs Mejorada');
  print('═══════════════════════════════════════════════════════════\n');
  
  // Obtener productos de prueba
  final testProducts = await getMonarcaCoronados(size: 30);
  print('Productos de prueba: ${testProducts.length}\n');
  
  if (testProducts.isEmpty) {
    print('No se pudieron obtener productos de Monarca');
    return;
  }
  
  int originalFound = 0;
  int improvedFound = 0;
  
  List<String> improvedExtraFinds = [];
  
  print('Iniciando comparación...\n');
  
  for (var i = 0; i < testProducts.length; i++) {
    final product = testProducts[i];
    final name = product['description'] as String;
    final brand = product['brand'] as String?;
    
    print('${i + 1}. $name');
    
    // Probar con versión ORIGINAL (query simple)
    final originalResults = await searchOriginal(name, brand);
    final originalHasResults = originalResults.isNotEmpty;
    if (originalHasResults) originalFound++;
    
    // Probar con versión MEJORADA (con fallbacks)
    final improvedResults = await searchImproved(name, brand);
    final improvedHasResults = improvedResults.isNotEmpty;
    if (improvedHasResults) improvedFound++;
    
    // Comparar resultados
    if (originalHasResults && improvedHasResults) {
      print('   ✓✓ Ambas versiones');
    } else if (improvedHasResults && !originalHasResults) {
      print('   ⭐ MEJORADA encontró, ORIGINAL no');
      improvedExtraFinds.add(name);
    } else if (originalHasResults && !improvedHasResults) {
      print('   ⚠️  ORIGINAL encontró, MEJORADA no (raro)');
    } else {
      print('   ❌ Ninguna versión encontró');
    }
    
    await Future.delayed(Duration(milliseconds: 300));
  }
  
  // RESULTADOS
  print('\n═══════════════════════════════════════════════════════════');
  print('  RESULTADOS FINALES');
  print('═══════════════════════════════════════════════════════════\n');
  
  print('Versión ORIGINAL:  $originalFound/${testProducts.length} (${((originalFound / testProducts.length) * 100).toStringAsFixed(1)}%)');
  print('Versión MEJORADA:  $improvedFound/${testProducts.length} (${((improvedFound / testProducts.length) * 100).toStringAsFixed(1)}%)');
  
  final improvement = improvedFound - originalFound;
  if (improvement > 0) {
    print('\n🎉 MEJORA: +$improvement productos encontrados (${((improvement / testProducts.length) * 100).toStringAsFixed(1)}% más)');
    
    if (improvedExtraFinds.isNotEmpty) {
      print('\nProductos que SOLO la versión mejorada encontró:');
      for (var name in improvedExtraFinds) {
        print('  • $name');
      }
    }
  } else if (improvement < 0) {
    print('\n⚠️  PEOR: $improvement productos (versión mejorada tiene bug)');
  } else {
    print('\n➖ Sin diferencia (ambas versiones iguales)');
  }
  
  print('\n═══════════════════════════════════════════════════════════\n');
}

// VERSIÓN ORIGINAL (query simple)
Future<List<Map<String, dynamic>>> searchOriginal(String productName, String? brand) async {
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
    
    return await _searchCoope(query);
  } catch (e) {
    return [];
  }
}

// VERSIÓN MEJORADA (con fallbacks)
Future<List<Map<String, dynamic>>> searchImproved(String productName, String? brand) async {
  try {
    // Normalización más inteligente (elimina stopwords adicionales)
    final stopWords = ['con', 'para', 'sin', 'los', 'las', 'del', 'de', 'la', 'el', 'en'];
    
    List<String> words = productName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    
    // Si hay marca, priorizarla
    if (brand != null && brand.isNotEmpty && !words.contains(brand.toLowerCase())) {
      words.insert(0, brand.toLowerCase());
    }
    
    final relevantWords = words.take(3).toList();
    final query = relevantWords.join('_').toUpperCase();
    
    // Intentar búsqueda principal
    var results = await _searchCoope(query);
    if (results.isNotEmpty) return results;
    
    // FALLBACK 1: Solo 2 palabras
    if (relevantWords.length > 2) {
      final fallback1 = relevantWords.take(2).join('_').toUpperCase();
      results = await _searchCoope(fallback1);
      if (results.isNotEmpty) return results;
    }
    
    // FALLBACK 2: Solo la primera palabra
    if (relevantWords.isNotEmpty) {
      final fallback2 = relevantWords.first.toUpperCase();
      results = await _searchCoope(fallback2);
      if (results.isNotEmpty) return results;
    }
    
    return [];
  } catch (e) {
    return [];
  }
}

Future<List<Map<String, dynamic>>> _searchCoope(String query) async {
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
  } catch (e) {
    // Silenciar
  }
  return [];
}

Future<List<Map<String, dynamic>>> getMonarcaCoronados({int size = 30}) async {
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
