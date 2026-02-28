import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/product.dart';
import '../utils/app_config.dart';
class CarrefourRepository {
  static const String baseUrl = 'https://www.carrefour.com.ar';

  Future<List<Product>> searchProducts(String query, {int page = 0, int size = 20, String? categoryId}) async {
    final from = page * size;
    final to = (page + 1) * size - 1;
    String endpoint = '$baseUrl/api/catalog_system/pub/products/search?_from=$from&_to=$to';
    if (categoryId != null && categoryId.isNotEmpty) {
      endpoint += '&fq=C:$categoryId';
      if (query.isNotEmpty) endpoint += '&ft=$query';
    } else {
      endpoint += '&ft=$query';
    }
    endpoint = AppConfig.getProxiedUrl(endpoint, AppConfig.carrefourProxy);
    final url = Uri.parse(endpoint);
     
    final client = http.Client();

    try {
      final response = await client.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          // TANDIL REGIONAL HEADERS
          'X-VTEX-Shipping-PostalCode': '7000',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        // 1. Parse Basic Products
        List<Product> tempProducts = [];
        List<Future<void>> benefitFutures = [];

        for (var item in data) {
           final itemsStr = item['items'];
           if (itemsStr != null && itemsStr is List && itemsStr.isNotEmpty) {
             final sku = itemsStr[0];
             String ean = sku['ean'] ?? '';
             
             // Extract name and complement for volume info
             String name = item['productName'] ?? '';
             final complementName = sku['complementName'] ?? sku['name'] ?? '';
             
             // If complementName has volume info not in name, append it
             if (complementName.isNotEmpty && !name.toLowerCase().contains(complementName.toLowerCase())) {
               final hasVolumeInfo = RegExp(r'\d+\s*(ml|cc|l|lt|lts|litros?|gr|grs?|kg|g)\b', caseSensitive: false).hasMatch(complementName);
               if (hasVolumeInfo) {
                 name = '$name $complementName';
               }
             }
             
             String? imageUrl = (sku['images'] != null && (sku['images'] as List).isNotEmpty) 
                  ? _resizeVtexImage(sku['images'][0]['imageUrl']) 
                  : null;

             double price = 0.0;
             double? oldPrice;
             
             final sellers = sku['sellers'];
             if (sellers != null && sellers is List && sellers.isNotEmpty) {
               final commertialOffer = sellers[0]['commertialOffer'];
               if (commertialOffer != null) {
                 price = (commertialOffer['Price'] ?? 0.0).toDouble();
                 double listPrice = (commertialOffer['ListPrice'] ?? 0.0).toDouble();
                 if (listPrice > price) {
                    oldPrice = listPrice;
                 }
               }
             }

             if (ean.length != 8 && ean.length != 13) ean = '';
             
             String itemId = sku['itemId'] ?? '';
             String productId = item['productId'] ?? ''; // Added ProductId
             String slug = item['linkText'] ?? '';

             // Create product with placeholder promo
             final product = Product(
                 name: name,
                 ean: ean,
                 price: price,
                 source: 'Carrefour',
                 imageUrl: imageUrl,
                 brand: item['brand'],
                 oldPrice: oldPrice,
                 promoDescription: (oldPrice != null && oldPrice > price) 
                    ? "${(((oldPrice - price) / oldPrice) * 100).round()}% OFF" 
                    : null
             );

             if ((ean.isNotEmpty || name.isNotEmpty) && price > 0) {
                 tempProducts.add(product);
                 
                 // 2. Queue Benefit Fetch
                 benefitFutures.add(_fetchProductBenefits(productId, slug).then((promo) { // Use productId
                     if (promo != null) {
                        // Find this product index and update it
                        int idx = tempProducts.indexOf(product);
                        if (idx != -1) {
                            tempProducts[idx] = tempProducts[idx].copyWith(promoDescription: promo);
                        }
                     }
                 }));
             }
           }
        }
        
        // Wait for benefits (with timeout to not block UI too long)
        // We limit wait time to 2 seconds to not degrade UX too much
        await Future.wait(benefitFutures).timeout(const Duration(seconds: 2), onTimeout: () => []);
        
        return tempProducts;
      } else {
        print('Carrefour API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Carrefour Exception: $e');
      return [];
    } finally {
      client.close();
    }
  }
  // GraphQL Search Implementation
  Future<List<Product>> searchProductsGraphQL(String query, {int page = 0, int size = 10}) async {
    // We use the raw productSearch query as verified in experiments.
    // Explicitly targeting 'Almacen' context if query matches, or generic logic.
    
    final from = page * size;
    final to = (page + 1) * size - 1;

    // Construct the GQL Query
    // We use the structure found in experiments. 
    // Variable 'query' usually maps to the search term. 
    // For "Almacen" specifically, we might want to ensure 'map: "c"' is used if we are browsing the category.
    // Since this is for 'Almacen' category (Grocery), we use map:"c" and query:"almacen" derived from user request.
    
    /* 
       User provided variables for Almacen:
       {"hideUnavailableItems":true,"behavior":"Static","categoryTreeBehavior":"default",
        "query":"almacen","map":"c","from":0,"to":10,
        "selectedFacets":[{"key":"c","value":"almacen"}], ...}
    */

    // If the query passed is "Almacen", we use the specific map "c". 
    // Otherwise we default to standard text search in GQL? 
    // For now, let's make it generic but support the "map" param if needed.
    
    String mapParam = 'ft'; // Default to fulltext
    if (query.toLowerCase() == 'almacen') {
       mapParam = 'c';
    }

    final rawQuery = '''
    query {
      productSearch(query: "$query", map: "$mapParam", from: $from, to: $to, hideUnavailableItems: true) {
        products {
          productName
          brand
          items {
            itemId
            name
            ean
            images {
              imageUrl
            }
            sellers {
              commertialOffer {
                Price
                ListPrice
              }
            }
          }
        }
      }
    }
    ''';

    final url = Uri.parse('$baseUrl/_v/segment/graphql/v1');
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Content-Type': 'application/json',
      'Origin': baseUrl,
      'Referer': '$baseUrl/',
    };

