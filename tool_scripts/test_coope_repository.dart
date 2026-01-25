import 'dart:io';
import '../lib/data/coope_repository.dart';

void main() async {
  print('=== TEST COOPE REPOSITORY ACTUALIZADO ===\n');
  
  final repo = CoopeRepository();
  
  // Test 1: Búsqueda de productos comunes
  print('1. Buscando "coca cola"...');
  var products = await repo.searchProducts('coca cola');
  print('   Resultados: ${products.length}');
  for (var i = 0; i < products.length && i < 3; i++) {
    print('   - ${products[i].name} (\$${products[i].price})');
  }
  
  print('\n2. Buscando "leche"...');
  products = await repo.searchProducts('leche');
  print('   Resultados: ${products.length}');
  for (var i = 0; i < products.length && i < 3; i++) {
    print('   - ${products[i].name} (\$${products[i].price})');
  }
  
  print('\n3. Buscando "vino"...');
  products = await repo.searchProducts('vino');
  print('   Resultados: ${products.length}');
  for (var i = 0; i < products.length && i < 3; i++) {
    print('   - ${products[i].name} (\$${products[i].price})');
  }
  
  print('\n4. Buscando "fideos"...');
  products = await repo.searchProducts('fideos');
  print('   Resultados: ${products.length}');
  for (var i = 0; i < products.length && i < 3; i++) {
    print('   - ${products[i].name} (\$${products[i].price})');
  }
  
  print('\n✅ Prueba completada');
}
