import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../models/language_model.dart';

class LanguageViewModel extends ChangeNotifier {
  static const String _languageKey = 'app_language_code';
  Locale _appLocale = const Locale('ar');

  Locale get appLocale => _appLocale;

  LanguageViewModel() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_languageKey)) {
      _appLocale = Locale(prefs.getString(_languageKey)!);
    } else {
      // Default to device language if supported, else Arabic
      final deviceLocale = PlatformDispatcher.instance.locale;
      final supportedCodes = LanguageModel.supportedLanguages.map((l) => l.languageCode).toList();
      
      if (supportedCodes.contains(deviceLocale.languageCode)) {
        _appLocale = Locale(deviceLocale.languageCode);
      } else {
        _appLocale = const Locale('ar'); // Default to Arabic for Vegtablity
      }
    }
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_appLocale.languageCode == languageCode) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    _appLocale = Locale(languageCode);
    notifyListeners();
  }
}
