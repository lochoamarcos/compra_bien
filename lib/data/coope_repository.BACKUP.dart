
import 'package:http/http.dart' as http;
// import 'dart:io'; 
import 'dart:convert';
import '../models/product.dart';

import 'package:flutter/foundation.dart'; // for kIsWeb

class CoopeRepository {
  static const String baseUrl = 'https://www.lacoopeencasa.coop';
  // Using a public CORS proxy for demo purposes on Web
  static const String corsProxy = 'https://corsproxy.io/?';

  Future<List<Product>> searchProducts(String query, {int page = 0, int size = 32, String? categoryId, bool isPromo = false}) async {
    // FIXED: Use /pagina_busqueda endpoint for text search
    // Query normalization: uppercase + replace spaces with underscores
    final client = http.Client();

    try {
      // Normalize query for API (uppercase, replace spaces with underscores)
      final String normalizedQuery = query.toUpperCase().replaceAll(' ', '_');
      
      http.Response response;
      
      if (categoryId != null) {
          // Category Search uses /pagina endpoint
          final categoryEndpoint = 'https://api.lacoopeencasa.coop/api/articulos/pagina';
          final categoryUrl = Uri.parse(categoryEndpoint);
          
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
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5) AppleWebKit/537.36',
              'Referer': 'https://www.lacoopeencasa.coop/',
              'Origin': 'https://www.lacoopeencasa.coop',
              'Accept': 'application/json, text/plain, */*',
            },
            body: json.encode(payload),
          );
      } else {
          // Text Search uses /pagina_busqueda endpoint
          final searchEndpoint = 'https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda';
          final searchUrl = Uri.parse(searchEndpoint);
          
          final payload = {
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
              "termino": normalizedQuery,
              "tipo_relacion": "busqueda"
            }
          };
          
          response = await client.post(
            searchUrl,
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5) AppleWebKit/537.36',
              'Referer': 'https://www.lacoopeencasa.coop/',
              'Origin': 'https://www.lacoopeencasa.coop',
              'Accept': 'application/json, text/plain, */*',
            },
            body: json.encode(payload),
          );
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        
        if (body['estado'] == 1 && body['datos'] != null) {
          final datos = body['datos'];
          final List<dynamic> articulos = datos['articulos'] ?? [];
          
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
             
             // Detect real EAN vs Internal ID
             // Standard EANs are 13 or 8 digits. Internal IDs are usually shorter or different.
             String rawId = (item['cod_interno'] ?? '').toString();
             String ean = (rawId.length == 13 || rawId.length == 8) ? rawId : '';
             
             String? promoDesc;
             // Check for 2nd unit promo details (often in 'leyenda' or 'desc_promo')
             String leyenda = (item['leyenda'] ?? '').toString();
             String descPromo = (item['desc_promo'] ?? '').toString();
             
             if (leyenda.isNotEmpty) {
                promoDesc = leyenda; // e.g. "50% EN LA 2DA"
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
      print('Coope API Error: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Coope Exception: $e');
      return [];
    } finally {
      client.close();
    }
  }
}
