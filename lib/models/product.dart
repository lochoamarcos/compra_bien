class Product {
  final String name;
  final String ean;
  final double price;
  final String presentation;
  final String source; // 'Monarca' or 'Carrefour'
  final String? imageUrl;
  final String? brand;

  final double? oldPrice;
  final String? promoDescription;

  Product({
    required this.name,
    required this.ean,
    required this.price,
    this.presentation = '',
    required this.source,
    this.imageUrl,
    this.brand,
    this.oldPrice,
    this.promoDescription,
  });

  Product copyWith({
    String? name,
    String? ean,
    double? price,
    String? presentation,
    String? source,
    String? imageUrl,
    String? brand,
    double? oldPrice,
    String? promoDescription,
  }) {
    return Product(
      name: name ?? this.name,
      ean: ean ?? this.ean,
      price: price ?? this.price,
      presentation: presentation ?? this.presentation,
      source: source ?? this.source,
      imageUrl: imageUrl ?? this.imageUrl,
      brand: brand ?? this.brand,
      oldPrice: oldPrice ?? this.oldPrice,
      promoDescription: promoDescription ?? this.promoDescription,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json, String source) {
    if (source == 'Monarca') {
      double price = (json['price'] is int) ? (json['price'] as int).toDouble() : (json['price'] ?? 0.0);
      double? oldPrice;
      String? promoDescription;
      
      // Parse Promotions
      if (json['promotions'] != null && (json['promotions'] as List).isNotEmpty) {
          final promo = json['promotions'][0];
          // Use unitPrice as the real selling price
          if (promo['unitPrice'] != null) {
              double promoPrice = double.tryParse(promo['unitPrice'].toString()) ?? 0.0;
              if (promoPrice > 0 && promoPrice < price) {
                 oldPrice = price; // The original 'price' becomes oldPrice
                 price = promoPrice; // The new selling price
                 String content = promo['content'] ?? '';
                 
                 // If content is a long string, keep it for detail view
                 // But prioritize specific discount text if found
                 promoDescription = content;
                 
                 // If we have prices, we can derive a percentage OFF
                 if (oldPrice > price) {
                    int pct = (((oldPrice - price) / oldPrice) * 100).round();
                    if (pct > 0 && pct < 100) {
                        // If description is empty or very generic, use the % OFF
                        if (promoDescription == null || promoDescription!.isEmpty || promoDescription!.length > 40) {
                            // We will handle short badge in UI, but keep description for detail
                        }
                    }
                 }
              }
          }
      }

      // Parse Text-Based Discounts (e.g. "PRODUCTO EN PROMO 20% DE DESCUENTO")
      // This is common in "Coronados" items where explicit price fields might be missing
      String? content = json['content'];
      if (content != null && (oldPrice == null || oldPrice <= price)) {
          final cleanContent = content.toUpperCase();
          final discountMatch = RegExp(r'(\d+)%\s*DE\s*DESCUENTO').firstMatch(cleanContent);
          if (discountMatch != null) {
              double pct = double.parse(discountMatch.group(1)!);
              if (pct > 0 && pct < 100) {
                  // If current 'price' is the discounted price, calculate oldPrice:
                  oldPrice = price / (1 - (pct / 100));
                  oldPrice = double.parse(oldPrice!.toStringAsFixed(2));
                  promoDescription = "$pct% OFF";
              }
          } else {
             // Check for 2nd Unit discounts (e.g. "2DA AL 80%")
             final secondUnitMatch = RegExp(r'(2DA|SEGUNDA)\s+(?:AL|AL LA)\s+(\d+)%').firstMatch(cleanContent);
             if (secondUnitMatch != null) {
                 String pct = secondUnitMatch.group(2)!;
                 promoDescription = "2da al $pct%";
             } else if (cleanContent.contains('2X1')) {
                 promoDescription = "2x1";
             } else if (cleanContent.contains('3X2')) {
                 promoDescription = "3x2";
             } else if (cleanContent.contains('4X3')) {
                 promoDescription = "4x3";
             } else {
                 promoDescription ??= content;
             }
          }
      }

      // Check Tags
      if (json['tags'] != null && json['tags'] is List) {
           final tags = json['tags'] as List;
           bool isCoronado = tags.any((t) {
              final desc = t['description'].toString().toLowerCase();
              final id = t['id'];
              return desc.contains('coronados') || id == 534;
           });
           
           if (isCoronado) {
              promoDescription ??= "Precio Coronado";
           }
      }
      
      return Product(
        name: json['description'] ?? '',
        ean: (json['barcode']?.length == 13 || json['barcode']?.length == 8) ? json['barcode'] : '',
        price: price,
        presentation: json['presentation'] ?? '',
        source: 'Monarca',
        imageUrl: _parseMonarcaImage(json),
        brand: json['brand'],
        oldPrice: oldPrice,
        promoDescription: promoDescription,
      );
    } else {
       // Carrefour logic simplified here for compilation, actual logic is in Repository
       return Product(
         name: json['productName'] ?? '',
         ean: '', 
         price: 0.0,
         source: 'Carrefour',
       );
    }
  }
  
  static String? _parseMonarcaImage(Map<String, dynamic> json) {
      if (json['featuredImage'] != null) {
          String path = json['featuredImage']['path'];
          if (!path.startsWith('http')) {
             // Use CORS proxy + Base URL for Web compatibility
             // Warning: This assumes the app is running on Web or environment where this proxy is reachable.
             return 'https://corsproxy.io/?https://monarcadigital.com.ar$path';
          }
          return path;
      }
      return null;
  }

  // --- Caching Methods ---
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ean': ean,
      'price': price,
      'presentation': presentation,
      'source': source,
      'imageUrl': imageUrl,
      'brand': brand,
      'oldPrice': oldPrice,
      'promoDescription': promoDescription,
    };
  }

  factory Product.fromCachedJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'],
      ean: json['ean'],
      price: (json['price'] as num).toDouble(),
      presentation: json['presentation'],
      source: json['source'],
      imageUrl: json['imageUrl'],
      brand: json['brand'],
      oldPrice: json['oldPrice'] != null ? (json['oldPrice'] as num).toDouble() : null,
      promoDescription: json['promoDescription'],
    );
  }
}

