import 'package:flutter/material.dart';

import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_name_vertical_bias_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import 'appearance_panel_chrome.dart';

String liveTvPosterLabel(AppLocalizations loc, LiveTvCardStyle s) => switch (s) {
      LiveTvCardStyle.nameOnly => loc.cardStyleLiveNameOnly,
      LiveTvCardStyle.logoNameEpg => loc.cardStyleLiveLogoNameProgram,
      LiveTvCardStyle.logoNameOnly => loc.cardStyleLiveLogoNameOnly,
      LiveTvCardStyle.logoOnly => loc.cardStyleLiveLogoOnly,
    };

IconData liveTvTileStyleIcon(LiveTvCardStyle s) => switch (s) {
      LiveTvCardStyle.nameOnly => Icons.title_rounded,
      LiveTvCardStyle.logoNameEpg => Icons.layers_outlined,
      LiveTvCardStyle.logoNameOnly => Icons.art_track_outlined,
      LiveTvCardStyle.logoOnly => Icons.image_outlined,
    };

/// Tiles row + optional name vertical strip (Live TV appearance).
class LiveTvPosterTileFrame extends StatelessWidget {
  const LiveTvPosterTileFrame({
    super.key,
    required this.sectionIndex,
    required this.selectedSection,
    required this.listenable,
    required this.posterSubRow,
    required this.tooltipFor,
    this.tilesTitle = 'Tiles',
  });

  final int sectionIndex;
  final int selectedSection;
  final Listenable listenable;
  final int posterSubRow;
  final String Function(LiveTvCardStyle s) tooltipFor;
  final String tilesTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final on = sectionIndex == selectedSection;
    final accent = shell.accent;
    const styles = LiveTvCardStyle.values;
    final nameRowOn = on && posterSubRow == 1;

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final current = liveTvCardStyleStore.style;
        final nameStep = liveTvNameVerticalBiasStore.step;
        final nameLevels = [
          for (var v = LiveTvNameVerticalBiasStore.minStep;
              v <= LiveTvNameVerticalBiasStore.maxStep;
              v++)
            v,
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration:
                appearanceSectionFrameDecoration(focused: on, shell: shell),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tilesTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.2,
                    color: on
                        ? Colors.white.withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                if (on) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      tooltipFor(current),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 7,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: on ? 2 : 1),
                Row(
                  children: [
                    for (final s in styles)
                      Expanded(
                        child: Center(
                          child: LiveTvStyleChip(
                            icon: liveTvTileStyleIcon(s),
                            tooltip: tooltipFor(s),
                            selected: s == current,
                            accent: accent,
                            dimmed: on && posterSubRow == 1,
                          ),
                        ),
                      ),
                  ],
                ),
                if (on) ...[
                  Text(
                    posterSubRow == 0
                        ? '◀  ▶  tile style'
                        : '◀  ▶  name height',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 6.5,
                      color: accent.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: nameRowOn
                          ? accent.withValues(alpha: 0.14)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: nameRowOn
                            ? accent.withValues(alpha: 0.45)
                            : Colors.white.withValues(alpha: 0.08),
                        width: nameRowOn ? 1.1 : 0.7,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Name',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: nameRowOn
                                ? Colors.white.withValues(alpha: 0.95)
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: SizedBox(
                            height: 14,
                            child: AppearanceVertTickStrip(
                              levels: nameLevels,
                              current: nameStep,
                              rangeFill: false,
                              accent: accent,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 14,
                          child: Text(
                            '$nameStep',
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Text(
                    '◀  ▶',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 7,
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LiveTvStyleChip extends StatelessWidget {
  const LiveTvStyleChip({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.accent,
    this.dimmed = false,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final Color accent;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final shell = context.teamPalette;
    final dim = dimmed ? 0.42 : 1.0;
    final baseA = selected ? 0.95 : 0.5;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      verticalOffset: 8,
      child: Semantics(
        label: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(2),
          decoration: appearanceIconChipDecoration(
            selected: selected,
            shell: shell,
            accent: accent,
          ),
          child: Icon(
            icon,
            size: 13,
            color: Colors.white.withValues(alpha: baseA * dim),
          ),
        ),
      ),
    );
  }
}

/// Horizontal tick strip + value (hero height %, channels per row).
class LiveTvSliderSection extends StatelessWidget {
  const LiveTvSliderSection({
    super.key,
    required this.label,
    required this.sectionIndex,
    required this.selectedSection,
    required this.listenable,
    required this.levels,
    required this.rangeFill,
    required this.currentValue,
    required this.formatValue,
    required this.subtitle,
    this.minHeight = 92,
  });

  final String label;
  final int sectionIndex;
  final int selectedSection;
  final Listenable listenable;
  final List<int> levels;
  final bool rangeFill;
  final int Function() currentValue;
  final String Function(int value) formatValue;
  final String subtitle;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final on = sectionIndex == selectedSection;
    final accent = shell.accent;

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final current = currentValue();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: appearanceSectionFrameDecoration(
              focused: on,
              shell: shell,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: SizedBox(
              height: minHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: on
                          ? Colors.white.withValues(alpha: 0.96)
                          : Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AppearanceVertTickStrip(
                            levels: levels,
                            current: current,
                            rangeFill: rangeFill,
                            accent: accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatValue(current),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                height: 1.05,
                                color: Colors.white.withValues(alpha: 0.96),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              subtitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 7,
                                color: Colors.white.withValues(alpha: 0.42),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '◀  ▶',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 7,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
