import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';
import 'mock_series_data.dart';

const Duration kSeriesBrowseHeroMotion = Duration(milliseconds: 320);
const Curve kSeriesBrowseHeroMotionCurve = Curves.easeOutCubic;

/// Display-only hero info for Series browse — not focusable.
class SeriesBrowseHeroCard extends StatelessWidget {
  const SeriesBrowseHeroCard({
    super.key,
    required this.listenable,
  });

  final ValueListenable<MockSeries> listenable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: ValueListenableBuilder<MockSeries>(
        valueListenable: listenable,
        builder: (context, s, _) {
          final n = s.seasons.length;

          return AnimatedSwitcher(
            duration: kSeriesBrowseHeroMotion,
            switchInCurve: kSeriesBrowseHeroMotionCurve,
            switchOutCurve: kSeriesBrowseHeroMotionCurve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Align(
              key: ValueKey(s.id),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.7),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              if (s.year > 0) '${s.year}',
                              if (s.genre.isNotEmpty) s.genre,
                              '$n season${n == 1 ? '' : 's'}',
                            ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: TeamPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (s.cast != null && s.cast!.isNotEmpty) ...[
                      _SeriesHeroMetaLine(
                        label: 'Cast:',
                        value: s.cast!,
                        theme: theme,
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (s.director != null &&
                        s.director!.isNotEmpty) ...[
                      _SeriesHeroMetaLine(
                        label: 'Director:',
                        value: s.director!,
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Flexible(
                      child: Text(
                        s.description,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.88),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SeriesHeroMetaLine extends StatelessWidget {
  const _SeriesHeroMetaLine({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: TeamPalette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          TextSpan(
            text: value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
