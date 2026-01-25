
import 'package:http/http.dart' as http;
import 'dart:convert';

// Mock Product class to avoid importing lib/models/product.dart which might have Flutter dependencies
class MockProduct {
  final String name;
  final double price;
  final String source;
  final String? brand;

  MockProduct({required this.name, required this.price, required this.source, this.brand});

  @override
  String toString() => '$name (\$${price.toStringAsFixed(2)}) - $source [Brand: $brand]';
}

/// Standalone test for La Coope logic
void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('  STANDALONE TEST: La Coope Improved Logic (No Flutter)');
  print('═══════════════════════════════════════════════════════════\n');
  
  final client = http.Client();
  
  final queries = ['coca cola', 'aceite de girasol', 'leche entera'];
  
  for (var query in queries) {
    print('Testing query: "$query"');
    final normalized = smartNormalize(query);
    print('Normalized: "$normalized"');
    
    try {
      final response = await searchWithFallbacks(client, normalized);
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        if (body['estado'] == 1 && body['datos'] != null) {
          final articulos = body['datos']['articulos'] as List? ?? [];
          print('✅ Found ${articulos.length} results');
          if (articulos.isNotEmpty) {
            final first = articulos.first;
            final prod = MockProduct(
              name: first['descripcion'] ?? '',
              price: double.tryParse((first['precio'] ?? '0').toString()) ?? 0.0,
              source: 'La Coope',
              brand: first['marca_desc'],
            );
            print('   Example: $prod');
          }
        } else {
          print('❌ API Error: ${body['mensaje']}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception: $e');
    }
    print('-----------------------------------------------------------\n');
    await Future.delayed(Duration(milliseconds: 500));
  }
}

String smartNormalize(String query) {
  final stopWords = ['con', 'para', 'sin', 'los', 'las', 'del', 'de', 'la', 'el', 'en'];
  final words = query.toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .split(' ')
      .where((w) => w.length > 2 && !stopWords.contains(w))
      .toList();
  return words.take(3).join('_').toUpperCase();
}

Future<http.Response> searchWithFallbacks(http.Client client, String normalizedQuery) async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5) AppleWebKit/537.36',
    'Referer': 'https://www.lacoopeencasa.coop/',
    'Origin': 'https://www.lacoopeencasa.coop',
  };

  final payload = {
    "pagina": 0,
    "filtros": {
      "preciomenor": -1, "preciomayor": -1,
      "categoria": [], "marca": [],
      "tipo_seleccion": "busqueda", "cant_articulos": 0,
      "filtros_gramaje": [], "modificado": false,
      "ofertas": false, "primer_filtro": "",
      "termino": normalizedQuery, "tipo_relacion": "busqueda"
    }
  };

  return await client.post(url, headers: headers, body: json.encode(payload));
}
