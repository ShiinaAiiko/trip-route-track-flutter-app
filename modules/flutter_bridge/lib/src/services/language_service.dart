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
          print('init Setting language: $_currentLanguage');
  }

  Future<void> setLanguage(String language) async {
          print('Setting language: $language');
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  String getLocalizedUrl(String baseUrl) {
        // print('getLocalizedUrl language: $baseUrl $_currentLanguage');
    if (_currentLanguage == 'system' || _currentLanguage.isEmpty) {
      return baseUrl;
    }
    String normalizedBaseUrl = baseUrl;
    // 移除末尾的 /
    while (normalizedBaseUrl.endsWith('/')) {
      normalizedBaseUrl = normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 1);
    }
        // print('getLocalizedUrl language: $normalizedBaseUrl $_currentLanguage');
    return '$normalizedBaseUrl/$_currentLanguage';
  }
}
