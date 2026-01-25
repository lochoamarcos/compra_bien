import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// SSL override for development testing
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// Script to investigate how volume/ML data is stored in different supermarket APIs
/// Specifically looking at La Coope and Carrefour responses for beverages

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  print('🔍 Investigando datos de volumen en APIs de supermercados\n');
  
  await inspectCoopeGaseosas();
  print('\n' + '=' * 80 + '\n');
  await inspectCarrefourGaseosas();
}

/// Inspect La Coope API response for sodas
Future<void> inspectCoopeGaseosas() async {
  print('📦 LA COOPE - Gaseosas');
  print('-' * 80);
  
  try {
    final url = Uri.parse('https://www.lacoopeencasa.coop/api/pagina');
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
        "termino": "coca cola",
        "tipo_relacion": "busqueda"
      },
      "pagina": 1
    };
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.lacoopeencasa.coop/',
        'Origin': 'https://www.lacoopeencasa.coop',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final productos = data['data']['productos'] as List?;
      
      if (productos != null && productos.isNotEmpty) {
        print('✅ Encontrados ${productos.length} productos\n');
        
        for (var i = 0; i < productos.length; i++) {
          final producto = productos[i];
          print('Producto ${i + 1}:');
          print('  Título: ${producto['titulo']}');
          print('  Descripción: ${producto['descripcion']}');
          print('  Precio: \$${producto['precio']}');
          
          // Check all available fields
          print('  📋 Campos disponibles:');
          producto.forEach((key, value) {
            if (key != 'titulo' && key != 'descripcion' && key != 'precio') {
              // Look for potential volume fields
              final keyLower = key.toString().toLowerCase();
              if (keyLower.contains('vol') || 
                  keyLower.contains('ml') || 
                  keyLower.contains('size') ||
                  keyLower.contains('cantidad') ||
                  keyLower.contains('medida') ||
                  keyLower.contains('peso') ||
                  keyLower.contains('capacidad')) {
                print('     ⭐ $key: $value');
              } else {
                print('     $key: $value');
              }
            }
          });
          print('');
        }
      } else {
        print('❌ No se encontraron productos');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}

/// Inspect Carrefour API response for sodas
Future<void> inspectCarrefourGaseosas() async {
  print('📦 CARREFOUR - Gaseosas (GraphQL)');
  print('-' * 80);
  
  try {
    // GraphQL query for sodas
    final query = '''
    query ProductSearch(\$fullText: String!, \$from: Int, \$to: Int) {
      productSearch(
        fullText: \$fullText
        from: \$from
        to: \$to
      ) {
        products {
          productId
          productName
          description
          brand
          items {
            itemId
            name
            images {
              imageUrl
            }
            sellers {
              sellerId
              commercialOffer: commertialOffer {
                Price
                ListPrice
                spotPrice
              }
            }
          }
          properties {
            name
            values
          }
          specificationGroups {
            name
            specifications {
              name
              values
            }
          }
        }
      }
    }
    ''';

    final url = Uri.parse('https://www.carrefour.com.ar/api/io/_v/public/graphql/v1');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        'variables': {
          'fullText': 'coca cola',
          'from': 0,
          'to': 5,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final products = data['data']?['productSearch']?['products'] as List?;
      
      if (products != null && products.isNotEmpty) {
        print('✅ Encontrados ${products.length} productos\n');
        
        for (var i = 0; i < products.length; i++) {
          final product = products[i];
          print('Producto ${i + 1}:');
          print('  ID: ${product['productId']}');
          print('  Nombre: ${product['productName']}');
          print('  Marca: ${product['brand']}');
          print('  Descripción: ${product['description']}');
          
          // Check properties
          final properties = product['properties'] as List?;
          if (properties != null && properties.isNotEmpty) {
            print('  📋 Properties:');
            for (var prop in properties) {
              final name = prop['name'];
              final values = prop['values'];
              print('     $name: $values');
            }
          }
          
          // Check specification groups
          final specGroups = product['specificationGroups'] as List?;
          if (specGroups != null && specGroups.isNotEmpty) {
            print('  📋 Specifications:');
            for (var group in specGroups) {
              final groupName = group['name'];
              final specs = group['specifications'] as List?;
              if (specs != null) {
                for (var spec in specs) {
                  final specName = spec['name'];
                  final specValues = spec['values'];
                  // Highlight volume-related fields
                  if (specName.toString().toLowerCase().contains('vol') ||
                      specName.toString().toLowerCase().contains('ml') ||
                      specName.toString().toLowerCase().contains('litro') ||
                      specName.toString().toLowerCase().contains('peso') ||
                      specName.toString().toLowerCase().contains('contenido')) {
                    print('     ⭐ [$groupName] $specName: $specValues');
                  } else {
                    print('     [$groupName] $specName: $specValues');
                  }
                }
              }
            }
          }
          
          // Check items
          final items = product['items'] as List?;
          if (items != null && items.isNotEmpty) {
            print('  📦 Items:');
            for (var item in items) {
              print('     Item ID: ${item['itemId']}');
              print('     Item Name: ${item['name']}');
            }
          }
          
          print('');
        }
      } else {
        print('❌ No se encontraron productos');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      print('Response: ${response.body.substring(0, 500)}...');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}
