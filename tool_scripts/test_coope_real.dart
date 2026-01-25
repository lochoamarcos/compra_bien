import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const baseUrl = 'https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda';
  print('Testing Real Coope Endpoint: $baseUrl');
  
  final payload = {
    "filtros": {
      "preciomenor": -1,
      "preciomayor": -1,
      "categoria": [],
      "marca": [],
      "tipo_seleccion": "busqueda",
      "cant_articulos": 0,
      "filtros_gramaje": [],
      "modificado": false,
      "ofertas": true, // Test Promos
      "primer_filtro": "",
      "termino": "",
      "tipo_relacion": "busqueda"
    },
    "pagina": 1
  };
  
  try {
     final res = await http.post(Uri.parse(baseUrl), 
        headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
            'Origin': 'https://www.lacoopeencasa.coop',
            'Referer': 'https://www.lacoopeencasa.coop/'   
        },
        body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(utf8.decode(res.bodyBytes));
         if (data['estado'] == 1) {
            final list = data['datos']['articulos'] as List;
            print('Success! Found ${list.length} promos.');
            if (list.isNotEmpty) print('Sample: ${list[0]['descripcion']}');
         } else {
            print('API returned error state: ${data['estado']}');
         }
     } else {
         print('Error ${res.statusCode}');
     }
  } catch(e) {
      print('Exception $e');
  }
}
