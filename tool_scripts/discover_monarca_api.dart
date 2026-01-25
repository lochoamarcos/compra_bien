import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- Checking Monarca Categories ---');
  final baseUrl = 'https://api.monarcadigital.com.ar';
  final endpoints = [
    '/categories',
    '/products/categories',
    '/taxonomy',
    '/menu',
  ];

  for (var e in endpoints) {
    print('Testing $e...');
    try {
      final res = await http.get(Uri.parse('$baseUrl$e'));
      if (res.statusCode == 200) {
        print('✅ Found something at $e');
        print(res.body.substring(0, 500));
      } else {
        print('❌ $e returned ${res.statusCode}');
      }
    } catch (e) {
      print('Error at $e: $e');
    }
  }
}
