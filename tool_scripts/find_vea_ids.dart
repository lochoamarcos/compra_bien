import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final targets = [
    'Electro', 'Tiempo Libre', 'Almacén', 'Almacen', 'Bebidas', 'Carnes', 
    'Frutas y Verduras', 'Verduras', 'Frutas', 'Lácteos', 'Lacteos', 'Perfumería', 'Perfumeria',
    'Mundo Bebé', 'Bebe', 'Limpieza', 'Quesos y Fiambres', 'Quesos', 'Fiambres',
    'Congelados', 'Panadería y Pastelería', 'Panadería', 'Pastelería', 'Panaderia',
    'Pastas Frescas', 'Pastas', 'Rotisería', 'Rotiseria', 'Mascotas', 'Hogar y Textil', 'Hogar'
  ];

  print('\n=== VEA CATEGORIES ONLY ===');
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
    final id = cat['id'];
    Navigation currentPath = Navigation(name, parentPath);
    
    // Check match
    bool match = false;
    for (var t in targets) {
        if (name.toString().toLowerCase() == t.toLowerCase()) {
            match = true;
            break;
        }
    }
    
    if (match) {
        print('[MATCH] "$name" (ID: $id) - Path: ${currentPath.fullPath}');
    }

    if (cat['children'] != null && (cat['children'] as List).isNotEmpty) {
        _searchRecursive(cat['children'], targets, currentPath.fullPath);
    }
  }
}

class Navigation {
    final String name;
    final String parent;
    String get fullPath => parent.isEmpty ? name : "$parent > $name";
    Navigation(this.name, this.parent);
}
