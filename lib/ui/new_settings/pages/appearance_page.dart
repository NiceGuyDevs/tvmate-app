/// "Appearance" sub-page — ports `renderAppearancePage` + its four tab
/// body renderers from settings.html (lines 5252–5418).
///
/// Layout:
///
///   subpage-head  [  Appearance   .....   Reset section  ]
///   tab strip     [  LiveTV | HeroBg | Movies | Series   ]
///   body          [  launcher card for the active tab   ]
///
/// **Live TV** opens the full-screen [LiveTvEditScreen] route (same as legacy
/// settings), not an embedded preview.
///
/// **Hero background** opens the same full-screen [HeroAppearanceEditScreen]
/// as legacy settings (live [LiveTvScreen] preview + hero edit sheet).
///
/// **Movies** / **Series** open the same [MediaRailEditScreen] routes as
/// legacy settings (full-screen preview + grid settings panel).
///
/// The tab strip always shows; each section uses a launcher card (or opens
/// immediately when the tab is selected) for the full-screen editors above.
/// "Reset section" on the head resets the active tab's [NsApDefaults] fields.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/hero_appearance_edit_screen.dart';
import '../../settings/live_tv_edit_screen.dart';
import '../../settings/media_rail_edit_screen.dart';
import '../../settings/player_settings_overlay_scope.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_appearance_controls.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

void _openLiveTvEditor(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const LiveTvEditScreen(),
    ),
  );
}

void _openHeroBgEditor(BuildContext context) {
  unawaited(
    pushSettingsRoute<void>(
      context,
      (_) => const HeroAppearanceEditScreen(),
    ),
  );
}

void _openMediaRailEditor(BuildContext context, MediaRailType type) {
  final loc = AppLocalizations.of(context);
  unawaited(
    pushSettingsRoute<void>(
      context,
      (_) => MediaRailEditScreen(
        title: type == MediaRailType.movies ? loc.navMovies : loc.navSeries,
        mediaType: type,
      ),
    ),
  );
}

class NsAppearancePage extends StatelessWidget {
  const NsAppearancePage({
    super.key,
    required this.state,
    required this.onBack,
  });

  final NewSettingsState state;
  final VoidCallback onBack;

  String _metaFor(String tabId) {
    final a = state.appearance;
    return switch (tabId) {
      'liveTv' => 'Hero ${a.liveTvHero}% · ${a.liveTvCols} cols',
      'heroBg' =>
        '${nsApSwatchName(kNsApBgColors, a.heroBgBgColor) ?? 'Custom'} · ${a.heroBgWash == 'brush' ? 'Brush' : 'Solid'}',
      'movies' =>
        '${a.moviesPerRow} per row · ${kNsApMediaStyles.firstWhere((s) => s.id == a.moviesCardStyle, orElse: () => kNsApMediaStyles.first).label}',
      'series' =>
        '${a.seriesPerRow} per row · ${kNsApMediaStyles.firstWhere((s) => s.id == a.seriesCardStyle, orElse: () => kNsApMediaStyles.first).label}',
      _ => '',
    };
  }

