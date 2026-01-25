import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Análisis DETALLADO de matching - muestra productos específicos y calidad de matches

void main() async {
  print('=== ANÁLISIS DETALLADO DE MATCHING - PRODUCTOS CORONADOS ===\n');
  
  final monarcaPromos = await getMonarcaCoronados();
  
  if (monarcaPromos.isEmpty) {
    print('No se encontraron productos Coronados');
    return;
  }
  
  print('Total Coronados: ${monarcaPromos.length}');
  print('Analizando primeros 5 productos en detalle...\n');
  
  for (var i = 0; i < monarcaPromos.length && i < 5; i++) {
    final product = monarcaPromos[i];
    await analyzeProductInDetail(product, i + 1);
    print('\n${'=' * 80}\n');
  }
}

Future<void> analyzeProductInDetail(Map<String, dynamic> product, int index) async {
  final name = product['description'] as String;
  final brand = product['brand'] as String?;
  final price = product['price'];
  
  print('PRODUCTO $index: $name');
  if (brand != null) print('Marca: $brand');
  print('Precio Monarca: \$$price');
  print('-' * 80);
  
  // Buscar en Vea
  print('\nVEA:');
  final veaResults = await searchInVea(name, brand);
  if (veaResults.isEmpty) {
    print('  [X] No encontrado');
  } else {
    print('  [✓] ${veaResults.length} resultados:');
    for (var j = 0; j < veaResults.length && j < 3; j++) {
      final match = veaResults[j];
      final matchName = match['productName'] ?? 'N/A';
      final matchPrice = match['price'] ?? 0;
      final similarity = calculateSimilarity(name, matchName);
      
      print('    ${j + 1}. $matchName');
      print('       Precio: \$$matchPrice | Similitud: ${(similarity * 100).toStringAsFixed(1)}%');
      
      if (similarity >= 0.75) {
        print('       ✓ MATCH VÁLIDO');
      } else if (similarity >= 0.5) {
        print('       ? MATCH DUDOSO');
      } else {
        print('       X PROBABLEMENTE FALSO POSITIVO');
      }
    }
  }
  
  // Buscar en Carrefour
  print('\nCARREFOUR:');
  final carrefourResults = await searchInCarrefour(name, brand);
  if (carrefourResults.isEmpty) {
    print('  [X] No encontrado');
  } else {
    print('  [✓] ${carrefourResults.length} resultados:');
    for (var j = 0; j < carrefourResults.length && j < 3; j++) {
      final match = carrefourResults[j];
      final matchName = match['productName'] ?? 'N/A';
      final matchPrice = match['price'] ?? 0;
      final similarity = calculateSimilarity(name, matchName);
      
      print('    ${j + 1}. $matchName');
      print('       Precio: \$$matchPrice | Similitud: ${(similarity * 100).toStringAsFixed(1)}%');
      
      if (similarity >= 0.75) {
        print('       ✓ MATCH VÁLIDO');
      } else if (similarity >= 0.5) {
        print('       ? MATCH DUDOSO');
      } else {
        print('       X PROBABLEMENTE FALSO POSITIVO');
      }
    }
  }
  
  // Buscar en La Coope
  print('\nLA COOPE:');
  final coopeResults = await searchInCoope(name, brand);
  if (coopeResults.isEmpty) {
    print('  [X] No encontrado');
  } else {
    print('  [✓] ${coopeResults.length} resultados:');
    for (var j = 0; j < coopeResults.length && j < 3; j++) {
      final match = coopeResults[j];
      final matchName = match['descripcion'] ?? 'N/A';
      final matchPrice = match['importe'] ?? 0;
      final similarity = calculateSimilarity(name, matchName);
      
      print('    ${j + 1}. $matchName');
      print('       Precio: \$$matchPrice | Similitud: ${(similarity * 100).toStringAsFixed(1)}%');
      
      if (similarity >= 0.75) {
        print('       ✓ MATCH VÁLIDO');
      } else if (similarity >= 0.5) {
        print('       ? MATCH DUDOSO');
      } else {
        print('       X PROBABLEMENTE FALSO POSITIVO');
      }
    }
  }
}

double calculateSimilarity(String str1, String str2) {
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

Future<List<Map<String, dynamic>>> getMonarcaCoronados() async {
  try {
    final url = 'https://api.monarcadigital.com.ar/products/search?query=coronados&page=0&size=20';
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

Future<List<Map<String, dynamic>>> searchInVea(String productName, String? brand) async {
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
    final query = keywords.join(' ');
    
    final url = 'https://www.vea.com.ar/$query?_q=$query&map=ft';
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
        return products.map((e) => e as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {
    // Silenciar
  }
  return [];
}

Future<List<Map<String, dynamic>>> searchInCarrefour(String productName, String? brand) async {
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
    final query = keywords.join(' ');
    
    final url = 'https://www.carrefour.com.ar/$query?_q=$query&map=ft';
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
        return products.map((e) => e as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {
    // Silenciar
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
    final query = keywords.join(' ');
    
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://www.lacoopeencasa.coop/api/catalog/search?q=$encodedQuery&page=1&pageSize=10';
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = data['items'] as List?;
      if (items != null) {
        return items.map((e) => e as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {
    // Silenciar
  }
  return [];
}
