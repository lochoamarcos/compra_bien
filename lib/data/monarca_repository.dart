
import 'package:http/http.dart' as http;
// import 'dart:io'; // Remove dart:io to support Web
import 'dart:convert';
import '../models/product.dart';
import '../models/bank_promotion.dart';

import 'package:flutter/foundation.dart'; // for kIsWeb

class MonarcaRepository {
  static const String baseUrl = 'https://api.monarcadigital.com.ar';
  static const String corsProxy = 'https://corsproxy.io/?';
  
  Future<List<Product>> searchProducts(String query, {int page = 0, int size = 20}) async {
    String endpoint = '$baseUrl/products/search?query=$query&page=$page&size=$size';
    if (kIsWeb) {
      endpoint = '$corsProxy${Uri.encodeComponent(endpoint)}';
    }
    final url = Uri.parse(endpoint);
    
    // On Web, we can't use IOClient to bypass SSL. The browser handles it.
    // If SSL is bad, the browser might block it, but we can't fix that processing code.
    final client = http.Client();

    try {
      final response = await client.get(
        url,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        List<dynamic> content = [];
        if (data.containsKey('products')) {
             var productsVal = data['products'];
             if (productsVal is Map) {
                content = productsVal['content'] ?? [];
             } else if (productsVal is List) {
                content = productsVal;
             }
        } else if (data.containsKey('content')) {
            content = data['content'];
        }

        return await Future.wait(content.map((itemJson) async {
             // Check if it's a "Coronado" item (Tag ID 534)
             bool isCoronado = false;
             if (itemJson['tags'] != null && itemJson['tags'] is List) {
                 final tags = itemJson['tags'] as List;
                 isCoronado = tags.any((t) => t['id'] == 534 || t['description'].toString().contains('coronados'));
             }

             if (isCoronado && itemJson['id'] != null) {
                 // Fetch full details to get 'promotions' data
                 try {
                     final detailJson = await _fetchProductDetail(itemJson['id'].toString(), client);
                     if (detailJson != null) {
                         // Correct "promoDescription" logic for Monarca:
                         // The textual offer is often in 'content' of the promotion, not 'description'.
                         // We pre-process to inject it into a field that Product.fromJson can use if we could,
                         // but Product.fromJson expects standard fields. 
                         
                         // Better: We instantiate Product and then override the description manually here.
                         var prod = Product.fromJson(detailJson, 'Monarca');
                         
                         if (detailJson['promotions'] != null && (detailJson['promotions'] as List).isNotEmpty) {
                             final p = (detailJson['promotions'] as List)[0];
                             // Prefer 'content' (e.g. "35% DE DESCUENTO") over 'description' (e.g. "U30 CORONADOS")
                             // if 'content' exists and looks like a readable offer.
                             if (p['content'] != null && p['content'].toString().isNotEmpty) {
                                 prod = prod.copyWith(promoDescription: p['content'].toString());
                             }
                         }
                         return prod;
                     }
                 } catch (e) {
                     print('Error fetching Monarca detail for ${itemJson['id']}: $e');
                 }
             }
             
             // Standard parsing for non-coronado or fallback
             var prod = Product.fromJson(itemJson, 'Monarca');
             // Also check standard list if 'promotions' exists without detail fetch (unlikely usually, but safe)
             if (itemJson['promotions'] != null && (itemJson['promotions'] as List).isNotEmpty) {
                  final p = (itemJson['promotions'] as List)[0];
                  if (p['content'] != null && p['content'].toString().isNotEmpty) {
                      prod = prod.copyWith(promoDescription: p['content'].toString());
                  }
             }
             return prod;
        }));
      } else {
        print('Monarca API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Monarca Exception: $e');
      return [];
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>?> _fetchProductDetail(String id, http.Client client) async {
      String endpoint = '$baseUrl/products/$id';
      if (kIsWeb) {
        endpoint = '$corsProxy${Uri.encodeComponent(endpoint)}';
      }
      final url = Uri.parse(endpoint);

      try {
          final response = await client.get(url, headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept': 'application/json',
          });

          if (response.statusCode == 200) {
              return json.decode(utf8.decode(response.bodyBytes));
          }
      } catch (e) {
          print('Monarca Detail Fetch Error: $e');
      }
      return null;
  }

  Future<List<BankPromotion>> getBankPromotions() async {
      String endpoint = '$baseUrl/marketingPromotions/getValidPromotions';
      if (kIsWeb) {
        endpoint = '$corsProxy${Uri.encodeComponent(endpoint)}';
      }
      final url = Uri.parse(endpoint);
      final client = http.Client();

      try {
           final response = await client.get(url, headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Accept': 'application/json',
           });

           if (response.statusCode == 200) {
               final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
               return data.map((json) => BankPromotion.fromJson(json, 'Monarca')).toList();
           }
      } catch (e) {
          print('Monarca Bank Promo Error: $e');
      } finally {
          client.close();
      }
      return [];
  }
}
