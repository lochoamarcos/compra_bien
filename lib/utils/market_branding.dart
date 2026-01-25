import 'package:flutter/material.dart';

class MarketStyle {
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  
  const MarketStyle({
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    this.textColor = Colors.white,
  });
  
  static const monarca = MarketStyle(
    name: 'Monarca',
    primaryColor: Color(0xFF001E80), // Dark Blue
    accentColor: Color(0xFFFF600C), // Orange
  );

  static const carrefour = MarketStyle(
    name: 'Carrefour', 
    primaryColor: Color(0xFF003D8D), // Classic Blue
    accentColor: Color(0xFFFF3E2F), // Red
  );

  static const vea = MarketStyle(
    name: 'Vea',
    primaryColor: Color(0xFFFFC107), // Yellow
    accentColor: Color(0xFFD32F2F), // Red
  );

  static const cooperativa = MarketStyle(
    name: 'La Coope',
    primaryColor: Color(0xFFE53212), // Request: #E53212
    accentColor: Color(0xFF024693), // Request: #024693
  );

  static MarketStyle get(String? source) {
    if (source == null) return const MarketStyle(name: 'Unknown', primaryColor: Colors.grey, accentColor: Colors.black);
    switch (source.toLowerCase()) {
      case 'monarca': return monarca;
      case 'carrefour': return carrefour;
      case 'vea': return vea;
      case 'la coope': return cooperativa; // Handle new name
      case 'la cooperativa': return cooperativa; // Fallback
      default: return MarketStyle(
        name: source, 
        primaryColor: Colors.grey, 
        accentColor: Colors.black
      );
    }
  }
}
