import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';
import 'mock_movies_data.dart';

const Duration kMovieBrowseHeroMotion = Duration(milliseconds: 320);
const Curve kMovieBrowseHeroMotionCurve = Curves.easeOutCubic;

String movieBrowseHeroMetaLine(MockMovie m) {
  return '${m.year} · ${m.duration} · ${m.genre}';
}

/// Display-only hero info for Movies browse — not focusable.
class MovieBrowseHeroCard extends StatelessWidget {
  const MovieBrowseHeroCard({
    super.key,
    required this.listenable,
  });

  final ValueListenable<MockMovie> listenable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.expand(
      child: ValueListenableBuilder<MockMovie>(
        valueListenable: listenable,
        builder: (context, movie, _) {
          return AnimatedSwitcher(
            duration: kMovieBrowseHeroMotion,
            switchInCurve: kMovieBrowseHeroMotionCurve,
            switchOutCurve: kMovieBrowseHeroMotionCurve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Align(
              key: ValueKey(movie.id),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.46,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      movie.title,
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
                              if (movie.year > 0) '${movie.year}',
                              if (movie.duration.isNotEmpty) movie.duration,
                              if (movie.genre.isNotEmpty) movie.genre,
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
                    if (movie.cast != null &&
                        movie.cast!.isNotEmpty) ...[
                      _HeroMetaLine(
                        label: 'Cast:',
                        value: movie.cast!,
                        theme: theme,
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (movie.director != null &&
                        movie.director!.isNotEmpty) ...[
                      _HeroMetaLine(
                        label: 'Director:',
                        value: movie.director!,
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Flexible(
                      child: Text(
                        movie.description,
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

class _HeroMetaLine extends StatelessWidget {
  const _HeroMetaLine({
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
