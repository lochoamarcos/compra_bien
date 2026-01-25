import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Try with trailing slash
  const baseUrl = 'https://lacoopeencasa.coop/api/destacados/buscar/'; 
  print('Testing Coope with trailing slash: $baseUrl');
  
  final payload = {
    "paginacion": {"pagina": 1, "cantidad": 5},
    "orden": "relevancia",
    "palabra": "",
    "filtros": {
      "ofertas": true, 
      "id_categoria": "", 
      "marcas": [], 
      "precios": {"min": 0, "max": 0}
    }
  };
  
  try {
     final res = await http.post(Uri.parse(baseUrl), 
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload)
     );
     
     if (res.statusCode == 200) {
         final data = json.decode(res.body);
         // The actual response structure might be different, let's print keys
         print('Success! Body keys: ${data.keys.toList()}');
         if (data['productos'] != null) {
            print('Productos count: ${(data['productos'] as List).length}');
         } else if (data['data'] != null) {
             print('Data count: ${(data['data'] as List).length}');
         }
     } else {
         print('Error ${res.statusCode}');
         print('Headers: ${res.headers}');
     }
  } catch(e) {
      print('Exception $e');
  }
}
