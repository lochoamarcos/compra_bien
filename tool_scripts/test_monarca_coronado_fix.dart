import '../lib/models/product.dart';

void main() {
  print('--- Testing Monarca Coronado Logic ---');
  
  final Map<String, dynamic> json = {
    'description': 'Test Coronado Item',
    'price': 1500,
    'tags': [
      {'id': 534, 'description': 'coronados'},
      {'id': 999, 'description': 'other'}
    ]
  };
  
  try {
      final p = Product.fromJson(json, 'Monarca');
      print('Name: ${p.name}');
      print('Promo Desc: ${p.promoDescription}');
      
      if (p.promoDescription == 'Precio Coronado') {
          print('SUCCESS: Detected Coronado tag correctly.');
      } else {
          print('FAILURE: Expected "Precio Coronado", got "${p.promoDescription}"');
      }
  } catch (e) {
      print('Error: $e');
  }
}
