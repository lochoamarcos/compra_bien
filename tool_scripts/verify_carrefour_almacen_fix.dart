import '../lib/data/carrefour_repository.dart';
import '../lib/models/product.dart';

Future<void> main() async {
  final repo = CarrefourRepository();
  print('Searching Carrefour Category "Almacen" (ID: 161)...');
  
  // Mimic ProductProvider logic: searchProducts('', categoryId: '161')
  final products = await repo.searchProducts('', categoryId: '161');
  
  print('Found ${products.length} products.');
  if (products.isNotEmpty) {
      print('First item: ${products[0].name} | Price: ${products[0].price}');
      print('SUCCESS: Category 161 is valid.');
  } else {
      print('FAILURE: Category 161 returned no results.');
  }
}
