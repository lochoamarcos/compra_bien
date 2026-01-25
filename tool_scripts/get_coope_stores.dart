import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Fetching La Coope stores...');
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/contenido/locales');
  try {
    final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'});
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      print('Response: $data');
    } else {
      print('HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
