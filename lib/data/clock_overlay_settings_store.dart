import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ClockCorner { topLeft, topRight, bottomLeft, bottomRight }

extension ClockCornerStorage on ClockCorner {
  String get storageValue => switch (this) {
        ClockCorner.topLeft => 'tl',
        ClockCorner.topRight => 'tr',
        ClockCorner.bottomLeft => 'bl',
        ClockCorner.bottomRight => 'br',
      };

  Alignment get alignment => switch (this) {
        ClockCorner.topLeft => Alignment.topLeft,
        ClockCorner.topRight => Alignment.topRight,
        ClockCorner.bottomLeft => Alignment.bottomLeft,
        ClockCorner.bottomRight => Alignment.bottomRight,
      };
}

enum ClockSizePreset { small, medium, large }

extension ClockSizePresetX on ClockSizePreset {
  String get storageValue => switch (this) {
        ClockSizePreset.small => 's',
        ClockSizePreset.medium => 'm',
        ClockSizePreset.large => 'l',
      };

  String get label => switch (this) {
        ClockSizePreset.small => 'Small',
        ClockSizePreset.medium => 'Medium',
        ClockSizePreset.large => 'Large',
      };

  double get fontSize => switch (this) {
        ClockSizePreset.small => 15,
        ClockSizePreset.medium => 19,
        ClockSizePreset.large => 24,
      };

  double get edgePadding => switch (this) {
        ClockSizePreset.small => 14,
        ClockSizePreset.medium => 18,
        ClockSizePreset.large => 22,
      };
}

/// Global on-screen clock (persisted). Used by [ClockOverlayLayer].
class ClockOverlaySettingsStore extends ChangeNotifier {
  static const _kEnabled = 'tvmatepro_clock_enabled_v1';
  static const _k24h = 'tvmatepro_clock_24h_v1';
  static const _kCorner = 'tvmatepro_clock_corner_v1';
  static const _kSize = 'tvmatepro_clock_size_v1';
  static const _kOpacity = 'tvmatepro_clock_opacity_v1';
  static const _kColorIdx = 'tvmatepro_clock_color_idx_v1';
  static const _kFramed = 'tvmatepro_clock_framed_v1';

  static const _kOffsetTlDx = 'tvmatepro_clock_offset_tl_dx_v1';
  static const _kOffsetTlDy = 'tvmatepro_clock_offset_tl_dy_v1';
  static const _kOffsetTrDx = 'tvmatepro_clock_offset_tr_dx_v1';
  static const _kOffsetTrDy = 'tvmatepro_clock_offset_tr_dy_v1';
  static const _kOffsetBlDx = 'tvmatepro_clock_offset_bl_dx_v1';
  static const _kOffsetBlDy = 'tvmatepro_clock_offset_bl_dy_v1';
  static const _kOffsetBrDx = 'tvmatepro_clock_offset_br_dx_v1';
  static const _kOffsetBrDy = 'tvmatepro_clock_offset_br_dy_v1';

  /// Max nudge from the default corner anchor (logical px). Keeps the clock on-screen.
  static const double maxCornerOffsetLogical = 180.0;

  /// Preset text colors (index persisted).
  /// Indices [kNeonRedIndex]–[kNeonYellowIndex] use 7-segment font + neon styling in the overlay.
  static const List<Color> presetColors = [
    Color(0xFFF5F5F5),
    Color(0xFF7DD3FC),
    Color(0xFFFDE047),
    Color(0xFF86EFAC),
    Color(0xFFF472B6),
    Color(0xFFFF2A6D), // neon red
    Color(0xFF39FF14), // neon green
    Color(0xFFFFEA00), // neon yellow
  ];

  static const int kNeonRedIndex = 5;
  static const int kNeonGreenIndex = 6;
  static const int kNeonYellowIndex = 7;

  /// 7-segment / LED digit font (bundled DSEG7 Classic).
  bool get useSegmentDigitFont =>
      colorIndex == kNeonRedIndex ||
      colorIndex == kNeonGreenIndex ||
      colorIndex == kNeonYellowIndex;

  var _loaded = false;
  bool _enabled = false;
  bool _use24Hour = true;
  ClockCorner _corner = ClockCorner.topLeft;
  ClockSizePreset _size = ClockSizePreset.large;
  double _opacity = 1.0;
  int _colorIndex = kNeonGreenIndex;
  bool _framed = false;

