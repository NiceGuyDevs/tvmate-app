import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted UI locale (en, he, fr, es, ar). Default English on first launch.
class AppLocaleStore extends ChangeNotifier {
  AppLocaleStore._();

  static final AppLocaleStore instance = AppLocaleStore._();

  static const _prefsKey = 'app_locale_language_code';

  /// BCP-47 language subtags we ship translations for.
  static const List<String> supportedLanguageCodes = [
    'en',
    'he',
    'fr',
    'es',
    'ar',
  ];

  String _languageCode = 'en';
  var _loaded = false;

  String get languageCode => _languageCode;

  Locale get locale => Locale(_languageCode);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw != null && supportedLanguageCodes.contains(raw)) {
      _languageCode = raw;
    } else {
      _languageCode = 'en';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    await ensureLoaded();
    if (!supportedLanguageCodes.contains(code)) return;
    if (_languageCode == code) return;
    _languageCode = code;
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, code);
    notifyListeners();
  }
}

final appLocaleStore = AppLocaleStore.instance;
