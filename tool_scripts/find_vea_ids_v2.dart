import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final targets = [
    'Electro', 'Tiempo Libre', 'Almacén', 'Almacen', 'Bebidas', 'Carnes', 
    'Frutas y Verduras', 'Verduras', 'Frutas', 'Lácteos', 'Lacteos', 'Perfumería', 'Perfumeria',
    'Mundo Bebé', 'Bebe', 'Limpieza', 'Quesos y Fiambres', 'Quesos', 'Fiambres',
    'Congelados', 'Panadería y Pastelería', 'Panadería', 'Pastelería', 'Panaderia',
    'Pastas Frescas', 'Pastas', 'Rotisería', 'Rotiseria', 'Mascotas', 'Hogar y Textil', 'Hogar',
    'Mundo Bebe', 'Indumentaria', 'Automotor', 'Ferretería'
  ];

  print('\n=== VEA CATEGORIES (Clean Run) ===');
  await findInTree('https://www.vea.com.ar/api/catalog_system/pub/category/tree/3', targets);
}

Future<void> findInTree(String url, List<String> targets) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      _searchRecursive(data, targets, "");
    } else {
      print('Failed to fetch tree: ${res.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

void _searchRecursive(List data, List<String> targets, String parentPath) {
  for (var cat in data) {
    final name = cat['name'];
    final int id = cat['id'];
    String currentPath = parentPath.isEmpty ? name : "$parentPath > $name";

    // Check match
    bool match = false;
    for (var t in targets) {
        if (name.toString().toLowerCase() == t.toLowerCase()) {
            match = true;
            break;
        }
    }
    
    if (match) {
        // Use simpler print format to avoid buffer weirdness?
        print('MATCH: "$name" ID:$id');
    }

    if (cat['children'] != null && (cat['children'] as List).isNotEmpty) {
        _searchRecursive(cat['children'], targets, currentPath);
    }
  }
}
