import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/team_palette.dart';

/// Center-weighted radial “light behind” the content (shell top bar, category pills, tiles).
RadialGradient radialShellTabGlowGradient(
  TeamPalette chrome, {
  required bool selected,
  required bool focused,
}) {
  final Color c = chrome.accent;
  final Color m = Color.lerp(chrome.nebulaMagenta, chrome.accent, 0.45)!;

  if (!selected && !focused) {
    return const RadialGradient(
      center: Alignment.center,
      radius: 1,
      colors: [Colors.transparent, Colors.transparent],
    );
  }
  if (focused) {
    return RadialGradient(
      center: Alignment.center,
      radius: 1.18,
      colors: [
        c.withValues(alpha: selected ? 0.48 : 0.40),
        c.withValues(alpha: 0.17),
        m.withValues(alpha: 0.07),
        Colors.transparent,
      ],
      stops: const [0.0, 0.32, 0.56, 1.0],
    );
  }
  return RadialGradient(
    center: Alignment.center,
    radius: 1.02,
    colors: [
      c.withValues(alpha: 0.15),
      c.withValues(alpha: 0.055),
      m.withValues(alpha: 0.025),
      Colors.transparent,
    ],
    stops: const [0.0, 0.38, 0.62, 1.0],
  );
}

/// Radial bloom behind [child], matching shell top tabs. Additive with focus rings.
class RadialFocusGlow extends StatelessWidget {
  const RadialFocusGlow({
    super.key,
    required this.chrome,
    required this.selected,
    required this.focused,
    required this.child,
    this.glowPadding = const EdgeInsets.fromLTRB(-16, -8, -16, -8),
  });

  final TeamPalette chrome;
  final bool selected;
  final bool focused;
  final Widget child;

  /// Extra space for the gradient beyond [child] (negative = outward).
  final EdgeInsets glowPadding;

  @override
  Widget build(BuildContext context) {
    final g = radialShellTabGlowGradient(
      chrome,
      selected: selected,
      focused: focused,
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: glowPadding.left,
          right: glowPadding.right,
          top: glowPadding.top,
          bottom: glowPadding.bottom,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: AppTheme.focusAnimationDuration,
              curve: AppTheme.focusAnimationCurve,
              decoration: BoxDecoration(
                gradient: g,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
