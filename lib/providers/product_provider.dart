import 'package:flutter/material.dart';
import '../data/monarca_repository.dart';
import '../data/carrefour_repository.dart';
import '../data/coope_repository.dart';
import '../data/vea_repository.dart';
import '../models/product.dart';
import '../utils/market_branding.dart';
import '../utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/correction_service.dart';

class ProductProvider with ChangeNotifier {
  final MonarcaRepository _monarcaRepo = MonarcaRepository();
  final CarrefourRepository _carrefourRepo = CarrefourRepository();
  final CoopeRepository _coopeRepo = CoopeRepository();
  final VeaRepository _veaRepo = VeaRepository();

  List<ComparisonResult> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  
  // Pagination State
  int _currentPage = 0;
  bool _hasMore = true;
  String _currentQuery = '';
  final Set<String> _processedEans = {}; // To avoid duplicates

  // Corrections State
  bool _correctionsLoaded = false;
  Map<String, dynamic> _activeCorrections = {};

  List<ComparisonResult> get searchResults => _searchResults;
  List<ComparisonResult> _categoryResults = [];
  List<ComparisonResult> get categoryResults => _categoryResults;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  // Live Enrichment State: Set<ResultKey + MarketName>
  final Set<String> _enrichingKeys = {};
  bool isMarketEnriching(ComparisonResult result, String marketName) {
      String key = _getResultUid(result);
      return _enrichingKeys.contains('$key|$marketName');
  }

  String _getResultUid(ComparisonResult r) {
      if (r.ean.isNotEmpty) return 'EAN:${r.ean}';
      return 'NAME:${_normalizeName(r.name)}';
  }

  // Categorized Promotions: Map<CategoryName, List<MergedResults>>
  Map<String, List<ComparisonResult>> _categorizedPromotions = {};
  Map<String, List<ComparisonResult>> get categorizedPromotions => _categorizedPromotions;

  // Cache Configuration
  static const String _cacheKey = 'promotions_cache';
  static const String _cacheDateKey = 'promotions_cache_date';
  static const Duration _cacheValidity = Duration(hours: 12);

  // --- Category Logic ---
  static const Map<String, String> _coopeCategoryIds = {
    'Bebidas': '4',
    'Perfumeria': '5',
    'Limpieza': '6',
    'Electro': '11', // Guessed/Assumed
    'Panaderia': '12', // Guessed/Assumed
    'Mascotas': '13', // Guessed/Assumed
  };

  // Harmonized Carrefour IDs (Verified)
  static const Map<String, String> _carrefourCategoryIds = {
    // Verified via tool_scripts/find_category_ids.dart
    'Almacen': '161',
    'Bebidas': '255', 
    'Frescos': '292', // General "Frescos" if tab exists. If splitting:
    // Subcats:
    'Carniceria': '293', // Guess/Todo: Verify exact ID if user selects. 
    // Wait, I saw 'Frutas y verduras'(330), 'Quesos'(310), 'Pastas Frescas'(463).
    // Let's map high level tabs first.
    'Limpieza': '359',
    'Perfumeria': '402',
    'Mascotas': '471', // Verified
    'Electro': '15',   // Verified
    'Estilo de Vida': '465', // Verified "Tiempo Libre"
    'Bebes': '457', // Verified "Mundo Bebe"
    'Congelados': '347', // Verified
    'Panaderia': '271', // Verified
    'Hogar': '71', // Verified
    'Desayuno': '222', // Legacy/Assumed
  };

  // Harmonized Vea IDs (Verified)
  static const Map<String, String> _veaCategoryIds = {
    // Verified via tool_scripts/find_vea_ids_v2.dart
    'Almacen': '1',
    'Bebidas': '2',
    'Frescos': '214', // Generic assumed.
    // Subcats found:
    'Frutas y Verduras': '3',
    'Carnes': '4', // Found via V2 script match 'Carnes' (ID 4)
    'Limpieza': '13',
    'Perfumeria': '11',
    'Desayuno': '21', 
    'Mascotas': '14',
    'Electro': '15',
    'Estilo de Vida': '465', // "Tiempo Libre" matches Text, ID 465 in Vea too? 
    // V2 script says: MATCH: "Tiempo Libre" ID:465. YES.
    'Bebes': '457', // "Mundo Bebe" ID:457 in Vea too.
    'Congelados': '8',
    'Panaderia': '271', 
    'Hogar': '16', // Verified Text "Hogar y textil" ID:16
  };

