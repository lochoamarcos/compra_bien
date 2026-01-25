import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  test('Fetch Monarca Chocolino', () async {
    // Modify URL to use a standard user agent to avoid basic blocks?
    // Monarca API seems to need User-Agent.
    // Use CORS proxy to try and bypass 403 or mimicking browser
    final url = Uri.parse('https://corsproxy.io/?https://api.monarcadigital.com.ar/api/products/search?query=chocolino&page=0&size=5');
    final response = await http.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    });
    
    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      print('MONARCA JSON START');
      print(jsonEncode(json)); // Print all to inspect
      print('MONARCA JSON END');
    } else {
      print('Failed: ${response.statusCode}');
    }
  });
}
