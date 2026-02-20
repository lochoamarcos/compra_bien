
class Correction {
  final String id;
  final String ean;
  final String market;
  final double? suggestedPrice;
  final String? suggestedOffer;
  final String? message;
  final String user;
  final String? imageUrl;
  final DateTime timestamp;
  final int votes;

  Correction({
    required this.id,
    required this.ean,
    required this.market,
    this.suggestedPrice,
    this.suggestedOffer,
    this.message,
    required this.user,
    this.imageUrl,
    required this.timestamp,
    this.votes = 0,
  });

  factory Correction.fromJson(Map<String, dynamic> json) {
    return Correction(
      id: json['id'].toString(),
      ean: json['ean'] ?? '',
      market: json['market'] ?? '',
      suggestedPrice: json['suggested_price'] != null ? (json['suggested_price'] as num).toDouble() : null,
      suggestedOffer: json['suggested_offer'],
      message: json['message'], // Note: 'message' col might not exist in reports table directly, usually it's 'details' or similar, aligning with Supabase schema.
      user: 'Usuario de Comunidad', // Start generic, enhance if auth is added
      imageUrl: json['image_url'], // Assuming column exists
      timestamp: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      votes: json['votes'] ?? 0,
    );
  }
}
