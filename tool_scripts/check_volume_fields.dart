import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// SSL override for development testing
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  
  print('🔍 ANÁLISIS DE DATOS DE VOLUMEN EN APIS');
  print('=' * 80);
  print('');
  
  // Test Carrefour first (simplest GraphQL)
  await testCarrefour();
  
  print('\n' + '=' * 80 + '\n');
  
  // Test Vea
  await testVea();
}

Future<void> testCarrefour() async {
  print('📦 CARREFOUR - Gaseosas (GraphQL)');
  print('-' * 80);
  
  try {
    const query = '''
    query GetProducts(\$fullText: String!) {
      productSearch(fullText: \$fullText, from: 0, to: 3) {
        products {
          productId
          productName
          description
          brand
          items {
            itemId
            name
            sellers {
              commercialOffer: commertialOffer {
                Price
                ListPrice
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
    final body = jsonEncode({
      'query': query,
      'variables': {'fullText': 'coca cola'}
    });
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: body,
    );
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      print('✅ Response received (status: ${response.statusCode})\n');
      final data = jsonDecode(response.body);
      final products = (data['data']?['productSearch']?['products'] as List?) ?? [];
      
      print('✅ Encontrados ${products.length} productos\n');
      
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        print('Producto ${i + 1}:');
        print('  Nombre: ${p['productName']}');
        print('  Marca: ${p['brand']}');
        print('  Descripción: ${p['description'] ?? "N/A"}');
        
        // Check name and description for volume
        final name = p['productName']?.toString() ?? '';
        final desc = p['description']?.toString() ?? '';
        final hasVolumeInText = _checkVolumeInText(name + ' ' + desc);
        print('  📊 Volumen en nombre/desc: ${hasVolumeInText ? "✅" : "❌"}');
        
        // Check properties
        final props = (p['properties'] as List?) ?? [];
        if (props.isNotEmpty) {
          print('  📋 Properties:');
          for (var prop in props) {
            final propName = prop['name'];
            final propVals = prop['values'];
            if (_isVolumeField(propName.toString())) {
              print('     ⭐ $propName: $propVals');
            } else {
              print('     $propName: $propVals');
            }
          }
        }
        
        // Check specifications
        final specGroups = (p['specificationGroups'] as List?) ?? [];
        if (specGroups.isNotEmpty) {
          print('  📋 Specifications:');
          for (var group in specGroups) {
            final specs = (group['specifications'] as List?) ?? [];
            for (var spec in specs) {
              final specName = spec['name'];
              final specVals = spec['values'];
              if (_isVolumeField(specName.toString())) {
                print('     ⭐ [${group['name']}] $specName: $specVals');
              } else {
                print('     [${group['name']}] $specName: $specVals');
              }
            }
          }
        }
        
        print('');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}

Future<void> testVea() async {
  print('📦 VEA - Gaseosas');
  print('-' * 80);
  
  try {
    final url = Uri.parse('https://www.vea.com.ar/api/catalog_system/pub/products/search/coca cola?_from=0&_to=3');
    
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0',
    });
    
    if (response.statusCode == 200) {
      final products = jsonDecode(response.body) as List;
      print('✅ Encontrados ${products.length} productos\n');
      
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        print('Producto ${i + 1}:');
        print('  Nombre: ${p['productName']}');
        print('  Marca: ${p['brand'] ?? "N/A"}');
        print('  Descripción: ${p['description'] ?? "N/A"}');
        
        // Check name and description for volume
        final name = p['productName']?.toString() ?? '';
        final desc = p['description']?.toString() ?? '';
        final hasVolumeInText = _checkVolumeInText(name + ' ' + desc);
        print('  📊 Volumen en nombre/desc: ${hasVolumeInText ? "✅" : "❌"}');
        
        // Check items
        final items = (p['items'] as List?) ?? [];
        if (items.isNotEmpty) {
          print('  📦 Items:');
          final item = items[0]; // First item
          print('     Item Name: ${item['name']}');
          
          // Check for complementName (often contains size info)
          if (item['complementName'] != null) {
            print('     ⭐ Complement Name: ${item['complementName']}');
          }
        }
        
        print('');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}

bool _checkVolumeInText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('ml') || 
         lower.contains('cc') || 
         lower.contains('litro') || 
         lower.contains(' l ') ||
         lower.contains('lts');
}

bool _isVolumeField(String fieldName) {
  final lower = fieldName.toLowerCase();
  return lower.contains('vol') ||
         lower.contains('ml') ||
         lower.contains('litro') ||
         lower.contains('size') ||
         lower.contains('cantidad') ||
         lower.contains('medida') ||
         lower.contains('peso') ||
         lower.contains('contenido') ||
         lower.contains('capacidad');
}
