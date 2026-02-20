import '../lib/data/monarca_repository.dart';
import '../lib/data/carrefour_repository.dart';
import '../lib/data/vea_repository.dart';
import '../lib/models/product.dart';

void main() async {
  final monarca = MonarcaRepository();
  final carrefour = CarrefourRepository();
  final vea = VeaRepository();

  print('--- Testing Bank Promos ---');

  // Keywords to look for
  final updates = ['galicia', 'santander', 'bbva', 'macro', 'cuenta dni', 'banco', 'tarjeta'];

  Future<void> check(String source, List<Product> products) async {
      print('\nChecking $source (${products.length} items)...');
      int found = 0;
      for (var p in products) {
          final content = p.promoDescription?.toLowerCase() ?? '';
          final name = p.name.toLowerCase();
          
          bool match = false;
          for (var k in updates) {
              if (content.contains(k) || name.contains(k)) {
                  match = true;
                  print('[$source] FOUND: ${p.name}');
                  print('   > Promo: ${p.promoDescription}');
                  print('   > Price: ${p.price} (Old: ${p.oldPrice})');
              }
          }
          if (match) found++;
      }
      print('Found $found bank/card promos in $source sample.');
  }

  try {
    // 1. Carrefour - Search for "celular" or "tv" or generic to find promos
    // Or just "oferta"
    print('Fetching Carrefour...');
    final cProds = await carrefour.searchProducts('oferta', page: 0, size: 50);
    await check('Carrefour', cProds);

    // 2. Monarca
    print('Fetching Monarca...');
    final mProds = await monarca.searchProducts('vino', page: 0, size: 50); // Wines often have promos
    await check('Monarca', mProds);
    
    // 3. Vea
    print('Fetching Vea...');
    final vProds = await vea.searchProducts('oferta', page: 0, size: 50);
    await check('Vea', vProds);

  } catch (e) {
    print('Error: $e');
  }
}
