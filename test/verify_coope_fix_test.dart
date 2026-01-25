import 'package:flutter_test/flutter_test.dart';
import 'package:compra_bien/data/coope_repository.dart';

void main() {
  test('La Coope categories return products after endpoint fix', () async {
    final repo = CoopeRepository();
    
    // Test Category Search (Almacen = ID 2)
    print('Testing La Coope Almacen category...');
    final almacenProducts = await repo.searchProducts('', categoryId: '2');
    
    expect(almacenProducts, isNotEmpty, reason: 'Almacen category should return products');
    print('✅ Almacen: Found ${almacenProducts.length} products');
    print('   Example: ${almacenProducts[0].name}');
    
    // Test Promotions
    print('\nTesting La Coope promotions...');
    final promoProducts = await repo.searchProducts('', isPromo: true);
    
    expect(promoProducts, isNotEmpty, reason: 'Promotions should return products');
    print('✅ Promotions: Found ${promoProducts.length} promotional items');
    
    // Check if promo detection works
    final hasPromoField = promoProducts.any((p) => p.promoDescription != null);
    print('   Promo descriptions detected: $hasPromoField');
  });
}
