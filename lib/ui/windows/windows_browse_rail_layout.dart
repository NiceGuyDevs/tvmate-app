import 'dart:math' as math;

import 'dart:io' show Platform;

/// First row holds at most this many full posters; above that uses a second (peek) row.
const int kWindowsBrowseFirstRowSlots = 8;

/// Height of the second row as a fraction of the full poster height (top half visible).
const double kWindowsBrowseSecondRowHeightFraction = 0.5;

/// Gap between the two rows on Windows (logical px before scale).
const double kWindowsBrowseRowGap = 12.0;

/// Space between category pill strip and poster rail (room for hover scale).
const double kWindowsBrowsePillToRailGap = 20.0;

/// Category chip strip height on Windows (larger tap targets / readability).
const double kWindowsBrowseCategoryStripHeight = 60.0;

/// Returns true when the browse rail should use two stacked rows.
bool windowsBrowseUseDoubleRow(int railPageSize) {
  if (!Platform.isWindows && !Platform.isAndroid) return false;
  return railPageSize > kWindowsBrowseFirstRowSlots;
}

/// Windows 9+ slots: index delta for arrow down within the two-row strip or to the next wave.
int windowsBrowseVerticalDownDelta({
  required int idx,
  required int waveStart,
  required int listLength,
  required int railPageSize,
}) {
  if ((!Platform.isWindows && !Platform.isAndroid) ||
      railPageSize <= kWindowsBrowseFirstRowSlots) {
    return railPageSize;
  }
  final slot = idx - waveStart;
  if (slot < kWindowsBrowseFirstRowSlots) {
    final jump = idx + kWindowsBrowseFirstRowSlots;
    if (jump <= waveStart + railPageSize - 1 && jump < listLength) {
      return kWindowsBrowseFirstRowSlots;
    }
    final nextWave = waveStart + railPageSize;
    if (nextWave < listLength) {
      return nextWave - idx;
    }
  } else {
    final nextWave = waveStart + railPageSize;
    if (nextWave < listLength) {
      return nextWave - idx;
    }
  }
  return railPageSize;
}

/// Segment key for [WindowsBrowseRailFlipSwitcher]: changes when the focused
/// wave or vertical row band (first vs second peek row) changes.
String windowsBrowseFlipSegmentKey({
  required int listIndex,
  required int railPageSize,
  required bool useDoubleRow,
}) {
  if (railPageSize <= 0) return '0_0';
  final waveStart = (listIndex ~/ railPageSize) * railPageSize;
  final slotInWave = listIndex - waveStart;
  final band =
      useDoubleRow && slotInWave >= kWindowsBrowseFirstRowSlots ? 1 : 0;
  return '${waveStart}_$band';
}

/// Poster dimensions and row widths for the movies/series browse rail (Windows).
class WindowsBrowseRailDimensions {
  const WindowsBrowseRailDimensions({
    required this.posterWidth,
    required this.posterHeight,
    required this.rowWidth,
    required this.useDoubleRow,
    required this.rowGap,
    this.secondRowVisibleHeight,
    this.secondRowWidth,
    this.contentWidth,
  });

  final double posterWidth;
  final double posterHeight;
  final double rowWidth;

  /// Single row, or double row with peek.
  final bool useDoubleRow;

  final double rowGap;

  /// Only when [useDoubleRow]: visible height of the second row strip (half poster).
  final double? secondRowVisibleHeight;

  /// Width of the shorter/longer row when they differ.
  final double? secondRowWidth;

  /// Outer width for [Align] / [SizedBox] (max of rows).
  final double? contentWidth;

  double get secondRowOpacity => 0.42;
}

/// `aspectHeightOverWidth`: poster height / width (e.g. 3/2 for portrait).
WindowsBrowseRailDimensions computeWindowsBrowseRailDimensions({
  required double availW,
  required double availH,
  required int railPageSize,
  required double slotGap,
  required double aspectHeightOverWidth,
}) {
  final n = railPageSize;
  if (n <= 0) {
    return WindowsBrowseRailDimensions(
      posterWidth: 0,
      posterHeight: 0,
      rowWidth: 0,
      useDoubleRow: false,
      rowGap: slotGap,
      contentWidth: 0,
    );
  }

  if (!windowsBrowseUseDoubleRow(n)) {
    // Width-first so poster size matches the double-row path and
    // stays consistent when toggling between 8 and 9 slots.
    if (Platform.isWindows || Platform.isAndroid) {
      var posterW = (availW - slotGap * (n - 1)) / n;
      if (posterW <= 0 || !posterW.isFinite) posterW = 0;
      var posterH = posterW * aspectHeightOverWidth;
      if (posterH > availH && availH > 0) {
        posterH = availH;
        posterW = posterH / aspectHeightOverWidth;
      }
      final rowW = posterW * n + slotGap * (n - 1);
      return WindowsBrowseRailDimensions(
        posterWidth: posterW,
        posterHeight: posterH,
        rowWidth: rowW,
        useDoubleRow: false,
        rowGap: slotGap,
        contentWidth: rowW,
      );
    }
    var posterH = availH;
    var posterW = posterH / aspectHeightOverWidth;
    var rowW = posterW * n + slotGap * (n - 1);
    if (rowW > availW) {
      posterW = (availW - slotGap * (n - 1)) / n;
      posterH = posterW * aspectHeightOverWidth;
      rowW = availW;
    }
    return WindowsBrowseRailDimensions(
      posterWidth: posterW,
      posterHeight: posterH,
      rowWidth: rowW,
      useDoubleRow: false,
      rowGap: slotGap,
      contentWidth: rowW,
    );
  }

  final n1 = kWindowsBrowseFirstRowSlots;
  final rg = kWindowsBrowseRowGap;
  final aspect = aspectHeightOverWidth;
  final kPeek = kWindowsBrowseSecondRowHeightFraction;

  // Row 1 always uses the full horizontal span (8 equal slots). Poster width
  // follows width, not height-first (height-first shrank row 1 when two rows).
  var posterW = (availW - slotGap * (n1 - 1)) / n1;
  if (posterW <= 0 || !posterW.isFinite) {
    posterW = 0;
  }
  var hFull = posterW * aspect;
  var remaining = availH - rg - hFull;
  double secondRowVisible;
  if (remaining >= 0) {
    secondRowVisible = math.min(hFull * kPeek, remaining);
  } else {
    // Viewport too short for full-width row at natural height: shrink until
    // row 1 fits; second row peek may become 0.
    posterW = math.min(posterW, (availH - rg) / aspect);
    hFull = posterW * aspect;
    remaining = availH - rg - hFull;
    secondRowVisible = remaining > 0
        ? math.min(hFull * kPeek, remaining)
        : 0.0;
  }

  final row1W = posterW * n1 + slotGap * (n1 - 1);
  // Peek row always shows n1 (8) slots regardless of how many overflow items
  // exist; items beyond the data range render as empty placeholder tiles.
  final row2W = posterW * n1 + slotGap * (n1 - 1);
  final cw = math.max(row1W, row2W);

  return WindowsBrowseRailDimensions(
    posterWidth: posterW,
    posterHeight: hFull,
    rowWidth: row1W,
    useDoubleRow: true,
    rowGap: rg,
    secondRowVisibleHeight: secondRowVisible,
    secondRowWidth: row2W,
    contentWidth: cw,
  );
}