  // Monarca Specific Keywords (Since it lacks ID search)
  static const Map<String, String> _monarcaCategoryKeywords = {
    'Almacen': 'Fideos', // Proxy: "Fideos" usually brings up dry goods
    'Bebidas': 'Gaseosa', 
    'Frescos': 'Lacteos',
    'Limpieza': 'Detergente',
    'Perfumeria': 'Shampoo',
    'Mascotas': 'Alimento Perro',
    'Bebes': 'Pañales',
    'Hogar': 'Rollo Cocina',
    'Electro': 'Pava', // Often empty, but worth a try
    'Congelados': 'Hamburguesas',
    'Panaderia': 'Facturas',
    'Desayuno': 'Cafe',
    'Muebles': 'Cajas', 
  };
  
  static const Map<String, List<String>> _categoryKeywords = {
    'Promociones': ['coronados', 'descuento', 'promo', 'oferta'], 
    'Almacen': ['Almacen'],
    'Desayuno': ['Desayuno', 'Merienda'],
    'Frescos': ['Lacteos', 'Frescos', 'Carnes', 'Verduras', 'Frutas', 'Quesos'], 
    'Bebidas': ['Bebidas', 'Gaseosas', 'Alcohol'], 
    'Perfumeria': ['Perfumeria', 'Higiene'],
    'Limpieza': ['Limpieza'],
    'Muebles': ['Organizacion', 'Cajas', 'Hogar'], // Maps to Hogar/Muebles (storage furniture)
    'Electro': ['Electro', 'Tecnologia'],
    'Mascotas': ['Mascotas'],
    'Bebes': ['Bebes', 'Pañales'],
    'Hogar': ['Hogar', 'Textil', 'Bazar'],
  };
  
  String? _currentCategory; // Track if we are in category mode

  Future<void> searchByCategory(String category) async {
      _isLoading = true;
      _error = null;
      _categoryResults = []; 
      _currentPage = 0;
      _hasMore = true;
      _currentQuery = category; 
      _currentCategory = category;
      _processedEans.clear();
      notifyListeners();

      await _fetchPage(_currentPage);
  }

  // --- External Methods ---

  // Called eagerly during onboarding without UI feedback to prep data
  Future<void> prefetchPromotions() async {
      await fetchPromotions(silent: true);
  }

  Future<void> fetchPromotions({bool silent = false}) async {
    // Legacy: We might want to keep this or replace it if "Promociones" is just another category?
    // For now, let's keep it but maybe it won't be used if UI changes.
    // If user selects "Promociones" category, we might use this logic?
    if (!silent) {
       _isLoading = true;
       notifyListeners(); 
    }
    // ... existing logic ...
    // Since we are replacing the tab, this might be deprecated or used for "Ofertas" category
    // Let's assume for now we don't break it.
    if (!silent) _isLoading = false;
    if (!silent) notifyListeners();
  }

  // --- Caching Implementation ---

  Future<bool> _loadCache() async {
     try {
        final prefs = await SharedPreferences.getInstance();
        if (!prefs.containsKey(_cacheKey) || !prefs.containsKey(_cacheDateKey)) {
           return false;
        }

        final dateStr = prefs.getString(_cacheDateKey)!;
        final cacheDate = DateTime.parse(dateStr);
        final now = DateTime.now();

        if (now.difference(cacheDate) > _cacheValidity) {
           AppLogger().log('Cache Expired: ${now.difference(cacheDate).inHours} hours old');
           return false;
        }

        final jsonStr = prefs.getString(_cacheKey)!;
        final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
        
        _categorizedPromotions = {};
        jsonMap.forEach((key, value) {
            final list = (value as List).map((i) => ComparisonResult.fromJson(i)).toList();
            _categorizedPromotions[key] = list;
        });
        
        AppLogger().log('Promotions Loaded from Cache ($dateStr)');
        return true;

     } catch (e) {
        AppLogger().log('Cache Load Error: $e');
        return false;
     }
  }