  void _resetActiveTab() {
    state.setAppearance((a) {
      switch (a.activeTab) {
        case 'liveTv':
          a.liveTvHero = NsApDefaults.liveTvHero;
          a.liveTvCols = NsApDefaults.liveTvCols;
          a.liveTvCardStyle = NsApDefaults.liveTvCardStyle;
        case 'heroBg':
          a.heroBgGradient = NsApDefaults.heroBgGradient;
          a.heroBgBgColor = NsApDefaults.heroBgBgColor;
          a.heroBgWash = NsApDefaults.heroBgWash;
          a.heroBgOverlayColor = NsApDefaults.heroBgOverlayColor;
          a.heroBgBezel = NsApDefaults.heroBgBezel;
        case 'movies':
          a.moviesPerRow = NsApDefaults.mediaPerRow;
          a.moviesCardStyle = NsApDefaults.mediaCardStyle;
        case 'series':
          a.seriesPerRow = NsApDefaults.mediaPerRow;
          a.seriesCardStyle = NsApDefaults.mediaCardStyle;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        d.listHorizontalPadding,
        d.listTopPadding,
        d.listHorizontalPadding,
        d.listBottomPadding,
      ),
      children: [
        NsSubPageHead(
              title: 'Appearance',
              subtitle:
                  'Pick a section, then tune its layout & cards. The preview updates live.',
              onBack: onBack,
              actions: [
                _GhostButton(
                  icon: Icons.restore_rounded,
                  label: 'Reset section',
                  onPressed: _resetActiveTab,
                ),
              ],
            ),
            NsAppearanceTabStrip(
              tabs: kNsApTabs,
              selectedId: state.appearance.activeTab,
              metaFor: _metaFor,
              onPick: (id) {
                if (state.appearance.activeTab == id) {
                  if (id == 'liveTv') {
                    _openLiveTvEditor(context);
                    return;
                  }
                  if (id == 'heroBg') {
                    _openHeroBgEditor(context);
                    return;
                  }
                  if (id == 'movies') {
                    _openMediaRailEditor(context, MediaRailType.movies);
                    return;
                  }
                  if (id == 'series') {
                    _openMediaRailEditor(context, MediaRailType.series);
                    return;
                  }
                  return;
                }
                state.setAppearance((a) => a.activeTab = id);
                if (id == 'liveTv') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) _openLiveTvEditor(context);
                  });
                } else if (id == 'heroBg') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) _openHeroBgEditor(context);
                  });
                } else if (id == 'movies') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      _openMediaRailEditor(context, MediaRailType.movies);
                    }
                  });
                } else if (id == 'series') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      _openMediaRailEditor(context, MediaRailType.series);
                    }
                  });
                }
              },
            ),
            _TabBody(state: state),
          ],
    );
  }
}

// ─── Tab body dispatcher ────────────────────────────────────────────────

class _TabBody extends StatelessWidget {
  const _TabBody({required this.state});

