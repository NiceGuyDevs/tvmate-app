import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global horizontal nudge for **channel name** on Live TV grid tiles (all tiles).
///
/// Persisted; pairs with [LiveTvNameVerticalBiasStore].
class LiveTvNameHorizontalBiasStore extends ChangeNotifier {
  static const _kPrefsKey = 'tvmatepro_live_tv_name_horizontal_step_v1';

  static const int minStep = -5;
  static const int maxStep = 5;
  static const int defaultStep = 0;

  var _loaded = false;
  int _step = defaultStep;

  bool get isLoaded => _loaded;
  int get step => _step;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_kPrefsKey);
    _step = _normalize(raw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> adjustStep(int delta) async {
    await setStep(_step + delta);
  }

  Future<void> setStep(int value) async {
    final next = _normalize(value);
    if (next == _step) return;
    _step = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefsKey, next);
    notifyListeners();
  }

  static int _normalize(int? raw) {
    if (raw == null) return defaultStep;
    return raw.clamp(minStep, maxStep);
  }

  /// Name-only tile: [Alignment] x; positive = toward right edge.
  double get textOnlyAlignmentX =>
      (0.0 + _step * 0.055).clamp(-0.88, 0.88).toDouble();

  /// Logo + text tiles: shifts the bottom text block horizontally (px).
  double get logoBottomTranslateX => _step * 2.2;
}

final LiveTvNameHorizontalBiasStore liveTvNameHorizontalBiasStore =
    LiveTvNameHorizontalBiasStore();
