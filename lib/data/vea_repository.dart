import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/product.dart';
import '../utils/app_config.dart';
class VeaRepository {
  static const String baseUrl = 'https://www.vea.com.ar';

  Future<List<Product>> searchProducts(String query, {int page = 0, int size = 20, String? categoryId}) async {
    final from = page * size;
    final to = (page + 1) * size - 1;
    // Removed sc=1 parameter - it causes "sc is inactive" error
    String endpoint = '$baseUrl/api/catalog_system/pub/products/search?_from=$from&_to=$to';
    if (categoryId != null && categoryId.isNotEmpty) {
      endpoint += '&fq=C:$categoryId';
      if (query.isNotEmpty) endpoint += '&ft=$query';
    } else {
      endpoint += '&ft=$query';
    }
    if (kIsWeb) {
      // Use internal Vercel rewrite proxy
      endpoint = endpoint.replaceFirst(baseUrl, AppConfig.veaProxy);
    }
    final url = Uri.parse(endpoint);
     
    final client = http.Client();

    try {
      final response = await client.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          // TANDIL REGIONAL HEADERS
          'Cookie': 'seguimiento_seller=jumboargentinav711tandil',
          'X-VTEX-Shipping-PostalCode': '7000',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        List<Product> products = [];
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
               // Check if complement contains volume-like info (ml, L, cc, gr, kg, etc)
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
                 // Check if stock is available
                 final available = commertialOffer['AvailableQuantity'] != null && commertialOffer['AvailableQuantity'] > 0;
                 if (available) {
                    // Vea often returns 'Price' as the selling price.
                    // 'ListPrice' is the old price.
                    // 'PriceWithoutDiscount' might exist.
                    // We must ensure we parse a pure double, not a string like "($2.428...)" which was seen in other properties.
                    // But commertialOffer['Price'] is usually a number in the JSON search API.
                    
                    price = (commertialOffer['Price'] ?? 0.0).toDouble();
                    double listPrice = (commertialOffer['ListPrice'] ?? 0.0).toDouble();
                    
                    // Sanity check: if Price is 0 or crazy, log it.
                    if (price <= 0) {
                       // Try PriceWithoutDiscount
                       price = (commertialOffer['PriceWithoutDiscount'] ?? 0.0).toDouble();
                    }

                    // User Feedback: Excessive discounts? 
                    // Sanity Check: If ListPrice is significantly larger than Price (e.g., > 10x), it might be an error.
                    // Also check PriceWithoutDiscount as a source for oldPrice.
                    double priceWithoutDiscount = (commertialOffer['PriceWithoutDiscount'] ?? 0.0).toDouble();

                    if (listPrice > price && listPrice < price * 10) {
                         oldPrice = listPrice;
                    } else if (priceWithoutDiscount > price && priceWithoutDiscount < price * 10) {
                         // Fallback to PriceWithoutDiscount if ListPrice is weird, but PWOD is sane
                         oldPrice = priceWithoutDiscount;
                    }
                 }
               }
             }

             // Validate EAN (must be 8 or 13 digits) to avoid internal IDs breaking matching
             if (ean.length != 8 && ean.length != 13) {
                 ean = '';
             }

             String? promoDesc;
             if (oldPrice != null && oldPrice > price) {
                 int pct = (((oldPrice - price) / oldPrice) * 100).round();
                 // Sanity check: Vea has a bug where ListPrice is sometimes huge (e.g. $433,884 vs $5,250)
                 // resulting in 98% off. We ignore these crazy discounts.
                 if (pct < 90) {
                     promoDesc = "$pct% OFF";
                 }
             }
             
             if ((ean.isNotEmpty || name.isNotEmpty) && price > 0) {
               products.add(Product(
                 name: name,
                 ean: ean,
                 price: price,
                 source: 'Vea',
                 imageUrl: imageUrl,
                 brand: item['brand'],
                 oldPrice: oldPrice,
                 promoDescription: promoDesc, 
               ));
             }
           }
        }
        return products;
      } else {
        print('Vea API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Vea Exception: $e');
      return [];
    } finally {
      client.close();
    }
  }
  
  String _resizeVtexImage(String url) {
     if (url.contains('/ids/')) {
        final regex = RegExp(r'-(\d+)-(\d+)');
        if (regex.hasMatch(url)) {
           return url.replaceFirst(regex, '-200-200');
        }
     }
     return url;
  }
}
