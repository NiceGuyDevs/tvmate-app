import 'package:flutter/material.dart';

import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_hero_appearance_store.dart';
import '../../l10n/app_localizations.dart';
import '../../data/live_tv_grid_columns_store.dart';
import '../../data/live_tv_hero_layout_store.dart';
import '../../data/media_card_style_store.dart';
import '../../data/movie_rail_page_size_store.dart';
import '../../data/series_rail_page_size_store.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'hero_appearance_edit_screen.dart';
import 'live_tv_edit_screen.dart';
import 'media_rail_edit_screen.dart';
import 'player_settings_overlay_scope.dart';
import 'vod_brushed_panel_fill.dart';

/// Settings hub: **Appearance** — all layout + card style options on one page.
class EditSettingsScreen extends StatelessWidget {
  const EditSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fromPlayerOverlay =
        PlayerSettingsOverlayScope.isActiveContext(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          playerSettingsRouteBackdrop(context),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: fromPlayerOverlay
                  ? _EditSettingsVodChromeShell(
                      theme: theme,
                      l10n: l10n,
                      child: _AppearanceSettingsColumns(vodPickerChrome: true),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AppearanceHeader(theme: theme, l10n: l10n),
                        const SizedBox(height: 8),
                        const Expanded(
                          child: _AppearanceSettingsColumns(
                            vodPickerChrome: false,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brushed outer shell + inset columns — same language as [VodSubtitlePickerPanel]
/// when Appearance is opened from the player settings overlay.
class _EditSettingsVodChromeShell extends StatelessWidget {
  const _EditSettingsVodChromeShell({
    required this.theme,
    required this.l10n,
    required this.child,
  });

  final ThemeData theme;
  final AppLocalizations l10n;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = context.teamPalette;
    final cardBorder = Color.alphaBlend(
      shell.accent.withValues(alpha: 0.28),
      Colors.white.withValues(alpha: 0.22),
    );
    const outerRadius = 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(outerRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(outerRadius),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  const VodBrushedPanelFill(),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AppearanceHeader(theme: theme, l10n: l10n),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 6),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppearanceHeader extends StatelessWidget {
  const _AppearanceHeader({
    required this.theme,
    required this.l10n,
  });

  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TvFocusable(
          focusPadding: const EdgeInsets.all(4),
          onActivate: () => Navigator.of(context).pop(),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.navAppearance,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _AppearanceSettingsColumns extends StatelessWidget {
  const _AppearanceSettingsColumns({required this.vodPickerChrome});

  /// When true (player overlay): dual inset panels + VOD subtitle column labels.
  final bool vodPickerChrome;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        liveTvHeroLayoutStore,
        liveTvHeroAppearanceStore,
        liveTvGridColumnsStore,
        movieRailPageSizeStore,
        seriesRailPageSizeStore,
        liveTvCardStyleStore,
        mediaCardStyleStore,
      ]),
      builder: (context, _) {
        final loc = AppLocalizations.of(context)!;

        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionLabel(
              loc.appearanceLayoutEditors,
              vodPickerStyle: vodPickerChrome,
            ),
            const SizedBox(height: 4),
            _CompactEditorTile(
              autofocus: true,
              vodPickerStyle: vodPickerChrome,
              icon: Icons.live_tv_rounded,
              title: loc.navLiveTv,
              subtitle: loc.settingsAppearanceSubtitle(
                liveTvHeroLayoutStore.heroHeightPercent,
                liveTvGridColumnsStore.columns,
              ),
              onActivate: () => pushSettingsRoute<void>(
                context,
                (_) => const LiveTvEditScreen(),
              ),
            ),
            const SizedBox(height: 4),
            _CompactEditorTile(
              vodPickerStyle: vodPickerChrome,
              icon: Icons.wallpaper_rounded,
              title: loc.appearanceHeroBackgroundTitle,
              subtitle: loc.appearanceHeroBackgroundSubtitle,
              onActivate: () => pushSettingsRoute<void>(
                context,
                (_) => const HeroAppearanceEditScreen(),
              ),
            ),
            const SizedBox(height: 4),
            _CompactEditorTile(
              vodPickerStyle: vodPickerChrome,
              icon: Icons.movie_creation_outlined,
              title: loc.navMovies,
              subtitle: loc.appearancePerRowSubtitle(
                movieRailPageSizeStore.size,
              ),
              onActivate: () => pushSettingsRoute<void>(
                context,
                (_) => MediaRailEditScreen(
                  title: loc.navMovies,
                  mediaType: MediaRailType.movies,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _CompactEditorTile(
              vodPickerStyle: vodPickerChrome,
              icon: Icons.subscriptions_rounded,
              title: loc.navSeries,
              subtitle: loc.appearancePerRowSubtitle(
                seriesRailPageSizeStore.size,
              ),
              onActivate: () => pushSettingsRoute<void>(
                context,
                (_) => MediaRailEditScreen(
                  title: loc.navSeries,
                  mediaType: MediaRailType.series,
                ),
              ),
            ),
          ],
        );

        final rightColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardStyleSection<LiveTvCardStyle>(
              vodPickerStyle: vodPickerChrome,
              title: loc.appearanceChannelCardStyle,
              values: LiveTvCardStyle.values,
              selected: liveTvCardStyleStore.style,
              label: (s) => _liveTvCardStyleLabel(loc, s),
              onSelect: liveTvCardStyleStore.setStyle,
            ),
            const SizedBox(height: 8),
            _CardStyleSection<MediaPosterCardStyle>(
              vodPickerStyle: vodPickerChrome,
              title: loc.appearanceMovieCardStyle,
              values: MediaPosterCardStyle.values,
              selected: mediaCardStyleStore.movieStyle,
              label: (s) => _mediaPosterCardStyleLabel(loc, s),
              onSelect: mediaCardStyleStore.setMovieStyle,
            ),
            const SizedBox(height: 8),
            _CardStyleSection<MediaPosterCardStyle>(
              vodPickerStyle: vodPickerChrome,
              title: loc.appearanceSeriesCardStyle,
              values: MediaPosterCardStyle.values,
              selected: mediaCardStyleStore.seriesStyle,
              label: (s) => _mediaPosterCardStyleLabel(loc, s),
              onSelect: mediaCardStyleStore.setSeriesStyle,
            ),
          ],
        );

        if (!vodPickerChrome) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: leftColumn),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: rightColumn),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _VodInsetPanel(
                child: SingleChildScrollView(
                  child: leftColumn,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: _VodInsetPanel(
                child: SingleChildScrollView(
                  child: rightColumn,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Same inner chrome as [VodSubtitlePickerPanel] `_columnChrome`.
class _VodInsetPanel extends StatelessWidget {
  const _VodInsetPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
    this.text, {
    this.vodPickerStyle = false,
  });

  final String text;

  /// Matches [VodSubtitlePickerPanel] column headers.
  final bool vodPickerStyle;

  @override
  Widget build(BuildContext context) {
    if (vodPickerStyle) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color.fromRGBO(255, 255, 255, 0.72),
          letterSpacing: 0.6,
        ),
      );
    }
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 0.5,
          ),
    );
  }
}

class _CompactEditorTile extends StatelessWidget {
  const _CompactEditorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onActivate,
    this.autofocus = false,
    this.vodPickerStyle = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onActivate;
  final bool autofocus;

  /// Flat chip fill like unselected [VodSubtitlePickerPanel] lang rows.
  final bool vodPickerStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      autofocus: autofocus,
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(vodPickerStyle ? 6 : 10),
          gradient: vodPickerStyle
              ? null
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.white.withValues(alpha: 0.025),
                  ],
                ),
          color: vodPickerStyle
              ? Colors.white.withValues(alpha: 0.035)
              : null,
          border: Border.all(
            color: Colors.white.withValues(alpha: vodPickerStyle ? 0.1 : 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline radio-chip row for selecting a card style.
class _CardStyleSection<T> extends StatelessWidget {
  const _CardStyleSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.vodPickerStyle = false,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final Future<void> Function(T) onSelect;
  final bool vodPickerStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionLabel(title, vodPickerStyle: vodPickerStyle),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: TvFocusable(
                  onActivate: () => onSelect(values[i]),
                  focusPadding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: _StyleChip(
                    label: label(values[i]),
                    isSelected: values[i] == selected,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Solid blue selected state — matches TV Appearance mockup (poster-style row).
const Color _kAppearanceChipSelectedFill = Color(0xFF1565C0);
const Color _kAppearanceChipSelectedBorder = Color(0xFF64B5F6);

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.isSelected,
  });

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isSelected
            ? _kAppearanceChipSelectedFill
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isSelected
              ? _kAppearanceChipSelectedBorder
              : Colors.white.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _kAppearanceChipSelectedBorder.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _liveTvCardStyleLabel(AppLocalizations l10n, LiveTvCardStyle s) =>
    switch (s) {
      LiveTvCardStyle.nameOnly => l10n.cardStyleLiveNameOnly,
      LiveTvCardStyle.logoNameEpg => l10n.cardStyleLiveLogoNameProgram,
      LiveTvCardStyle.logoNameOnly => l10n.cardStyleLiveLogoNameOnly,
      LiveTvCardStyle.logoOnly => l10n.cardStyleLiveLogoOnly,
    };

String _mediaPosterCardStyleLabel(
  AppLocalizations l10n,
  MediaPosterCardStyle s,
) =>
    switch (s) {
      MediaPosterCardStyle.posterAndTitle => l10n.cardStylePosterTitle,
      MediaPosterCardStyle.posterOnly => l10n.cardStylePosterOnly,
      MediaPosterCardStyle.posterAndName => l10n.cardStyleNamePoster,
      MediaPosterCardStyle.titleOnly => l10n.cardStyleTitleOnly,
    };
