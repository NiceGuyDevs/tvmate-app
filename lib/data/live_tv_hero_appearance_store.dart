import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/team_palette.dart';

/// Persisted Live TV hero background: custom gradient + optional brushed wash + TV frame.
class LiveTvHeroAppearanceStore extends ChangeNotifier {
  LiveTvHeroAppearanceStore();

  static const _prefsKey = 'live_tv_hero_appearance';

  var _loaded = false;
  var _useCustom = false;

  /// Base gradient top color (ARGB).
  int _baseTopArgb = 0xFF0A0E14;

  /// Mid tone before depth darkening (ARGB).
  int _baseBottomArgb = 0xFF050608;

  /// Wash overlay color (ARGB).
  int _washArgb = 0xFF0D1118;

  /// 0–100 — brush strength (UI percent).
  int _washIntensity = 42;

  /// 0 … [brushStyleMax] — brushed texture style.
  int _brushStyle = 0;

  static const int brushStyleMax = 7;

  /// 0 = textured brush strokes; 1 = uniform “color on color” solid overlay.
  int _washMode = 0;

  static const int washModeBrush = 0;
  static const int washModeSolid = 1;

  /// Show decorative TV bezel around the hero video.
  bool _tvFrameOn = true;

  /// 0 slim … 3 minimal — matches [HeroTvBezelFrame].
  int _tvFrameStyle = 1;

  /// 0 graphite … 5 chrome — bezel outer gradient.
  int _bezelFinish = 0;

  /// 10–55 — how dark the bottom of the base gradient is (higher = deeper).
  int _gradientDepth = 28;

  bool get loaded => _loaded;
  bool get useCustom => _useCustom;

  /// Selected base swatch (gradient top).
  Color get baseColor => Color(_baseTopArgb);

  Color get washColor => Color(_washArgb);

  /// 0–100 for UI and [HeroBrushOverlay] scaling.
  int get washIntensity => _washIntensity;

  int get brushStyle => _brushStyle;

  /// [washModeBrush] or [washModeSolid].
  int get washMode => _washMode;

  bool get tvFrameOn => _tvFrameOn;
  int get tvFrameStyle => _tvFrameStyle;
  int get bezelFinish => _bezelFinish;
  int get gradientDepth => _gradientDepth;

  /// Hide brush layer when off or intensity zero.
  bool get showWashOverlay => useCustom && _washIntensity > 0;

