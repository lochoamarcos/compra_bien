
void main() {
  testMatch("gaseosa coca-cola sabor original descartable 2250cm3", "Coca Cola Sabor Original 2.25 L");
  testMatch("gaseosa coca-cola sabor original descartable 2250cm3", "Coca Cola Regular 2.25 L");
  testMatch("gaseosa coca-cola sabor original descartable 1500cm3", "Coca Cola 1.5 L");
  testMatch("Aceite Girasol Cocinero 1.5L", "Aceite Cocinero Girasol 1500cc");
}

void testMatch(String n1, String n2) {
  bool match = _areNamesSimilar(n1, n2);
  print("'$n1' vs '$n2' -> MATCH: $match");
  print("  Norm1: ${_normalizeName(n1)}");
  print("  Norm2: ${_normalizeName(n2)}");
}

// COPY PASTE OF LOGIC
  String _normalizeName(String name) {
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

  double? _extractVolume(String name) {
      String norm = _normalizeName(name); 
      RegExp reg = RegExp(r'\b(\d+(\.\d+)?)\b');
      var matches = reg.allMatches(norm);
      for (var m in matches) {
          double? val = double.tryParse(m.group(1)!);
          if (val != null) return val;
      }
      return null;
  }

  bool _areNamesSimilar(String name1, String name2) {
      if (name1.isEmpty || name2.isEmpty) return false;
      
      double? vol1 = _extractVolume(name1);
      double? vol2 = _extractVolume(name2);
      
      bool volumeMatch = (vol1 != null && vol2 != null && (vol1 - vol2).abs() < 0.05);

      String n1 = _normalizeName(name1);
      String n2 = _normalizeName(name2);
      
      if (n1 == n2) return true;
      
      if (volumeMatch) {
         Set<String> w1 = n1.split(' ').toSet();
         Set<String> w2 = n2.split(' ').toSet();
         int intersection = w1.intersection(w2).length;
         if (intersection >= 2) return true;
      }
      
      Set<String> w1 = n1.split(' ').toSet();
      Set<String> w2 = n2.split(' ').toSet();
      
      int intersection = w1.intersection(w2).length;
      int union = w1.union(w2).length;
      
      if (union == 0) return false;
      
      double jaccard = intersection / union;
      
      if (w1.length > 1 && w2.length > 1) {
          if (w1.containsAll(w2) || w2.containsAll(w1)) return true;
      }

      return jaccard > 0.6; 
  }
