import 'package:flutter/material.dart';

import '../../data/media_card_style_store.dart';
import '../../data/movie_vod_label_store.dart';
import '../focus/vod_live_tv_style_focus.dart';
import '../widgets/movie_watched_badge.dart';
import '../widgets/vod_imdb_rating_badge.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import '../windows/windows_desktop_scale.dart';
import 'mock_movies_data.dart';

const double kMoviePosterRailRadius = 13;

String moviePosterRailHiResUrl(String url) {
  final t = url.trim();
  if (catalogArtIsBundledAsset(t)) return t;
  if (!url.contains('image.tmdb.org/t/p/')) return url;
  return url.replaceFirstMapped(
    RegExp(r'/t/p/[^/]+/'),
    (_) => '/t/p/w780/',
  );
}

class MoviePosterRailHiResImage extends StatelessWidget {
  const MoviePosterRailHiResImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const TvUniversalMediaPlaceholder();
    }
    if (catalogArtIsBundledAsset(trimmed)) {
      return Image.asset(
        trimmed,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const TvUniversalMediaPlaceholder(),
      );
    }
    return Image.network(
      trimmed,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const TvImageShimmer();
      },
      errorBuilder: (_, __, ___) => const TvUniversalMediaPlaceholder(),
    );
  }
}

class MoviePosterRailStrip extends StatelessWidget {
  const MoviePosterRailStrip({
    super.key,
    required this.railPageSize,
    required this.categoryLabel,
    required this.movies,
    required this.waveStart,
    required this.posterWidth,
    required this.posterHeight,
    required this.gap,
    required this.slotFocusNodes,
    required this.onSlotKey,
    required this.onPosterFocused,
    required this.onMovieActivate,
  });

  final int railPageSize;
  final String categoryLabel;
  final List<MockMovie> movies;
  final int waveStart;
  final double posterWidth;
  final double posterHeight;
  final double gap;
  final List<FocusNode> slotFocusNodes;
  final KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey;
  final void Function(MockMovie movie, int index) onPosterFocused;
  final Future<void> Function(MockMovie movie) onMovieActivate;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return Center(
        child: Text(
          'No titles in $categoryLabel',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var slot = 0; slot < railPageSize; slot++)
            Padding(
              padding: EdgeInsets.only(
                right: slot == railPageSize - 1 ? 0 : gap,
              ),
              child: SizedBox(
                width: posterWidth,
                height: posterHeight,
                child: _moviesRailSlot(
                  railPageSize: railPageSize,
                  slot: slot,
                  waveStart: waveStart,
                  movies: movies,
                  slotFocusNodes: slotFocusNodes,
                  onSlotKey: onSlotKey,
                  onPosterFocused: onPosterFocused,
                  onMovieActivate: onMovieActivate,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _moviesRailSlot({
  required int railPageSize,
  required int slot,
  required int waveStart,
  required List<MockMovie> movies,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(MockMovie movie, int index) onPosterFocused,
  required Future<void> Function(MockMovie movie) onMovieActivate,
}) {
  final gi = waveStart + slot;
  if (gi >= movies.length) {
    return const SizedBox.expand();
  }
  final m = movies[gi];
  return RepaintBoundary(
    child: MoviePosterTile(
      movie: m,
      focusNode: slotFocusNodes[slot],
      onFocusedChange: (has) {
        if (has) onPosterFocused(m, gi);
      },
      onKeyIntercept: (node, ev) => onSlotKey(slot, node, ev),
      onActivate: () => onMovieActivate(m),
    ),
  );
}

class MoviePosterTile extends StatelessWidget {
  const MoviePosterTile({
    super.key,
    required this.movie,
    required this.onFocusedChange,
    required this.onKeyIntercept,
    required this.onActivate,
    required this.focusNode,
  });

  final MockMovie movie;
  final ValueChanged<bool> onFocusedChange;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onKeyIntercept;
  final VoidCallback onActivate;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posterUrl = moviePosterRailHiResUrl(moviePosterUrl(movie));
    final style = mediaCardStyleStore.movieStyle;
    final ratingText = movie.rating?.trim();

    return ListenableBuilder(
      listenable: MovieVodLabelStore.instance,
      builder: (context, _) {
        final lab = MovieVodLabelStore.instance.labelFor(movie.id);
        Widget? cornerBadge;
        if (lab == MovieVodLabel.watched) {
          cornerBadge = const MovieWatchedCornerBadge();
        } else if (lab == MovieVodLabel.continueWatching) {
          cornerBadge = const MovieContinueWatchingCornerBadge();
        } else if (lab == MovieVodLabel.watching) {
          cornerBadge = const MovieWatchingCornerBadge();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final pm = WindowsPosterTextMetrics(constraints.maxWidth);
            return VodLiveTvStyleFocus(
              focusNode: focusNode,
              borderRadius: kMoviePosterRailRadius,
              onFocusedChange: onFocusedChange,
              onKeyIntercept: onKeyIntercept,
              onActivate: onActivate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(kMoviePosterRailRadius),
                      color: const Color(0xFF131822),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(kMoviePosterRailRadius),
                      child: switch (style) {
                        MediaPosterCardStyle.posterAndTitle => Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: MoviePosterRailHiResImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.68),
                                    ],
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: pm.overlayPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        fontSize: pm.titleFont,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: pm.titleShadows,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${movie.year} · ${movie.duration}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                        fontSize: pm.metaFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        MediaPosterCardStyle.posterAndName => Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: MoviePosterRailHiResImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.68),
                                    ],
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: pm.overlayPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Spacer(),
                                    Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        fontSize: pm.titleFont,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: pm.titleShadows,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        MediaPosterCardStyle.posterOnly => Padding(
                            padding: EdgeInsets.all(pm.posterOnlyOuterPad),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(10 * pm.scale),
                                color: Colors.black.withOpacity(0.22),
                                border: Border.all(
                                    color:
                                        Colors.white.withOpacity(0.12)),
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(10 * pm.scale),
                                child: MoviePosterRailHiResImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        MediaPosterCardStyle.titleOnly => DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.06),
                                  Colors.black.withOpacity(0.2),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: pm.horizontalTitleOnlyPad),
                                child: Text(
                                  movie.title,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontSize: pm.titleOnlyFont,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      },
                    ),
                  ),
                  if (ratingText != null && ratingText.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 2,
                      child: IgnorePointer(
                        child: VodImdbRatingBadge(
                          rating: ratingText,
                          size: VodImdbRatingBadgeSize.poster,
                        ),
                      ),
                    ),
                  if (cornerBadge != null)
                    Positioned(
                      left: pm.badgeLeft,
                      bottom: pm.badgeBottom,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: cornerBadge,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