class ComparisonResult {
  final String ean;
  Product? monarcaParam;
  Product? carrefourParam;
  Product? coopeParam;
  Product? veaParam;
  
  Product? get monarcaProduct => monarcaParam;
  Product? get carrefourProduct => carrefourParam;
  Product? get coopeProduct => coopeParam;
  Product? get veaProduct => veaParam;

  ComparisonResult({required this.ean, this.monarcaParam, this.carrefourParam, this.coopeParam, this.veaParam});
  
  String get name => monarcaParam?.name ?? carrefourParam?.name ?? coopeParam?.name ?? veaParam?.name ?? 'Unknown';

  // --- Caching Methods ---

  Map<String, dynamic> toJson() {
    return {
      'ean': ean,
      'monarcaParam': monarcaParam?.toJson(),
      'carrefourParam': carrefourParam?.toJson(),
      'coopeParam': coopeParam?.toJson(),
      'veaParam': veaParam?.toJson(),
    };
  }

  factory ComparisonResult.fromJson(Map<String, dynamic> json) {
    return ComparisonResult(
      ean: json['ean'],
      monarcaParam: json['monarcaParam'] != null ? Product.fromCachedJson(json['monarcaParam']) : null,
      carrefourParam: json['carrefourParam'] != null ? Product.fromCachedJson(json['carrefourParam']) : null,
      coopeParam: json['coopeParam'] != null ? Product.fromCachedJson(json['coopeParam']) : null,
      veaParam: json['veaParam'] != null ? Product.fromCachedJson(json['veaParam']) : null,
    );
  }
}
