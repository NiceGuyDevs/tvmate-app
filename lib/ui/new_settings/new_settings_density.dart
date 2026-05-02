/// Density tokens — compact for Android TV / small logical canvases,
/// comfortable for desktop / tablet. A single provider resolves the
/// right preset once per build based on [MediaQuery.size.height].
///
/// Every sizing decision in the new settings surface reads from
/// [NsDensity]. There are **no** hardcoded numbers or `d.isCompact ? X : Y`
/// ternaries inside widgets anymore — change a token here and the whole
/// surface rescales on next frame. New pages inherit the right scale for
/// free.
///
/// Why this exists: the HTML reference was sized for a 1080-CSS-px
/// viewport. Android TV renders Flutter at a smaller logical canvas
/// (typically 720 or 540 logical px tall), so px values copied straight
/// from the CSS render visually huge on the panel.
///
/// Tokens live in three families:
///
///   * **Explicit tokens** (cardPadding, pillHeight, etc.) — used when
///     the value is a layout primitive that appears many places.
///   * **Scale helpers** (`fs`, `sp`, `ic`) — used for one-off numbers
///     inside a widget. Each scales linearly between compact and
///     comfortable via a single factor.
///   * **Type helpers** (`t(size)`) — shorthand for the common "scale
///     this font size" case.
library;

import 'package:flutter/widgets.dart';

class NsDensity {
  const NsDensity._({
    // Type / spacing / icon scale factors.
    required this.scale,

    // Existing tokens — still used directly by common widgets.
    required this.paneTitleSize,
    required this.paneTitleLh,
    required this.paneDescSize,
    required this.paneDescLh,
    required this.paneHeadBottomGap,
    required this.groupLabelSize,
    required this.groupLabelBottomGap,
    required this.interGroupGap,
    required this.rowVerticalPadding,
    required this.rowHorizontalPadding,
    required this.rowTitleSize,
    required this.rowSubSize,
    required this.rowSubLh,
    required this.rowGapTitleSub,
    required this.listTopPadding,
    required this.listBottomPadding,
    required this.listHorizontalPadding,
    required this.railTileHeight,
    required this.railTileIconSize,
    required this.railTileLabelSize,
    required this.railTileHorizontalPadding,
    required this.railTileVerticalMargin,
    required this.railTileHorizontalMargin,
    required this.railTopSectionTopPad,
    required this.railTopSectionBottomPad,
    required this.railBottomPadding,
    required this.eyebrowSize,
    required this.eyebrowBottomGap,
    required this.eyebrowTitleGap,
    required this.titleDescGap,
    required this.sectionLabelSize,
    required this.cardRowDividerOpacity,
    required this.headerHeight,

    // New global tokens (promoted from widget internals).
    required this.cardPadding,
    required this.cardGap,
    required this.cardBorderRadius,
    required this.subPageTitleSize,
    required this.subPageSubtitleSize,
    required this.subPageHeadBottomGap,
    required this.switchPillWidth,
    required this.switchPillHeight,
    required this.snapChipFontSize,
    required this.snapChipPadH,
    required this.snapChipPadV,
    required this.buttonHeight,
    required this.buttonPadH,
    required this.buttonPadV,
    required this.buttonFontSize,
    required this.ghostButtonFontSize,
    required this.segmentedPadH,
    required this.segmentedPadV,
    required this.segmentedFontSize,
    required this.sliderTrackHeight,
    required this.sliderThumbRadius,
    required this.sliderOverlayRadius,
    required this.sliderRowHeight,
    required this.valuePillFontSize,
    required this.valuePillPadH,
    required this.valuePillMinWidth,
    required this.swatchSize,
    required this.iconTiny,
    required this.iconSmall,
    required this.iconMedium,
    required this.iconLarge,
    required this.fieldLabelSize,
    required this.fieldLabelGap,
    required this.statTilePadH,
    required this.statTilePadV,
    required this.statValueSize,
    required this.statLabelSize,
    required this.badgePadH,
    required this.badgePadV,
    required this.badgeFontSize,

    required this.isCompact,
  });

  /// Single linear factor used by [fs] / [sp] / [ic] to rescale raw
  /// numbers at the call site. Compact = 0.82, comfortable = 1.0.
  final double scale;

  /// Scale a raw font size (baseline = comfortable). `d.fs(14)` gives
  /// 14 px on comfortable and 11.5 px on compact.
  double fs(double basePx) => basePx * scale;

  /// Scale a raw spacing / padding value. Identical to [fs] today but
  /// kept separate so we can tune text vs spacing independently later
  /// without touching every call site.
  double sp(double basePx) => basePx * scale;

