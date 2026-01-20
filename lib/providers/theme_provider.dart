import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  // Default to Light as requested
  ThemeMode _themeMode = ThemeMode.light;
  bool _isFirstLaunch = true;

  ThemeMode get themeMode => _themeMode;
  bool get isFirstLaunch => _isFirstLaunch;

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
    // Default to ThemeMode.light.index if key not found
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.light.index;

    if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.light;
    }

    _isFirstLaunch = false;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  // Helper to toggle between light/dark (skipping system)
  void toggleTheme(BuildContext context) {
    final isDark = isDarkMode(context);
    setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }
}
