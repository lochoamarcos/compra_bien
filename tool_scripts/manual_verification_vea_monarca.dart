import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// VERIFICACIÓN MANUAL: 10 productos de Vea → buscar en Monarca paso a paso

void main() async {
  print('╔════════════════════════════════════════════════════════════╗');
  print('║  VERIFICACIÓN MANUAL: Vea → Monarca (Producto por Producto)  ║');
  print('╚════════════════════════════════════════════════════════════╝\n');
  
  // Obtener productos reales de Vea
  print('Obteniendo productos de Vea...\n');
  final veaProducts = await getVeaProductsDetailed();
  
  if (veaProducts.isEmpty) {
    print('❌ No se pudieron obtener productos de Vea');
    return;
  }
  
  print('✅ Obtenidos ${veaProducts.length} productos de Vea\n');
  print('═══════════════════════════════════════════════════════════════\n');
  
  int realMatches = 0;
  int noMatches = 0;
  int falsePositives = 0;
  
  for (var i = 0; i < veaProducts.length && i < 10; i++) {
    final product = veaProducts[i];
    final name = product['name'] as String;
    final brand = product['brand'] as String?;
    final price = product['price'];
    
    print('┌─────────────────────────────────────────────────────────┐');
    print('│ PRODUCTO ${i + 1}/10');
    print('├─────────────────────────────────────────────────────────┤');
    print('│ 🏷️  $name');
    if (brand != null && brand.isNotEmpty) {
      print('│ 🏭 Marca: $brand');
    }
    if (price != null) {
      print('│ 💰 Precio Vea: \$$price');
    }
    print('└─────────────────────────────────────────────────────────┘\n');
    
    // Construir queries de búsqueda
    final queries = _buildSearchQueries(name, brand);
    
    print('Intentando ${queries.length} variaciones de búsqueda en Monarca:\n');
    
    bool foundMatch = false;
    
    for (var q = 0; q < queries.length; q++) {
      final query = queries[q];
      print('   Intento ${q + 1}: "$query"');
      
      final results = await searchMonarca(query);
      
      if (results.isEmpty) {
        print('      ❌ Sin resultados\n');
        continue;
      }
      
      print('      📦 ${results.length} resultados:');
      
      // Analizar cada resultado
      for (var r = 0; r < results.length && r < 3; r++) {
        final result = results[r];
        final resultName = result['description'] as String;
        final resultBrand = result['brand'] as String?;
        final resultPrice = result['price'];
        
        final similarity = _calculateSimilarity(name, resultName);
        
        print('         ${r + 1}. $resultName');
        if (resultBrand != null) print('            Marca: $resultBrand');
        if (resultPrice != null) print('            Precio: \$$resultPrice');
        print('            Similitud nombres: ${(similarity * 100).toStringAsFixed(1)}%');
        
        // Determinar si es match real
        bool isBrandMatch = false;
        if (brand != null && resultBrand != null) {
          isBrandMatch = brand.toLowerCase() == resultBrand.toLowerCase();
        }
        
        if (similarity > 0.7 || (isBrandMatch && similarity > 0.4)) {
          print('            ✅ MATCH REAL');
          foundMatch = true;
        } else if (similarity > 0.4) {
          print('            ⚠️  POSIBLE MATCH (revisar manualmente)');
        } else {
          print('            ❌ Producto diferente');
        }
      }
      print('');
      
      if (foundMatch) break;
    }
    
    if (foundMatch) {
      realMatches++;
      print('   🎯 RESULTADO: ENCONTRADO en Monarca\n');
    } else {
      noMatches++;
      print('   ❌ RESULTADO: NO EXISTE en Monarca o nombre muy diferente\n');
    }
    
    print('═══════════════════════════════════════════════════════════════\n');
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  // RESUMEN FINAL
  print('\n╔════════════════════════════════════════════════════════════╗');
  print('║                    RESUMEN FINAL                           ║');
  print('╠════════════════════════════════════════════════════════════╣');
  print('║ Productos analizados: 10                                   ║');
  print('║ ✅ Encontrados en Monarca: $realMatches                                 ║');
  print('║ ❌ NO en Monarca: $noMatches                                       ║');
  print('║ Tasa de matching: ${(realMatches / 10 * 100).toStringAsFixed(1)}%                              ║');
  print('╚════════════════════════════════════════════════════════════╝\n');
  
  if (noMatches > 5) {
    print('💡 CONCLUSIÓN:');
    print('   Monarca tiene un catálogo MUY diferente a Vea.');
    print('   Esto es NORMAL para un super regional vs uno nacional.\n');
  }
}

List<String> _buildSearchQueries(String name, String? brand) {
  List<String> queries = [];
  
  // Query 1: Marca + primeras 2 palabras clave
  if (brand != null && brand.isNotEmpty) {
    final words = name.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .take(2)
        .join(' ');
    queries.add('$brand $words');
  }
  
  // Query 2: Primeras 3 palabras del nombre
  final words = name.toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(' ')
      .where((w) => w.length > 2)
      .toList();
  
  if (words.length >= 3) {
    queries.add(words.take(3).join(' '));
  }
  
  // Query 3: Solo marca (si hay)
  if (brand != null && brand.isNotEmpty) {
    queries.add(brand);
  }
  
  // Query 4: Primera palabra significativa
  if (words.isNotEmpty) {
    queries.add(words.first);
  }
  
  return queries;
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

Future<List<Map<String, dynamic>>> getVeaProductsDetailed() async {
  try {
    // Buscar productos en oferta con API directa
    final url = 'https://www.vea.com.ar/api/catalog_system/pub/products/search?_from=0&_to=15&ft=oferta';
    
    print('URL: $url\n');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      
      List<Map<String, dynamic>> products = [];
      
      for (var item in data) {
        final name = item['productName'] as String? ?? '';
        if (name.isEmpty) continue; // Skip productos sin nombre
        
        final brand = item['brand'] as String?;
        
        // Extraer precio
        dynamic price;
        final items = item['items'];
        if (items != null && items is List && items.isNotEmpty) {
          final sellers = items[0]['sellers'];
          if (sellers != null && sellers is List && sellers.isNotEmpty) {
            final commertialOffer = sellers[0]['commertialOffer'];
            if (commertialOffer != null) {
              price = commertialOffer['Price'];
            }
          }
        }
        
        products.add({
          'name': name,
          'brand': brand,
          'price': price,
        });
      }
      
      return products;
    }
  } catch (e) {
    print('Error: $e');
  }
  return [];
}

Future<List<Map<String, dynamic>>> searchMonarca(String query) async {
  try {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.monarcadigital.com.ar/products/search?query=$encodedQuery&page=0&size=5';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
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
