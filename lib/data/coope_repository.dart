
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/product.dart';
import 'package:flutter/foundation.dart';

/// VERSIÃ“N MEJORADA con fuzzy matching y bÃºsqueda mÃ¡s flexible
class CoopeRepository {
  static const String baseUrl = 'https://www.lacoopeencasa.coop';

  Future<List<Product>> searchProducts(String query, {int page = 0, int size = 32, String? categoryId, bool isPromo = false}) async {
    final client = http.Client();

    try {
      // MEJORA 1: NormalizaciÃ³n mÃ¡s inteligente del query
      final String normalizedQuery = _smartNormalizeQuery(query);
      
      print('[La Coope] Query original: "$query"');
      print('[La Coope] Query normalizado: "$normalizedQuery"');
      
      http.Response response;

      // Public CORS proxy for Web
      const String corsProxy = 'https://corsproxy.io/?';
      
      if (categoryId != null) {
          String endpoint = 'https://api.lacoopeencasa.coop/api/articulos/pagina';
          if (kIsWeb) {
             endpoint = '$corsProxy${Uri.encodeComponent(endpoint)}';
          }
          final categoryUrl = Uri.parse(endpoint);
          
          final payload = {
            "id_busqueda": categoryId,
            "pagina": page,
            "filtros": {
              "preciomenor": -1,
              "preciomayor": -1,
              "categoria": [],
              "marca": [],
              "tipo_seleccion": "categoria",
              "cant_articulos": 0,
              "filtros_gramaje": [],
              "modificado": false,
              "ofertas": isPromo,
              "primer_filtro": "",
              "termino": "",
              "tipo_relacion": "busqueda"
            }
          };
          
          response = await client.post(
            categoryUrl,
            headers: _getHeaders(),
            body: json.encode(payload),
          );
      } else {
          // MEJORA 2: Si la bÃºsqueda principal falla, intentar con variaciones
          response = await _searchWithFallbacks(client, normalizedQuery, page, isPromo);
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        
        if (body['estado'] == 1 && body['datos'] != null) {
          final datos = body['datos'];
          final List<dynamic> articulos = datos['articulos'] ?? [];
          
          print('[La Coope] Resultados encontrados: ${articulos.length}');
          
          List<Product> products = [];
          for (var item in articulos) {
             final String name = item['descripcion'] ?? '';
             final double price = double.tryParse((item['precio'] ?? '0').toString()) ?? 0.0;
             final double? oldPrice = item['precio_anterior'] != null && 
                                     double.tryParse(item['precio_anterior'].toString()) != price 
                  ? double.tryParse(item['precio_anterior'].toString()) 
                  : null;
             
             final String imageUrl = item['imagen'] ?? '';
             final String brand = item['marca_desc'] ?? '';
             
             String rawId = (item['cod_interno'] ?? '').toString();
             String ean = (rawId.length == 13 || rawId.length == 8) ? rawId : '';
             
             String? promoDesc;
             String leyenda = (item['leyenda'] ?? '').toString();
             String descPromo = (item['desc_promo'] ?? '').toString();
             
             if (leyenda.isNotEmpty) {
                promoDesc = leyenda;
             } else if (descPromo.isNotEmpty) {
                promoDesc = descPromo;
             }

             if (item['existe_promo'] == "1" || item['existe_promo'] == 1) {
                if (promoDesc == null && oldPrice != null && oldPrice > price) {
                   int pct = (((oldPrice - price) / oldPrice) * 100).round();
                   promoDesc = "$pct% OFF";
                } else if (promoDesc == null) {
                   promoDesc = "Oferta";
                }
             }

             if (price > 0) {
                products.add(Product(
                  name: name,
                  ean: ean,
                  price: price,
                  oldPrice: oldPrice,
                  source: 'La Coope',
                  imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
                  brand: brand,
                  promoDescription: promoDesc,
                ));
             }
          }
          return products;
        }
      }
      print('[La Coope] API Error: ${response.statusCode}');
      return [];
    } catch (e) {
      print('[La Coope] Exception: $e');
      return [];
    } finally {
      client.close();
    }
  }
  
