import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_grid_columns_store.dart';
import '../../data/live_tv_hero_layout_store.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';
import 'appearance_neon_focus_shell.dart';
import 'channel_grid_reference_layout.dart';
import 'vod_brushed_panel_fill.dart';

/// **Channel Grid Settings** card (reference layout — brushed panel, gold sliders).
class ChannelGridSettingsPanel extends StatelessWidget {
  const ChannelGridSettingsPanel({
    super.key,
    required this.onRequestHide,
    required this.section,
    required this.posterSubRow,
    required this.tooltipFor,
    required this.onExit,
    required this.onResetDefaults,
    this.hideRailSelected = false,
    this.nameAdjustArmed = false,
    required this.channelDisplayFocusIndex,
  });

  final VoidCallback onRequestHide;
  final bool hideRailSelected;
  final bool nameAdjustArmed;
  final int section;
  final int posterSubRow;
  final int channelDisplayFocusIndex;
  final String Function(LiveTvCardStyle s) tooltipFor;
  final VoidCallback onExit;
  final Future<void> Function() onResetDefaults;

  /// D-pad order (must match [LiveTvEditScreen] rail indices).
  static const int kSectionHide = 0;
  static const int kSectionHero = 1;
  static const int kSectionChannels = 2;
  static const int kSectionPoster = 3;
  static const int kSectionFooterExit = 4;
  static const int kSectionFooterReset = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = context.teamPalette;

