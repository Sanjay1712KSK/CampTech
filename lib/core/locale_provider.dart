import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  static const _prefKey = 'app_locale';

  static const List<Map<String, dynamic>> supportedLanguages = [
    {'name': 'English', 'locale': 'en'},
    {'name': 'हिंदी', 'locale': 'hi'},
    {'name': 'தமிழ்', 'locale': 'ta'},
    {'name': 'తెలుగు', 'locale': 'te'},
    {'name': 'ಕನ್ನಡ', 'locale': 'kn'},
    {'name': 'मराठी', 'locale': 'mr'},
    {'name': 'اردو', 'locale': 'ur'},
  ];

  LocaleProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);
    notifyListeners();
  }
}
