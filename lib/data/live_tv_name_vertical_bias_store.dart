import 'package:flutter/foundation.dart'
    show ChangeNotifier, TargetPlatform, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

/// Global vertical nudge for **channel name** on Live TV grid tiles (all tiles).
///
/// Persisted; applied to name-only tiles ([Alignment]) and logo tiles (bottom block
/// [Transform]).
class LiveTvNameVerticalBiasStore extends ChangeNotifier {
  static const _kPrefsKey = 'tvmatepro_live_tv_name_vertical_step_v1';

  /// Inclusive; step **0** = default layout.
  static const int minStep = -5;
  static const int maxStep = 5;
  static const int defaultStep = 0;

  /// First launch on **Windows** (no pref): three “up” nudges vs default (0).
  static const int defaultStepWindows = -3;

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
    if (raw == null) {
      return defaultTargetPlatform == TargetPlatform.windows
          ? defaultStepWindows
          : defaultStep;
    }
    return raw.clamp(minStep, maxStep);
  }

  /// [LiveTvCardStyle] name-only tile: added to base [Alignment] y (~0.38).
  double get textOnlyAlignmentY =>
      (0.38 + _step * 0.026).clamp(0.1, 0.82).toDouble();

  /// Logo + text tiles: shifts the bottom text block (px); positive = downward.
  double get logoBottomTranslateY => _step * 2.2;
}

final LiveTvNameVerticalBiasStore liveTvNameVerticalBiasStore =
    LiveTvNameVerticalBiasStore();
