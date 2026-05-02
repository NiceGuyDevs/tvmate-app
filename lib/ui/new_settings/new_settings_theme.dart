/// 1:1 port of the CSS custom-property tokens at the top of `settings.html`
/// (see the `:root { ... }` block, lines 16–57 of the reference file).
///
/// Every color is the exact hex (or rgba) from the stylesheet. Radii,
/// shadows and easing curves mirror the `--r-*`, `--shadow-*` and `--ease*`
/// variables so subsequent sub-page ports only ever need to read tokens
/// from here — no magic numbers scattered through widget code.
///
/// Kept on its own so the phase-2+ pages (Appearance, Clock overlay,
/// Playlists, etc.) all share a single source of truth for the chrome
/// and never drift from the HTML reference.
library;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Palette — direct translation of the `:root` CSS custom properties.
///
/// Names match the CSS variable names (`--bg-2` → `bg2`, `--text-3` → `text3`)
/// so a reader with the stylesheet open can cross-reference line by line.
class NsColors {
  const NsColors._();

  // Surfaces / layering
  static const Color bg = Color(0xFF0A0D13); // --bg
  static const Color bg2 = Color(0xFF0D1119); // --bg-2
  static const Color surface = Color(0xFF131822); // --surface
  static const Color surface2 = Color(0xFF181F2C); // --surface-2
  static const Color surface3 = Color(0xFF1F2837); // --surface-3
  static const Color line = Color(0xFF1B2330); // --line
  static const Color line2 = Color(0xFF28324A); // --line-2

  // Text ramp
  static const Color text = Color(0xFFEEF2F7); // --text
  static const Color text2 = Color(0xFFA8B0BD); // --text-2
  static const Color text3 = Color(0xFF6F7889); // --text-3
  static const Color text4 = Color(0xFF4B5363); // --text-4

  // Accent — cyan family
  static const Color accent = Color(0xFF4DD0E1); // --accent
  static const Color accent2 = Color(0xFF22D3EE); // --accent-2
  static const Color accentSoft = Color(0x244DD0E1); // rgba(77,208,225,0.14)
  static const Color accentLine = Color(0x804DD0E1); // rgba(77,208,225,0.50)
  static const Color accentGlow = Color(0x384DD0E1); // rgba(77,208,225,0.22)

  // Focus accent — neon orange from the HTML preview the user
  // approved (`focus_fix_preview.html`, orange toggle). Chosen over
  // cyan because the rest of the new-settings surface is cyan; orange
  // gives the focus bar the contrast it needs to read clearly on
  // every element (including cyan primary buttons) without getting
  // lost in the rail background.
  static const Color focusAccent = Color(0xFFFF7A18);      // neon orange
  static const Color focusAccentGlow = Color(0x73FF7A18);  // 45% orange

  // Status
  static const Color danger = Color(0xFFF87171);
  static const Color dangerSoft = Color(0x1FF87171); // rgba(248,113,113,0.12)
  static const Color success = Color(0xFF4ADE80);
  static const Color successSoft = Color(0x1F4ADE80); // rgba(74,222,128,0.12)
  static const Color warn = Color(0xFFFBBF24);

  // Category-specific icon tints — ported from settings.html's `.pl-card
  // .stats .tile.t-*` rules (lines 1071–1074). Each stat category gets a
  // distinct hue so the three counts read as three different categories
  // at a glance, not a monolithic cyan wall.
  static const Color movie = Color(0xFFFB923C); // Movies — orange
  static const Color movieSoft = Color(0x1FFB923C); // rgba(251,146,60,.12)
  static const Color movieLine = Color(0x59FB923C); // rgba(251,146,60,.35)

  static const Color series = Color(0xFFA78BFA); // Series — violet
  static const Color seriesSoft = Color(0x1FA78BFA); // rgba(167,139,250,.12)
  static const Color seriesLine = Color(0x59A78BFA); // rgba(167,139,250,.35)
}

/// Radii — the three `--r-*` CSS vars. `pill` is the HTML's 999px,
/// clamped to a sane Flutter value (anything ≥ half the control height
/// paints as a full pill, so 999 translates cleanly to 999 here too).
class NsRadius {
  const NsRadius._();

  static const double card = 14; // --r-card
  static const double row = 10; // --r-row
  static const double pill = 999; // --r-pill
}

/// Layout constants taken from `:root` so rail width + header height stay
/// consistent with the HTML reference across all sub-pages.
class NsSizes {
  const NsSizes._();

  static const double railWidth = 300; // --rail-w
  static const double headerHeight = 60; // --header-h

  /// Wide-layout breakpoint. At or above this logical width we paint the
  /// two-pane desktop layout exactly like the HTML; below it the rail
  /// collapses into a horizontal category strip above the detail pane
  /// (phone portrait only — TV and tablets are always wide).
  static const double wideBreakpoint = 900;
}

/// Easings — same cubic-beziers the HTML uses for every hover / focus /
/// sheet transition. `ease` is the snappy "entry" curve; `easeOut` is the
/// slower material-like settle for modals and toasts.
class NsEase {
  const NsEase._();

  /// --ease: cubic-bezier(.2, .8, .2, 1)
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  /// --ease-out: cubic-bezier(.16, 1, .3, 1)
  static const Curve easeOut = Cubic(0.16, 1, 0.3, 1);
}

