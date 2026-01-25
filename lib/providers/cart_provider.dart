import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider with ChangeNotifier {
  List<CartItem> _items = [];
  static const String _cartKey = 'cart_items';

  List<CartItem> get items => _items;

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_cartKey)) {
      final String? cartJson = prefs.getString(_cartKey);
      if (cartJson != null) {
        final List<dynamic> decodedList = json.decode(cartJson);
        _items = decodedList.map((item) => CartItem.fromJson(item)).toList();
        notifyListeners();
      }
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String cartJson = json.encode(_items.map((item) => item.toJson()).toList());
    await prefs.setString(_cartKey, cartJson);
  }

  void addItem(Product product, {String? bestMarket, double? bestPrice}) {
    int index = _items.indexWhere((item) {
       // Only match if SAME product (EAN/Name) AND SAME Source (Market)
       // This allows having the same "Coke" from Monarca AND Carrefour as separate lines if user wants
       bool sameProduct = (item.product.ean.isNotEmpty && item.product.ean == product.ean) ||
                          (item.product.name == product.name);
       return sameProduct && item.product.source == product.source;
    });

    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(
        product: product, 
        bestMarket: bestMarket, 
        bestPrice: bestPrice,
      ));
    }
    _saveCart();
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
      _saveCart();
      notifyListeners();
    }
  }
  
  void removeItemCompletely(CartItem itemToRemove) {
     _items.remove(itemToRemove);
     _saveCart();
     notifyListeners();
  }

  void toggleSelection(CartItem item) {
    item.isSelected = !item.isSelected;
    _saveCart();
    notifyListeners();
  }

  void clearSelectedOrAll() {
    bool hasSelection = _items.any((item) => item.isSelected);
    if (hasSelection) {
      _items.removeWhere((item) => item.isSelected);
    } else {
      _items = [];
    }
    _saveCart();
    notifyListeners();
  }

  void clear() {
    _items = [];
    _saveCart();
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

  double getTotalForStore(String storeName) {
    var storeItems = itemsByStore[storeName] ?? [];
    return storeItems.fold(0.0, (sum, item) {
       return sum + item.totalPrice;
    });
  }
}
