import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';

/// Bottom strip for episode poster tiles: season/episode label only (e.g. S02E01).
/// Use on any catalog episode card for a consistent look.
class EpisodeSeasonCaptionBar extends StatelessWidget {
  const EpisodeSeasonCaptionBar({
    super.key,
    required this.label,
    this.height = 40,
  });

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.0),
              Colors.black.withOpacity(0.62),
              const Color(0xF5000000),
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
          border: Border(
            top: BorderSide(
              color: p.accent.withOpacity(0.5),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white.withOpacity(0.96),
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                fontSize: 13,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
