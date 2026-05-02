import 'package:flutter/material.dart';

/// Visual “team” — backdrop + chrome only (Cosmic … Canvas, Mist).
@immutable
class TeamPalette {
  const TeamPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.topBarFill,
    required this.topBarFillEnd,
    required this.accent,
    required this.neonLine,
    required this.nebulaViolet,
    required this.nebulaMagenta,
    required this.nebulaWash,
    required this.deepSpaceColors,
    required this.deepSpaceStops,
    required this.neonRimColors,
    required this.neonRimStops,
    required this.nebulaBlobMidCyan,
    required this.nebulaBlobTeal,
    required this.lightLeakAccentOpacity,
    required this.lightLeakMagentaOpacity,
    required this.brandCyan,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color topBarFill;
  final Color topBarFillEnd;
  final Color accent;
  final Color neonLine;
  final Color nebulaViolet;
  final Color nebulaMagenta;
  final Color nebulaWash;

  final List<Color> deepSpaceColors;
  final List<double> deepSpaceStops;
  final List<Color> neonRimColors;
  final List<double> neonRimStops;

  /// Second nebula blob mid (team1: dark blue; team2: deep purple).
  final Color nebulaBlobMidCyan;
  /// Fourth nebula hint (team1: teal; team2: plum).
  final Color nebulaBlobTeal;

  final double lightLeakAccentOpacity;
  final double lightLeakMagentaOpacity;

  /// Legacy “brand” accent (splash / progress). Matches [accent] on Aurora.
  final Color brandCyan;

  /// Global D-pad / TV focus ring (all themes, all [TvFocusable] defaults).
  static const Color focusNeonPink = Color(0xFFFF2A9A);

  Color get glassPanelFill => Color.lerp(canvas, Colors.black, 0.35)!.withOpacity(0.62);

  static const Color textMuted = Color(0xFF8E8E93);
  static const Color textSecondary = Color(0xFFB0B0B8);

  // ── Shell / hero text (dark TV shell) ─────────────────────────────────
  /// Hero title, channel name on hero.
  Color get shellTitleColor => const Color(0xFFEEF2F7);
  /// EPG / meta line on hero.
  Color get shellBodyHint => const Color(0xFF6F7889);
  /// Logo / channel art well behind preview.
  Color get shellLogoWell => const Color(0xFF0D1119);
  /// [Colors.white] @ [a].
  Color shellTextOpacity(double a) => Colors.white.withValues(alpha: a);
  /// Category / idle text when not using [textSecondary] static.
  Color get onShellTextSecondary => textSecondary;

  /// D-pad / TV focus ring: follows the active team via [neonLine] (cyan → blue, ember → coral, etc.).
  /// Legacy hot pink: [focusNeonPink] (kept for reference rows that still use it directly).
  Color get defaultFocusRingColor => neonLine;

