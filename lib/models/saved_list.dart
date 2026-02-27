import 'cart_item.dart';

class SavedList {
  final String id;
  String name;
  final DateTime createdAt;
  final List<CartItem> items;

  SavedList({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  factory SavedList.fromJson(Map<String, dynamic> json) {
    return SavedList(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
      items: (json['items'] as List)
          .map((item) => CartItem.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