  double _offsetTlDx = 0;
  double _offsetTlDy = 0;
  double _offsetTrDx = 0;
  double _offsetTrDy = 0;
  double _offsetBlDx = 0;
  double _offsetBlDy = 0;
  double _offsetBrDx = 0;
  double _offsetBrDy = 0;

  bool get isLoaded => _loaded;
  bool get enabled => _enabled;
  bool get framed => _framed;
  bool get use24Hour => _use24Hour;
  ClockCorner get corner => _corner;
  ClockSizePreset get size => _size;
  double get opacity => _opacity;
  int get colorIndex => _colorIndex;

  /// Fine-tune offset for [corner] relative to the default [ClockCorner.alignment] placement.
  Offset offsetForCorner(ClockCorner corner) {
    switch (corner) {
      case ClockCorner.topLeft:
        return Offset(_offsetTlDx, _offsetTlDy);
      case ClockCorner.topRight:
        return Offset(_offsetTrDx, _offsetTrDy);
      case ClockCorner.bottomLeft:
        return Offset(_offsetBlDx, _offsetBlDy);
      case ClockCorner.bottomRight:
        return Offset(_offsetBrDx, _offsetBrDy);
    }
  }

  Color get textColor {
    final i = _colorIndex.clamp(0, presetColors.length - 1);
    return presetColors[i];
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? false;
    _use24Hour = prefs.getBool(_k24h) ?? true;
    _corner = _cornerFrom(prefs.getString(_kCorner));
    _size = _sizeFrom(prefs.getString(_kSize));
    _opacity = (prefs.getDouble(_kOpacity) ?? 1.0).clamp(0.2, 1.0);
    _colorIndex = (prefs.getInt(_kColorIdx) ?? kNeonGreenIndex)
        .clamp(0, presetColors.length - 1);
    _framed = prefs.getBool(_kFramed) ?? false;
    _offsetTlDx = _readOffset(prefs, _kOffsetTlDx);
    _offsetTlDy = _readOffset(prefs, _kOffsetTlDy);
    _offsetTrDx = _readOffset(prefs, _kOffsetTrDx);
    _offsetTrDy = _readOffset(prefs, _kOffsetTrDy);
    _offsetBlDx = _readOffset(prefs, _kOffsetBlDx);
    _offsetBlDy = _readOffset(prefs, _kOffsetBlDy);
    _offsetBrDx = _readOffset(prefs, _kOffsetBrDx);
    _offsetBrDy = _readOffset(prefs, _kOffsetBrDy);
    _loaded = true;
    notifyListeners();
  }

  static double _readOffset(SharedPreferences prefs, String key) {
    final v = prefs.getDouble(key);
    if (v == null) return 0;
    return v.clamp(-maxCornerOffsetLogical, maxCornerOffsetLogical);
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    await _saveBool(_kEnabled, value);
    notifyListeners();
  }

  Future<void> setUse24Hour(bool value) async {
    if (_use24Hour == value) return;
    _use24Hour = value;
    await _saveBool(_k24h, value);
    notifyListeners();
  }

