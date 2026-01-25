import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Script exhaustivo para analizar el matching de productos promocionales entre supermercados
/// Verifica cómo los productos de un súper se encuentran (o no) en los demás

void main() async {
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║   ANÁLISIS EXHAUSTIVO DE MATCHING ENTRE SUPERMERCADOS   ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  // FASE 1: Obtener productos Coronados de Monarca
  print('📊 FASE 1: Productos Coronados de Monarca\n');
  final monarcaPromos = await getMonarcaCoronados();
  print('\n✅ Total de Coronados encontrados: ${monarcaPromos.length}\n');

  if (monarcaPromos.isEmpty) {
    print('❌ No se encontraron productos Coronados en Monarca');
    return;
  }

  // Limitar análisis a los primeros 15 productos
  final productsToAnalyze = monarcaPromos.take(15).toList();
  
  print('═══════════════════════════════════════════════════════════\n');
  print('🔍 Analizando ${productsToAnalyze.length} productos Coronados...\n');
  print('═══════════════════════════════════════════════════════════\n');

  int totalAnalyzed = 0;
  int foundInVea = 0;
  int foundInCarrefour = 0;
  int foundInCoope = 0;
  
  for (var i = 0; i < productsToAnalyze.length; i++) {
    final product = productsToAnalyze[i];
    final description = product['description'] as String;
    final brand = product['brand'] as String?;
    final price = product['price'];
    
    print('┌─────────────────────────────────────────────────────────┐');
    print('│ PRODUCTO ${(i + 1).toString().padLeft(2, '0')}/${productsToAnalyze.length}');
    print('├─────────────────────────────────────────────────────────┤');
    print('│ 🏷️  $description');
    if (brand != null && brand.isNotEmpty) {
      print('│ 🏭 Marca: $brand');
    }
    print('│ 💰 Precio Monarca: \$$price');
    print('└─────────────────────────────────────────────────────────┘\n');
    
    totalAnalyzed++;
    
    // Buscar en Vea
    print('   🔎 Buscando en Vea...');
    final veaResults = await searchInVea(description, brand);
    if (veaResults.isNotEmpty) {
      foundInVea++;
      print('   ✅ Encontrado ${veaResults.length} resultados en Vea:');
      for (var j = 0; j < veaResults.length && j < 3; j++) {
        final match = veaResults[j];
        print('      ${j + 1}. ${match['productName']}');
        print('         💵 \$${match['price'] ?? 'N/A'}');
      }
    } else {
      print('   ❌ No encontrado en Vea');
    }
    
    // Buscar en Carrefour
    print('\n   🔎 Buscando en Carrefour...');
    final carrefourResults = await searchInCarrefour(description, brand);
    if (carrefourResults.isNotEmpty) {
      foundInCarrefour++;
      print('   ✅ Encontrado ${carrefourResults.length} resultados en Carrefour:');
      for (var j = 0; j < carrefourResults.length && j < 3; j++) {
        final match = carrefourResults[j];
        print('      ${j + 1}. ${match['productName']}');
        print('         💵 \$${match['price'] ?? 'N/A'}');
      }
    } else {
      print('   ❌ No encontrado en Carrefour');
    }
    
    // Buscar en La Coope
    print('\n   🔎 Buscando en La Coope...');
    final coopeResults = await searchInCoope(description, brand);
    if (coopeResults.isNotEmpty) {
      foundInCoope++;
      print('   ✅ Encontrado ${coopeResults.length} resultados en La Coope:');
      for (var j = 0; j < coopeResults.length && j < 3; j++) {
        final match = coopeResults[j];
        print('      ${j + 1}. ${match['descripcion']}');
        print('         💵 \$${match['importe'] ?? 'N/A'}');
      }
    } else {
      print('   ❌ No encontrado en La Coope');
    }
    
    print('\n');
    await Future.delayed(Duration(milliseconds: 300)); // Evitar saturar APIs
  }
  
  // RESUMEN FINAL
  print('\n╔═══════════════════════════════════════════════════════════╗');
  print('║                  RESUMEN DEL ANÁLISIS                    ║');
  print('╠═══════════════════════════════════════════════════════════╣');
  print('║ Total de productos analizados: ${totalAnalyzed.toString().padLeft(3)} / 15              ║');
  print('╠═══════════════════════════════════════════════════════════╣');
  print('║ ✅ Encontrados en Vea:       ${foundInVea.toString().padLeft(3)} (${((foundInVea / totalAnalyzed) * 100).toStringAsFixed(1)}%)      ║');
  print('║ ✅ Encontrados en Carrefour: ${foundInCarrefour.toString().padLeft(3)} (${((foundInCarrefour / totalAnalyzed) * 100).toStringAsFixed(1)}%)      ║');
  print('║ ✅ Encontrados en La Coope:  ${foundInCoope.toString().padLeft(3)} (${((foundInCoope / totalAnalyzed) * 100).toStringAsFixed(1)}%)      ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');
}

Future<List<Map<String, dynamic>>> getMonarcaCoronados() async {
  try {
    // Buscar "coronados" directamente
    final url = 'https://api.monarcadigital.com.ar/products/search?query=coronados&page=0&size=50';
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
      
      print('   📦 Obtenidos ${content.length} productos de Monarca');
      return content.map((e) => e as Map<String, dynamic>).toList();
    }
  } catch (e) {
    print('   ❌ Error obteniendo Monarca: $e');
  }
  return [];
}

Future<List<Map<String, dynamic>>> searchInVea(String productName, String? brand) async {
  try {
    // Construir query optimizada
    List<String> keywords = [];
    if (brand != null && brand.isNotEmpty) {
      keywords.add(brand);
    }
    
    // Extraer palabras clave del nombre
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
      // Extraer JSON de VTEX
      final regex = RegExp(r'"products":\s*(\[.*?\])', multiLine: true, dotAll: true);
      final match = regex.firstMatch(response.body);
      if (match != null) {
        final jsonStr = match.group(1)!;
        final products = json.decode(jsonStr) as List;
        return products.map((e) => e as Map<String, dynamic>).toList();
      }
    }
  } catch (e) {
    // Silenciar errores de timeout o conexión
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
    // Silenciar errores
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
    // Silenciar errores
  }
  return [];
}