  Future<void> _saveCache() async {
      try {
         final prefs = await SharedPreferences.getInstance();
         final now = DateTime.now();
         
         final Map<String, dynamic> jsonMap = {};
         _categorizedPromotions.forEach((key, value) {
             jsonMap[key] = value.map((r) => r.toJson()).toList();
         });
         
         final jsonStr = json.encode(jsonMap);
         
         await prefs.setString(_cacheKey, jsonStr);
         await prefs.setString(_cacheDateKey, now.toIso8601String());
         AppLogger().log('Promotions Saved to Cache');
      } catch (e) {
         AppLogger().log('Cache Save Error: $e');
      }
  }

  String _normalizeName(String name) {
    if (name.isEmpty) return '';
    
    // 1. Lowercase & remove accents
    String s = name.toLowerCase();
    s = s.replaceAll('-', ' '); 
    const accents = 'áéíóúüñ';
    const noAccents = 'aeiouun';
    for (int i = 0; i < accents.length; i++) {
       s = s.replaceAll(accents[i], noAccents[i]);
    }
    
    // Normalize variants
    s = s.replaceAll('sin azucares', 'zero');
    s = s.replaceAll('sin azucar', 'zero');
    s = s.replaceAll('light', 'zero'); 
    s = s.replaceAll('s/az', 'zero'); 
    
    // Robust Volume Normalization (Regex)
    // 2250cm3 -> 2.25 | 2250 ml -> 2.25
    s = s.replaceAllMapped(RegExp(r'(\d+[\.,]?\d*)\s*(cm3|cc|ml|grs|lts|gr|lt|litros|kg|g|l|k)\b'), (Match m) {
        String numStr = m.group(1)!.replaceAll(',', '.');
        double val = double.tryParse(numStr) ?? 0;
        String unit = m.group(2)!.toLowerCase();
        
        // Already in Liters/Kg?
        if (unit == 'kg' || unit == 'l' || unit == 'lt' || unit == 'lts' || unit == 'litros' || unit == 'k') {
           return '$val'; 
        }
        // Conversion needed (ml/gr -> L/Kg)
        return '${val / 1000}'; 
    });
    
    // Handle unlabeled large numbers (e.g. "Coca Cola 2250")
    s = s.replaceAllMapped(RegExp(r'\b(\d{3,5})\b'), (Match m) {
        double val = double.tryParse(m.group(1)!) ?? 0;
        if (val >= 100 && val < 10000) {
           return '${val / 1000}'; 
        }
        return m.group(0)!;
    });

    // Remove noise words
    s = s.replaceAll(RegExp(r'\b(x|gaseosa|botella|retornable|descartable|sabor|original|frasco|bolsa|caja|pack|polvo|cm3|ml|lts|cc|gr|grs|kg|pet|litros|lt|de|en|la|el|los|las|un|una)\b'), ' ');
    
    // Remove non-alphanumeric (except spaces and dots for decimals)
    s = s.replaceAll(RegExp(r'[^a-z0-9\s\.]'), '');
    
    // Singularize & Sort
    List<String> words = s.split(' ').where((w) => w.trim().isNotEmpty).map((w) {
        if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
           return w.substring(0, w.length - 1);
        }
        return w;
    }).toList();
    