  /// Scale a raw icon size.
  double ic(double basePx) => basePx * scale;

  // ── Existing tokens (pane / row / rail / header) ──────────────────

  final double paneTitleSize;
  final double paneTitleLh;
  final double paneDescSize;
  final double paneDescLh;
  final double paneHeadBottomGap;

  final double groupLabelSize;
  final double groupLabelBottomGap;
  final double interGroupGap;

  final double rowVerticalPadding;
  final double rowHorizontalPadding;
  final double rowTitleSize;
  final double rowSubSize;
  final double rowSubLh;
  final double rowGapTitleSub;

  final double listTopPadding;
  final double listBottomPadding;
  final double listHorizontalPadding;

  final double railTileHeight;
  final double railTileIconSize;
  final double railTileLabelSize;
  final double railTileHorizontalPadding;
  final double railTileVerticalMargin;
  final double railTileHorizontalMargin;
  final double railTopSectionTopPad;
  final double railTopSectionBottomPad;
  final double railBottomPadding;

  final double eyebrowSize;
  final double eyebrowBottomGap;
  final double eyebrowTitleGap;
  final double titleDescGap;

  final double sectionLabelSize;

  final double cardRowDividerOpacity;

  final double headerHeight;

  // ── New global tokens ─────────────────────────────────────────────

  /// Uniform padding inside a card-style surface.
  final double cardPadding;

  /// Gap between adjacent cards / sections.
  final double cardGap;

  /// Radius for card-level surfaces.
  final double cardBorderRadius;

  /// Sub-page head title + subtitle + bottom gap.
  final double subPageTitleSize;
  final double subPageSubtitleSize;
  final double subPageHeadBottomGap;

  /// Switch pill (used by Clock toggle, Parental toggles, row toggle, …).
  final double switchPillWidth;
  final double switchPillHeight;

  /// Snap / opacity chips.
  final double snapChipFontSize;
  final double snapChipPadH;
  final double snapChipPadV;

  /// Primary / ghost / danger button chrome.
  final double buttonHeight;
  final double buttonPadH;
  final double buttonPadV;
  final double buttonFontSize;
  final double ghostButtonFontSize;

  /// Segmented chip group.
  final double segmentedPadH;
  final double segmentedPadV;
  final double segmentedFontSize;

  /// Slider thumb / track / row height.
  final double sliderTrackHeight;
  final double sliderThumbRadius;
  final double sliderOverlayRadius;
  final double sliderRowHeight;

  /// Value pill rendered next to a slider.
  final double valuePillFontSize;
  final double valuePillPadH;
  final double valuePillMinWidth;

  /// Color swatch picker (Appearance / Clock).
  final double swatchSize;

  /// Icon-size ramp.
  final double iconTiny;
  final double iconSmall;
  final double iconMedium;
  final double iconLarge;

  /// Field-label (the small uppercase caption above a control).
  final double fieldLabelSize;
  final double fieldLabelGap;

  /// Playlist card stat tile.
  final double statTilePadH;
  final double statTilePadV;
  final double statValueSize;
  final double statLabelSize;

  /// Rounded badge pill (PRO, Active, etc.).
  final double badgePadH;
  final double badgePadV;
  final double badgeFontSize;

  final bool isCompact;

