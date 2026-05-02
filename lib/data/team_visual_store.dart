import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/team_palette.dart';

/// Visual shell: [settingsStyle], [ember], or [nocturne] (dark purple–rose).
enum AppVisualTeam {
  /// settings.html body stack: [SettingsStyleBackdrop] + cyan [TeamPalette].
  settingsStyle,
  /// Warm radial backdrop + [TeamPalette.ember] chrome.
  ember,
  /// Nocturne field + [TeamPalette.nocturne] (dark; TV focus = [TeamPalette.focusNeonPink]).
  nocturne,
}

extension AppVisualTeamX on AppVisualTeam {
  String get storageValue => switch (this) {
        AppVisualTeam.settingsStyle => 'settings_style',
        AppVisualTeam.ember => 'ember',
        AppVisualTeam.nocturne => 'nocturne',
      };

  String get label => switch (this) {
        AppVisualTeam.settingsStyle => 'Settings style',
        AppVisualTeam.ember => 'Ember',
        AppVisualTeam.nocturne => 'Nocturne',
      };

  TeamPalette get palette => switch (this) {
        AppVisualTeam.settingsStyle => TeamPalette.cyan,
        AppVisualTeam.ember => TeamPalette.ember,
        AppVisualTeam.nocturne => TeamPalette.nocturne,
      };
}

/// Persisted shell visual team (backdrop + chrome).
class TeamVisualStore extends ChangeNotifier {
  static const _kTeam = 'tvmatepro_visual_team_v1';

  var _loaded = false;
  AppVisualTeam _team = AppVisualTeam.settingsStyle;

  bool get isLoaded => _loaded;
  AppVisualTeam get team => _team;
  TeamPalette get palette => _team.palette;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _team = _teamFrom(prefs.getString(_kTeam));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setTeam(AppVisualTeam value) async {
    if (_team == value) return;
    _team = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTeam, value.storageValue);
    notifyListeners();
  }

  static AppVisualTeam _teamFrom(String? raw) => parseStorage(raw);

  /// Legacy stored keys (Cosmic, Canvas, etc.) map to [settingsStyle].
  static AppVisualTeam parseStorage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return AppVisualTeam.settingsStyle;
    }
    switch (raw) {
      case 'ember':
      case 'ember_field':
        return AppVisualTeam.ember;
      case 'nocturne':
      case 'daybreak': // legacy key (former light theme) → new dark Nocturne
        return AppVisualTeam.nocturne;
      case 'settings_style':
      case 'settingsStyle':
        return AppVisualTeam.settingsStyle;
      default:
        return AppVisualTeam.settingsStyle;
    }
  }
}

final TeamVisualStore teamVisualStore = TeamVisualStore();
