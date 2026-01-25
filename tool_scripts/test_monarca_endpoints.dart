import 'package:http/http.dart' as http;

void main() async {
  const String baseUrl = 'https://api.monarcadigital.com.ar';
  final endpoints = [
    '/products/offers',
    '/products/promotions',
    '/products/on-sale',
    '/offers',
    '/promotions',
    '/products/search?query=ofertas', // Plural
    '/products/search?query=&promotions=true', // Query param guess
    '/products/search?query=&offer=true', // Query param guess
  ];

  for (final ep in endpoints) {
    print('Testing: $ep');
    try {
        final response = await http.get(Uri.parse('$baseUrl$ep'));
        print('  -> Status: ${response.statusCode}');
        if (response.statusCode == 200) {
            print('  -> SUCCESS! Content length: ${response.body.length}');
        }
    } catch (e) {
        print('  -> Error: $e');
    }
  }
}