  /// Compact preset — targets Android TV / ≤ 760 logical-px canvas.
  static const NsDensity compact = NsDensity._(
    scale: 0.82,
    // Existing
    paneTitleSize: 14,
    paneTitleLh: 1.1,
    paneDescSize: 10.5,
    paneDescLh: 1.3,
    paneHeadBottomGap: 6,
    groupLabelSize: 9.5,
    groupLabelBottomGap: 3,
    interGroupGap: 6,
    rowVerticalPadding: 4,
    rowHorizontalPadding: 13,
    rowTitleSize: 11.5,
    rowSubSize: 10,
    rowSubLh: 1.2,
    rowGapTitleSub: 1,
    listTopPadding: 6,
    listBottomPadding: 10,
    listHorizontalPadding: 18,
    railTileHeight: 28,
    railTileIconSize: 14,
    railTileLabelSize: 11.5,
    railTileHorizontalPadding: 9,
    railTileVerticalMargin: 1,
    railTileHorizontalMargin: 7,
    railTopSectionTopPad: 6,
    railTopSectionBottomPad: 4,
    railBottomPadding: 6,
    eyebrowSize: 9,
    eyebrowBottomGap: 3,
    eyebrowTitleGap: 2,
    titleDescGap: 2,
    sectionLabelSize: 9,
    cardRowDividerOpacity: 0.7,
    headerHeight: 40,
    // New
    cardPadding: 9,
    cardGap: 6,
    cardBorderRadius: 12,
    subPageTitleSize: 14,
    subPageSubtitleSize: 10.5,
    subPageHeadBottomGap: 10,
    switchPillWidth: 30,
    switchPillHeight: 17,
    snapChipFontSize: 9,
    snapChipPadH: 5,
    snapChipPadV: 2,
    buttonHeight: 28,
    buttonPadH: 10,
    buttonPadV: 5,
    buttonFontSize: 10.5,
    ghostButtonFontSize: 10,
    segmentedPadH: 8,
    segmentedPadV: 5,
    segmentedFontSize: 10,
    sliderTrackHeight: 3,
    sliderThumbRadius: 5,
    sliderOverlayRadius: 9,
    sliderRowHeight: 20,
    valuePillFontSize: 9,
    valuePillPadH: 5,
    valuePillMinWidth: 32,
    swatchSize: 20,
    iconTiny: 10,
    iconSmall: 12,
    iconMedium: 14,
    iconLarge: 18,
    fieldLabelSize: 9,
    fieldLabelGap: 3,
    statTilePadH: 6,
    statTilePadV: 5,
    statValueSize: 12,
    statLabelSize: 8.5,
    badgePadH: 6,
    badgePadV: 2,
    badgeFontSize: 9,
    isCompact: true,
  );

  /// Comfortable — HTML-proportional for wide canvases.
  static const NsDensity comfortable = NsDensity._(
    scale: 1.0,
    // Existing
    paneTitleSize: 22,
    paneTitleLh: 1.15,
    paneDescSize: 13,
    paneDescLh: 1.45,
    paneHeadBottomGap: 18,
    groupLabelSize: 10.5,
    groupLabelBottomGap: 8,
    interGroupGap: 18,
    rowVerticalPadding: 11,
    rowHorizontalPadding: 16,
    rowTitleSize: 13.5,
    rowSubSize: 12,
    rowSubLh: 1.35,
    rowGapTitleSub: 4,
    listTopPadding: 22,
    listBottomPadding: 28,
    listHorizontalPadding: 24,
    railTileHeight: 40,
    railTileIconSize: 18,
    railTileLabelSize: 13.5,
    railTileHorizontalPadding: 12,
    railTileVerticalMargin: 2,
    railTileHorizontalMargin: 6,
    railTopSectionTopPad: 18,
    railTopSectionBottomPad: 10,
    railBottomPadding: 16,
    eyebrowSize: 10.5,
    eyebrowBottomGap: 8,
    eyebrowTitleGap: 6,
    titleDescGap: 6,
    sectionLabelSize: 10.5,
    cardRowDividerOpacity: 0.7,
    headerHeight: 60,
    // New
    cardPadding: 14,
    cardGap: 12,
    cardBorderRadius: 14,
    subPageTitleSize: 22,
    subPageSubtitleSize: 13,
    subPageHeadBottomGap: 22,
    switchPillWidth: 44,
    switchPillHeight: 24,
    snapChipFontSize: 10.5,
    snapChipPadH: 8,
    snapChipPadV: 4,
    buttonHeight: 40,
    buttonPadH: 20,
    buttonPadV: 9,
    buttonFontSize: 12.5,
    ghostButtonFontSize: 12,
    segmentedPadH: 11,
    segmentedPadV: 6,
    segmentedFontSize: 11.5,
    sliderTrackHeight: 4,
    sliderThumbRadius: 7,
    sliderOverlayRadius: 14,
    sliderRowHeight: 28,
    valuePillFontSize: 11.5,
    valuePillPadH: 10,
    valuePillMinWidth: 48,
    swatchSize: 28,
    iconTiny: 12,
    iconSmall: 14,
    iconMedium: 16,
    iconLarge: 22,
    fieldLabelSize: 11,
    fieldLabelGap: 5,
    statTilePadH: 8,
    statTilePadV: 7,
    statValueSize: 13.5,
    statLabelSize: 9.5,
    badgePadH: 7,
    badgePadV: 2,
    badgeFontSize: 10.5,
    isCompact: false,
  );

  static const double _compactThreshold = 760;

  /// Resolve the right preset from context.
  static NsDensity of(BuildContext context) {
    final h = MediaQuery.maybeOf(context)?.size.height ?? 0;
    return h > 0 && h > _compactThreshold ? comfortable : compact;
  }
}
