import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted **Live TV grid** column count (channels per row).
///
/// Valid values: **4–12**, step **1**. Default **6**.
class LiveTvGridColumnsStore extends ChangeNotifier {
  LiveTvGridColumnsStore._();
  static final LiveTvGridColumnsStore instance = LiveTvGridColumnsStore._();

  static const _kPrefsKey = 'tvmatepro_live_tv_grid_columns_v1';

  static const int minColumns = 4;
  static const int maxColumns = 12;
  static const int defaultColumns = 6;

  var _loaded = false;
  int _columns = defaultColumns;

  bool get isLoaded => _loaded;
  int get columns => _columns;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kPrefsKey);
    _columns = _normalize(raw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> adjustColumns(int delta) async {
    await setColumns(_columns + delta);
  }

  Future<void> setColumns(int value) async {
    final next = _normalize(value);
    if (next == _columns) return;
    _columns = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKey, next);
    notifyListeners();
  }

  static int _normalize(int? raw) {
    if (raw == null) return defaultColumns;
    return raw.clamp(minColumns, maxColumns);
  }
}

final LiveTvGridColumnsStore liveTvGridColumnsStore =
    LiveTvGridColumnsStore.instance;
