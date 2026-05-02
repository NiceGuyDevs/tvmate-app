import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the ordered list of TV on-screen keyboard languages (`en`, `he`, `ar`).
/// Used by the language chip, globe key, and Languages picker — same order everywhere.
class TvKeyboardLanguageStore {
  TvKeyboardLanguageStore._();

  static const _prefsKey = 'tvmatepro_tv_kbd_lang_order_v1';

  static const Set<String> keyboardLocaleIds = {'en', 'he', 'ar'};

  static const List<String> defaultOrder = ['en', 'he', 'ar'];

  static Future<List<String>> loadOrderedIds() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return List<String>.from(defaultOrder);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List<String>.from(defaultOrder);
      final list = decoded.cast<String>();
      final filtered = <String>[];
      for (final id in list) {
        if (keyboardLocaleIds.contains(id) && !filtered.contains(id)) {
          filtered.add(id);
        }
      }
      if (filtered.isEmpty) return List<String>.from(defaultOrder);
      return filtered;
    } catch (_) {
      return List<String>.from(defaultOrder);
    }
  }

  /// Returns the ordered language list for backup JSON.
  static Future<List<String>> exportForBackup() async {
    return loadOrderedIds();
  }

  /// Replaces the language order from a backup restore.
  static Future<void> replaceFromBackup(List<String>? ids) async {
    if (ids == null || ids.isEmpty) {
      await saveOrderedIds(defaultOrder);
    } else {
      await saveOrderedIds(ids);
    }
  }

  static Future<void> saveOrderedIds(List<String> ids) async {
    final out = <String>[];
    for (final id in ids) {
      if (keyboardLocaleIds.contains(id) && !out.contains(id)) {
        out.add(id);
      }
    }
    if (out.isEmpty) out.addAll(defaultOrder);
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode(out));
  }
}