  List<BoxShadow> get railCardRestShadow {
    return [
        BoxShadow(
          color: Colors.black.withOpacity(0.58),
          blurRadius: 26,
          spreadRadius: -4,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: accent.withOpacity(0.12),
          blurRadius: 22,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];
  }

  List<BoxShadow> get railCardFocusShadow {
    return [
        BoxShadow(
          color: Colors.black.withOpacity(0.72),
          blurRadius: 40,
          spreadRadius: -6,
          offset: const Offset(0, 22),
        ),
        BoxShadow(
          color: accent.withOpacity(0.28),
          blurRadius: 32,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: accent.withOpacity(0.45),
          blurRadius: 48,
          spreadRadius: -4,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: nebulaMagenta.withOpacity(0.25),
          blurRadius: 36,
          spreadRadius: -2,
          offset: const Offset(6, 4),
        ),
        BoxShadow(
          color: nebulaWash.withOpacity(0.2),
          blurRadius: 28,
          spreadRadius: 0,
          offset: const Offset(-4, 8),
        ),
      ];
  }

  static List<BoxShadow> get heroPanelShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.65),
          blurRadius: 36,
          spreadRadius: -8,
          offset: const Offset(0, 18),
        ),
      ];

  List<BoxShadow> get heroNeonGlow => [
        BoxShadow(
          color: accent.withOpacity(0.38),
          blurRadius: 26,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: nebulaMagenta.withOpacity(0.22),
          blurRadius: 44,
          spreadRadius: 1,
          offset: const Offset(4, 10),
        ),
        BoxShadow(
          color: nebulaWash.withOpacity(0.18),
          blurRadius: 32,
          spreadRadius: -2,
          offset: const Offset(-6, 4),
        ),
        BoxShadow(
          color: nebulaViolet.withOpacity(0.14),
          blurRadius: 50,
          spreadRadius: 0,
          offset: const Offset(0, 16),
        ),
      ];

  List<BoxShadow> get neonFrameVariedShadows => [
        BoxShadow(
          color: accent.withOpacity(0.35),
          blurRadius: 22,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: nebulaMagenta.withOpacity(0.2),
          blurRadius: 36,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: nebulaWash.withOpacity(0.15),
          blurRadius: 18,
          spreadRadius: -1,
          offset: const Offset(-4, 0),
        ),
      ];

  List<BoxShadow> get neonFrameBrowseHeroShadows => [
        BoxShadow(
          color: accent.withOpacity(0.52),
          blurRadius: 28,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: nebulaMagenta.withOpacity(0.38),
          blurRadius: 42,
          spreadRadius: 1,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: nebulaWash.withOpacity(0.28),
          blurRadius: 24,
          spreadRadius: -1,
          offset: const Offset(-6, 2),
        ),
        BoxShadow(
          color: nebulaViolet.withOpacity(0.22),
          blurRadius: 48,
          spreadRadius: 0,
          offset: const Offset(4, 14),
        ),
      ];

  List<BoxShadow> get glassFloatShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.55),
          blurRadius: 32,
          spreadRadius: -4,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: accent.withOpacity(0.15),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];

  /// Live TV hero panel when user chooses **theme default** (not custom paints).
  LinearGradient get heroDefaultGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(const Color(0xFF34343C), surfaceElevated, 0.22)!,
          Color.lerp(const Color(0xFF1F1F26), surface, 0.25)!,
        ],
      );

  /// “Settings style” / settings.html chrome — [NsColors] in
  /// `new_settings_theme.dart` (`:root` in the HTML reference: `--bg`, `--surface`,
  /// `--surface-2`, `--accent`, etc.). [AppVisualTeam.settingsStyle] uses this
  /// palette; Live TV cards/hero use [surface] / [surfaceElevated] so they match
  /// the new-settings / HTML row + card grays, not the older deeper-blue [surface].
  static const TeamPalette cyan = TeamPalette(
    canvas: Color(0xFF0A0D13), // NsColors.bg
    surface: Color(0xFF131822), // NsColors.surface
    surfaceElevated: Color(0xFF181F2C), // NsColors.surface2
    topBarFill: Color(0xFF0D1119), // NsColors.bg2
    topBarFillEnd: Color(0xFF0A0D13), // NsColors.bg
    accent: Color(0xFF4DD0E1), // NsColors.accent
    neonLine: Color(0xFF22D3EE), // NsColors.accent2
    nebulaViolet: Color(0xFF3D4A5C), // slate (depth; avoids purple push vs Ns)
    nebulaMagenta: Color(0xFF2A3D50),
    nebulaWash: Color(0xFF4A8EB8), // settings-style cool wash, not electric blue
    deepSpaceColors: [
      Color(0xFF0A0D13),
      Color(0xFF0D1119),
      Color(0xFF0A0C12),
      Color(0xFF080A10),
    ],
    deepSpaceStops: [0.0, 0.35, 0.72, 1.0],
    neonRimColors: [
      Color(0xFF8AEBF5),
      Color(0xFF4DD0E1),
      Color(0xFF22D3EE),
      Color(0xFF3DB8D4),
      Color(0xFF5AD4E0),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF151A22),
    nebulaBlobTeal: Color(0xFF1A202C),
    lightLeakAccentOpacity: 0.09,
    lightLeakMagentaOpacity: 0.06,
    brandCyan: Color(0xFF4DD0E1),
  );

  /// Purple / pink neon team.
  static const TeamPalette violet = TeamPalette(
    canvas: Color(0xFF070510),
    surface: Color(0xFF120A18),
    surfaceElevated: Color(0xFF1A0F26),
    topBarFill: Color(0xFF0C0614),
    topBarFillEnd: Color(0xFF140A1E),
    accent: Color(0xFFFF4DDE),
    neonLine: Color(0xFFFF8AE8),
    nebulaViolet: Color(0xFF8B5CFF),
    nebulaMagenta: Color(0xFFFF2A9A),
    nebulaWash: Color(0xFFB84DFF),
    deepSpaceColors: [
      Color(0xFF050208),
      Color(0xFF0E0618),
      Color(0xFF08040F),
      Color(0xFF030206),
    ],
    deepSpaceStops: [0.0, 0.35, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFFFB8F5),
      Color(0xFFFF4DDE),
      Color(0xFFC86BFF),
      Color(0xFFFF2A9A),
      Color(0xFFE040FB),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF2A0A38),
    nebulaBlobTeal: Color(0xFF301040),
    lightLeakAccentOpacity: 0.1,
    lightLeakMagentaOpacity: 0.08,
    brandCyan: Color(0xFFFF6BEB),
  );

  /// Electric yellow / gold neon — same energy as Cosmic & Aurora.
  static const TeamPalette solar = TeamPalette(
    canvas: Color(0xFF0A0805),
    surface: Color(0xFF14100A),
    surfaceElevated: Color(0xFF1C160E),
    topBarFill: Color(0xFF0E0B06),
    topBarFillEnd: Color(0xFF161008),
    accent: Color(0xFFFFE24A),
    neonLine: Color(0xFFFFF59D),
    nebulaViolet: Color(0xFFFF9F1C),
    nebulaMagenta: Color(0xFFFF5A4A),
    nebulaWash: Color(0xFFFFC857),
    deepSpaceColors: [
      Color(0xFF050402),
      Color(0xFF0E0A06),
      Color(0xFF080604),
      Color(0xFF030201),
    ],
    deepSpaceStops: [0.0, 0.35, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFFFF8C4),
      Color(0xFFFFE24A),
      Color(0xFFFFB020),
      Color(0xFFFF8E53),
      Color(0xFFFFF176),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF2A1810),
    nebulaBlobTeal: Color(0xFF1A2210),
    lightLeakAccentOpacity: 0.1,
    lightLeakMagentaOpacity: 0.075,
    brandCyan: Color(0xFFFFD54F),
  );

  /// Refined multi-tone look: champagne gold, wine, and midnight (no neon harshness).
  static const TeamPalette heritage = TeamPalette(
    canvas: Color(0xFF090B10),
    surface: Color(0xFF12151C),
    surfaceElevated: Color(0xFF1A1E28),
    topBarFill: Color(0xFF0D1016),
    topBarFillEnd: Color(0xFF141820),
    accent: Color(0xFFC9A962),
    neonLine: Color(0xFFE8D4A8),
    nebulaViolet: Color(0xFF3D4F7A),
    nebulaMagenta: Color(0xFF7A2D46),
    nebulaWash: Color(0xFF5C6B8C),
    deepSpaceColors: [
      Color(0xFF040506),
      Color(0xFF0B0D12),
      Color(0xFF070910),
      Color(0xFF020304),
    ],
    deepSpaceStops: [0.0, 0.35, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFF2EBDC),
      Color(0xFFC9A962),
      Color(0xFF8B3A4A),
      Color(0xFFB89B72),
      Color(0xFFD4C4A8),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF1A1522),
    nebulaBlobTeal: Color(0xFF15201A),
    lightLeakAccentOpacity: 0.048,
    lightLeakMagentaOpacity: 0.032,
    brandCyan: Color(0xFFC9A962),
  );

  /// Two-tone editorial calm: cool graphite base + warm pewter accent — muted, no neon harshness.
  static const TeamPalette studio = TeamPalette(
    canvas: Color(0xFF0E0F12),
    surface: Color(0xFF16181D),
    surfaceElevated: Color(0xFF1E2128),
    topBarFill: Color(0xFF121418),
    topBarFillEnd: Color(0xFF181B22),
    accent: Color(0xFFB8A99A),
    neonLine: Color(0xFFD4CBC0),
    nebulaViolet: Color(0xFF4A5568),
    nebulaMagenta: Color(0xFF6B5B54),
    nebulaWash: Color(0xFF5C6678),
    deepSpaceColors: [
      Color(0xFF08090B),
      Color(0xFF12141A),
      Color(0xFF0C0D10),
      Color(0xFF060708),
    ],
    deepSpaceStops: [0.0, 0.38, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFE8E2DA),
      Color(0xFFB8A99A),
      Color(0xFF8A7F76),
      Color(0xFF9A9088),
      Color(0xFFC9C0B4),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF1A1D24),
    nebulaBlobTeal: Color(0xFF1E1C1A),
    lightLeakAccentOpacity: 0.035,
    lightLeakMagentaOpacity: 0.025,
    brandCyan: Color(0xFFB8A99A),
  );

  /// Flat shell: [canvas] → [surfaceElevated] gradient only (no starfield). Restrained steel / slate chrome.
  static const TeamPalette canvasTheme = TeamPalette(
    canvas: Color(0xFF0A0C10),
    surface: Color(0xFF141820),
    surfaceElevated: Color(0xFF222831),
    topBarFill: Color(0xFF0E1016),
    topBarFillEnd: Color(0xFF161A22),
    accent: Color(0xFF8FA3B8),
    neonLine: Color(0xFFB8C5D4),
    nebulaViolet: Color(0xFF3D4758),
    nebulaMagenta: Color(0xFF4A4F58),
    nebulaWash: Color(0xFF5A6578),
    deepSpaceColors: [
      Color(0xFF060708),
      Color(0xFF0E1018),
      Color(0xFF0A0C12),
      Color(0xFF040506),
    ],
    deepSpaceStops: [0.0, 0.38, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFC8D4E0),
      Color(0xFF8FA3B8),
      Color(0xFF6B7A8C),
      Color(0xFF7A8A9C),
      Color(0xFFA8B6C4),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF151820),
    nebulaBlobTeal: Color(0xFF181A20),
    lightLeakAccentOpacity: 0.02,
    lightLeakMagentaOpacity: 0.015,
    brandCyan: Color(0xFF8FA3B8),
  );

  /// Shifting black/gray shell + animated yellow/pink wash; chrome uses same hues (soft, not harsh neon).
  static const TeamPalette mistTheme = TeamPalette(
    canvas: Color(0xFF09090A),
    surface: Color(0xFF131315),
    surfaceElevated: Color(0xFF1D1D22),
    topBarFill: Color(0xFF0C0C0E),
    topBarFillEnd: Color(0xFF141418),
    accent: Color(0xFFE8D078),
    neonLine: Color(0xFFF5ECC8),
    nebulaViolet: Color(0xFF4A4A52),
    nebulaMagenta: Color(0xFFD8A8C8),
    nebulaWash: Color(0xFFC4B896),
    deepSpaceColors: [
      Color(0xFF060607),
      Color(0xFF0E0E10),
      Color(0xFF0A0A0C),
      Color(0xFF040405),
    ],
    deepSpaceStops: [0.0, 0.38, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFFFF4D0),
      Color(0xFFE8D078),
      Color(0xFFD8A8C8),
      Color(0xFFF0D8A0),
      Color(0xFFE8C8E0),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF161618),
    nebulaBlobTeal: Color(0xFF18161A),
    lightLeakAccentOpacity: 0.055,
    lightLeakMagentaOpacity: 0.045,
    brandCyan: Color(0xFFE8D078),
  );

  /// Warm amber & umber — canvas-style chrome with a heavy brushed-gold wash (not flat).
  static const TeamPalette gildedBrushTheme = TeamPalette(
    canvas: Color(0xFF0A0907),
    surface: Color(0xFF15120E),
    surfaceElevated: Color(0xFF1E1A14),
    topBarFill: Color(0xFF0D0B08),
    topBarFillEnd: Color(0xFF16130F),
    accent: Color(0xFFD4B078),
    neonLine: Color(0xFFE8D8C0),
    nebulaViolet: Color(0xFF7A5038),
    nebulaMagenta: Color(0xFFB07048),
    nebulaWash: Color(0xFFC9A060),
    deepSpaceColors: [
      Color(0xFF060504),
      Color(0xFF100E0A),
      Color(0xFF0B0907),
      Color(0xFF040403),
    ],
    deepSpaceStops: [0.0, 0.38, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFF0E4D0),
      Color(0xFFD4B078),
      Color(0xFF9A7048),
      Color(0xFFC89868),
      Color(0xFFE0C8A8),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF181410),
    nebulaBlobTeal: Color(0xFF1A1612),
    lightLeakAccentOpacity: 0.045,
    lightLeakMagentaOpacity: 0.032,
    brandCyan: Color(0xFFD4B078),
  );

  /// Cool teal & slate — canvas-style chrome with a heavy brushed-steel wash (not flat).
  static const TeamPalette inkBrushTheme = TeamPalette(
    canvas: Color(0xFF06090C),
    surface: Color(0xFF0E141A),
    surfaceElevated: Color(0xFF161E28),
    topBarFill: Color(0xFF080C10),
    topBarFillEnd: Color(0xFF101820),
    accent: Color(0xFF7BA3B8),
    neonLine: Color(0xFFB8D0E0),
    nebulaViolet: Color(0xFF4A6070),
    nebulaMagenta: Color(0xFF5C7A8C),
    nebulaWash: Color(0xFF6B8FA0),
    deepSpaceColors: [
      Color(0xFF040608),
      Color(0xFF0C1016),
      Color(0xFF080A10),
      Color(0xFF030508),
    ],
    deepSpaceStops: [0.0, 0.38, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFC8DCE8),
      Color(0xFF7BA3B8),
      Color(0xFF506878),
      Color(0xFF6A8A9C),
      Color(0xFFA0B8C8),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF121820),
    nebulaBlobTeal: Color(0xFF141C24),
    lightLeakAccentOpacity: 0.04,
    lightLeakMagentaOpacity: 0.028,
    brandCyan: Color(0xFF7BA3B8),
  );

  /// Warm charcoal shell + coral / ember focus — second app theme (with [AppVisualTeam.ember]).
  static const TeamPalette ember = TeamPalette(
    canvas: Color(0xFF10080C),
    surface: Color(0xFF1A1014),
    surfaceElevated: Color(0xFF26181E),
    topBarFill: Color(0xFF120A0E),
    topBarFillEnd: Color(0xFF1A1016),
    accent: Color(0xFFFF8A65),
    neonLine: Color(0xFFFFB8A0),
    nebulaViolet: Color(0xFF9B4B6A),
    nebulaMagenta: Color(0xFFFF6B8A),
    nebulaWash: Color(0xFFFF9E6E),
    deepSpaceColors: [
      Color(0xFF080410),
      Color(0xFF120A0E),
      Color(0xFF0A0608),
      Color(0xFF040204),
    ],
    deepSpaceStops: [0.0, 0.35, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFFFD4C4),
      Color(0xFFFF8A65),
      Color(0xFFFF6B5C),
      Color(0xFFFF9E6E),
      Color(0xFFFFB3A0),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF2A1020),
    nebulaBlobTeal: Color(0xFF1A1018),
    lightLeakAccentOpacity: 0.1,
    lightLeakMagentaOpacity: 0.07,
    brandCyan: Color(0xFFFF8A65),
  );

  /// **Nocturne** — deep purple–rose dark shell; TV focus follows [neonLine] / [defaultFocusRingColor].
  static const TeamPalette nocturne = TeamPalette(
    canvas: Color(0xFF080510),
    surface: Color(0xFF120C18),
    surfaceElevated: Color(0xFF1A1222),
    topBarFill: Color(0xFF0A0612),
    topBarFillEnd: Color(0xFF100A18),
    accent: Color(0xFFFF8AE8),
    neonLine: Color(0xFFFF4DC4),
    nebulaViolet: Color(0xFF7A4A9A),
    nebulaMagenta: Color(0xFFFF2A9A),
    nebulaWash: Color(0xFFD060C8),
    deepSpaceColors: [
      Color(0xFF040308),
      Color(0xFF0C0812),
      Color(0xFF08060C),
      Color(0xFF020204),
    ],
    deepSpaceStops: [0.0, 0.35, 0.72, 1.0],
    neonRimColors: [
      Color(0xFFFFB0F0),
      Color(0xFFFF4DDE),
      Color(0xFFFF2A9A),
      Color(0xFFE040FB),
      Color(0xFFFF8AE8),
    ],
    neonRimStops: [0.0, 0.28, 0.52, 0.78, 1.0],
    nebulaBlobMidCyan: Color(0xFF241028),
    nebulaBlobTeal: Color(0xFF1C0E2A),
    lightLeakAccentOpacity: 0.09,
    lightLeakMagentaOpacity: 0.075,
    brandCyan: Color(0xFFFF6BEB),
  );
}
