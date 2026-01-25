import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('=== TEST LA COOPE API ===\n');
  
  // Probar búsqueda de productos comunes
  await testCoopeSearch('vino');
  await testCoopeSearch('coca cola');
  await testCoopeSearch('leche');
  await testCoopeSearch('pan');
  
  print('\n=== TEST BÚSQUEDA POR PRODUCTO ESPECÍFICO CORONADO ===\n');
  // Intentar buscar un producto Coronado específico
  await testCoopeSearch('fideos');
await testCoopeSearch('aceite');
}

Future<void> testCoopeSearch(String searchTerm) async {
  print('Buscando: "$searchTerm"');
  
  try {
    final normalizedQuery = searchTerm.toUpperCase().replaceAll(' ', '_');
    
    final payload = {
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
        "termino": normalizedQuery,
        "tipo_relacion": "busqueda"
      },
      "pagina": 0
    };
    
    final response = await http.post(
      Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
      },
      body: json.encode(payload),
    ).timeout(Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      
      if (data['estado'] == 1 && data['datos'] != null) {
        final articulos = data['datos']['articulos'] as List?;
        if (articulos != null && articulos.isNotEmpty) {
          print('  ✓ Encontrados ${articulos.length} productos');
          for (var i = 0; i < articulos.length && i < 3; i++) {
            final art = articulos[i];
            print('    ${i + 1}. ${art['descripcion']} - \$${art['precio']}');
          }
        } else {
          print('  ✗ Sin resultados');
        }
      } else {
        print('  ✗ Respuesta sin datos válidos');
        print('    Estado: ${data['estado']}');
      }
    } else {
      print('  ✗ Error HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('  ✗ Excepción: $e');
  }
  
  print('');
}