/// Shadow stacks that mirror `--shadow-1 / -2 / -3`. Each `BoxShadow`
/// below corresponds line-for-line with the CSS multi-shadow, including
/// the inset highlight the HTML fakes with a top-edge inset shadow.
///
/// Flutter doesn't support inset box-shadow directly; the top-edge inset
/// is approximated by a 1-px bright `BoxShadow` at `offset: (0, 1)` with
/// a tiny blur. Visually indistinguishable at TV viewing distance.
class NsShadow {
  const NsShadow._();

  /// --shadow-1: 0 1px 0 rgba(255,255,255,0.04) inset, 0 8px 30px rgba(0,0,0,0.35)
  static const List<BoxShadow> s1 = [
    BoxShadow(
      color: Color(0x0AFFFFFF), // rgba(255,255,255,0.04)
      offset: Offset(0, 1),
      blurRadius: 0,
    ),
    BoxShadow(
      color: Color(0x59000000), // rgba(0,0,0,0.35)
      offset: Offset(0, 8),
      blurRadius: 30,
    ),
  ];

  /// --shadow-2: 0 1px 0 rgba(255,255,255,0.05) inset, 0 18px 60px rgba(0,0,0,0.55)
  static const List<BoxShadow> s2 = [
    BoxShadow(
      color: Color(0x0DFFFFFF),
      offset: Offset(0, 1),
      blurRadius: 0,
    ),
    BoxShadow(
      color: Color(0x8C000000),
      offset: Offset(0, 18),
      blurRadius: 60,
    ),
  ];

  /// --shadow-3: 0 24px 80px rgba(0,0,0,0.6)
  static const List<BoxShadow> s3 = [
    BoxShadow(
      color: Color(0x99000000),
      offset: Offset(0, 24),
      blurRadius: 80,
    ),
  ];

  // NOTE: intentionally NO generic "focusRing" token. The HTML reference
  // only paints an outer accent-soft ring on two element types:
  //   * `.icon-btn`      — 3 px (settings.html line 188)
  //   * `.search input`  — 4 px (settings.html line 156)
  // Every other focusable element uses a combination of background change
  // and/or an INSET 2 px accent-soft wash (rendered in Flutter as a 2 px
  // [Border] painted via `foregroundDecoration`). Providing a reusable
  // ring token tempts future phases to slap it on rows, option tiles and
  // the like — which the HTML never does. If a phase-6+ form input needs
  // a 3 px ring, paint it inline on that element so the intent is
  // explicit and not inherited by accident.
}

/// Typography token bundle. The HTML uses Inter (with the DSEG7 Classic
/// font only for LED clock digits). Inter is not bundled in the app yet,
/// so phase 1 uses the platform default sans-serif with the exact weights
/// and sizes from the HTML. If the user later wants pixel-exact typography
/// we drop Inter assets in and flip the `fontFamily` here — nothing else
/// changes.
///
/// Every style sets [TextDecoration.none] so [Text] does not merge in
/// link/underline from the ambient [DefaultTextStyle] (e.g. Material
/// `textTheme` on TV), which otherwise draws colored underlines on dialogs.
class NsType {
  const NsType._();

  static const String? fontFamily = null;

  static const TextStyle brandName = TextStyle(
    color: NsColors.text,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle crumbStep = TextStyle(
    color: NsColors.text3,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle crumbCurrent = TextStyle(
    color: NsColors.text,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle railSection = TextStyle(
    color: NsColors.text3,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  // Rail item label — HTML `.cat { font: 600 13.5px/1.2 }`. Same
  // font size / weight for every state (base, hover, focused,
  // selected); only the text `color` changes between states. That's
  // why there's no distinct "dim" weight — both styles keep weight
  // 600 so a focused-but-not-selected tile doesn't visibly shift
  // label typography, matching the HTML transition feel.
  static const TextStyle railItemLabel = TextStyle(
    color: NsColors.text,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle railItemLabelDim = TextStyle(
    color: NsColors.text2,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  // Rail meta pill — HTML `.cat .meta { color: text-4;
  // background: surface; border: 1px solid line; font-size: 11.5px;
  // font-weight: 500; }`. Only weight 600 kept for TV legibility;
  // color, size and surface match exactly.
  static const TextStyle railItemMeta = TextStyle(
    color: NsColors.text4,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle eyebrow = TextStyle(
    color: NsColors.accent,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle paneTitle = TextStyle(
    color: NsColors.text,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle paneDesc = TextStyle(
    color: NsColors.text2,
    fontSize: 14,
    height: 1.45,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle groupLabel = TextStyle(
    color: NsColors.text3,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle rowTitle = TextStyle(
    color: NsColors.text,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle rowSub = TextStyle(
    color: NsColors.text3,
    fontSize: 13,
    height: 1.4,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle rowValue = TextStyle(
    color: NsColors.text2,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle optionLabel = TextStyle(
    color: NsColors.text,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle optionSub = TextStyle(
    color: NsColors.text3,
    fontSize: 12,
    height: 1.35,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle badge = TextStyle(
    color: NsColors.accent,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );

  static const TextStyle badgeWarn = TextStyle(
    color: NsColors.warn,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    fontFamily: fontFamily,
    decoration: TextDecoration.none,
  );
}

/// Short-hand opacity helper so CSS rgba literals can be ported literally
/// without mental math — `.op(0.14)` reads like the CSS.
/// Kept short and unique to avoid collision with [Color.alpha] (an int
/// property) and the deprecated [Color.withOpacity].
extension NsColorOpacity on Color {
  Color op(double value) => withValues(alpha: value);
}
