import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../movies/mock_movies_data.dart';
import '../movies/movie_poster_rail.dart';
import '../series/mock_series_data.dart';
import '../series/series_poster_rail.dart';
import '../windows/windows_browse_rail_layout.dart';
import 'vod_unified_entry.dart';

/// Single rail row: mixed movie + series posters at full rail size.
class VodUnifiedPosterStrip extends StatelessWidget {
  const VodUnifiedPosterStrip({
    super.key,
    required this.railPageSize,
    required this.categoryLabel,
    required this.entries,
    required this.waveStart,
    required this.posterWidth,
    required this.posterHeight,
    required this.gap,
    required this.slotFocusNodes,
    required this.onSlotKey,
    required this.onPosterFocused,
    required this.onMovieActivate,
    required this.onSeriesActivate,
    this.slotStart = 0,
    this.slotEnd,
    this.clipTopHalfOfPoster = false,
    this.peekClipHeight,
  });

  final int railPageSize;
  final String categoryLabel;
  final List<VodUnifiedEntry> entries;
  final int waveStart;
  final double posterWidth;
  final double posterHeight;
  final double gap;
  final List<FocusNode> slotFocusNodes;
  final KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey;
  final void Function(VodUnifiedEntry entry, int index) onPosterFocused;
  final Future<void> Function(MockMovie m) onMovieActivate;
  final Future<void> Function(MockSeries s) onSeriesActivate;
  final int slotStart;
  final int? slotEnd;
  final bool clipTopHalfOfPoster;

  /// Windows two-row second line: override peek strip height (logical px).
  final double? peekClipHeight;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
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
              child: _unifiedSlotCell(
                railPageSize: railPageSize,
                slot: slot,
                waveStart: waveStart,
                entries: entries,
                slotFocusNodes: slotFocusNodes,
                onSlotKey: onSlotKey,
                onPosterFocused: onPosterFocused,
                onMovieActivate: onMovieActivate,
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

Widget _unifiedSlotCell({
  required int railPageSize,
  required int slot,
  required int waveStart,
  required List<VodUnifiedEntry> entries,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(VodUnifiedEntry entry, int index) onPosterFocused,
  required Future<void> Function(MockMovie m) onMovieActivate,
  required Future<void> Function(MockSeries s) onSeriesActivate,
  required double posterWidth,
  required double posterHeight,
  required bool clipTopHalfOfPoster,
  double? peekClipHeight,
}) {
  final tile = SizedBox(
    width: posterWidth,
    height: posterHeight,
    child: _unifiedSlot(
      railPageSize: railPageSize,
      slot: slot,
      waveStart: waveStart,
      entries: entries,
      slotFocusNodes: slotFocusNodes,
      onSlotKey: onSlotKey,
      onPosterFocused: onPosterFocused,
      onMovieActivate: onMovieActivate,
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

Widget _unifiedSlot({
  required int railPageSize,
  required int slot,
  required int waveStart,
  required List<VodUnifiedEntry> entries,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(VodUnifiedEntry entry, int index) onPosterFocused,
  required Future<void> Function(MockMovie m) onMovieActivate,
  required Future<void> Function(MockSeries s) onSeriesActivate,
  bool styleEmptyPeekSlot = false,
}) {
  final gi = waveStart + slot;
  if (gi >= entries.length) {
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
  final e = entries[gi];
  if (e.isMovie) {
    final m = e.movie!;
    return RepaintBoundary(
      child: MoviePosterTile(
        movie: m,
        focusNode: slotFocusNodes[slot],
        onFocusedChange: (has) {
          if (has) onPosterFocused(e, gi);
        },
        onKeyIntercept: (node, ev) => onSlotKey(slot, node, ev),
        onActivate: () => onMovieActivate(m),
      ),
    );
  }
  final s = e.series!;
  return RepaintBoundary(
    child: SeriesPosterTile(
      series: s,
      focusNode: slotFocusNodes[slot],
      onFocusedChange: (has) {
        if (has) onPosterFocused(e, gi);
      },
      onKeyIntercept: (node, ev) => onSlotKey(slot, node, ev),
      onActivate: () => onSeriesActivate(s),
    ),
  );
}
