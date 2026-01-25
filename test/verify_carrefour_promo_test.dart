import 'package:flutter_test/flutter_test.dart';
import 'package:compra_bien/data/carrefour_repository.dart';

void main() {
  test('CarrefourRepository fetches 2do al 50% promo for Quilmes', () async {
    final repo = CarrefourRepository();
    print('Searching "cerveza blanca quilmes sin alcohol"...');
    
    final products = await repo.searchProducts('cerveza blanca quilmes sin alcohol');
    
    expect(products, isNotEmpty);
    
    bool foundPromo = false;
    for (var p in products) {
        print('Items: ${p.name} | Promo: ${p.promoDescription}');
        if (p.promoDescription == "2do al 50%" || (p.promoDescription ?? '').contains('50%')) {
            foundPromo = true;
        }
    }
    
    expect(foundPromo, isTrue, reason: 'Should have found 2do al 50% promotion');
  });
}
