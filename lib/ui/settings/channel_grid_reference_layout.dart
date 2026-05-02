import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/live_tv_card_style_store.dart';
import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';

/// Reference mock: gold–orange slider fill (not team accent).
const Color _kGoldHi = Color(0xFFFFE082);
const Color _kGoldLo = Color(0xFFFF9100);
const Color _kTrackDeep = Color(0xFF12151A);
const Color _kPickGold = Color(0xFFFFD54F);
const Color _kPickGoldBorder = Color(0xFFE6B422);

/// Same inset chrome as [VodSubtitleStylePanel] / movie grid settings.
BoxDecoration channelGridInsetDecoration({required bool focused}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: focused
          ? _kPickGoldBorder.withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.12),
      width: focused ? 2 : 1,
    ),
    color: const Color(0xFF1A1A2E).withValues(alpha: 0.55),
  );
}

/// Section row titles — match subtitle / grid inset headers.
const TextStyle kChannelGridSectionLabelStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  color: Color.fromRGBO(255, 255, 255, 0.72),
  letterSpacing: 0.6,
);

/// Header: gear-in-circle + title + **Hide** (icon + label, reference style).
class ChannelGridReferenceHeader extends StatelessWidget {
  const ChannelGridReferenceHeader({
    super.key,
    required this.title,
    required this.hideLabel,
    required this.onHide,
    required this.hideRailSelected,
  });

