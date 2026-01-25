import '../lib/data/monarca_repository.dart';

void main() async {
  print('--- Testing Monarca Detail Integration ---');
  final repo = MonarcaRepository();
  
  // Searching for "coronados" explicitly to trigger the logic
  print('Searching for "coronados"...');
  final results = await repo.searchProducts('coronados', size: 5);
  
  print('Found ${results.length} results.');
  for (var p in results) {
      print('Name: ${p.name}');
      print('Price: ${p.price}');
      print('Old Price: ${p.oldPrice}');
      print('Promo: ${p.promoDescription}');
      print('---');
  }
}
