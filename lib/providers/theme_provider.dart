import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  bool _isFirstLaunch = true;

  ThemeMode get themeMode => _themeMode;
  bool get isFirstLaunch => _isFirstLaunch;

  // This helper is useful if we need to know the *current* brightness
  // but typically the UI should check Theme.of(context).brightness
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.system.index;
    if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.system;
    }

    _isFirstLaunch = prefs.getBool('first_launch') ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  // Toggle between light and dark (skips system)
  Future<void> toggleTheme(BuildContext context) async {
    final isDark = isDarkMode(context);
    await setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> dismissFirstLaunch() async {
    _isFirstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
    notifyListeners();
  }
}
