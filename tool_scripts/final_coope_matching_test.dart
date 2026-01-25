import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('=== TEST FINAL LA COOPE - MATCHING ANALYSIS ===\n');
  
  // Obtener productos Coronados de Monarca
  final monarcaProducts = await getMonarcaCoronados();
  print('Productos Coronados de Monarca: ${monarcaProducts.length}\n');
  
  if (monarcaProducts.isEmpty) {
    print('No se encontraron productos de Monarca');
    return;
  }
  
  // Probar búsqueda cross-market con La Coope
  int found = 0;
  
  for (var i = 0; i < monarcaProducts.length && i < 10; i++) {
    final product = monarcaProducts[i];
    final name = product['description'] as String;
    final brand = product['brand'] as String?;
    
    print('${i + 1}. $name');
    
    // Buscar en La Coope
    final coopeResults = await searchInCoope(name, brand);
    if (coopeResults.isNotEmpty) {
      found++;
      print('   ✅ Encontrado en La Coope: ${coopeResults[0]['descripcion']}');
    } else {
      print('   ❌ No encontrado en La Coope');
    }
    print('');
  }
  
  print('\n═══════════════════════════════════════');
  print('RESULTADO: ${found}/10 productos encontrados en La Coope');
  print('Tasa de éxito: ${((found / 10) * 100).toStringAsFixed(1)}%');
  print('═══════════════════════════════════════\n');
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
    // Silenciar
  }
  return [];
}
