import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../focus/tv_focusable.dart';
import '../movies/movies_screen.dart';
import '../series/series_screen.dart';
import 'movie_grid_settings_panel.dart';
import 'player_settings_overlay_scope.dart';

enum MediaRailType { movies, series }

/// Appearance editor for Movies or Series: same **MovieGridSettingsPanelHost** as Movies
/// (posters per row, poster display modes, Hide/Show, Exit, Reset).
class MediaRailEditScreen extends StatelessWidget {
  const MediaRailEditScreen({
    super.key,
    required this.title,
    required this.mediaType,
  });

  final String title;
  final MediaRailType mediaType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMovies = mediaType == MediaRailType.movies;
    final panelTarget = isMovies
        ? MediaGridPanelTarget.movies
        : MediaGridPanelTarget.series;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final designW = math.min(460.0, constraints.maxWidth * 0.44);
          final targetW = designW * 0.65;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: playerSettingsRouteBackdrop(context),
              ),
              Positioned.fill(
                child: ExcludeFocus(
                  excluding: true,
                  child: isMovies
                      ? const MoviesScreen(previewMode: true)
                      : const SeriesScreen(previewMode: true),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Row(
                    children: [
                      TvFocusable(
                        focusPadding: const EdgeInsets.all(4),
                        onActivate: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              '$title · Appearance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: constraints.maxWidth * 0.02,
                top: constraints.maxHeight * 0.10,
                child: MovieGridSettingsPanelHost(
                  designW: designW,
                  targetW: targetW,
                  panelTarget: panelTarget,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
