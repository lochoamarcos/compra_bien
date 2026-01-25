import 'dart:io';
import 'dart:convert';
import '../lib/data/coope_repository.dart';
import '../lib/data/carrefour_repository.dart';
import '../lib/data/vea_repository.dart';

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
  
  print('🔍 Investigando campos de volumen en productos');
  print('=' * 80);
  print('');
  
  final coopeRepo = LaCoopeRepository();
  final carrefourRepo = CarrefourRepository();
  final veaRepo = VeaRepository();
  
  // Test 1: La Coope - Coca Cola
  print('📦 LA COOPE - "Coca Cola"');
  print('-' * 80);
  try {
    final products = await coopeRepo.searchProducts('coca cola', page: 1, size: 3);
    if (products.isNotEmpty) {
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        print('\nProducto ${i + 1}:');
        print('  Store: ${p.store}');
        print('  Name: ${p.name}');
        print('  Price: \$${p.price}');
        print('  EAN: ${p.ean}');
        print('  ImageURL: ${p.imageUrl}');
        print('  Description: ${p.description}');
        
        // Check if volume info is in description or name
        final combined = '${p.name} ${p.description}'.toLowerCase();
        final hasML = combined.contains('ml') || combined.contains('cc');
        final hasL = combined.contains('litro') || combined.contains(' l ');
        print('  📊 Contiene volumen en text: ${hasML || hasL ? "✅" : "❌"}');
      }
    } else {
      print('❌ No se encontraron productos');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n');
  print('=' * 80);
  print('');
  
  // Test 2: Carrefour - Coca Cola (GraphQL)
  print('📦 CARREFOUR - "Coca Cola"');
  print('-' * 80);
  try {
    final products = await carrefourRepo.searchProducts('coca cola', page: 1, size: 3);
    if (products.isNotEmpty) {
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        print('\nProducto ${i + 1}:');
        print('  Store: ${p.store}');
        print('  Name: ${p.name}');
        print('  Price: \$${p.price}');
        print('  EAN: ${p.ean}');
        print('  ImageURL: ${p.imageUrl}');
        print('  Description: ${p.description}');
        
        // Check if volume info is in description or name
        final combined = '${p.name} ${p.description}'.toLowerCase();
        final hasML = combined.contains('ml') || combined.contains('cc');
        final hasL = combined.contains('litro') || combined.contains(' l ');
        print('  📊 Contiene volumen en text: ${hasML || hasL ? "✅" : "❌"}');
      }
    } else {
      print('❌ No se encontraron productos');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n');
  print('=' * 80);
  print('');
  
  // Test 3: Vea - Coca Cola
  print('📦 VEA - "Coca Cola"');
  print('-' * 80);
  try {
    final products = await veaRepo.searchProducts('coca cola', page: 1, size: 3);
    if (products.isNotEmpty) {
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        print('\nProducto ${i + 1}:');
        print('  Store: ${p.store}');
        print('  Name: ${p.name}');
        print('  Price: \$${p.price}');
        print('  EAN: ${p.ean}');
        print('  ImageURL: ${p.imageUrl}');
        print('  Description: ${p.description}');
        
        // Check if volume info is in description or name
        final combined = '${p.name} ${p.description}'.toLowerCase();
        final hasML = combined.contains('ml') || combined.contains('cc');
        final hasL = combined.contains('litro') || combined.contains(' l ');
        print('  📊 Contiene volumen en text: ${hasML || hasL ? "✅" : "❌"}');
      }
    } else {
      print('❌ No se encontraron productos');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n');
  print('=' * 80);
  print('\n✅ Análisis completo');
}