  /// MEJORA: Normalización más inteligente
  String _smartNormalizeQuery(String query) {
    // 1. Eliminar palabras comunes que no aportan
    final stopWords = ['con', 'para', 'sin', 'los', 'las', 'del', 'de', 'la', 'el', 'en'];
    
    // 2. Extraer palabras clave
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    
    // 3. Tomar las 3 palabras más relevantes (o menos si hay pocas)
    final relevantWords = words.take(3).toList();
    
    // 4. Unir con underscore y uppercase
    return relevantWords.join('_').toUpperCase();
  }
  
  /// MEJORA: Intentar con variaciones si la bÃºsqueda principal falla
  Future<http.Response> _searchWithFallbacks(
    http.Client client, 
    String normalizedQuery, 
    int page, 
    bool isPromo
  ) async {
    const String corsProxy = 'https://corsproxy.io/?';
    String endpoint = 'https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda';
    if (kIsWeb) {
       endpoint = '$corsProxy${Uri.encodeComponent(endpoint)}';
    }
    final searchUrl = Uri.parse(endpoint);
    
    // 1. Intentar bÃºsqueda principal
    var payload = _buildSearchPayload(normalizedQuery, page, isPromo);
    var response = await client.post(
      searchUrl,
      headers: _getHeaders(),
      body: json.encode(payload),
    );
    
    // Si encontró resultados, retornar
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (data['estado'] == 1 && data['datos'] != null) {
        final articulos = data['datos']['articulos'] as List?;
        if (articulos != null && articulos.isNotEmpty) {
          print('[La Coope] ✓ Búsqueda principal exitosa');
          return response;
        }
      }
    }
    
    // 2. FALLBACK: Intentar solo con las primeras 2 palabras
    final words = normalizedQuery.split('_');
    if (words.length > 2) {
      final simplifiedQuery = words.take(2).join('_');
      print('[La Coope] Intentando fallback con: "$simplifiedQuery"');
      
      payload = _buildSearchPayload(simplifiedQuery, page, isPromo);
      response = await client.post(
        searchUrl,
        headers: _getHeaders(),
        body: json.encode(payload),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (data['estado'] == 1 && data['datos'] != null) {
          final articulos = data['datos']['articulos'] as List?;
          if (articulos != null && articulos.isNotEmpty) {
            print('[La Coope] âœ“ Fallback exitoso con 2 palabras');
            return response;
          }
        }
      }
    }
    
    // 3. ÚLTIMO FALLBACK: Solo la primera palabra (generalmente la marca)
    if (words.isNotEmpty) {
      final singleWord = words.first;
      print('[La Coope] Último fallback con: "$singleWord"');
      
      payload = _buildSearchPayload(singleWord, page, isPromo);
      response = await client.post(
        searchUrl,
        headers: _getHeaders(),
        body: json.encode(payload),
      );
    }
    
    return response;
  }
  
  Map<String, dynamic> _buildSearchPayload(String query, int page, bool isPromo) {
    return {
      "pagina": page,
      "filtros": {
        "preciomenor": -1,
        "preciomayor": -1,
        "categoria": [],
        "marca": [],
        "tipo_seleccion": "busqueda",
        "cant_articulos": 0,
        "filtros_gramaje": [],
        "modificado": false,
        "ofertas": isPromo,
        "primer_filtro": "",
        "termino": query,
        "tipo_relacion": "busqueda"
      }
    };
  }
  
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5) AppleWebKit/537.36',
      'Referer': 'https://www.lacoopeencasa.coop/',
      'Origin': 'https://www.lacoopeencasa.coop',
      'Accept': 'application/json, text/plain, */*',
    };
  }
}
