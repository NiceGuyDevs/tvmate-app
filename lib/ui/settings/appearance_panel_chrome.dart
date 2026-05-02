import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';

/// Dark dock behind bottom appearance controls (Live TV, Movies/Series rail).
BoxDecoration appearanceBottomBarDecoration(TeamPalette shell) {
  final base = Color.lerp(Colors.black, shell.surface, 0.42)!;
  return BoxDecoration(
    color: base.withValues(alpha: 0.9),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
    ),
    border: Border.all(
      color: Color.alphaBlend(
        shell.accent.withValues(alpha: 0.28),
        Colors.white.withValues(alpha: 0.16),
      ),
    ),
  );
}

/// One “cube” in the bar: always visible frame; stronger when [focused].
BoxDecoration appearanceSectionFrameDecoration({
  required bool focused,
  required TeamPalette shell,
}) {
  final softBorder = Color.alphaBlend(
    shell.accent.withValues(alpha: 0.22),
    Colors.white.withValues(alpha: 0.28),
  );
  return BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: Border.all(
      color: focused ? shell.accent.withValues(alpha: 0.94) : softBorder,
      width: focused ? 2.35 : 1.12,
    ),
    color: focused
        ? Color.alphaBlend(
            shell.accent.withValues(alpha: 0.2),
            shell.surface.withValues(alpha: 0.14),
          )
        : Color.alphaBlend(
            shell.surface.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0.06),
          ),
  );
}

/// Tile-style icon chip (Live TV tiles row): light, theme-tinted.
BoxDecoration appearanceIconChipDecoration({
  required bool selected,
  required TeamPalette shell,
  required Color accent,
}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(5),
    color: selected
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.32),
            shell.surface.withValues(alpha: 0.15),
          )
        : Color.alphaBlend(
            shell.surface.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.04),
          ),
    border: Border.all(
      color: selected
          ? accent.withValues(alpha: 0.62)
          : Color.alphaBlend(
              shell.accent.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.13),
            ),
    ),
  );
}

/// Vertical ticks spread across the track width (appearance sliders).
class AppearanceVertTickStrip extends StatelessWidget {
  const AppearanceVertTickStrip({
    super.key,
    required this.levels,
    required this.current,
    required this.rangeFill,
    required this.accent,
  });

  final List<int> levels;
  final int current;
  final bool rangeFill;
  final Color accent;

  bool _tickLit(int level, int c) {
    if (rangeFill) return level <= c;
    return level == c;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < levels.length; i++)
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AppearanceVertTick(
                lit: _tickLit(levels[i], current),
                accent: accent,
              ),
            ),
          ),
      ],
    );
  }
}

class AppearanceVertTick extends StatelessWidget {
  const AppearanceVertTick({
    super.key,
    required this.lit,
    required this.accent,
  });

  final bool lit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 1.2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        width: 2.5,
        height: 14,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: lit
              ? accent.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.14),
          border: Border.all(
            color: lit
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.transparent,
            width: lit ? 0.4 : 0,
          ),
        ),
      ),
    );
  }
}
