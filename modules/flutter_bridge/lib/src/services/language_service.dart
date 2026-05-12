import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _languageKey = 'setLanguage';
  String _currentLanguage = 'system';

  String get currentLanguage => _currentLanguage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'system';
  }

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  String getLocalizedUrl(String baseUrl) {
    if (_currentLanguage == 'system' || _currentLanguage.isEmpty) {
      return baseUrl;
    }
    return '$baseUrl$_currentLanguage';
  }
}
