import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// SSL override
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  
  print('\n🔍 Análisis de Volumen en APIs\n');
  
  // Just fetch Vea first (simpler)
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('  📦 VEA - Coca Cola');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  
  try {
    final url = Uri.parse('https://www.vea.com.ar/api/catalog_system/pub/products/search/coca cola?_from=0&_to=2');
    print('⏳ Fetching...');
    
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0',
    });
    
    print('✅ Status: ${response.statusCode}\n');
    
    if (response.statusCode == 200) {
      // Save raw JSON
      final file = File('tool_scripts/vea_raw.json');
      await file.writeAsString(response.body);
      print('💾 JSON guardado en: tool_scripts/vea_raw.json\n');
      
      final products = jsonDecode(response.body) as List;
      print('📊 Productos encontrados: ${products.length}\n');
      
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        print('─── Producto ${i + 1} ───');
        print('Nombre: ${p['productName']}');
        
        // Check items
        final items = (p['items'] as List?) ?? [];
        if (items.isNotEmpty && items[0]['complementName'] != null) {
          print('⭐ Complement Name: ${items[0]['complementName']}');
        }
        
        // Show ALL keys
        print('\n📋 Campos disponibles:');
        p.keys.forEach((key) {
          if (key != 'items' && key != 'skuSpecifications') {
            final val = p[key];
            if (val != null && val.toString().isNotEmpty && val.toString() != '{}' && val.toString() != '[]') {
              print('   • $key');
            }
          }
        });
        print('');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
    }
  } catch (e, stack) {
    print('❌ Error: $e');
    print(stack);
  }
  
  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
}
