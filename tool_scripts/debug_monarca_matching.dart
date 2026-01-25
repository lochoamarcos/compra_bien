import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// DEBUG PROFUNDO: Ver exactamente qué pasa cuando buscamos en Monarca

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('  DEBUG: ¿Por qué tan bajo matching hacia Monarca?');
  print('═══════════════════════════════════════════════════════════\n');
  
  // Obtener productos de Vea que fallaron con Monarca
  print('Obteniendo productos de Vea...\n');
  final veaProducts = await getVeaPromotions(limit: 15);
  
  if (veaProducts.isEmpty) {
    print('No se pudieron obtener productos de Vea');
    return;
  }
  
  int found = 0;
  int notFound = 0;
  List<Map<String, dynamic>> failures = [];
  
  for (var i = 0; i < veaProducts.length; i++) {
    final product = veaProducts[i];
    final name = product['name'] as String;
    final brand = product['brand'] as String?;
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('${i + 1}. $name');
    if (brand != null) print('   Marca: $brand');
    
    // Construir query
    List<String> keywords = [];
    if (brand != null && brand.isNotEmpty) keywords.add(brand);
    
    final cleanName = name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .take(3);
    
    keywords.addAll(cleanName);
    final query = keywords.join(' ');
    
    print('   Query enviado a Monarca: "$query"');
    
    // Buscar en Monarca
    final results = await searchInMonarcaDetailed(query);
    
    if (results.isEmpty) {
      notFound++;
      print('   ❌ NO ENCONTRADO en Monarca');
      failures.add({
        'name': name,
        'brand': brand,
        'query': query,
      });
    } else {
      found++;
      print('   ✅ ENCONTRADO - ${results.length} resultados:');
      for (var j = 0; j < results.length && j < 3; j++) {
        final match = results[j];
        final matchName = match['description'] as String;
        final matchBrand = match['brand'] as String?;
        final similarity = _calculateSimilarity(name, matchName);
        
        print('      ${j + 1}. $matchName');
        if (matchBrand != null) print('         Marca: $matchBrand');
        print('         Similitud: ${(similarity * 100).toStringAsFixed(1)}%');
        
        if (similarity >= 0.7) {
          print('         ✓ MATCH VÁLIDO');
        } else if (similarity >= 0.4) {
          print('         ? MATCH DUDOSO - podría ser el mismo');
        } else {
          print('         ✗ FALSO POSITIVO - nombres muy diferentes');
        }
      }
    }
    
    print('');
    await Future.delayed(Duration(milliseconds: 300));
  }
  
  // RESUMEN
  print('\n═══════════════════════════════════════════════════════════');
  print('  RESUMEN');
  print('═══════════════════════════════════════════════════════════\n');
  
  print('Total analizados: ${veaProducts.length}');
  print('Encontrados: $found (${((found / veaProducts.length) * 100).toStringAsFixed(1)}%)');
  print('No encontrados: $notFound (${((notFound / veaProducts.length) * 100).toStringAsFixed(1)}%)');
  
  if (failures.isNotEmpty) {
    print('\n─── PRODUCTOS QUE MONARCA NO TIENE ───\n');
    for (var failure in failures) {
      print('• ${failure['name']}');
      print('  Query usado: "${failure['query']}"');
      
      // Intentar búsqueda más agresiva (solo marca)
      if (failure['brand'] != null && failure['brand'].toString().isNotEmpty) {
        final brandOnly = failure['brand'] as String;
        print('  Probando solo con marca: "$brandOnly"');
        
        final brandResults = await searchInMonarcaDetailed(brandOnly);
        if (brandResults.isNotEmpty) {
          print('  ⚠️  ATENCIÓN: Encontró ${brandResults.length} productos de esa marca');
          print('  → Posible mejora: buscar marca + categoría');
        } else {
          print('  → Monarca NO vende esa marca');
        }
      }
      print('');
    }
  }
  
  print('\n═══════════════════════════════════════════════════════════');
  print('  CONCLUSIÓN');
  print('═══════════════════════════════════════════════════════════\n');
  
  if (notFound > veaProducts.length * 0.5) {
    print('❗ ALTA tasa de no-encontrados (>50%)');
    print('Posibles causas:');
    print('  1. Monarca es regional, Vea es nacional → catálogos diferentes');
    print('  2. Monarca enfocado en básicos, Vea tiene gourmet/importados');
    print('  3. Las búsquedas funcionan pero productos realmente no existen');
  } else {
    print('✅ Tasa razonable - búsquedas funcionan correctamente');
  }
}

double _calculateSimilarity(String str1, String str2) {
  final words1 = str1.toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(' ')
      .where((w) => w.length > 2)
      .toSet();
  
  final words2 = str2.toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(' ')
      .where((w) => w.length > 2)
      .toSet();
  
  if (words1.isEmpty || words2.isEmpty) return 0.0;
  
  final intersection = words1.intersection(words2).length;
  final union = words1.union(words2).length;
  
  return union > 0 ? intersection / union : 0.0;
}

Future<List<Map<String, dynamic>>> getVeaPromotions({int limit = 15}) async {
  try {
    final url = 'https://www.vea.com.ar/ofertas?_q=ofertas&map=ft';
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
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
  } catch (e) {
    print('Error obteniendo Vea: $e');
  }
  return [];
}

Future<List<Map<String, dynamic>>> searchInMonarcaDetailed(String query) async {
  try {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.monarcadigital.com.ar/products/search?query=$encodedQuery&page=0&size=10';
    
    print('   API URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    print('   Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      List<dynamic> content = [];
      if (data.containsKey('products')) {
        var productsVal = data['products'];
        if (productsVal is Map) {
          content = productsVal['content'] ?? [];
          print('   Productos en respuesta: ${content.length}');
        } else if (productsVal is List) {
          content = productsVal;
          print('   Productos en respuesta: ${content.length}');
        }
      } else if (data.containsKey('content')) {
        content = data['content'];
        print('   Productos en respuesta: ${content.length}');
      }
      
      return content.map((e) => e as Map<String, dynamic>).toList();
    }
  } catch (e) {
    print('   Error: $e');
  }
  return [];
}
