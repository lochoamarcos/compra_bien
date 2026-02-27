import 'dart:io';
import '../lib/data/monarca_repository.dart';
import '../lib/data/coope_repository.dart';
import '../lib/data/vea_repository.dart';
import '../lib/data/carrefour_repository.dart';
import '../lib/models/product.dart';

void main() async {
  print('--- Monarca ---');
  final monarcaRepo = MonarcaRepository();
  final monarcaRes = await monarcaRepo.searchProducts('Agua Saborizada Naranja');
  for (var p in monarcaRes.take(3)) {
    print('Name: ${p.name} | Pres: ${p.presentation} | EAN: ${p.ean}');
  }

  print('\n--- La Coope ---');
  final coopeRepo = CoopeRepository();
  final coopeRes = await coopeRepo.searchProducts('Agua Saborizada Naranja');
  for (var p in coopeRes.take(3)) {
    print('Name: ${p.name} | Pres: ${p.presentation} | EAN: ${p.ean}');
  }

  print('\n--- Vea ---');
  final veaRepo = VeaRepository();
  final veaRes = await veaRepo.searchProducts('Agua Saborizada Naranja');
  for (var p in veaRes.take(3)) {
    print('Name: ${p.name} | Pres: ${p.presentation} | EAN: ${p.ean}');
  }
}
