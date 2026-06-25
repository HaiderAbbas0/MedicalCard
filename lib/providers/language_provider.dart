import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, urdu }

/// App language + text direction (Urdu drives RTL app-wide).
class LanguageProvider extends ChangeNotifier {
  static const _key = 'language';
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  bool get isUrdu => _language == AppLanguage.urdu;
  TextDirection get direction =>
      isUrdu ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => isUrdu ? const Locale('ur') : const Locale('en');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language =
        prefs.getString(_key) == 'urdu' ? AppLanguage.urdu : AppLanguage.english;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }
}