    try {
       final response = await http.post(
          url,
          headers: headers,
          body: json.encode({'query': rawQuery}),
       );

       if (response.statusCode == 200) {
           final body = json.decode(utf8.decode(response.bodyBytes));
           if (body['data'] != null && body['data']['productSearch'] != null && body['data']['productSearch']['products'] != null) {
               final rawProducts = body['data']['productSearch']['products'] as List;
               List<Product> products = [];
               
               for (var item in rawProducts) {
                   String name = item['productName'] ?? '';
                   String brand = item['brand'] ?? '';
                   
                   final itemsList = item['items'] as List?;
                   if (itemsList != null && itemsList.isNotEmpty) {
                       final sku = itemsList[0]; // First SKU
                       String ean = sku['ean'] ?? '';
                       if (ean.length != 8 && ean.length != 13) ean = '';

                       String? imageUrl;
                       if (sku['images'] != null && (sku['images'] as List).isNotEmpty) {
                           imageUrl = _resizeVtexImage(sku['images'][0]['imageUrl']);
                       }

                       double price = 0.0;
                       double? oldPrice;

                       final sellers = sku['sellers'] as List?;
                       if (sellers != null && sellers.isNotEmpty) {
                            final offer = sellers[0]['commertialOffer'];
                            if (offer != null) {
                                price = (offer['Price'] ?? 0.0).toDouble();
                                double listPrice = (offer['ListPrice'] ?? 0.0).toDouble();
                                if (listPrice > price) oldPrice = listPrice;
                            }
                       }
                       
                       // Promo Description
                       String? promoDesc;
                       if (oldPrice != null && oldPrice > price) {
                           int pct = (((oldPrice - price) / oldPrice) * 100).round();
                           promoDesc = "$pct% OFF";
                       }

                       if ((ean.isNotEmpty || name.isNotEmpty) && price > 0) {
                           products.add(Product(
                             name: name,
                             ean: ean,
                             price: price,
                             source: 'Carrefour',
                             imageUrl: imageUrl,
                             brand: brand,
                             oldPrice: oldPrice,
                             promoDescription: promoDesc,
                           ));
                       }
                   }
               }
               return products;
           }
       }
       print('Carrefour GraphQL Error: ${response.statusCode}');
       return [];
    } catch (e) {
       print('Carrefour GraphQL Exception: $e');
       return [];
    }
  }

  // Helper to fetch details/benefits for a specific product ID/Slug
  Future<String?> _fetchProductBenefits(String id, String? slug) async {
      try {
        final url = Uri.parse('$baseUrl/_v/segment/graphql/v1?workspace=master&maxAge=short&appsEtag=remove&domain=store&locale=es-AR');
        final operationName = 'ProductBenefits';
        final sha256 = '07791ce6321bdbc77b77eaf67350988d3c71cec0738f46a1cbd16fb7884c4dd1';
        
        // If slug is unknown, we might default to something or just rely on ID?
        // The query requires slug usually for the "slug" variable, but identifier uses ID.
        // Let's try passing empty slug if null?
        
        final variables = {
            "slug": slug ?? "",
            "identifier": {"field": "id", "value": id}
        };
        
        final extensions = {
            "persistedQuery": {
                "version": 1,
                "sha256Hash": sha256,
                "sender": "vtex.store-resources@0.x",
                "provider": "vtex.search-graphql@0.x"
            },
            "variables": base64Encode(utf8.encode(json.encode(variables)))
        };

        final fullUrl = url.replace(queryParameters: {
            ...url.queryParameters,
            'operationName': operationName,
            'variables': '{}',
            'extensions': json.encode(extensions)
        });

        String finalUrl = fullUrl.toString();
        finalUrl = AppConfig.getProxiedUrl(finalUrl, AppConfig.carrefourProxy);

        final res = await http.get(Uri.parse(finalUrl), headers: {
           'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        });

        if (res.statusCode == 200) {
             final data = json.decode(res.body);
             if (data['data'] != null && data['data']['product'] != null) {
                 final benefits = data['data']['product']['benefits'] as List?;
                 if (benefits != null && benefits.isNotEmpty) {
                     // Logic to parse "2do al 50%" etc
                     // Typically items have "teaserType": "Catalog", "name": "...", "items": [...]
                     for (var b in benefits) {
                         if (b['items'] != null) {
                             for (var item in b['items']) {
                                 // item['benefitSKUIds'] check?
                                 // item['discount'] might be 25 (for 50% on 2nd unit: (100+50)/2 = 75% paid? No.
                                 // "2do al 50%" on 2 units = 1.5 units paid. 1.5/2 = 0.75. 25% global discount?
                                 // If discount is 25 and minQuantity is 2, it means 25% off TOTAL when buying 2.
                                 // 2 units cost 0.75 * 2 = 1.5. 
                                 // Real cost: 1 + 0.5 = 1.5. Correct.
                                 
                                 final discount = item['discount'];
                                 final minQty = item['minQuantity'];
                                 
                                 if (discount == 25 && minQty == 2) {
                                     return "2do al 50%";
                                 }
                                 if (discount == 15 && minQty == 2) return "2da al 70%"; 
                                 if (discount == 50 && minQty == 2) return "2x1"; 
                                 if (discount == 33.3 || discount == 33) {
                                     if (minQty == 3) return "3x2";
                                 }
                                 if (discount == 25 && minQty == 4) return "4x3";
                                 
                                 // Generic Fallback
                                 if (discount != null && discount > 0) {
                                    return b['name'] ?? "Oferta especial";
                                 }
                             }
                         }
                     }
                 }
             }
        }
      } catch (e) {
         print('Error fetching benefits: $e');
      }
      return null;
  }

  // Helper to resize VTEX images (Carrefour uses VTEX)
  // Format: .../ids/123456/name.jpgOr .../ids/123456-500-500/name.jpg
  String _resizeVtexImage(String url) {
     if (url.contains('/ids/')) {
        // Replace existing dimensions or insert them
        // Regex to find -number-number
        final regex = RegExp(r'-(\d+)-(\d+)');
        if (regex.hasMatch(url)) {
           return url.replaceFirst(regex, '-200-200');
        } else {
           // Insert dimensions after ID if not present (usually .../ids/ID/name)
           // This is riskier if format varies, but usually safe to append params in query if direct path fails?
           // Actually VTEX allows replacement.
           // Safe bet: just return original if no dimensions found to avoid breaking, 
           // but often it is .../ids/123456/foo.jpg. We can try to inject.
           // Let's stick to replacing if dimensions exist, otherwise leave as is to be safe.
        }
     }
     return url;
  }
}
