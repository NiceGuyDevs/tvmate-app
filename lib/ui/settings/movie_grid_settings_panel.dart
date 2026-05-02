import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/media_card_style_store.dart';
import '../../data/movie_rail_page_size_store.dart';
import '../../data/series_rail_page_size_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../../theme/team_palette.dart';
import 'appearance_neon_focus_shell.dart';
import 'tv_remote_keys.dart';
import 'vod_brushed_panel_fill.dart';

/// Gold slider fill (not theme — reads as “track gold” on all teams).
const Color _kGold = Color(0xFFF0C040);
const Color _kPickGold = Color(0xFFFFD54F);
const Color _kPickGoldBorder = Color(0xFFE6B422);
const Color _kTrackMuted = Color(0xFF151820);

/// Same inset chrome as [VodSubtitleStylePanel] / [VodSubtitlePickerPanel] columns.
BoxDecoration _movieGridInsetDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
  );
}

/// Which browse rail the grid panel configures (**Movies** vs **Series**).
enum MediaGridPanelTarget { movies, series }

/// Left-docked **Movie / Series Grid Settings** card (browse appearance). Same layout for both.
class MovieGridSettingsPanel extends StatelessWidget {
  const MovieGridSettingsPanel({
    super.key,
    required this.onRequestHide,
    this.panelTarget = MediaGridPanelTarget.movies,
  });

  /// Collapses the card (parent shows [MovieGridSettingsPanelHost]’s Show control only).
  final VoidCallback onRequestHide;

  /// [MediaGridPanelTarget.movies] — [movieRailPageSizeStore] + [MediaCardStyleStore.movieStyle].
  /// [MediaGridPanelTarget.series] — [seriesRailPageSizeStore] + [MediaCardStyleStore.seriesStyle].
  final MediaGridPanelTarget panelTarget;

