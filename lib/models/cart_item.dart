import 'product.dart';

// part 'cart_item.g.dart'; // Removed to avoid build_runner dependency

class CartItem {
  final Product product;
  int quantity;
  String? bestMarket;
  double? bestPrice;
  List<Product>? alternatives;

  bool isSelected;

  CartItem({
    required this.product, 
    this.quantity = 1,
    this.bestMarket,
    this.bestPrice,
    this.alternatives,
    this.isSelected = false,
  });

  double get totalPrice {
    // If we have a promo description (volume discount), use oldPrice as base if it exists
    // consistently to avoid "double discounting" if 'product.price' is already an average.
    double basePrice = (product.promoDescription != null && product.oldPrice != null && product.oldPrice! > product.price) 
        ? product.oldPrice! 
        : product.price;

    if (product.promoDescription != null) {
      final desc = product.promoDescription!.toLowerCase();
      // 2da unidad 50%
      if (desc.contains('2da') && desc.contains('50')) {
        int pairs = quantity ~/ 2;
        int remaining = quantity % 2;
        return (pairs * basePrice * 1.5) + (remaining * basePrice);
      }
      // 2da unidad 70%
      if (desc.contains('2da') && desc.contains('70')) {
        int pairs = quantity ~/ 2;
        int remaining = quantity % 2;
        return (pairs * basePrice * 1.3) + (remaining * basePrice);
      }
      // 3x2
      if (desc.contains('3x2')) {
        int sets = quantity ~/ 3;
        int remaining = quantity % 3;
        return (sets * basePrice * 2) + (remaining * basePrice);
      }
      // 4x3
      if (desc.contains('4x3')) {
        int sets = quantity ~/ 4;
        int remaining = quantity % 4;
        return (sets * basePrice * 3) + (remaining * basePrice);
      }
    }
    return basePrice * quantity;
  }

  // JSON Serialization
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromCachedJson(json['product']),
      quantity: json['quantity'] ?? 1,
      bestMarket: json['bestMarket'],
      bestPrice: json['bestPrice'] != null ? (json['bestPrice'] as num).toDouble() : null,
      isSelected: json['isSelected'] ?? false,
      alternatives: json['alternatives'] != null 
          ? (json['alternatives'] as List).map((p) => Product.fromCachedJson(p as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
       'product': _productToJson(product),
       'quantity': quantity,
       'bestMarket': bestMarket,
       'bestPrice': bestPrice,
       'isSelected': isSelected,
       if (alternatives != null) 'alternatives': alternatives!.map((p) => _productToJson(p)).toList(),
    };
  }
  
  Map<String, dynamic> _productToJson(Product p) {
    return {
      'name': p.name,
      'ean': p.ean,
      'price': p.price,
      'presentation': p.presentation,
      'source': p.source,
      'imageUrl': p.imageUrl,
      'brand': p.brand,
      'oldPrice': p.oldPrice,
      'promoDescription': p.promoDescription,
    };
  }
}
