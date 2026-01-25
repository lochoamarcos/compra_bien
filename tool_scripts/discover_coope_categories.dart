
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('--- DISCOVERING COOPE CATEGORIES ---');
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina');
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Referer': 'https://www.lacoopeencasa.coop/',
    'Origin': 'https://www.lacoopeencasa.coop',
  };

  // Iterate IDs 3 to 6 to confirm mapping
  for (int i = 3; i <= 6; i++) {
      final payload = {
        "id_busqueda": i.toString(),
        "pagina": 0,
        "filtros": {
          "preciomenor": -1,
          "preciomayor": -1,
          "marca": [],
          "categoria": [],
          "tipo_seleccion": "categoria", // Changed from "busqueda" to "categoria" likely? 
          // User said: tipo_seleccion: "categoria" in their example payload.
          "cant_articulos": 0,
          "filtros_gramaje": [],
          "modificado": false,
          "ofertas": false,
          "primer_filtro": "",
          "termino": "", // Empty term?
          "tipo_relacion": "busqueda" // Or maybe this changes too? User payload showed "tipo_relacion": "busqueda"
        }
      };

      try {
        final response = await http.post(url, headers: headers, body: json.encode(payload));
        if (response.statusCode == 200) {
           final body = json.decode(utf8.decode(response.bodyBytes));
           if (body['estado'] == 1 && body['datos'] != null) {
               final datos = body['datos'];
               // Try to find a specific field that says the category name
               // Often in 'filtros_disponibles' -> 'categoria' or similar
               // Or just listing the first few products to infer
               
               final List items = datos['articulos'] ?? [];
               if (items.isNotEmpty) {
                   print('ID $i: Found ${items.length} items.');
                   // Infer category from first item
                   print('  Example: ${items[0]['descripcion']}');
                   
                   // Check structure for Category Name hint
                   // sometimes returned in other fields of 'datos'
                   if (datos['nombre_seccion'] != null) {
                       print('  Section Name: ${datos['nombre_seccion']}');
                   }
               } else {
                   print('ID $i: No items found.');
               }
           } else {
               print('ID $i: State ${body['estado']} (Empty?)');
           }
        } else {
           print('ID $i: HTTP ${response.statusCode}');
        }
      } catch (e) {
        print('ID $i: Error $e');
      }
      print('---');
  }
}
