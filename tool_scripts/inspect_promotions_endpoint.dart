import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://api.monarcadigital.com.ar/promotions');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final dynamic data = json.decode(utf8.decode(response.bodyBytes));
      
      print('Type: ${data.runtimeType}');
      if (data is List) {
        print('Items: ${data.length}');
        if (data.isNotEmpty) {
           print('First item keys: ${data[0].keys.toList()}');
           print('First item sample: ${data[0]}');
        }
      } else if (data is Map) {
         print('Keys: ${data.keys.toList()}');
      }
    } else {
      print('Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