  final NewSettingsState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.appearance.activeTab) {
      'liveTv' => const _LiveTvTabLauncher(),
      'heroBg' => const _HeroBgTabLauncher(),
      'movies' => const _MediaTabLauncher(isMovies: true),
      'series' => const _MediaTabLauncher(isMovies: false),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Live TV tab: full editor is a separate route — this card re-opens it or
/// explains the flow when the tab is already selected.
class _LiveTvTabLauncher extends StatelessWidget {
  const _LiveTvTabLauncher();

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsAppearanceCard(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          d.isCompact ? 12 : 16,
          16,
          d.isCompact ? 12 : 16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Live TV appearance',
              style: NsType.rowTitle.copyWith(
                fontSize: d.isCompact ? 12 : 14,
              ),
            ),
            SizedBox(height: d.isCompact ? 6 : 8),
            Text(
              'Opens the full-screen editor with the real Live TV preview and '
              'channel grid panel. Use Back when you are done to return to '
              'Appearance.',
              style: NsType.rowSub.copyWith(
                fontSize: d.isCompact ? 10.5 : 12,
              ),
            ),
            SizedBox(height: d.isCompact ? 12 : 16),
            NsFocusable(
              onActivate: () => _openLiveTvEditor(context),
              builder: (context, focused) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: d.isCompact ? 12 : 16,
                    vertical: d.isCompact ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: focused ? NsColors.surface2 : NsColors.bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused ? NsColors.accent : NsColors.line,
                      width: focused ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        size: d.isCompact ? 20 : 22,
                        color: NsColors.text2,
                      ),
                      SizedBox(width: d.isCompact ? 10 : 12),
                      Expanded(
                        child: Text(
                          'Open full-screen editor',
                          style: NsType.rowTitle.copyWith(
                            fontSize: d.isCompact ? 12.5 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero background tab: same route as legacy — [HeroAppearanceEditScreen].
class _HeroBgTabLauncher extends StatelessWidget {
  const _HeroBgTabLauncher();

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsAppearanceCard(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          d.isCompact ? 12 : 16,
          16,
          d.isCompact ? 12 : 16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hero background',
              style: NsType.rowTitle.copyWith(
                fontSize: d.isCompact ? 12 : 14,
              ),
            ),
            SizedBox(height: d.isCompact ? 6 : 8),
            Text(
              'Opens the same full-screen hero editor as classic Settings: '
              'live TV preview with the hero background edit plate. Use Back '
              'when you are done to return to Appearance.',
              style: NsType.rowSub.copyWith(
                fontSize: d.isCompact ? 10.5 : 12,
              ),
            ),
            SizedBox(height: d.isCompact ? 12 : 16),
            NsFocusable(
              onActivate: () => _openHeroBgEditor(context),
              builder: (context, focused) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: d.isCompact ? 12 : 16,
                    vertical: d.isCompact ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: focused ? NsColors.surface2 : NsColors.bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused ? NsColors.accent : NsColors.line,
                      width: focused ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        size: d.isCompact ? 20 : 22,
                        color: NsColors.text2,
                      ),
                      SizedBox(width: d.isCompact ? 10 : 12),
                      Expanded(
                        child: Text(
                          'Open full-screen editor',
                          style: NsType.rowTitle.copyWith(
                            fontSize: d.isCompact ? 12.5 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Movies or Series: same [MediaRailEditScreen] as legacy settings.
class _MediaTabLauncher extends StatelessWidget {
  const _MediaTabLauncher({required this.isMovies});

  final bool isMovies;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final loc = AppLocalizations.of(context);
    final title = isMovies ? loc.navMovies : loc.navSeries;
    return NsAppearanceCard(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          d.isCompact ? 12 : 16,
          16,
          d.isCompact ? 12 : 16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: NsType.rowTitle.copyWith(
                fontSize: d.isCompact ? 12 : 14,
              ),
            ),
            SizedBox(height: d.isCompact ? 6 : 8),
            Text(
              isMovies
                  ? 'Opens the same full-screen Movies editor as classic Settings: '
                      'browse preview with posters-per-row and poster display. '
                      'Use Back when you are done to return to Appearance.'
                  : 'Opens the same full-screen Series editor as classic Settings: '
                      'browse preview with posters-per-row and poster display. '
                      'Use Back when you are done to return to Appearance.',
              style: NsType.rowSub.copyWith(
                fontSize: d.isCompact ? 10.5 : 12,
              ),
            ),
            SizedBox(height: d.isCompact ? 12 : 16),
            NsFocusable(
              onActivate: () => _openMediaRailEditor(
                context,
                isMovies ? MediaRailType.movies : MediaRailType.series,
              ),
              builder: (context, focused) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: d.isCompact ? 12 : 16,
                    vertical: d.isCompact ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: focused ? NsColors.surface2 : NsColors.bg2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused ? NsColors.accent : NsColors.line,
                      width: focused ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.open_in_full_rounded,
                        size: d.isCompact ? 20 : 22,
                        color: NsColors.text2,
                      ),
                      SizedBox(width: d.isCompact ? 10 : 12),
                      Expanded(
                        child: Text(
                          'Open full-screen editor',
                          style: NsType.rowTitle.copyWith(
                            fontSize: d.isCompact ? 12.5 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared bits ────────────────────────────────────────────────────────

/// Ghost-style button used for the "Reset section" head action. Ports
/// `.btn.ghost` at settings.html lines 405–406.
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface : Colors.transparent,
          border: Border.all(
            color: focused ? NsColors.line : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: focused ? NsColors.text : NsColors.text2,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: focused ? NsColors.text : NsColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
