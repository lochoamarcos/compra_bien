import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String baseUrl = 'https://api.monarcadigital.com.ar';
  
  // Check /promotions
  print('CHECKING: $baseUrl/promotions');
  var response = await http.get(Uri.parse('$baseUrl/promotions'));
  print('Status: ${response.statusCode}');
  if (response.statusCode == 200) {
      print('Body sample: ${response.body.substring(0, 100)}');
  }

  // Check /products/search?query=ofertas
  print('\nCHECKING: $baseUrl/products/search?query=ofertas');
  response = await http.get(Uri.parse('$baseUrl/products/search?query=ofertas'));
  print('Status: ${response.statusCode}');
  if (response.statusCode == 200) {
      // Decode and count
      try {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        print('Items: ${data['products']['content'].length} (if structured as expected)');
      } catch (e) {
        print('Could not parse count: $e');
        print('Body sample: ${response.body.substring(0, 100)}');
      }
  }
}
