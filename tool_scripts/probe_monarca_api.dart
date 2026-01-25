import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // 1. Probe Endpoints
  final Endpoints = [
      'https://api.monarcadigital.com.ar/categories',
      'https://api.monarcadigital.com.ar/rubros',
      'https://api.monarcadigital.com.ar/menu',
      'https://api.monarcadigital.com.ar/filters',
      'https://api.monarcadigital.com.ar/products/categories',
  ];
  
  print('=== Probing Endpoints ===');
  for (var url in Endpoints) {
      try {
          final res = await http.get(Uri.parse(url));
          print('$url -> ${res.statusCode}');
          if (res.statusCode == 200) {
              print('Content Preview: ${res.body.substring(0, (res.body.length > 200 ? 200 : res.body.length))}');
          }
      } catch (e) {
          print('$url -> Error: $e');
      }
  }
  
  // 2. Test Filtering Parameters
  print('\n=== Testing Filters ===');
  // Base query "leche" returns many items.
  // We saw "ENTERA" (count 7) as a categoryDetail.
  // Let's try to filter by it.
  
  final params = [
      'category=ENTERA',
      'categoryName=ENTERA',
      'rubro=ENTERA',
      'filter=ENTERA',
      'fq=C:ENTERA',
      'categories=ENTERA',
  ];
  
  for (var p in params) {
      final url = 'https://api.monarcadigital.com.ar/products/search?query=leche&page=0&size=5&$p';
      try {
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
              final data = json.decode(res.body);
              final content = data['content'] as List? ?? [];
              final total = data['page']?['totalElements'] ?? 0; // Check metadata
              
              // If filtering works, total should be roughly 7 (from previous count) or at least different from unfiltered
              // Unfiltered "leche" count needs to be known?
              // Previous run showed "ENTERA" count 7.
              
              print('Param "$p" -> Total Items: $total (First: ${content.isNotEmpty ? content[0]['description'] : "None"})');
          } 
      } catch (e) {
          print('Param "$p" -> Error: $e');
      }
  }
}