  /// Bottom color blended toward black by [gradientDepth]/100.
  LinearGradient baseGradient(TeamPalette shell) {
    if (!_useCustom) return shell.heroDefaultGradient;
    final top = Color(_baseTopArgb);
    final bot = Color(_baseBottomArgb);
    final t = (_gradientDepth.clamp(10, 55)) / 100.0;
    final deep = Color.lerp(bot, Colors.black, t)!;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, deep],
      stops: const [0.0, 1.0],
    );
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _applyMap(m);
      } catch (_) {
        _useCustom = false;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void _applyMap(Map<String, dynamic> m) {
    _useCustom = m['useCustom'] == true;
    _baseTopArgb = _readArgb(m['baseTop'] ?? m['base'], _baseTopArgb);
    _baseBottomArgb = _readArgb(m['baseBottom'], _baseBottomArgb);
    _washArgb = _readArgb(m['wash'], _washArgb);
    _washIntensity = _readWashIntensity(m['washIntensity'], _washIntensity);
    _brushStyle =
        _readInt(m['brushStyle'], _brushStyle).clamp(0, brushStyleMax);
    _washMode = _readInt(m['washMode'], _washMode).clamp(0, 1);
    _tvFrameOn = m['tvFrameOn'] is bool ? m['tvFrameOn'] as bool : true;
    _tvFrameStyle = _readInt(m['tvFrameStyle'], _tvFrameStyle).clamp(0, 3);
    _bezelFinish = _readInt(m['bezelFinish'], _bezelFinish).clamp(0, 5);
    _gradientDepth =
        _readInt(m['gradientDepth'], _gradientDepth).clamp(10, 55);
  }

  static int _readWashIntensity(dynamic v, int fallback) {
    if (v is int) return v.clamp(0, 100);
    if (v is num) {
      final d = v.toDouble();
      if (d <= 1.0 && d >= 0) return (d * 100).round().clamp(0, 100);
      return d.round().clamp(0, 100);
    }
    return fallback;
  }

  static int _readArgb(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  static int _readInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'useCustom': _useCustom,
      'baseTop': _baseTopArgb,
      'baseBottom': _baseBottomArgb,
      'wash': _washArgb,
      'washIntensity': _washIntensity,
      'brushStyle': _brushStyle,
      'washMode': _washMode,
      'tvFrameOn': _tvFrameOn,
      'tvFrameStyle': _tvFrameStyle,
      'bezelFinish': _bezelFinish,
      'gradientDepth': _gradientDepth,
    };
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  Future<void> setUseCustom(bool v) async {
    _useCustom = v;
    notifyListeners();
    await _persist();
  }

  Future<void> setBaseColor(Color c) async {
    _useCustom = true;
    _baseTopArgb = c.toARGB32();
    _baseBottomArgb =
        Color.lerp(c, const Color(0xFF06080C), 0.52)!.toARGB32();
    notifyListeners();
    await _persist();
  }

  Future<void> setWashColor(Color c) async {
    _useCustom = true;
    _washArgb = c.toARGB32();
    notifyListeners();
    await _persist();
  }

  Future<void> adjustWashIntensity(int delta) async {
    _useCustom = true;
    _washIntensity = (_washIntensity + delta).clamp(0, 100);
    notifyListeners();
    await _persist();
  }

  Future<void> setWashIntensity(int value) async {
    _useCustom = true;
    _washIntensity = value.clamp(0, 100);
    notifyListeners();
    await _persist();
  }

  Future<void> setBrushStyle(int v) async {
    _useCustom = true;
    _brushStyle = v.clamp(0, brushStyleMax);
    notifyListeners();
    await _persist();
  }

  Future<void> setWashMode(int v) async {
    _useCustom = true;
    _washMode = v.clamp(0, 1);
    notifyListeners();
    await _persist();
  }

  Future<void> setTvFrameOn(bool v) async {
    _tvFrameOn = v;
    notifyListeners();
    await _persist();
  }

  Future<void> setTvFrameStyle(int v) async {
    _tvFrameStyle = v.clamp(0, 3);
    notifyListeners();
    await _persist();
  }

  Future<void> setBezelFinish(int v) async {
    _bezelFinish = v.clamp(0, 5);
    notifyListeners();
    await _persist();
  }

  Future<void> setGradientDepth(int v) async {
    _useCustom = true;
    _gradientDepth = v.clamp(10, 55);
    notifyListeners();
    await _persist();
  }

  Future<void> adjustGradientDepth(int delta) async {
    await setGradientDepth(_gradientDepth + delta);
  }

  Future<void> resetToDefault() async {
    _useCustom = false;
    _baseTopArgb = 0xFF0A0E14;
    _baseBottomArgb = 0xFF050608;
    _washArgb = 0xFF0D1118;
    _washIntensity = 42;
    _brushStyle = 0;
    _washMode = 0;
    _tvFrameOn = true;
    _tvFrameStyle = 1;
    _bezelFinish = 0;
    _gradientDepth = 28;
    notifyListeners();
    await _persist();
  }

  Map<String, dynamic> exportForBackup() => {
        'useCustom': _useCustom,
        'baseTop': _baseTopArgb,
        'baseBottom': _baseBottomArgb,
        'wash': _washArgb,
        'washIntensity': _washIntensity,
        'brushStyle': _brushStyle,
        'washMode': _washMode,
        'tvFrameOn': _tvFrameOn,
        'tvFrameStyle': _tvFrameStyle,
        'bezelFinish': _bezelFinish,
        'gradientDepth': _gradientDepth,
      };

  Future<void> replaceFromBackup(Map<String, dynamic>? m) async {
    if (m == null) return;
    _applyMap(m);
    notifyListeners();
    await _persist();
  }
}

final liveTvHeroAppearanceStore = LiveTvHeroAppearanceStore();
