import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// Order matches ◀▶ cycle in Live TV appearance (name → … → logo only).
enum LiveTvCardStyle { nameOnly, logoNameEpg, logoNameOnly, logoOnly }

/// Left→right order in **Channel Grid Settings** reference UI (Logo only … Name only).
const kChannelGridDisplayStyleOrder = <LiveTvCardStyle>[
  LiveTvCardStyle.logoOnly,
  LiveTvCardStyle.logoNameOnly,
  LiveTvCardStyle.logoNameEpg,
  LiveTvCardStyle.nameOnly,
];

extension LiveTvCardStyleStorage on LiveTvCardStyle {
  String get storageValue => switch (this) {
        LiveTvCardStyle.nameOnly => 'text_only',
        LiveTvCardStyle.logoNameEpg => 'logo_text',
        LiveTvCardStyle.logoNameOnly => 'logo_name_only',
        LiveTvCardStyle.logoOnly => 'logo_only',
      };

  String get label => switch (this) {
        LiveTvCardStyle.nameOnly => 'Name only',
        LiveTvCardStyle.logoNameEpg => 'Logo + name + program',
        LiveTvCardStyle.logoNameOnly => 'Logo + name',
        LiveTvCardStyle.logoOnly => 'Logo only',
      };
}

class LiveTvCardStyleStore extends ChangeNotifier {
  static const _kPrefsKey = 'tvmatepro_live_tv_card_style_v1';
  var _loaded = false;
  /// Fresh install: **Logo + name** (no EPG line).
  LiveTvCardStyle _style = LiveTvCardStyle.logoNameOnly;

  bool get isLoaded => _loaded;
  LiveTvCardStyle get style => _style;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    _style = raw == null ? LiveTvCardStyle.logoNameOnly : _fromStorage(raw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setStyle(LiveTvCardStyle next) async {
    if (_style == next) return;
    _style = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, next.storageValue);
    notifyListeners();
  }

  static LiveTvCardStyle _fromStorage(String? raw) => parseStyleStorage(raw);

  static LiveTvCardStyle parseStyleStorage(String? raw) {
    switch (raw) {
      case 'logo_only':
        return LiveTvCardStyle.logoOnly;
      case 'text_only':
        return LiveTvCardStyle.nameOnly;
      case 'logo_name_only':
        return LiveTvCardStyle.logoNameOnly;
      case 'logo_text':
      default:
        return LiveTvCardStyle.logoNameEpg;
    }
  }
}

final LiveTvCardStyleStore liveTvCardStyleStore = LiveTvCardStyleStore();
