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
    print('LanguageService init: $_currentLanguage');
  }

  Future<void> setLanguage(String language) async {
    if (language == _currentLanguage) return;
    
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    print('LanguageService setLanguage: $_currentLanguage');
  }

  String getLocalizedUrl(String baseUrl) {
    if (_currentLanguage == 'system' || _currentLanguage.isEmpty) {
      return baseUrl;
    }
    String normalizedBaseUrl = baseUrl;
    while (normalizedBaseUrl.endsWith('/')) {
      normalizedBaseUrl = normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 1);
    }
    return '$normalizedBaseUrl/$_currentLanguage';
  }
}
