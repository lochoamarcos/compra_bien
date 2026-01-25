import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- Probing Monarca Detail Endpoint ---');
  final baseUrl = 'https://api.monarcadigital.com.ar/products';
  
  // IDs found in previous scan: 679546 (Cerveza IPA), 12953 (Vino), 14534 (Sal)
  final ids = ['679546', '12953', '14534'];

  for (var id in ids) {
      print('\nFetching ID: $id');
      final uri = Uri.parse('$baseUrl/$id');
      
      try {
        final res = await http.get(uri);
        print('Status: ${res.statusCode}');
        if (res.statusCode == 200) {
             final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
             print(JsonEncoder.withIndent('  ').convert(data));
        }
      } catch (e) {
         print('Error: $e');
      }
  }
}
