import 'package:flutter/material.dart';

import '../../theme/team_palette_theme.dart';

/// Gradient “neon” rim (cyan → violet → cyan) + soft multi-color outer bloom.
class NeonGradientFrame extends StatelessWidget {
  const NeonGradientFrame({
    super.key,
    required this.borderRadius,
    required this.child,
    this.strokeWidth = 1.75,
    this.outerShadows,
  });

  final double borderRadius;
  final double strokeWidth;
  final Widget child;

  /// When null, uses [AppTheme.neonFrameVariedShadows].
  final List<BoxShadow>? outerShadows;

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    final outerR = borderRadius + strokeWidth;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: p.neonRimColors,
          stops: p.neonRimStops,
        ),
        boxShadow: outerShadows ?? p.neonFrameVariedShadows,
      ),
      padding: EdgeInsets.all(strokeWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
