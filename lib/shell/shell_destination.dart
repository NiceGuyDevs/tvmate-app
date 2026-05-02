import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// All possible top-bar entries. The first five are "fixed" (always shown);
/// the rest are "optional" (shown only when enabled in Top Menu Manager).
/// [newSettings] is the main **Settings** top-menu tab. The legacy
/// [settings] body still exists for in-app routes (e.g. “Old settings” in
/// the new settings rail) but is not shown as its own top-bar entry.
enum ShellDestination {
  // ── fixed (always in top menu) ──
  liveTv,
  movies,
  series,
  recording,

  // ── optional (can be added to top menu from settings) ──
  playlist,
  team,
  clock,
  appearance,
  backup,
  favorites,
  language,

  // ── pinned last (only the main Settings tab) ──
  settings,
  newSettings,
}

extension ShellDestinationX on ShellDestination {
  /// Localized tab / menu label (built-in UI only).
  ///
  String labelL10n(AppLocalizations l10n) => switch (this) {
        ShellDestination.liveTv => l10n.navLiveTv,
        ShellDestination.movies => l10n.navMovies,
        ShellDestination.series => l10n.navSeries,
        ShellDestination.recording => l10n.navRecording,
        ShellDestination.playlist => l10n.navPlaylist,
        ShellDestination.team => l10n.navTheme,
        ShellDestination.clock => l10n.navClock,
        ShellDestination.appearance => l10n.navAppearance,
        ShellDestination.backup => l10n.navBackup,
        ShellDestination.favorites => l10n.navFavorites,
        ShellDestination.language => l10n.navLanguage,
        ShellDestination.settings => l10n.navSettings,
        ShellDestination.newSettings => l10n.navSettings,
      };

  IconData get icon => switch (this) {
        ShellDestination.liveTv => Icons.live_tv_rounded,
        ShellDestination.movies => Icons.movie_rounded,
        ShellDestination.series => Icons.video_library_rounded,
        ShellDestination.recording => Icons.fiber_smart_record_rounded,
        ShellDestination.playlist => Icons.playlist_play_rounded,
        ShellDestination.team => Icons.palette_rounded,
        ShellDestination.clock => Icons.schedule_rounded,
        ShellDestination.appearance => Icons.tune_rounded,
        ShellDestination.backup => Icons.cloud_download_rounded,
        ShellDestination.favorites => Icons.star_rounded,
        ShellDestination.language => Icons.language_rounded,
        ShellDestination.settings => Icons.settings_rounded,
        ShellDestination.newSettings => Icons.settings_rounded,
      };

  bool get isFixed => switch (this) {
        ShellDestination.liveTv ||
        ShellDestination.movies ||
        ShellDestination.series ||
        ShellDestination.recording =>
          true,
        _ => false,
      };

  bool get isOptional =>
      !isFixed &&
      this != ShellDestination.settings &&
      this != ShellDestination.newSettings;

  bool get hasOwnScreen => switch (this) {
        ShellDestination.liveTv ||
        ShellDestination.movies ||
        ShellDestination.series ||
        ShellDestination.recording ||
        ShellDestination.team ||
        ShellDestination.settings ||
        ShellDestination.newSettings =>
          true,
        _ => false,
      };
}
