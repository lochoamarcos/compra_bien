import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/saved_list.dart';
import 'package:uuid/uuid.dart';

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  List<SavedList> _savedLists = [];
  List<Product> _favoriteProducts = [];

  static const String _cartKey = 'cart_items';
  static const String _savedListsKey = 'saved_lists';
  static const String _favoritesKey = 'favorite_products';

  List<CartItem> get items => _items;
  List<SavedList> get savedLists => _savedLists;
  List<Product> get favoriteProducts => _favoriteProducts;

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get itemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  CartProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Cart Items
    if (prefs.containsKey(_cartKey)) {
      final String? cartJson = prefs.getString(_cartKey);
      if (cartJson != null) {
        final List<dynamic> decodedList = json.decode(cartJson);
        _items = decodedList.map((item) => CartItem.fromJson(item)).toList();
      }
    }

    // Load Saved Lists
    if (prefs.containsKey(_savedListsKey)) {
      final String? listsJson = prefs.getString(_savedListsKey);
      if (listsJson != null) {
        final List<dynamic> decodedList = json.decode(listsJson);
        _savedLists = decodedList.map((item) => SavedList.fromJson(item)).toList();
      }
    }

    // Load Favorites
    if (prefs.containsKey(_favoritesKey)) {
      final String? favJson = prefs.getString(_favoritesKey);
      if (favJson != null) {
          final List<dynamic> decodedList = json.decode(favJson);
          _favoriteProducts = decodedList.map((item) => Product.fromCachedJson(item as Map<String, dynamic>)).toList().cast<Product>();
      }
    }

    notifyListeners();
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save Cart
    final String cartJson = json.encode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(_cartKey, cartJson);

    // Save Lists
    final String listsJson = json.encode(_savedLists.map((l) => l.toJson()).toList());
    await prefs.setString(_savedListsKey, listsJson);

    // Save Favorites
    final String favJson = json.encode(_favoriteProducts.map((p) => p.toJson()).toList());
    await prefs.setString(_favoritesKey, favJson);
  }

  void addItem(Product product, {String? bestMarket, double? bestPrice, List<Product>? alternatives}) {
    int index = _items.indexWhere((item) {
       // Only match if SAME product (EAN/Name) AND SAME Source (Market)
       // This allows having the same "Coke" from Monarca AND Carrefour as separate lines if user wants
       bool sameProduct = (item.product.ean.isNotEmpty && item.product.ean != '0' && item.product.ean == product.ean) ||
                          (item.product.name == product.name && item.product.presentation == product.presentation);
       return sameProduct && item.product.source == product.source;
    });

    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(
        product: product, 
        bestMarket: bestMarket, 
        bestPrice: bestPrice,
        alternatives: alternatives,
      ));
    }
    _saveAll();
    notifyListeners();
  }

  void removeSingleItem(CartItem itemToRemove) {
    int index = _items.indexOf(itemToRemove);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      _saveAll();
      notifyListeners();
    }
  }
  
  void removeItemCompletely(CartItem itemToRemove) {
     _items.remove(itemToRemove);
     _saveAll();
     notifyListeners();
  }

  void toggleSelection(CartItem item) {
    item.isSelected = !item.isSelected;
    _saveAll();
    notifyListeners();
  }

  void clearSelectedOrAll() {
    bool hasSelection = _items.any((item) => item.isSelected);
    if (hasSelection) {
      _items.removeWhere((item) => item.isSelected);
    } else {
      _items = [];
    }
    _saveAll();
    notifyListeners();
  }

  void clear() {
    _items = [];
    _saveAll();
    notifyListeners();
  }

  Map<String, List<CartItem>> get itemsByStore {
    Map<String, List<CartItem>> grouped = {
      'Monarca': [],
      'Carrefour': [],
      'Vea': [],
      'La Coope': [], 
    };

    for (var item in _items) {
      String targetStore = item.product.source;
      
      // Normalize if needed
      if (targetStore == 'Cooperativa') targetStore = 'La Coope'; 
      
      if (grouped.containsKey(targetStore)) {
        grouped[targetStore]!.add(item);
      } else {
        grouped.putIfAbsent(targetStore, () => []).add(item);
      }
    }
    return grouped;
  }

  // --- Saved Lists Methods ---

  void saveCurrentCartAsList(String name) {
    if (_items.isEmpty) return;
    
    final newList = SavedList(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      items: List.from(_items.map((i) => CartItem(
        product: i.product,
        quantity: i.quantity,
        bestMarket: i.bestMarket,
        bestPrice: i.bestPrice,
        isSelected: false, // Reset selection for saved lists
      ))),
    );
    
    _savedLists.insert(0, newList);
    _saveAll();
    notifyListeners();
  }

  void deleteSavedList(String id) {
    _savedLists.removeWhere((l) => l.id == id);
    _saveAll();
    notifyListeners();
  }

  void renameSavedList(String id, String newName) {
    int index = _savedLists.indexWhere((l) => l.id == id);
    if (index >= 0) {
      _savedLists[index].name = newName;
      _saveAll();
      notifyListeners();
    }
  }

  void loadListToCart(SavedList list) {
    // Clear current cart and load items from list
    // Or ask user? Usually better to replace for these "shopping list" flows.
    _items = List.from(list.items.map((i) => CartItem(
      product: i.product,
      quantity: i.quantity,
      bestMarket: i.bestMarket,
      bestPrice: i.bestPrice,
      isSelected: false,
    )));
    _saveAll();
    notifyListeners();
  }

  // --- Favorites Methods ---

  void toggleFavorite(Product product) {
    if (product.ean.isEmpty || product.ean == '0') return;
    if (isFavorite(product.ean)) {
      _favoriteProducts.removeWhere((p) => p.ean == product.ean);
    } else {
      _favoriteProducts.add(product);
    }
    _saveAll();
    notifyListeners();
  }

  bool isFavorite(String ean) {
    return _favoriteProducts.any((p) => p.ean == ean);
  }
}
