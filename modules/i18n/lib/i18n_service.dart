import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translations.dart';

class I18nService {
  static final I18nService _instance = I18nService._internal();
  factory I18nService() => _instance;
  I18nService._internal();

  static const String _languageKey = 'setLanguage';
  static const MethodChannel _channel = MethodChannel('app_language');
  
  String _currentLanguage = AppTranslations.defaultLocale;
  String _storedLanguage = 'system';
  final _languageController = StreamController<String>.broadcast();

  String get currentLanguage => _currentLanguage;
  String get storedLanguage => _storedLanguage;
  Stream<String> get languageStream => _languageController.stream;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _storedLanguage = prefs.getString(_languageKey) ?? 'system';
    _currentLanguage = _resolveLanguage(_storedLanguage);
    print('I18nService init, stored=$_storedLanguage resolved=$_currentLanguage');
    
    await _updateAppTitle();
  }

  Future<void> setLanguage(String language) async {
    final resolvedLanguage = _resolveLanguage(language);
    if (resolvedLanguage == _currentLanguage && language == _storedLanguage) return;
    
    _storedLanguage = language;
    _currentLanguage = resolvedLanguage;
    _languageController.add(_currentLanguage);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    print('I18nService setLanguage: $language -> resolved: $_currentLanguage');
    
    await _updateAppTitle();
  }

  String _resolveLanguage(String language) {
    if (language == 'system' || language.isEmpty) {
      return _getSystemLanguage();
    }
    if (!AppTranslations.supportedLocales.contains(language)) {
      return AppTranslations.defaultLocale;
    }
    return language;
  }

  String _getSystemLanguage() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageTag = '${systemLocale.languageCode}-${systemLocale.countryCode ?? ''}';
    
    if (AppTranslations.supportedLocales.contains(languageTag)) {
      return languageTag;
    }
    
    final languageOnly = systemLocale.languageCode;
    for (final locale in AppTranslations.supportedLocales) {
      if (locale.startsWith('$languageOnly-')) {
        return locale;
      }
    }
    
    return AppTranslations.defaultLocale;
  }

  String getSystemLanguage() {
    return _getSystemLanguage();
  }

  String translate(String key, [Map<String, String>? params]) {
    final translations = AppTranslations.translations[_currentLanguage] ?? 
        AppTranslations.translations[AppTranslations.defaultLocale]!;
    
    String text = translations[key] ?? key;
    
    if (params != null) {
      params.forEach((paramKey, value) {
        text = text.replaceAll('{$paramKey}', value);
      });
    }
    
    return text;
  }

  String t(String key, [Map<String, String>? params]) {
    return translate(key, params);
  }

  Future<void> _updateAppTitle() async {
    final title = t('app_title');
    try {
      await _channel.invokeMethod('updateAppTitle', {'title': title});
      print('I18nService updated app title to: $title');
    } catch (e) {
      print('I18nService failed to update app title: $e');
    }
  }

  void dispose() {
    _languageController.close();
  }
}