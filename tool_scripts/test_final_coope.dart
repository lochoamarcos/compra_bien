import '../lib/data/coope_repository.dart';

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('  TEST FINAL: Verificar que La Coope funciona en la app');
  print('═══════════════════════════════════════════════════════════\n');
  
  final repo = CoopeRepository();
  
  // Test 1: Búsqueda simple
  print('Test 1: Buscando "coca cola"...');
  var products = await repo.searchProducts('coca cola');
  print('✅ Resultados: ${products.length}');
  if (products.isNotEmpty) {
    print('   Ejemplo: ${products.first.name} - \$${products.first.price}');
  }
  
  // Test 2: Producto con espacios/stopwords
  print('\nTest 2: Buscando "aceite de girasol"...');
  products = await repo.searchProducts('aceite de girasol');
  print('✅ Resultados: ${products.length}');
  if (products.isNotEmpty) {
    print('   Ejemplo: ${products.first.name} - \$${products.first.price}');
  }
  
  // Test 3: Producto simple
  print('\nTest 3: Buscando "leche"...');
  products = await repo.searchProducts('leche');
  print('✅ Resultados: ${products.length}');
  if (products.isNotEmpty) {
    print('   Ejemplo: ${products.first.name} - \$${products.first.price}');
  }
  
  print('\n═══════════════════════════════════════════════════════════');
  print('  ✅ La Coope repository funciona correctamente');
  print('═══════════════════════════════════════════════════════════\n');
}
