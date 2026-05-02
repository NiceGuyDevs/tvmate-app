import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../data/media_card_style_store.dart';
import '../../data/movie_vod_label_store.dart';
import '../../data/series_vod_label_store.dart';
import '../focus/vod_live_tv_style_focus.dart';
import '../widgets/movie_watched_badge.dart';
import '../widgets/vod_imdb_rating_badge.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import '../windows/windows_browse_rail_layout.dart';
import '../windows/windows_desktop_scale.dart';
import 'mock_series_data.dart';

const double kSeriesPosterRailRadius = 13;

String seriesPosterRailHiResUrl(String url) {
  final t = url.trim();
  if (catalogArtIsBundledAsset(t)) return t;
  if (!url.contains('image.tmdb.org/t/p/')) return url;
  return url.replaceFirstMapped(
    RegExp(r'/t/p/[^/]+/'),
    (_) => '/t/p/w780/',
  );
}

class SeriesPosterRailHiResImage extends StatelessWidget {
  const SeriesPosterRailHiResImage({
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

class SeriesPosterRailStrip extends StatelessWidget {
  const SeriesPosterRailStrip({
    super.key,
    required this.railPageSize,
    required this.categoryLabel,
    required this.series,
    required this.waveStart,
    required this.posterWidth,
    required this.posterHeight,
    required this.gap,
    required this.slotFocusNodes,
    required this.onSlotKey,
    required this.onPosterFocused,
    required this.onSeriesActivate,
    this.slotStart = 0,
    this.slotEnd,
    this.clipTopHalfOfPoster = false,
    this.peekClipHeight,
  });

  final int railPageSize;
  final String categoryLabel;
  final List<MockSeries> series;
  final int waveStart;
  final double posterWidth;
  final double posterHeight;
  final double gap;
  final List<FocusNode> slotFocusNodes;
  final KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey;
  final void Function(MockSeries s, int index) onPosterFocused;
  final Future<void> Function(MockSeries s) onSeriesActivate;
  final int slotStart;
  final int? slotEnd;
  final bool clipTopHalfOfPoster;

  /// Windows two-row second line: peek strip height in logical px.
  final double? peekClipHeight;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Center(
        child: Text(
          'No titles in $categoryLabel',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final end = slotEnd ?? railPageSize;
    final rowMainAxis = clipTopHalfOfPoster &&
            (end - slotStart) < kWindowsBrowseFirstRowSlots
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: rowMainAxis,
        children: [
          for (var slot = slotStart; slot < end; slot++)
            Padding(
              padding: EdgeInsets.only(
                right: slot == end - 1 ? 0 : gap,
              ),
              child: _seriesRailSlotCell(
                railPageSize: railPageSize,
                slot: slot,
                waveStart: waveStart,
                series: series,
                slotFocusNodes: slotFocusNodes,
                onSlotKey: onSlotKey,
                onPosterFocused: onPosterFocused,
                onSeriesActivate: onSeriesActivate,
                posterWidth: posterWidth,
                posterHeight: posterHeight,
                clipTopHalfOfPoster: clipTopHalfOfPoster,
                peekClipHeight: peekClipHeight,
              ),
            ),
        ],
      ),
    );
  }
}

Widget _seriesRailSlotCell({
  required int railPageSize,
  required int slot,
  required int waveStart,
  required List<MockSeries> series,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(MockSeries s, int index) onPosterFocused,
  required Future<void> Function(MockSeries s) onSeriesActivate,
  required double posterWidth,
  required double posterHeight,
  required bool clipTopHalfOfPoster,
  double? peekClipHeight,
}) {
  final tile = SizedBox(
    width: posterWidth,
    height: posterHeight,
    child: _seriesRailSlot(
      railPageSize: railPageSize,
      slot: slot,
      waveStart: waveStart,
      series: series,
      slotFocusNodes: slotFocusNodes,
      onSlotKey: onSlotKey,
      onPosterFocused: onPosterFocused,
      onSeriesActivate: onSeriesActivate,
      styleEmptyPeekSlot: clipTopHalfOfPoster,
    ),
  );
  if (!clipTopHalfOfPoster) return tile;
  final clipH = peekClipHeight ??
      posterHeight * kWindowsBrowseSecondRowHeightFraction;
  return SizedBox(
    height: clipH,
    child: ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: tile,
      ),
    ),
  );
}