  final String title;
  final String hideLabel;
  final VoidCallback onHide;
  final bool hideRailSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.settings_outlined,
              size: 18,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white.withValues(alpha: 0.96),
                letterSpacing: 0.15,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: hideRailSelected ? TeamPalette.focusNeonPink : Colors.transparent,
                width: hideRailSelected ? 2.5 : 0,
              ),
              boxShadow: hideRailSelected
                  ? [
                      BoxShadow(
                        color: TeamPalette.focusNeonPink.withValues(alpha: 0.28),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onHide,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 42),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_off_rounded,
                        size: 20,
                        color: const Color(0xFFFFD54F),
                        shadows: [
                          Shadow(
                            color:
                                const Color(0xFFFFC107).withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hideLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.35,
                          color: Colors.white.withValues(alpha: 0.98),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero / Channels rows: label + value, gold gradient track, white thumb, tick labels.
class ChannelGridGoldSliderBlock extends StatelessWidget {
  const ChannelGridGoldSliderBlock({
    super.key,
    required this.label,
    required this.sectionIndex,
    required this.selectedSection,
    required this.listenable,
    required this.levels,
    required this.currentValue,
    required this.formatValue,
    required this.formatTickLabel,
  });

  final String label;
  final int sectionIndex;
  final int selectedSection;
  final Listenable listenable;
  final List<int> levels;
  final int Function() currentValue;
  final String Function(int) formatValue;
  final String Function(int) formatTickLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = sectionIndex == selectedSection;

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final current = currentValue();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: channelGridInsetDecoration(focused: on),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: kChannelGridSectionLabelStyle,
                      ),
                    ),
                    Text(
                      formatValue(current),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 18.5,
                        color: Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final idx = levels.indexOf(current);
                    final safeIdx = idx < 0 ? 0 : idx;
                    final t = levels.length <= 1
                        ? 0.0
                        : safeIdx / (levels.length - 1);
                    const thumb = 15.0;
                    final travel = math.max(0.0, w - thumb);
                    final x = t * travel;
                    final fillW = (x + thumb / 2).clamp(0.0, w);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 32,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.centerLeft,
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _kTrackDeep,
                                    border: Border.all(
                                      color:
                                          Colors.black.withValues(alpha: 0.65),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                width: fillW,
                                top: 0,
                                bottom: 0,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    height: 8,
                                    margin: EdgeInsets.only(right: thumb / 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: const LinearGradient(
                                        colors: [_kGoldHi, _kGoldLo],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kGoldLo.withValues(
                                            alpha: 0.45,
                                          ),
                                          blurRadius: 10,
                                          spreadRadius: -1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: x,
                                top: 8,
                                child: Container(
                                  width: thumb,
                                  height: thumb,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFECEFF1),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final v in levels)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: Text(
                                    formatTickLabel(v),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(
                                        alpha: 0.38,
                                      ),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Four text segments: neon ring = D-pad focus; gold fill/border + check = committed style.
class ChannelGridDisplaySegmentRow extends StatelessWidget {
  const ChannelGridDisplaySegmentRow({
    super.key,
    required this.title,
    required this.sectionIndex,
    required this.selectedSection,
    required this.posterSubRow,
    required this.tooltipFor,
    /// D-pad focus in the 2×2 grid (0–3), only visual when this section row is active.
    required this.channelDisplayFocusIndex,
  });

  final String title;
  final int sectionIndex;
  final int selectedSection;
  final int posterSubRow;
  final String Function(LiveTvCardStyle s) tooltipFor;
  final int channelDisplayFocusIndex;

  @override
  Widget build(BuildContext context) {
    final on = sectionIndex == selectedSection && posterSubRow == 0;

    return ListenableBuilder(
      listenable: liveTvCardStyleStore,
      builder: (context, _) {
        final current = liveTvCardStyleStore.style;
        final fi = channelDisplayFocusIndex.clamp(0, 3);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: channelGridInsetDecoration(focused: on),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: kChannelGridSectionLabelStyle,
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < 2; i++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: _SegmentPill(
                                label: tooltipFor(
                                  kChannelGridDisplayStyleOrder[i],
                                ),
                                selected: current ==
                                    kChannelGridDisplayStyleOrder[i],
                                focused: on && fi == i,
                                dimmed: on && posterSubRow == 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 2; i < 4; i++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: _SegmentPill(
                                label: tooltipFor(
                                  kChannelGridDisplayStyleOrder[i],
                                ),
                                selected: current ==
                                    kChannelGridDisplayStyleOrder[i],
                                focused: on && fi == i,
                                dimmed: on && posterSubRow == 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    /// Saved choice (checkmark) — updated on OK, not on D-pad move.
    required this.selected,
    /// D-pad cursor in the 2×2 grid (neon ring).
    this.focused = false,
    required this.dimmed,
  });

  final String label;
  final bool selected;
  final bool focused;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final shell = context.teamPalette;
    final dim = dimmed ? 0.45 : 1.0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: dim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: focused ? const EdgeInsets.all(3) : EdgeInsets.zero,
        decoration: focused
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TeamPalette.focusNeonPink.withValues(alpha: 0.95),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: TeamPalette.focusNeonPink.withValues(alpha: 0.28),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ],
              )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: selected
                    ? _kPickGold.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.035),
                border: Border.all(
                  color: selected
                      ? _kPickGoldBorder
                      : Colors.white.withValues(alpha: 0.12),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14.5,
                        height: 1.18,
                        letterSpacing: 0.02,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: Colors.white.withValues(
                          alpha: selected ? 0.96 : 0.62,
                        ),
                      ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                right: -1,
                bottom: -2,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: const Color(0xFFFFD54F),
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// CH Name Position label + recessed D-pad (visual; D-pad handled by rail).
class ChannelGridNameDpadRow extends StatelessWidget {
  const ChannelGridNameDpadRow({
    super.key,
    required this.title,
    required this.sectionIndex,
    required this.selectedSection,
    required this.posterSubRow,
    required this.nameAdjustArmed,
  });

  final String title;
  final int sectionIndex;
  final int selectedSection;
  final int posterSubRow;
  final bool nameAdjustArmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = context.teamPalette;
    final on = sectionIndex == selectedSection && posterSubRow == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: channelGridInsetDecoration(focused: on),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: kChannelGridSectionLabelStyle,
                  ),
                ),
                _RecessedDpad(lit: on, adjustArmed: on && nameAdjustArmed),
              ],
            ),
            if (on) ...[
              const SizedBox(height: 4),
              Text(
                nameAdjustArmed
                    ? '▲ ▼ up/down · ◀ ▶ left/right · OK to exit'
                    : 'OK to move name (then all arrows)',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: TeamPalette.focusNeonPink.withValues(alpha: 0.88),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecessedDpad extends StatelessWidget {
  const _RecessedDpad({required this.lit, required this.adjustArmed});

  final bool lit;
  final bool adjustArmed;

  @override
  Widget build(BuildContext context) {
    final shell = context.teamPalette;
    final base = const Color(0xFF0d0f12);
    final hi = Colors.white.withValues(alpha: lit ? 0.14 : 0.1);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: adjustArmed ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: adjustArmed
              ? TeamPalette.focusNeonPink.withValues(alpha: 0.95)
              : Colors.transparent,
          width: adjustArmed ? 2.2 : 0,
        ),
        boxShadow: adjustArmed
            ? [
                BoxShadow(
                  color: TeamPalette.focusNeonPink.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Container(
        width: 86,
        height: 86,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(hi, base),
              base,
            ],
          ),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.65),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 0,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_left_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