    final cardBorder = Color.alphaBlend(
      shell.accent.withValues(alpha: 0.28),
      Colors.white.withValues(alpha: 0.22),
    );
    const outerRadius = 12.0;

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
                    ChannelGridReferenceHeader(
                      title: l10n.channelGridSettingsTitle,
                      hideLabel: l10n.movieGridHidePanel,
                      hideRailSelected: hideRailSelected,
                      onHide: onRequestHide,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ChannelGridGoldSliderBlock(
                            label: l10n.channelGridHeroBannerSize,
                            sectionIndex: kSectionHero,
                            selectedSection: section,
                            listenable: liveTvHeroLayoutStore,
                            levels: [
                              for (var v = LiveTvHeroLayoutStore
                                      .minHeightPercent;
                                  v <= LiveTvHeroLayoutStore.maxHeightPercent;
                                  v += LiveTvHeroLayoutStore.heightPercentStep)
                                v,
                            ],
                            currentValue: () =>
                                liveTvHeroLayoutStore.heroHeightPercent,
                            formatValue: (v) => '$v%',
                            formatTickLabel: (v) => '$v%',
                          ),
                          ChannelGridGoldSliderBlock(
                            label: l10n.channelGridChannelsPerRowLabel,
                            sectionIndex: kSectionChannels,
                            selectedSection: section,
                            listenable: liveTvGridColumnsStore,
                            levels: [
                              for (var v = LiveTvGridColumnsStore.minColumns;
                                  v <= LiveTvGridColumnsStore.maxColumns;
                                  v++)
                                v,
                            ],
                            currentValue: () => liveTvGridColumnsStore.columns,
                            formatValue: (v) => '$v',
                            formatTickLabel: (v) => '$v',
                          ),
                          ChannelGridDisplaySegmentRow(
                            title: l10n.channelGridChannelDisplay,
                            sectionIndex: kSectionPoster,
                            selectedSection: section,
                            posterSubRow: posterSubRow,
                            tooltipFor: tooltipFor,
                            channelDisplayFocusIndex:
                                channelDisplayFocusIndex,
                          ),
                          ChannelGridNameDpadRow(
                            title: l10n.channelGridChNamePosition,
                            sectionIndex: kSectionPoster,
                            selectedSection: section,
                            posterSubRow: posterSubRow,
                            nameAdjustArmed: nameAdjustArmed,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                      child: DecoratedBox(
                        decoration:
                            channelGridInsetDecoration(focused: false),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              Expanded(
                                child: FocusTraversalOrder(
                                  order: const NumericFocusOrder(8),
                                  child: _ChannelPanelFooterButton(
                                    icon: Icons.close_rounded,
                                    label: l10n.movieGridExit,
                                    railSelected:
                                        section == kSectionFooterExit,
                                    onActivate: onExit,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FocusTraversalOrder(
                                  order: const NumericFocusOrder(9),
                                  child: _ChannelPanelFooterButton(
                                    icon: Icons.refresh_rounded,
                                    label: l10n.movieGridResetDefaults,
                                    railSelected:
                                        section == kSectionFooterReset,
                                    onActivate: () {
                                      unawaited(onResetDefaults());
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
}

class _ChannelPanelFooterButton extends StatelessWidget {
  const _ChannelPanelFooterButton({
    required this.icon,
    required this.label,
    required this.onActivate,
    this.railSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onActivate;
  final bool railSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    return AppearanceNeonFocusShell(
      debugLabel: 'liveTvFooter',
      canRequestFocus: false,
      onActivate: onActivate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: railSelected ? TeamPalette.focusNeonPink : Colors.transparent,
            width: railSelected ? 2.5 : 0,
          ),
          boxShadow: railSelected
              ? [
                  BoxShadow(
                    color: TeamPalette.focusNeonPink.withValues(alpha: 0.28),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
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
      ),
    );
  }
}

/// [FittedBox] host + Hide/Show (same contract as [MovieGridSettingsPanelHost]).
class ChannelGridSettingsPanelHost extends StatefulWidget {
  const ChannelGridSettingsPanelHost({
    super.key,
    required this.designW,
    required this.targetW,
    required this.section,
    required this.posterSubRow,
    required this.tooltipFor,
    required this.onExit,
    required this.onResetDefaults,
    this.onPanelVisibilityChanged,
    this.nameAdjustArmed = false,
    required this.channelDisplayFocusIndex,
  });

  final double designW;
  final double targetW;
  final int section;
  final int posterSubRow;
  final int channelDisplayFocusIndex;
  final bool nameAdjustArmed;
  final String Function(LiveTvCardStyle s) tooltipFor;
  final VoidCallback onExit;
  final Future<void> Function() onResetDefaults;

  /// `true` when the full settings card is shown; `false` when only **Show** is visible.
  final ValueChanged<bool>? onPanelVisibilityChanged;

  @override
  State<ChannelGridSettingsPanelHost> createState() =>
      ChannelGridSettingsPanelHostState();
}

class ChannelGridSettingsPanelHostState
    extends State<ChannelGridSettingsPanelHost> {
  var _panelVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPanelVisibilityChanged?.call(_panelVisible);
    });
  }

  /// Collapse the panel to the **Show** chip (same as header **Hide**).
  void collapsePanel() {
    if (!_panelVisible) return;
    setState(() => _panelVisible = false);
    widget.onPanelVisibilityChanged?.call(false);
  }

  void _expandPanel() {
    setState(() => _panelVisible = true);
    widget.onPanelVisibilityChanged?.call(true);
  }

  /// Same as tapping the **Show** chip (e.g. when the rail [Focus] handles OK).
  void expandPanel() => _expandPanel();

  @override
  Widget build(BuildContext context) {
    if (!_panelVisible) {
      // Same width contract as the expanded [FittedBox] slot so [Row]/[Flexible]
      // in the chip get bounded constraints (avoids empty / failed layout in [Align]).
      return SizedBox(
        width: widget.targetW,
        child: Align(
          alignment: Alignment.topRight,
          child: _ChannelGridShowChip(
            key: const ValueKey<Object>('channelGridShowChip'),
            onShow: _expandPanel,
          ),
        ),
      );
    }
    return SizedBox(
      width: widget.targetW,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topRight,
        child: SizedBox(
          width: widget.designW,
          child: ChannelGridSettingsPanel(
            onRequestHide: () {
              setState(() => _panelVisible = false);
              widget.onPanelVisibilityChanged?.call(false);
            },
            hideRailSelected:
                widget.section == ChannelGridSettingsPanel.kSectionHide,
            nameAdjustArmed: widget.nameAdjustArmed,
            section: widget.section,
            posterSubRow: widget.posterSubRow,
            tooltipFor: widget.tooltipFor,
            onExit: widget.onExit,
            onResetDefaults: widget.onResetDefaults,
            channelDisplayFocusIndex: widget.channelDisplayFocusIndex,
          ),
        ),
      ),
    );
  }
}

class _ChannelGridShowChip extends StatelessWidget {
  const _ChannelGridShowChip({super.key, required this.onShow});

  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final shell = context.teamPalette;
    final neon = TeamPalette.focusNeonPink;
    return Material(
      type: MaterialType.transparency,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: AppearanceNeonFocusShell(
        debugLabel: 'liveTvShow',
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.settings_suggest_rounded,
                size: 22,
                color: neon.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l10n.channelGridShowSettingsPanel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.35,
                    color: Colors.white.withValues(alpha: 0.98),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
