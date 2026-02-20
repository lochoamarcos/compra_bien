import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeType { classic }

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeType _themeType = ThemeType.classic;

  ThemeMode get themeMode => _themeMode;
  ThemeType get themeType => _themeType;

  ThemeProvider() {
    _loadFromPrefs();
  }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveToPrefs();
    notifyListeners();
  }

  // setThemeType simplified as there's only one type now
  void setThemeType(ThemeType type) {
    _themeType = ThemeType.classic;
    _saveToPrefs();
    notifyListeners();
  }

  double _fontScale = 1.0;
  double get fontScale => _fontScale;

  void cycleFontScale() {
    if (_fontScale == 1.0) {
      _fontScale = 1.15;
    } else if (_fontScale == 1.15) {
      _fontScale = 1.3;
    } else {
      _fontScale = 1.0;
    }
    _saveToPrefs();
    notifyListeners();
  }

  void setFontScale(double scale) {
    _fontScale = scale;
    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? ThemeMode.light.index;
    final scale = prefs.getDouble('font_scale') ?? 1.0;
    
    _themeMode = ThemeMode.values[modeIndex];
    _themeType = ThemeType.classic; // Default to classic
    _fontScale = scale;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', _themeMode.index);
    await prefs.setInt('theme_type', _themeType.index);
    await prefs.setDouble('font_scale', _fontScale);
  }
}
