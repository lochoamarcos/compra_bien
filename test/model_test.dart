import 'package:flutter_test/flutter_test.dart';
import 'package:compra_bien/models/product.dart';

void main() {
  test('Product JSON parsing for Monarca', () {
    final json = {
      'description': 'Coca Cola',
      'barcode': '123456',
      'price': 150.0,
      'presentation': '1.5L',
      'featuredImage': {'path': 'http://image.com'}
    };
    
    final product = Product.fromJson(json, 'Monarca');
    
    expect(product.name, 'Coca Cola');
    expect(product.ean, '123456');
    expect(product.price, 150.0);
    expect(product.source, 'Monarca');
    expect(product.imageUrl, 'http://image.com');
  });

  test('ComparisonResult logic', () {
    final p1 = Product(name: 'A', ean: '111', price: 10, source: 'Monarca');
    final p2 = Product(name: 'B', ean: '111', price: 12, source: 'Carrefour');
    
    final comparison = ComparisonResult(ean: '111', monarcaParam: p1, carrefourParam: p2);
    
    expect(comparison.monarcaProduct, isNotNull);
    expect(comparison.carrefourProduct, isNotNull);
    expect(comparison.name, 'A');
  });
}
