import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'opensubtitles_config.dart';

/// VOD subtitles: default language (for OpenSubtitles result sorting).
/// OpenSubtitles API key is built in; see [kOpenSubtitlesBuiltInApiKey].
class SubtitleSettingsStore extends ChangeNotifier {
  SubtitleSettingsStore._();
  static final SubtitleSettingsStore instance = SubtitleSettingsStore._();

  static const _kLang = 'tvmatepro_subtitle_default_lang';

  bool _loaded = false;
  String _defaultLanguageCode = 'en';

  bool get loaded => _loaded;
  String get defaultLanguageCode => _defaultLanguageCode;

  /// Always returns the app built-in key (users do not configure this in Settings).
  String get openSubtitlesApiKey => kOpenSubtitlesBuiltInApiKey;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _defaultLanguageCode = (p.getString(_kLang) ?? 'en').trim().toLowerCase();
    if (_defaultLanguageCode.isEmpty) _defaultLanguageCode = 'en';
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDefaultLanguageCode(String code) async {
    var c = code.trim().toLowerCase();
    if (c.isEmpty) c = 'en';
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, c);
    _defaultLanguageCode = c;
    notifyListeners();
  }

  /// No-op: API key is fixed at [kOpenSubtitlesBuiltInApiKey]. Kept for call-site compatibility.
  Future<void> setOpenSubtitlesApiKey(String key) async {
    await ensureLoaded();
  }

  Map<String, dynamic> exportForBackup({bool stripSecrets = false}) => {
        'defaultLanguageCode': _defaultLanguageCode,
      };

  Future<void> applyFromBackup(Map<String, dynamic>? m) async {
    await ensureLoaded();
    if (m == null) return;
    final lang = m['defaultLanguageCode'];
    if (lang is String && lang.trim().isNotEmpty) {
      await setDefaultLanguageCode(lang);
    }
  }
}
