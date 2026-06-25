import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls light / dark / system theme, persisted to SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'themeMode';
  // Default to the light (white + green) theme to match the design.
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool isDark(BuildContext context) {
    if (_mode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _mode == ThemeMode.dark;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    _mode = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light, // no stored preference → light by default
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Convenience toggle used by the Settings switch.
  Future<void> toggleDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);
}