  static const _movieModes = <MediaPosterCardStyle>[
    MediaPosterCardStyle.posterOnly,
    MediaPosterCardStyle.posterAndName,
    MediaPosterCardStyle.posterAndTitle,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final isSeries = panelTarget == MediaGridPanelTarget.series;
    final settingsTitle = isSeries
        ? l10n.seriesGridSettingsTitle
        : l10n.movieGridSettingsTitle;
    final perRowLabel =
        isSeries ? l10n.seriesGridSeriesPerRow : l10n.movieGridMoviesPerRow;

    final cardBorder = Color.alphaBlend(
      shell.accent.withValues(alpha: 0.28),
      Colors.white.withValues(alpha: 0.22),
    );
    const outerRadius = 12.0;

    // Avoid M3 Material tint reading as a white sheet behind the card on TV.
    return Material(
      type: MaterialType.transparency,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
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
              alignment: Alignment.topCenter,
              children: [
                const Positioned.fill(child: VodBrushedPanelFill()),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: cardBorder, width: 1),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settingsTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: Colors.white.withValues(alpha: 0.96),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: AppearanceNeonFocusShell(
                        debugLabel: 'movieGridHide',
                        onActivate: onRequestHide,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 72,
                            minHeight: 40,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.52),
                                Colors.black.withValues(alpha: 0.3),
                              ],
                            ),
                            border: Border.all(
                              color: TeamPalette.focusNeonPink.withValues(alpha: 0.5),
                              width: 1.35,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.movieGridHidePanel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.35,
                              color: Colors.white.withValues(alpha: 0.98),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    isSeries ? seriesRailPageSizeStore : movieRailPageSizeStore,
                    mediaCardStyleStore,
                  ]),
                  builder: (context, _) {
                    final size = isSeries
                        ? seriesRailPageSizeStore.size
                        : movieRailPageSizeStore.size;
                    final selectedStyle = isSeries
                        ? mediaCardStyleStore.seriesStyle
                        : mediaCardStyleStore.movieStyle;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DecoratedBox(
                          decoration: _movieGridInsetDecoration(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  perRowLabel,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color.fromRGBO(255, 255, 255, 0.72),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(2),
                                  child: _MoviesPerRowSliderRow(
                                    value: size,
                                    panelTarget: panelTarget,
                                    autofocus: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: _movieGridInsetDecoration(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.movieGridPosterDisplay,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color.fromRGBO(255, 255, 255, 0.72),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    for (var i = 0;
                                        i < _movieModes.length;
                                        i++) ...[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: FocusTraversalOrder(
                                          order: NumericFocusOrder(
                                              3 + i.toDouble()),
                                          child: _PosterModeChip(
                                            label: _labelFor(
                                                l10n, _movieModes[i]),
                                            selected: selectedStyle ==
                                                _movieModes[i],
                                            onSelect: () => unawaited(
                                              isSeries
                                                  ? mediaCardStyleStore
                                                      .setSeriesStyle(
                                                      _movieModes[i],
                                                    )
                                                  : mediaCardStyleStore
                                                      .setMovieStyle(
                                                      _movieModes[i],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: DecoratedBox(
                  decoration: _movieGridInsetDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(6),
                            child: _FooterButton(
                              icon: Icons.close_rounded,
                              label: l10n.movieGridExit,
                              onActivate: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(7),
                            child: _FooterButton(
                              icon: Icons.refresh_rounded,
                              label: l10n.movieGridResetDefaults,
                              onActivate: () {
                                if (isSeries) {
                                  unawaited(
                                    seriesRailPageSizeStore.setSize(
                                      SeriesRailPageSizeStore.defaultSize,
                                    ),
                                  );
                                  unawaited(
                                    mediaCardStyleStore.setSeriesStyle(
                                      MediaPosterCardStyle.posterAndTitle,
                                    ),
                                  );
                                } else {
                                  unawaited(
                                    movieRailPageSizeStore.setSize(
                                      MovieRailPageSizeStore.defaultSize,
                                    ),
                                  );
                                  unawaited(
                                    mediaCardStyleStore.setMovieStyle(
                                      MediaPosterCardStyle.posterAndName,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _labelFor(AppLocalizations l10n, MediaPosterCardStyle s) {
    return switch (s) {
      MediaPosterCardStyle.posterOnly => l10n.cardStylePosterOnly,
      MediaPosterCardStyle.posterAndName => l10n.cardStyleNamePoster,
      MediaPosterCardStyle.posterAndTitle => l10n.cardStylePosterTitle,
      MediaPosterCardStyle.titleOnly => l10n.cardStyleTitleOnly,
    };
  }
}

/// Same [FittedBox] / size contract as before; toggles between the full card and a lone Show chip.
class MovieGridSettingsPanelHost extends StatefulWidget {
  const MovieGridSettingsPanelHost({
    super.key,
    required this.designW,
    required this.targetW,
    this.panelTarget = MediaGridPanelTarget.movies,
  });

  final double designW;
  final double targetW;
  final MediaGridPanelTarget panelTarget;

  @override
  State<MovieGridSettingsPanelHost> createState() =>
      _MovieGridSettingsPanelHostState();
}

class _MovieGridSettingsPanelHostState extends State<MovieGridSettingsPanelHost> {
  var _panelVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_panelVisible) {
      return _MovieGridShowPanelChip(
        onShow: () => setState(() => _panelVisible = true),
      );
    }
    return SizedBox(
      width: widget.targetW,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: widget.designW,
          child: MovieGridSettingsPanel(
            onRequestHide: () => setState(() => _panelVisible = false),
            panelTarget: widget.panelTarget,
          ),
        ),
      ),
    );
  }
}

class _MovieGridShowPanelChip extends StatelessWidget {
  const _MovieGridShowPanelChip({required this.onShow});

  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final shell = context.teamPalette;
    final neon = TeamPalette.focusNeonPink;
    return Material(
      type: MaterialType.transparency,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: AppearanceNeonFocusShell(
        debugLabel: 'movieGridShow',
        autofocus: true,
        onActivate: onShow,
        child: Container(
          constraints: const BoxConstraints(minWidth: 120, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  shell.accent.withValues(alpha: 0.14),
                  const Color(0xFF2a303c),
                ),
                const Color(0xFF1e222a),
              ],
            ),
            border: Border.all(
              color: neon.withValues(alpha: 0.82),
              width: 2.25,
            ),
            boxShadow: [
              BoxShadow(
                color: neon.withValues(alpha: 0.38),
                blurRadius: 22,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.58),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            l10n.movieGridShowPanel,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.4,
              color: Colors.white.withValues(alpha: 0.98),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoviesPerRowSliderRow extends StatelessWidget {
  const _MoviesPerRowSliderRow({
    required this.value,
    required this.panelTarget,
    this.autofocus = false,
  });

  final int value;
  final MediaGridPanelTarget panelTarget;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: AppearanceNeonFocusShell(
            debugLabel: 'movieGridMoviesPerRow',
            autofocus: autofocus,
            onKeyIntercept: (node, event) {
              if (tvRemoteIsDpadLeft(event)) {
                unawaited(
                  panelTarget == MediaGridPanelTarget.series
                      ? seriesRailPageSizeStore.adjustSize(-1)
                      : movieRailPageSizeStore.adjustSize(-1),
                );
                return KeyEventResult.handled;
              }
              if (tvRemoteIsDpadRight(event)) {
                unawaited(
                  panelTarget == MediaGridPanelTarget.series
                      ? seriesRailPageSizeStore.adjustSize(1)
                      : movieRailPageSizeStore.adjustSize(1),
                );
                return KeyEventResult.handled;
              }
              return null;
            },
            onActivate: () {},
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final minV = (panelTarget == MediaGridPanelTarget.series
                        ? SeriesRailPageSizeStore.minSize
                        : MovieRailPageSizeStore.minSize)
                    .toDouble();
                final maxV = (panelTarget == MediaGridPanelTarget.series
                        ? SeriesRailPageSizeStore.maxSize
                        : MovieRailPageSizeStore.maxSize)
                    .toDouble();
                final t = (value - minV) / (maxV - minV);
                final thumb = 14.0;
                final travel = math.max(0.0, w - thumb);
                final x = t * travel;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 22,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _kTrackMuted,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                width: math.max(0.0, w * t),
                                height: 6,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _kGold,
                                        _kGold.withValues(alpha: 0.85),
                                        Colors.white.withValues(alpha: 0.75),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: x.clamp(0.0, travel),
                            top: 4,
                            child: Container(
                              width: thumb,
                              height: thumb,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.25),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _TickScaleRow(panelTarget: panelTarget),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.0,
              color: Colors.white.withValues(alpha: 0.96),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _TickScaleRow extends StatelessWidget {
  const _TickScaleRow({required this.panelTarget});

  final MediaGridPanelTarget panelTarget;

  @override
  Widget build(BuildContext context) {
    final minS = panelTarget == MediaGridPanelTarget.series
        ? SeriesRailPageSizeStore.minSize
        : MovieRailPageSizeStore.minSize;
    final maxS = panelTarget == MediaGridPanelTarget.series
        ? SeriesRailPageSizeStore.maxSize
        : MovieRailPageSizeStore.maxSize;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var v = minS; v <= maxS; v++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                '$v',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.38),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterModeChip extends StatelessWidget {
  const _PosterModeChip({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppearanceNeonFocusShell(
      debugLabel: 'movieGridPosterMode',
      onActivate: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? _kPickGoldBorder
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? _kPickGold.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.035),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: Colors.white.withValues(alpha: selected ? 0.96 : 0.72),
                ),
              ),
            ),
            if (selected)
              Positioned(
                right: -2,
                bottom: -4,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: _kPickGold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onActivate,
  });

  final IconData icon;
  final String label;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppearanceNeonFocusShell(
      debugLabel: 'movieGridFooter',
      onActivate: onActivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
