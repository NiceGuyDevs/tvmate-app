import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted **Live TV hero** chrome height as a percentage of the design height.
///
/// Valid values: **30–100** in steps of **10**. Default **60** (fresh install).
class LiveTvHeroLayoutStore extends ChangeNotifier {
  LiveTvHeroLayoutStore._();
  static final LiveTvHeroLayoutStore instance = LiveTvHeroLayoutStore._();

  static const _kPrefsKey = 'tvmatepro_live_tv_hero_height_pct_v1';

  /// Design-time hero inner height (logical px); see [live_tv_hero_panel.dart].
  static const double baseHeroLogicalHeight = 232;

  static const int minHeightPercent = 30;
  static const int maxHeightPercent = 100;
  static const int heightPercentStep = 10;

  var _loaded = false;
  static const int defaultHeightPercent = 60;

  int _heroHeightPercent = defaultHeightPercent;

  bool get isLoaded => _loaded;

  int get heroHeightPercent => _heroHeightPercent;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kPrefsKey);
    _heroHeightPercent = _normalizePercent(raw);
    _loaded = true;
    notifyListeners();
  }

  /// [delta] should be a multiple of [heightPercentStep] (e.g. ±10 from UI).
  Future<void> adjustHeroHeightPercent(int delta) async {
    await setHeroHeightPercent(_heroHeightPercent + delta);
  }

  Future<void> setHeroHeightPercent(int value) async {
    final next = _normalizePercent(value);
    if (next == _heroHeightPercent) return;
    _heroHeightPercent = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKey, next);
    notifyListeners();
  }

  static int _normalizePercent(int? raw) {
    if (raw == null) {
      return defaultHeightPercent;
    }
    final stepped =
        (raw / heightPercentStep).round() * heightPercentStep;
    return stepped.clamp(minHeightPercent, maxHeightPercent);
  }
}

final LiveTvHeroLayoutStore liveTvHeroLayoutStore = LiveTvHeroLayoutStore.instance;
