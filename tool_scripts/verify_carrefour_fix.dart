import '../lib/data/carrefour_repository.dart';
import '../lib/models/product.dart';

Future<void> main() async {
  final repo = CarrefourRepository();
  print('Searching "cerveza blanca quilmes sin alcohol"...');
  
  final products = await repo.searchProducts('cerveza blanca quilmes sin alcohol');
  
  print('Found ${products.length} products.');
  for (var p in products) {
      print('---');
      print('Name: ${p.name}');
      print('Price: ${p.price}');
      print('Promo: ${p.promoDescription}');
      if (p.promoDescription == "2do al 50%") {
          print('✅ SUCCESS: Found target promotion!');
      }
  }
}
