
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  await fetchVea('FRESCOS'); 
  await fetchVea('LACTEOS');
}

Future<void> fetchVea(String query) async {
  print('--- VEA DEBUG ($query) ---');
  final url = Uri.parse('https://www.vea.com.ar/api/catalog_system/pub/products/search?ft=$query&_from=0&_to=5');
  
  try {
    final response = await http.get(url, headers: {
       'User-Agent': 'Mozilla/5.0'
    });
    
    if (response.statusCode == 200 || response.statusCode == 206) {
       final List data = json.decode(response.body);
       print('VEA Found ${data.length} items');
       for (var item in data.take(5)) {
           final items = item['items'] as List;
           if (items.isNotEmpty) {
               final sku = items[0];
               print('  Name: ${item['productName']}');
               print('  Brand: ${item['brand']}');
               print('  EAN: ${sku['ean']}');
               // Helper to normalize
               String name = '${item['brand']} ${item['productName']}';
               print('  Normalized: ${normalizeName(name)}');
               print('-------------------');
           }
       }
    } else {
        print('Vea Error ${response.statusCode}');
    }
  } catch (e) {
      print('Vea Exception $e');
  }
}

Future<void> fetchCoope() async {
  print('--- LA COOPE DEBUG ---');
  final url = Uri.parse('https://api.lacoopeencasa.coop/api/articulos/pagina_busqueda');
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Referer': 'https://www.lacoopeencasa.coop/',
    'Origin': 'https://www.lacoopeencasa.coop',
  };
  
  // Search for Coca Cola to check 2250cm3 issue
  // Also search for a category-like term
  final queries = ['COCA_COLA', 'ALMACEN'];

  for (var q in queries) {
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
          "ofertas": false,
          "primer_filtro": "",
          "termino": q,
          "tipo_relacion": "busqueda"
        },
        "pagina": 0
      };

      try {
        final response = await http.post(url, headers: headers, body: json.encode(payload));
        if (response.statusCode == 200) {
           final body = json.decode(utf8.decode(response.bodyBytes));
           final items = body['datos']['articulos'] as List;
           print('Query: $q - Found ${items.length} items');
           
           // Print first 5 items names and details
           for (var item in items.take(5)) {
              print('  Name: ${item['descripcion']}');
              print('  Brand: ${item['marca_desc']}');
              print('  Price: ${item['precio']}');
              print('  Promo: ${item['existe_promo']}');
              
              if (item['existe_promo'] == 1 || item['existe_promo'] == "1") {
                  print('  FULL JSON PROMO: $item');
              }

              // Test Normalization
              String name = '${item['marca_desc']} ${item['descripcion']}';
              String norm = normalizeName(name);
              print('  Normalized: $norm');
              print('-------------------');
           }
        } else {
           print('Error ${response.statusCode}');
        }
      } catch (e) {
        print('Error: $e');
      }
  }
}

String normalizeName(String name) {
    if (name.isEmpty) return '';
    String s = name.toLowerCase();
    s = s.replaceAll('-', ' '); 
    const accents = 'áéíóúüñ';
    const noAccents = 'aeiouun';
    for (int i = 0; i < accents.length; i++) {
       s = s.replaceAll(accents[i], noAccents[i]);
    }
    s = s.replaceAll('sin azucares', 'zero');
    s = s.replaceAll('sin azucar', 'zero');
    s = s.replaceAll('light', 'zero'); 
    s = s.replaceAll('s/az', 'zero'); 

    s = s.replaceAllMapped(RegExp(r'(\d+[\.,]?\d*)\s*(cm3|cc|ml|grs|lts|gr|lt|litros|kg|g|l|k)\b'), (Match m) {
        String numStr = m.group(1)!.replaceAll(',', '.');
        double val = double.tryParse(numStr) ?? 0;
        String unit = m.group(2)!.toLowerCase();
        if (unit == 'kg' || unit == 'l' || unit == 'lt' || unit == 'lts' || unit == 'litros' || unit == 'k') {
           return '$val'; 
        }
        return '${val / 1000}'; 
    });
    
    s = s.replaceAllMapped(RegExp(r'\b(\d{3,5})\b'), (Match m) {
        double val = double.tryParse(m.group(1)!) ?? 0;
        if (val >= 100 && val < 10000) {
           return '${val / 1000}'; 
        }
        return m.group(0)!;
    });

    s = s.replaceAll(RegExp(r'\b(x|gaseosa|botella|retornable|descartable|sabor|original|frasco|bolsa|caja|pack|polvo|cm3|ml|lts|cc|gr|grs|kg|pet|litros|lt|de|en|la|el|los|las|un|una)\b'), ' ');
    s = s.replaceAll(RegExp(r'[^a-z0-9\s\.]'), '');
    
    List<String> words = s.split(' ').where((w) => w.trim().isNotEmpty).map((w) {
        if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
           return w.substring(0, w.length - 1);
        }
        return w;
    }).toList();
    
    words.sort();
    return words.join(' ');
}
