import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final queries = ['garbanzo', 'garbanzos'];
  
  for (final q in queries) {
    print('====================================');
    print('SEARCHING FOR: \$q');
    print('====================================\n');
    
    await testMonarca(q);
    await testCarrefour(q);
    await testVea(q);
    await testCoope(q);
  }
}

Future<void> testMonarca(String query) async {
  print('--- MONARCA ---');
  try {
    final originalUrl = 'https://us-central1-comprabien-fadb5.cloudfunctions.net/api/v1/monarca/search?q=\$query';
    final response = await http.get(Uri.parse(originalUrl));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final products = jsonResponse['products'] as List?;
      print('Status: 200, Count: \${products?.length ?? 0}');
      if (products != null && products.isNotEmpty) {
        for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
          print('  - \${products[i]["name"]} (EAN: \${products[i]["ean"]})');
        }
      }
    } else {
      print('Error \${response.statusCode}: \${response.body}');
    }
  } catch (e) {
    print('Exception: \$e');
  }
  print('');
}

Future<void> testCarrefour(String query) async {
  print('--- CARREFOUR ---');
  try {
    final originalUrl = 'https://us-central1-comprabien-fadb5.cloudfunctions.net/api/v1/carrefour/search?q=\$query';
    final response = await http.get(Uri.parse(originalUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final products = data['products'] as List?;
      print('Status: 200, Count: \${products?.length ?? 0}');
      if (products != null && products.isNotEmpty) {
        for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
          print('  - \${products[i]["name"]} (EAN: \${products[i]["ean"]})');
        }
      }
    } else {
      print('Error \${response.statusCode}: \${response.body}');
    }
  } catch (e) {
    print('Exception: \$e');
  }
  print('');
}

Future<void> testVea(String query) async {
  print('--- VEA ---');
  try {
    final originalUrl = 'https://us-central1-comprabien-fadb5.cloudfunctions.net/api/v1/vea/search?q=\$query';
    final response = await http.get(Uri.parse(originalUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final products = data['products'] as List?;
      print('Status: 200, Count: \${products?.length ?? 0}');
      if (products != null && products.isNotEmpty) {
        for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
          print('  - \${products[i]["name"]} (EAN: \${products[i]["ean"]})');
        }
      }
    } else {
      print('Error \${response.statusCode}: \${response.body}');
    }
  } catch (e) {
    print('Exception: \$e');
  }
  print('');
}

Future<void> testCoope(String query) async {
  print('--- LA COOPE ---');
  try {
    final originalUrl = 'https://us-central1-comprabien-fadb5.cloudfunctions.net/api/v1/coope/search?q=\$query';
    final response = await http.get(Uri.parse(originalUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final products = data['products'] as List?;
      print('Status: 200, Count: \${products?.length ?? 0}');
      if (products != null && products.isNotEmpty) {
        for (int i = 0; i < (products.length > 5 ? 5 : products.length); i++) {
          print('  - \${products[i]["name"]} (EAN: \${products[i]["ean"]})');
        }
      }
    } else {
      print('Error \${response.statusCode}: \${response.body}');
    }
  } catch (e) {
    print('Exception: \$e');
  }
  print('');
}
