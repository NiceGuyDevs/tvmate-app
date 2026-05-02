import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global VOD subtitle look: colors, size, on/off, and caption position (logical px).
class SubtitleAppearanceStore extends ChangeNotifier {
  SubtitleAppearanceStore._();
  static final SubtitleAppearanceStore instance = SubtitleAppearanceStore._();

  static const _kEnabled = 'tvmatepro_subtitle_appearance_enabled';
  static const _kBg = 'tvmatepro_subtitle_appearance_bg';
  static const _kFg = 'tvmatepro_subtitle_appearance_fg';
  static const _kSize = 'tvmatepro_subtitle_appearance_size_sp';
  static const _kBgOpacity = 'tvmatepro_subtitle_appearance_bg_opacity';
  static const _kPosDx = 'tvmatepro_subtitle_appearance_pos_dx';
  static const _kPosDy = 'tvmatepro_subtitle_appearance_pos_dy';

  /// Same order for background and text color pickers.
  static const List<Color> paletteColors = <Color>[
    Color(0xFF000000),
    Color(0xFF424242),
    Color(0xFFFFFFFF),
    Color(0xFFFFEB3B),
    Color(0xFF2196F3),
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFFE040FB),
  ];

  static const double fontSizeMin = 14;
  static const double fontSizeMax = 40;
  static const double fontSizeDefault = 22;

  /// Subtitle caption background alpha (0 = invisible … 1 = opaque). Default matches previous fixed 0.92 look.
  static const double backgroundOpacityDefault = 0.92;
  static const double backgroundOpacityMin = 0.0;
  static const double backgroundOpacityMax = 1.0;

  bool _loaded = false;
  bool _subtitlesEnabled = true;
  int _backgroundColorIndex = 0;
  int _textColorIndex = 2;
  double _fontSizeSp = fontSizeDefault;
  double _backgroundOpacity = backgroundOpacityDefault;
  double _positionDx = 0;
  double _positionDy = 0;

  bool get loaded => _loaded;
  bool get subtitlesEnabled => _subtitlesEnabled;
  int get backgroundColorIndex => _backgroundColorIndex.clamp(0, paletteColors.length - 1);
  int get textColorIndex => _textColorIndex.clamp(0, paletteColors.length - 1);
  double get fontSizeSp => _fontSizeSp.clamp(fontSizeMin, fontSizeMax);

  double get backgroundOpacity =>
      _backgroundOpacity.clamp(backgroundOpacityMin, backgroundOpacityMax);

  Color get backgroundColor => paletteColors[backgroundColorIndex];
  Color get textColor => paletteColors[textColorIndex];

  /// Persistent caption translation from default placement (logical pixels).
  Offset get positionOffset => Offset(_positionDx, _positionDy);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _subtitlesEnabled = p.getBool(_kEnabled) ?? true;
    _backgroundColorIndex = (p.getInt(_kBg) ?? 0).clamp(0, paletteColors.length - 1);
    _textColorIndex = (p.getInt(_kFg) ?? 2).clamp(0, paletteColors.length - 1);
    _fontSizeSp = (p.getDouble(_kSize) ?? fontSizeDefault).clamp(fontSizeMin, fontSizeMax);
    _backgroundOpacity = (p.getDouble(_kBgOpacity) ?? backgroundOpacityDefault)
        .clamp(backgroundOpacityMin, backgroundOpacityMax);
    _positionDx = p.getDouble(_kPosDx) ?? 0;
    _positionDy = p.getDouble(_kPosDy) ?? 0;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setSubtitlesEnabled(bool value) async {
    await ensureLoaded();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, value);
    _subtitlesEnabled = value;
    notifyListeners();
  }

  Future<void> setBackgroundColorIndex(int i) async {
    await ensureLoaded();
    final v = i.clamp(0, paletteColors.length - 1);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kBg, v);
    _backgroundColorIndex = v;
    notifyListeners();
  }

  Future<void> setTextColorIndex(int i) async {
    await ensureLoaded();
    final v = i.clamp(0, paletteColors.length - 1);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kFg, v);
    _textColorIndex = v;
    notifyListeners();
  }

  Future<void> setFontSizeSp(double sp) async {
    await ensureLoaded();
    final v = sp.clamp(fontSizeMin, fontSizeMax);
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSize, v);
    _fontSizeSp = v;
    notifyListeners();
  }

  Future<void> setBackgroundOpacity(double opacity) async {
    await ensureLoaded();
    final v = opacity.clamp(backgroundOpacityMin, backgroundOpacityMax);
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kBgOpacity, v);
    _backgroundOpacity = v;
    notifyListeners();
  }

  /// Clamps to the same bounds [PlayerScreen] uses for the current surface size.
  Future<void> setPositionOffset(Offset o,
      {required double maxX, required double maxY}) async {
    await ensureLoaded();
    final dx = o.dx.clamp(-maxX, maxX);
    final dy = o.dy.clamp(-maxY, maxY);
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kPosDx, dx);
    await p.setDouble(_kPosDy, dy);
    _positionDx = dx;
    _positionDy = dy;
    notifyListeners();
  }

  /// Restores factory defaults (on, palette indices, size, opacity, centered position).
  Future<void> resetToDefaults() async {
    await ensureLoaded();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, true);
    await p.setInt(_kBg, 0);
    await p.setInt(_kFg, 2);
    await p.setDouble(_kSize, fontSizeDefault);
    await p.setDouble(_kBgOpacity, backgroundOpacityDefault);
    await p.setDouble(_kPosDx, 0);
    await p.setDouble(_kPosDy, 0);
    _subtitlesEnabled = true;
    _backgroundColorIndex = 0;
    _textColorIndex = 2;
    _fontSizeSp = fontSizeDefault;
    _backgroundOpacity = backgroundOpacityDefault;
    _positionDx = 0;
    _positionDy = 0;
    notifyListeners();
  }

  Map<String, dynamic> exportForBackup() => {
        'subtitlesEnabled': _subtitlesEnabled,
        'backgroundColorIndex': backgroundColorIndex,
        'textColorIndex': textColorIndex,
        'fontSizeSp': fontSizeSp,
        'backgroundOpacity': backgroundOpacity,
        'positionDx': _positionDx,
        'positionDy': _positionDy,
      };

  Future<void> applyFromBackup(Map<String, dynamic>? m) async {
    await ensureLoaded();
    if (m == null) return;
    final en = m['subtitlesEnabled'];
    if (en is bool) await setSubtitlesEnabled(en);
    final bg = m['backgroundColorIndex'];
    if (bg is int) await setBackgroundColorIndex(bg);
    final fg = m['textColorIndex'];
    if (fg is int) await setTextColorIndex(fg);
    final fs = m['fontSizeSp'];
    if (fs is num) await setFontSizeSp(fs.toDouble());
    final bo = m['backgroundOpacity'];
    if (bo is num) await setBackgroundOpacity(bo.toDouble());
    final pdx = m['positionDx'];
    final pdy = m['positionDy'];
    if (pdx is num && pdy is num) {
      await ensureLoaded();
      final prefs = await SharedPreferences.getInstance();
      final x = pdx.toDouble();
      final y = pdy.toDouble();
      await prefs.setDouble(_kPosDx, x);
      await prefs.setDouble(_kPosDy, y);
      _positionDx = x;
      _positionDy = y;
      notifyListeners();
    }
  }
}
