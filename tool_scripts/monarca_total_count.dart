import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final res = await http.get(Uri.parse('https://api.monarcadigital.com.ar/products/search?query=&size=1'));
  if (res.statusCode == 200) {
    final Map data = json.decode(res.body);
    print('Total Elements: ${data['products']['totalElements']}');
  }
}
