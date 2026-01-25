import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  await inspectResponse('leche');
}

Future<void> inspectResponse(String query) async {
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  
  final payload = {
    "palabraclave": query.toUpperCase().replaceAll(' ', '_'),
    "pagina": 0,
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
    }
  };
  
  print('=== Inspecting La Coope Response for "$query" ===\n');
  
  try {
     final res = await http.post(
       url, 
       headers: {
         'Content-Type': 'application/json',
         'User-Agent': 'Mozilla/5.0',
       },
       body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         
         print('Top-level keys: ${data.keys.toList()}');
         print('Estado: ${data['estado']}');
         print('Mensaje: ${data['mensaje']}');
         
         if (data['datos'] != null) {
             final datos = data['datos'];
             print('\nDatos keys: ${datos.keys.toList()}');
             
             // Check for articles
             if (datos['articulos'] != null) {
                 List items = datos['articulos'];
                 print('Found ${items.length} items in datos.articulos');
                 if (items.isNotEmpty) {
                     print('\nFirst item structure:');
                     print(JsonEncoder.withIndent('  ').convert(items[0]));
                 }
             }
             
             // Check for categories
             if (datos['categorias'] != null) {
                 print('\nAvailable categories:');
                 print(JsonEncoder.withIndent('  ').convert(datos['categorias']));
             }
         }
     } else {
         print('HTTP ${res.statusCode}');
     }
  } catch (e) {
      print('Exception: $e');
  }
}