Widget _seriesRailSlot({
  required int railPageSize,
  required int slot,
  required int waveStart,
  required List<MockSeries> series,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(MockSeries s, int index) onPosterFocused,
  required Future<void> Function(MockSeries s) onSeriesActivate,
  bool styleEmptyPeekSlot = false,
}) {
  final gi = waveStart + slot;
  if (gi >= series.length) {
    if (Platform.isWindows && styleEmptyPeekSlot) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kSeriesPosterRailRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: const SizedBox.expand(),
      );
    }
    return const SizedBox.expand();
  }
  final s = series[gi];
  Widget tile = RepaintBoundary(
    child: SeriesPosterTile(
      series: s,
      focusNode: slotFocusNodes[slot],
      onFocusedChange: (has) {
        if (has) onPosterFocused(s, gi);
      },
      onKeyIntercept: (node, ev) => onSlotKey(slot, node, ev),
      onActivate: () => onSeriesActivate(s),
    ),
  );
  if (Platform.isWindows) {
    tile = MouseRegion(
      onEnter: (_) => onPosterFocused(s, gi),
      child: tile,
    );
  }
  return tile;
}

class SeriesPosterTile extends StatelessWidget {
  const SeriesPosterTile({
    super.key,
    required this.series,
    required this.onFocusedChange,
    required this.onKeyIntercept,
    required this.onActivate,
    required this.focusNode,
  });

  final MockSeries series;
  final ValueChanged<bool> onFocusedChange;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onKeyIntercept;
  final VoidCallback onActivate;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seasons = series.seasons.length;
    final posterUrl = seriesPosterRailHiResUrl(seriesPosterUrl(series));
    final style = mediaCardStyleStore.seriesStyle;
    final ratingText = series.rating?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final pm = WindowsPosterTextMetrics(constraints.maxWidth);
        return VodLiveTvStyleFocus(
          focusNode: focusNode,
          borderRadius: kSeriesPosterRailRadius,
          onFocusedChange: onFocusedChange,
          onKeyIntercept: onKeyIntercept,
          onActivate: onActivate,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(kSeriesPosterRailRadius),
                  color: const Color(0xFF131822),
                ),
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(kSeriesPosterRailRadius),
                  child: switch (style) {
                    MediaPosterCardStyle.posterAndTitle => Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: SeriesPosterRailHiResImage(
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
                                  series.title,
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
                                  '${series.year} · $seasons season${seasons == 1 ? '' : 's'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
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
                            child: SeriesPosterRailHiResImage(
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
                                  series.title,
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
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(10 * pm.scale),
                            child: SeriesPosterRailHiResImage(
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
                              series.title,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
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
              ListenableBuilder(
                listenable: SeriesVodLabelStore.instance,
                builder: (context, _) {
                  final lab =
                      SeriesVodLabelStore.instance.labelFor(series.id);
                  Widget? cornerBadge;
                  if (lab == MovieVodLabel.watched) {
                    cornerBadge = const MovieWatchedCornerBadge();
                  } else if (lab == MovieVodLabel.continueWatching) {
                    cornerBadge = const MovieContinueWatchingCornerBadge();
                  } else if (lab == MovieVodLabel.watching) {
                    cornerBadge = const MovieWatchingCornerBadge();
                  }
                  if (cornerBadge == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: pm.badgeLeft,
                    bottom: pm.badgeBottom,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: cornerBadge,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
