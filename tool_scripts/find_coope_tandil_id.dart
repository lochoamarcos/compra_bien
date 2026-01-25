import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Obteniendo locales de La Coope...');
  
  try {
    final response = await http.get(
      Uri.parse('https://api.lacoopeencasa.coop/api/sucursales/listado'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://www.lacoopeencasa.coop/',
      },
    ).timeout(Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (data['estado'] == 1 && data['datos'] != null) {
        final sucursales = data['datos'] as List;
        print('Encontradas ${sucursales.length} sucursales.');
        
        for (var s in sucursales) {
          final nombre = s['descripcion'] as String? ?? '';
          if (nombre.toLowerCase().contains('tandil')) {
            print('🎯 TANDIL ENCONTRADO:');
            print('   ID Local: ${s['id_local']}');
            print('   Descripción: ${s['descripcion']}');
            print('   Dirección: ${s['direccion']}');
          }
        }
      }
    } else {
      print('Error HTTP: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
