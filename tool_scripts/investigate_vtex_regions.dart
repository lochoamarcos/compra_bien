import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Investigar cómo Vea y Carrefour manejan regiones en VTEX

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('  INVESTIGACIÓN: Filtros Regionales VTEX para Tandil');
  print('═══════════════════════════════════════════════════════════\n');
  
  const query = 'coca cola';
  const postalCodeTandil = '7000';
  
  print('Producto de prueba: "$query"');
  print('Código postal Tandil: $postalCodeTandil\n');
  
  // Test 1: Sin filtro regional (nacional)
  print('─── TEST 1: SIN FILTRO REGIONAL (Nacional) ───\n');
  await testVea(query, null, null, null);
  
  // Test 2: Con postalCode
  print('\n─── TEST 2: CON postalCode=7000 ───\n');
  await testVea(query, postalCodeTandil, null, null);
  
  // Test 3: Con regionId
  print('\n─── TEST 3: CON regionId=7000 ───\n');
  await testVea(query, null, postalCodeTandil, null);
  
  // Test 4: Con sc (sales channel)
  print('\n─── TEST 4: CON sc=1 (Tandil?) ───\n');
  await testVea(query, null, null, '1');
  
  // Test 5: Probar con headers especiales
  print('\n─── TEST 5: CON HEADERS DE REGIÓN ───\n');
  await testVeaWithHeaders(query, postalCodeTandil);
  
  print('\n═══════════════════════════════════════════════════════════');
  print('  AHORA PROBANDO CARREFOUR');
  print('═══════════════════════════════════════════════════════════\n');
  
  // Mismos tests para Carrefour
  print('─── TEST 1: SIN FILTRO ───\n');
  await testCarrefour(query, null, null, null);
  
  print('\n─── TEST 2: CON postalCode=7000 ───\n');
  await testCarrefour(query, postalCodeTandil, null, null);
  
  print('\n─── TEST 3: CON regionId=7000 ───\n');
  await testCarrefour(query, null, postalCodeTandil, null);
}

Future<void> testVea(String query, String? postalCode, String? regionId, String? sc) async {
  try {
    String url = 'https://www.vea.com.ar/api/catalog_system/pub/products/search?_from=0&_to=5&ft=$query';
    
    if (postalCode != null) url += '&postalCode=$postalCode';
    if (regionId != null) url += '&regionId=$regionId';
    if (sc != null) url += '&sc=$sc';
    
    print('URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      print('Productos encontrados: ${data.length}');
      
      if (data.isNotEmpty) {
        // Mostrar primer producto
        final first = data[0];
        print('Ejemplo: ${first['productName']}');
        
        // Ver si hay info de sellers/región
        final items = first['items'];
        if (items != null && items is List && items.isNotEmpty) {
          final sellers = items[0]['sellers'];
          if (sellers != null && sellers is List && sellers.isNotEmpty) {
            print('Sellers: ${sellers.length}');
            // Ver si hay info de región en sellers
            final seller = sellers[0];
            print('Seller info: ${seller.keys}');
          }
        }
      }
    } else {
      print('Error HTTP: ${response.statusCode}');
      print('Body: ${response.body.substring(0, 200)}...');
    }
  } catch (e) {
    print('Excepción: $e');
  }
}

Future<void> testVeaWithHeaders(String query, String postalCode) async {
  try {
    String url = 'https://www.vea.com.ar/api/catalog_system/pub/products/search?_from=0&_to=5&ft=$query';
    
    print('URL: $url');
    print('Con headers especiales...');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'X-VTEX-Shipping-PostalCode': postalCode,
        'X-VTEX-Shipping-RegionId': postalCode,
      },
    ).timeout(Duration(seconds: 10));
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      print('Productos encontrados: ${data.length}');
    }
  } catch (e) {
    print('Excepción: $e');
  }
}

Future<void> testCarrefour(String query, String? postalCode, String? regionId, String? sc) async {
  try {
    String url = 'https://www.carrefour.com.ar/api/catalog_system/pub/products/search?_from=0&_to=5&ft=$query';
    
    if (postalCode != null) url += '&postalCode=$postalCode';
    if (regionId != null) url += '&regionId=$regionId';
    if (sc != null) url += '&sc=$sc';
    
    print('URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    ).timeout(Duration(seconds: 10));
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200 || response.statusCode == 206) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      print('Productos encontrados: ${data.length}');
      
      if (data.isNotEmpty) {
        print('Ejemplo: ${data[0]['productName']}');
      }
    } else {
      print('Error HTTP: ${response.statusCode}');
    }
  } catch (e) {
    print('Excepción: $e');
  }
}
