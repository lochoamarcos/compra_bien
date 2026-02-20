class BankPromotion {
  final String id;
  final String title;
  final String imageUrl;
  final String supermarket;

  BankPromotion({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.supermarket,
  });

  factory BankPromotion.fromJson(Map<String, dynamic> json, String supermarket) {
    String title = json['title'] ?? json['description'] ?? json['name'] ?? '';
    String imageUrl = '';
    
    if (supermarket == 'Monarca') {
       if (json['imageShelfMode'] != null) {
         imageUrl = json['imageShelfMode']['path'] ?? '';
       } else if (json['imageVerticalMode'] != null) {
          imageUrl = json['imageVerticalMode']['path'] ?? '';
       }
    }
    
    return BankPromotion(
      id: json['id'].toString(),
      title: title,
      imageUrl: imageUrl,
      supermarket: supermarket,
    );
  }
}
