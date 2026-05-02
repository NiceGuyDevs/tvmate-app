import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted **Movies** rail page size (visible posters per row).
///
/// Valid values: **4–12**, step **1**. Fresh install (no pref): **8** on all
/// platforms.
class MovieRailPageSizeStore extends ChangeNotifier {
  MovieRailPageSizeStore._();
  static final MovieRailPageSizeStore instance = MovieRailPageSizeStore._();

  static const _kPrefsKey = 'tvmatepro_movie_rail_page_size_v1';

  static const int minSize = 4;
  static const int maxSize = 12;
  static const int defaultSize = 8;

  var _loaded = false;
  int _size = defaultSize;

  bool get isLoaded => _loaded;
  int get size => _size;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kPrefsKey);
    _size = _normalize(raw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> adjustSize(int delta) async {
    await setSize(_size + delta);
  }

  Future<void> setSize(int value) async {
    final next = _normalize(value);
    if (next == _size) return;
    _size = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKey, next);
    notifyListeners();
  }

  static int _normalize(int? raw) {
    if (raw == null) return defaultSize;
    return raw.clamp(minSize, maxSize);
  }
}

final MovieRailPageSizeStore movieRailPageSizeStore =
    MovieRailPageSizeStore.instance;