  Future<void> setCorner(ClockCorner value) async {
    if (_corner == value) return;
    _corner = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCorner, value.storageValue);
    notifyListeners();
  }

  Future<void> setSize(ClockSizePreset value) async {
    if (_size == value) return;
    _size = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSize, value.storageValue);
    notifyListeners();
  }

  Future<void> setOpacity(double value) async {
    final v = value.clamp(0.2, 1.0);
    if ((_opacity - v).abs() < 0.001) return;
    _opacity = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kOpacity, v);
    notifyListeners();
  }

  Future<void> setFramed(bool value) async {
    if (_framed == value) return;
    _framed = value;
    await _saveBool(_kFramed, value);
    notifyListeners();
  }

  Future<void> setColorIndex(int index) async {
    final i = index.clamp(0, presetColors.length - 1);
    if (_colorIndex == i) return;
    _colorIndex = i;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColorIdx, i);
    notifyListeners();
  }

  /// Persists per-corner nudge from default anchor (used by overlay + placement screen).
  Future<void> setCornerOffset(ClockCorner corner, Offset value) async {
    final dx = value.dx.clamp(-maxCornerOffsetLogical, maxCornerOffsetLogical);
    final dy = value.dy.clamp(-maxCornerOffsetLogical, maxCornerOffsetLogical);
    switch (corner) {
      case ClockCorner.topLeft:
        if (_offsetTlDx == dx && _offsetTlDy == dy) return;
        _offsetTlDx = dx;
        _offsetTlDy = dy;
        notifyListeners();
        await _persistCornerOffsets(
          dxKey: _kOffsetTlDx,
          dyKey: _kOffsetTlDy,
          dx: dx,
          dy: dy,
        );
      case ClockCorner.topRight:
        if (_offsetTrDx == dx && _offsetTrDy == dy) return;
        _offsetTrDx = dx;
        _offsetTrDy = dy;
        notifyListeners();
        await _persistCornerOffsets(
          dxKey: _kOffsetTrDx,
          dyKey: _kOffsetTrDy,
          dx: dx,
          dy: dy,
        );
      case ClockCorner.bottomLeft:
        if (_offsetBlDx == dx && _offsetBlDy == dy) return;
        _offsetBlDx = dx;
        _offsetBlDy = dy;
        notifyListeners();
        await _persistCornerOffsets(
          dxKey: _kOffsetBlDx,
          dyKey: _kOffsetBlDy,
          dx: dx,
          dy: dy,
        );
      case ClockCorner.bottomRight:
        if (_offsetBrDx == dx && _offsetBrDy == dy) return;
        _offsetBrDx = dx;
        _offsetBrDy = dy;
        notifyListeners();
        await _persistCornerOffsets(
          dxKey: _kOffsetBrDx,
          dyKey: _kOffsetBrDy,
          dx: dx,
          dy: dy,
        );
    }
  }

  Future<void> _persistCornerOffsets({
    required String dxKey,
    required String dyKey,
    required double dx,
    required double dy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(dxKey, dx);
    await prefs.setDouble(dyKey, dy);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Map<String, dynamic> exportForBackup() => {
        'enabled': _enabled,
        'use24Hour': _use24Hour,
        'corner': _corner.storageValue,
        'size': _size.storageValue,
        'opacity': _opacity,
        'colorIndex': _colorIndex,
        'framed': _framed,
        'cornerOffsets': {
          'tl': {'dx': _offsetTlDx, 'dy': _offsetTlDy},
          'tr': {'dx': _offsetTrDx, 'dy': _offsetTrDy},
          'bl': {'dx': _offsetBlDx, 'dy': _offsetBlDy},
          'br': {'dx': _offsetBrDx, 'dy': _offsetBrDy},
        },
      };

  Future<void> applyBackup(Map<String, dynamic> m) async {
    await ensureLoaded();
    if (m['enabled'] is bool) await setEnabled(m['enabled'] as bool);
    if (m['use24Hour'] is bool) await setUse24Hour(m['use24Hour'] as bool);
    if (m['corner'] is String) {
      await setCorner(_cornerFrom(m['corner'] as String));
    }
    if (m['size'] is String) {
      await setSize(_sizeFrom(m['size'] as String));
    }
    if (m['opacity'] is num) await setOpacity((m['opacity'] as num).toDouble());
    if (m['colorIndex'] is num) await setColorIndex((m['colorIndex'] as num).toInt());
    if (m['framed'] is bool) await setFramed(m['framed'] as bool);
    final co = m['cornerOffsets'];
    if (co is Map<String, dynamic>) {
      Future<void> apply(String key, ClockCorner corner) async {
        final e = co[key];
        if (e is! Map<String, dynamic>) return;
        final dx = e['dx'];
        final dy = e['dy'];
        if (dx is! num || dy is! num) return;
        await setCornerOffset(
          corner,
          Offset(dx.toDouble(), dy.toDouble()),
        );
      }

      await apply('tl', ClockCorner.topLeft);
      await apply('tr', ClockCorner.topRight);
      await apply('bl', ClockCorner.bottomLeft);
      await apply('br', ClockCorner.bottomRight);
    }
  }

  static ClockCorner _cornerFrom(String? raw) {
    switch (raw) {
      case 'tl':
        return ClockCorner.topLeft;
      case 'tr':
        return ClockCorner.topRight;
      case 'bl':
        return ClockCorner.bottomLeft;
      case 'br':
        return ClockCorner.bottomRight;
      case null:
        return ClockCorner.topLeft;
      default:
        return ClockCorner.topLeft;
    }
  }

  static ClockSizePreset _sizeFrom(String? raw) {
    switch (raw) {
      case 's':
        return ClockSizePreset.small;
      case 'm':
        return ClockSizePreset.medium;
      case 'l':
        return ClockSizePreset.large;
      case null:
      default:
        return ClockSizePreset.large;
    }
  }
}

final ClockOverlaySettingsStore clockOverlaySettingsStore =
    ClockOverlaySettingsStore();