    words.sort();
    return words.join(' ');
  }

  // Extract volume for strict matching
  double? _extractVolume(String name) {
      String norm = _normalizeName(name); 
      // Look for standalone numbers in normalized string (e.g. "2.25 coca")
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
      
      // 1. Strict Volume Match
      double? vol1 = _extractVolume(name1);
      double? vol2 = _extractVolume(name2);
      
      // STRICT Volume Match: Products must have IDENTICAL volumes to match
    // This prevents Coca Cola 500ml from matching with 1L, 1.5L, 2.25L, etc.
    bool volumeMatch = (vol1 != null && vol2 != null && (vol1 - vol2).abs() < 0.001);

      String n1 = _normalizeName(name1);
      String n2 = _normalizeName(name2);
      
      if (n1 == n2) return true;
      
      // If Volume Matches, be more lenient on text
      if (volumeMatch) {
         Set<String> w1 = n1.split(' ').toSet();
         Set<String> w2 = n2.split(' ').toSet();
         int intersection = w1.intersection(w2).length;
         // If they share at least 2 key words (e.g. "coca", "cola")
         if (intersection >= 2) return true;
      }
      
      // Fallback: Standard Similarity
      Set<String> w1 = n1.split(' ').toSet();
      Set<String> w2 = n2.split(' ').toSet();
      
      int intersection = w1.intersection(w2).length;
      int union = w1.union(w2).length;
      
      if (union == 0) return false;
      
      double jaccard = intersection / union;
      
      if (w1.length > 1 && w2.length > 1) {
          if (w1.containsAll(w2) || w2.containsAll(w1)) return true;
      }

      return jaccard > 0.75; // Stricter threshold to prevent false matches 
  }

  // Key generation for matching map
  String _generateMatchKey(Product p) {
      if (p.ean.isNotEmpty && p.ean != '0') {
         // Prefer EAN if valid
         return 'EAN:${p.ean.trim().replaceFirst(RegExp(r'^0+'), '')}';
      }
      // Fallback to Brand + Normalized Name + Presentation
      String brand = _normalizeName(p.brand ?? '');
      String name = _normalizeName('${p.name} ${p.presentation}');
      return 'NAME:$brand|$name';
  }

  // Market Priority (Order of display)
  List<String> _marketPriority = ['Monarca', 'Carrefour', 'Vea', 'La Coope'];
  List<String> get marketPriority => _marketPriority;
  
  // Active Markets for Search (defaults to all)
  Set<String> _activeMarkets = {'Monarca', 'Carrefour', 'Vea', 'La Coope'};

  void reorderMarkets(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = _marketPriority.removeAt(oldIndex);
    _marketPriority.insert(newIndex, item);
    notifyListeners();
  }

  Future<void> search(String query, {Set<String>? activeMarkets}) async {
    _isLoading = true;
    _error = null;
    _searchResults = []; // Clear search results
    // _categoryResults = []; // Do NOT clear category results
    _currentPage = 0;
    _hasMore = true;
    _currentQuery = query;
    _currentCategory = null; // Reset category mode
    _processedEans.clear();
    _activeMarkets = activeMarkets ?? {'Monarca', 'Carrefour', 'Vea', 'La Coope'};
    
    notifyListeners();
    
    await _fetchPage(_currentPage);
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    notifyListeners();
    
    _currentPage++;
    await _fetchPage(_currentPage);
  }

  Future<void> _fetchPage(int page) async {
    // Ensure corrections
    if (!_correctionsLoaded) {
       _activeCorrections = await CorrectionService.fetchCorrections();
       _correctionsLoaded = true;
    }

    final String requestedQuery = _currentQuery;
    final String? requestedCategory = _currentCategory;
    
    try {
      Future<List<Product>> monarcaFuture, carrefourFuture, coopeFuture, veaFuture;
      
      if (_currentCategory != null) {
          // CATEGORY SEARCH
          String coopeId = _coopeCategoryIds[_currentCategory] ?? '';
          String carrefourId = _carrefourCategoryIds[_currentCategory] ?? '';
          String veaId = _veaCategoryIds[_currentCategory] ?? '';
          
          List<String> keywords = _categoryKeywords[_currentCategory] ?? [_currentQuery];
          String primaryKeyword = keywords.first;
          
          bool isPromo = _currentCategory == 'Promociones';

          coopeFuture = (_activeMarkets.contains('La Coope') && _currentCategory != 'Muebles')
              ? (isPromo 
                  ? _coopeRepo.searchProducts('', page: page, size: 20, isPromo: true).catchError((e) { return <Product>[]; })
                  : (coopeId.isNotEmpty 
                      ? _coopeRepo.searchProducts('', page: page, size: 20, categoryId: coopeId).catchError((e) { return <Product>[]; })
                      : Future.value(<Product>[])))
              : Future.value(<Product>[]);
          
          // Monarca uses specific keywords since it lacks category IDs
          String monarcaKeyword = _monarcaCategoryKeywords[_currentCategory] ?? primaryKeyword;
          monarcaFuture = (_activeMarkets.contains('Monarca') && _currentCategory != 'Muebles')
              ? _monarcaRepo.searchProducts(monarcaKeyword, page: page, size: 20)
              : Future.value(<Product>[]);
              
          // Improved Carrefour Logic
          String carrefourQuery = primaryKeyword;
          if (_currentCategory == 'Promociones') carrefourQuery = 'oferta';

          carrefourFuture = (_activeMarkets.contains('Carrefour')) 
              ? (_currentCategory == 'Muebles' 
                  ? _carrefourRepo.searchProducts('Almacen', page: page, size: 20)
                  : (carrefourId.isNotEmpty 
                     ? _carrefourRepo.searchProducts('', page: page, size: 20, categoryId: carrefourId)
                     : _carrefourRepo.searchProducts(carrefourQuery, page: page, size: 20)))
              : Future.value(<Product>[]);
              
          // Improved Vea Logic
          String veaQuery = primaryKeyword;
          if (_currentCategory == 'Promociones') veaQuery = 'oferta';
          
          veaFuture = (_activeMarkets.contains('Vea') && _currentCategory != 'Muebles')
              ? _veaRepo.searchProducts('', page: page, size: 20, categoryId: veaId).then((results) async {
                  if (results.isEmpty && veaId.isNotEmpty) {
                      return _veaRepo.searchProducts(veaQuery, page: page, size: 20);
                  }
                  return results;
              }).catchError((e) => <Product>[])
              : Future.value(<Product>[]);
          
          // Apply same fallback to Carrefour
          final carrefourBase = carrefourFuture;
          carrefourFuture = carrefourBase.then((results) async {
              if (results.isEmpty && carrefourId.isNotEmpty && _activeMarkets.contains('Carrefour')) {
                  return _carrefourRepo.searchProducts(carrefourQuery, page: page, size: 20);
              }
              return results;
          });
      } else {
         // TEXT SEARCH
         monarcaFuture = _activeMarkets.contains('Monarca') 
            ? _monarcaRepo.searchProducts(_currentQuery, page: page, size: 20)
            : Future.value(<Product>[]);
         carrefourFuture = _activeMarkets.contains('Carrefour')
            ? _carrefourRepo.searchProducts(_currentQuery, page: page, size: 20)
            : Future.value(<Product>[]);
         coopeFuture = _activeMarkets.contains('La Coope')
            ? _coopeRepo.searchProducts(_currentQuery, page: page, size: 20).catchError((e) { return <Product>[]; })
            : Future.value(<Product>[]);
         veaFuture = _activeMarkets.contains('Vea')
            ? _veaRepo.searchProducts(_currentQuery, page: page, size: 20).catchError((e) { return <Product>[]; })
            : Future.value(<Product>[]);
      }

      final results = await Future.wait([monarcaFuture, carrefourFuture, coopeFuture, veaFuture]);
      
      // ABORT if the query or category has changed since the request started
      if (_currentQuery != requestedQuery || _currentCategory != requestedCategory) {
          AppLogger().log('Aborting fetch for "$requestedQuery": Query changed to "$_currentQuery"');
          return;
      }

      final monarcaItems = results[0].where((p) => p.price > 0).toList();
      final carrefourItems = results[1].where((p) => p.price > 0).toList();
      final coopeItems = results[2].where((p) => p.price > 0).toList();
      final veaItems = results[3].where((p) => p.price > 0).toList();

      // Check if ALL ACTIVE markets are empty
      final activeResults = <List<Product>>[];
      if (_activeMarkets.contains('Monarca')) activeResults.add(monarcaItems);
      if (_activeMarkets.contains('Carrefour')) activeResults.add(carrefourItems);
      if (_activeMarkets.contains('La Coope')) activeResults.add(coopeItems);
      if (_activeMarkets.contains('Vea')) activeResults.add(veaItems);
      
      if (activeResults.every((list) => list.isEmpty)) {
         _hasMore = false;
         _isLoading = false;
         notifyListeners();
         return;
      }

      // Merge logic
      final Map<String, ComparisonResult> merged = {};
      
      List<ComparisonResult> currentBatch = [];
      List<Product> allProducts = [...monarcaItems, ...carrefourItems, ...coopeItems, ...veaItems];
      
      // 1. Group by EAN (Strict)
      Map<String, List<Product>> eanGroups = {};
      List<Product> noEanProducts = [];
      
      for (var p in allProducts) {
          if (p.ean.isNotEmpty && p.ean != '0') {
              String eanKey = p.ean.trim().replaceFirst(RegExp(r'^0+'), '');
              eanGroups.putIfAbsent(eanKey, () => []).add(p);
          } else {
              noEanProducts.add(p);
          }
      }
      
      // Convert EAN groups to ComparisonResult
      for (var entry in eanGroups.entries) {
          Product? m, c, l, v;
          for (var p in entry.value) {
              if (p.source == 'Monarca') m = p;
              else if (p.source == 'Carrefour') c = p;
              else if (p.source == 'La Coope') l = p;
              else if (p.source == 'Vea') v = p;
          }
          currentBatch.add(ComparisonResult(ean: entry.key, monarcaParam: m, carrefourParam: c, coopeParam: l, veaParam: v));
      }
      
      // 2. Match No-EAN products (Coope) to existing EAN groups (Fuzzy Name)
      for (var p in noEanProducts) {
          String pNameNorm = _normalizeName('${p.brand} ${p.name} ${p.presentation}');
          bool matched = false;
          
          for (int i = 0; i < currentBatch.length; i++) {
              var result = currentBatch[i];
              Product? representative = result.monarcaProduct ?? result.carrefourProduct ?? result.veaProduct;
              if (representative != null) {
                  String rNameNorm = _normalizeName('${representative.brand} ${representative.name} ${representative.presentation}');
                  
                  if (_areNamesSimilar(pNameNorm, rNameNorm)) {
                      currentBatch[i] = ComparisonResult(
                          ean: result.ean,
                          monarcaParam: result.monarcaParam ?? (p.source == 'Monarca' ? p : null),
                          carrefourParam: result.carrefourParam ?? (p.source == 'Carrefour' ? p : null),
                          coopeParam: result.coopeParam ?? (p.source == 'La Coope' ? p : null),
                          veaParam: result.veaParam ?? (p.source == 'Vea' ? p : null),
                      );
                      matched = true;
                      break;
                  }
              }
          }
          
          if (!matched) {
               // Check if we already added a "No EAN" group for this name in currentBatch 
              for (int i = 0; i < currentBatch.length; i++) {
                 if (currentBatch[i].ean.isEmpty) { 
                     Product? rep = currentBatch[i].monarcaProduct ?? currentBatch[i].coopeProduct ?? currentBatch[i].carrefourProduct ?? currentBatch[i].veaProduct;
                     if (rep != null) {
                         String rNameNorm = _normalizeName('${rep.brand} ${rep.name} ${rep.presentation}');
                         if (_areNamesSimilar(pNameNorm, rNameNorm)) {
                               currentBatch[i] = ComparisonResult(
                                   ean: '',
                                   monarcaParam: currentBatch[i].monarcaParam ?? (p.source == 'Monarca' ? p : null),
                                   coopeParam: currentBatch[i].coopeParam ?? (p.source == 'La Coope' ? p : null),
                                   carrefourParam: currentBatch[i].carrefourParam ?? (p.source == 'Carrefour' ? p : null),
                                   veaParam: currentBatch[i].veaParam ?? (p.source == 'Vea' ? p : null),
                               );
                               matched = true;
                               break;
                         }
                     }
                 }
              }
              
              if (!matched) {
                  currentBatch.add(ComparisonResult(
                      ean: '', // No EAN
                      monarcaParam: p.source == 'Monarca' ? p : null,
                      carrefourParam: p.source == 'Carrefour' ? p : null,
                      coopeParam: p.source == 'La Coope' ? p : null,
                      veaParam: p.source == 'Vea' ? p : null,
                  ));
              }
          }
      }

      // Filter out seen EANS to avoid duplicates across pages (if any)
      List<ComparisonResult> uniqueBatch = [];
      for (var res in currentBatch) {
          // Use EAN or a robust Name+Brand+Presentation key
          String key = res.ean.isNotEmpty ? res.ean : _normalizeName('${res.name} ${res.monarcaProduct?.presentation ?? res.carrefourProduct?.presentation ?? res.coopeProduct?.presentation ?? res.veaProduct?.presentation ?? ""}');
          if (!_processedEans.contains(key)) {
             // APPLY CORRECTIONS HERE
             _applyCorrectionsToResult(res);
             uniqueBatch.add(res);
             _processedEans.add(key);
          }
      }

      // --- NEW SORTING LOGIC ---
      // User Request: "Prioritize products with 3 or more markets available first, then 2, then 1"
      uniqueBatch.sort((a, b) {
          // 1. Availability Count (Descending)
          int countA = 0;
          if (a.monarcaProduct != null) countA++;
          if (a.carrefourProduct != null) countA++;
          if (a.coopeProduct != null) countA++;
          if (a.veaProduct != null) countA++;

          int countB = 0;
          if (b.monarcaProduct != null) countB++;
          if (b.carrefourProduct != null) countB++;
          if (b.coopeProduct != null) countB++;
          if (b.veaProduct != null) countB++;

          // Priority Tiers: 
          // Tier 1: 3 or 4 markets (count >= 3)
          // Tier 2: 2 markets (count == 2)
          // Tier 3: 1 market (count <= 1)

          int tierA = (countA >= 3) ? 1 : (countA == 2 ? 2 : 3);
          int tierB = (countB >= 3) ? 1 : (countB == 2 ? 2 : 3);
          
          if (tierA != tierB) {
             return tierA.compareTo(tierB); // Lower tier number comes first
          }

          // 2. Secondary Sort: Relevance (Simple string length match or existing order?)
          // For now, keep existing relative order from API/Merge which implies relevance
          return 0; 
      });

      if (_currentCategory != null) {
         _categoryResults.addAll(uniqueBatch);
      } else {
         _searchResults.addAll(uniqueBatch);
      }
      
      // Updated hasMore logic: Check if we got meaningful results from active markets
      int totalFromActive = activeResults.fold(0, (sum, list) => sum + list.length);
      if (totalFromActive < 5) { // If less than 5 products from active markets, likely no more
         _hasMore = false;
      }
      
    } catch (e) {
      if (_currentQuery == requestedQuery && _currentCategory == requestedCategory) {
        _error = e.toString();
      }
    } finally {
      if (_currentQuery == requestedQuery && _currentCategory == requestedCategory) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> enrichResult(ComparisonResult result) async {
      final marketsToFetch = <String>[];
      if (result.monarcaProduct == null) marketsToFetch.add('Monarca');
      if (result.carrefourProduct == null) marketsToFetch.add('Carrefour');
      if (result.coopeProduct == null) marketsToFetch.add('La Coope');
      if (result.veaProduct == null) marketsToFetch.add('Vea');

      if (marketsToFetch.isEmpty) return;

      final uid = _getResultUid(result);
      
      for (var market in marketsToFetch) {
          final key = '$uid|$market';
          if (_enrichingKeys.contains(key)) continue; // Already fetching
          
          _enrichingKeys.add(key);
          notifyListeners();

          _enrichMarket(result, market).then((_) {
              _enrichingKeys.remove(key);
              notifyListeners();
          }).catchError((e) {
              _enrichingKeys.remove(key);
              notifyListeners();
          });
      }
  }

  Future<void> _enrichMarket(ComparisonResult result, String marketName) async {
      try {
          List<Product> matches = [];
          
          // Use name for searching
          String searchName = result.name;
          // If we have brand, prepend it
          String brand = result.monarcaProduct?.brand ?? result.carrefourProduct?.brand ?? result.coopeProduct?.brand ?? result.veaProduct?.brand ?? '';
          if (brand.isNotEmpty && !searchName.toLowerCase().contains(brand.toLowerCase())) {
              searchName = '$brand $searchName';
          }

          if (marketName == 'Monarca') {
              matches = await _monarcaRepo.searchProducts(searchName, page: 0, size: 5);
          } else if (marketName == 'Carrefour') {
              matches = await _carrefourRepo.searchProducts(searchName, page: 0, size: 5);
          } else if (marketName == 'La Coope') {
              matches = await _coopeRepo.searchProducts(searchName, page: 0, size: 5);
          } else if (marketName == 'Vea') {
              matches = await _veaRepo.searchProducts(searchName, page: 0, size: 5);
          }

          if (matches.isNotEmpty) {
              // 1. Try EAN Match first if available
              String targetEan = result.ean;
              if (targetEan.isNotEmpty) {
                  for (var m in matches) {
                      if (m.ean.isNotEmpty && m.ean.trim().replaceFirst(RegExp(r'^0+'), '') == targetEan) {
                          _updateComparisonWithMarket(result, m);
                          return;
                      }
                  }
              }

              // 2. Fuzzy Name Match
              Product? best;
              double bestScore = 0;
              for (var m in matches) {
                  String mName = m.name;
                  if (m.brand != null) mName = '${m.brand} $mName';
                  if (m.presentation.isNotEmpty) mName = '$mName ${m.presentation}';
                  
                  // Score it
                  if (_areNamesSimilar(searchName, mName)) {
                      _updateComparisonWithMarket(result, m);
                      return;
                  }
              }
          }
      } catch (e) {
          print('Error enriching $marketName for ${result.name}: $e');
      }
  }

  void _updateComparisonWithMarket(ComparisonResult target, Product p) {
      if (p.source == 'Monarca') target.monarcaParam = p;
      else if (p.source == 'Carrefour') target.carrefourParam = p;
      else if (p.source == 'La Coope') target.coopeParam = p;
      else if (p.source == 'Vea') target.veaParam = p;
  }

  // Transient search for manual matching (Dialog)
  Future<List<Product>> searchMarketTransient(String query, String marketName) async {
       try {
           if (marketName == 'Monarca') return await _monarcaRepo.searchProducts(query, page: 0, size: 20);
           if (marketName == 'Carrefour') return await _carrefourRepo.searchProducts(query, page: 0, size: 20);
           if (marketName == 'La Coope') return await _coopeRepo.searchProducts(query, page: 0, size: 20);
           if (marketName == 'Vea') return await _veaRepo.searchProducts(query, page: 0, size: 20);
           return [];
       } catch (e) {
           print('Transient search error ($marketName): $e');
           return [];
       }
  }


  // Locally link a product (Session based)
  void manualLinkProduct(ComparisonResult targetResult, String marketName, Product matchedProduct) {
      // 1. Update the objects in memory
      // We need to find the specific instance in _searchResults or _categoryResults
      // But since we pass the object reference (targetResult), we can update it directly!
      // However, we should notify listeners so UI updates.
      
      _updateComparisonWithMarket(targetResult, matchedProduct);
      
      // Also update in lists if by any chance the reference is different (unlikely)
      // or just to trigger a refresh.
      notifyListeners();
  }

  // --- Correction Logic ---
  void _applyCorrectionsToResult(ComparisonResult res) {
      if (_activeCorrections.isEmpty) return;

      void apply(Product? p, String market) {
         if (p == null || p.ean.isEmpty) return;
         final key = "${p.ean}_$market"; // Key must match Supabase/Consensus logic
         
         if (_activeCorrections.containsKey(key)) {
             final data = _activeCorrections[key];
             // Apply Price
             double? newPrice = (data['suggested_price'] as num?)?.toDouble();
             String? newOffer = data['suggested_offer'] as String?;
             
             // Update the product (immutable copy)
             Product newP = p.copyWith(
                 price: newPrice,
                 promoDescription: newOffer,
             );

             // Re-assign to ComparisonResult (mutable fields)
             if (market == 'Monarca') res.monarcaParam = newP;
             else if (market == 'Carrefour') res.carrefourParam = newP;
             else if (market == 'La Coope') res.coopeParam = newP;
             else if (market == 'Vea') res.veaParam = newP;
         }
      }

      apply(res.monarcaProduct, 'Monarca');
      apply(res.carrefourProduct, 'Carrefour');
      apply(res.coopeProduct, 'La Coope');
      apply(res.veaProduct, 'Vea');
  }
}
