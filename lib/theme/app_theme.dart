import 'package:flutter/material.dart';

import 'team_palette.dart';
import 'team_palette_theme.dart';

/// Premium dark TV baseline — single soft accent, image-first layouts.
abstract final class AppTheme {
  /// Deep space blue-black (global scaffold / browse backdrop).
  static const Color canvas = Color(0xFF060818);

  static const Color surface = Color(0xFF0C1226);
  static const Color surfaceElevated = Color(0xFF141C38);

  /// Top navigation strip (replaces legacy sidebar fill).
  static const Color topBarFill = Color(0xFF080E24);
  static const Color topBarFillEnd = Color(0xFF0C1034);

  /// Alias for older call sites (sidebar removed; same as [topBarFill]).
  static const Color sidebarFill = topBarFill;

  /// Neon cyan — pills, focus chrome, subtle glows.
  static const Color accent = Color(0xFF3DD9FF);

  /// Hairline / frame glow on chrome (cyan-violet edge).
  static const Color neonLine = Color(0xFF5AE8FF);

  /// Cosmic backdrop washes (purple / pink clouds in [CosmicSpaceBackdrop]).
  static const Color nebulaViolet = Color(0xFF6B3DFF);
  static const Color nebulaMagenta = Color(0xFFC43BFF);
  static const Color nebulaCyanWash = Color(0xFF2A8CFF);

  /// Alternate “mood board” chrome when you want magenta-primary instead of cyan.
  static const Color accentMagenta = Color(0xFFE040FB);

  /// Text fields / high-contrast focus from brand mark.
  static const Color brandCyan = Color(0xFF00D4FF);

  /// Smoked glass behind text on top of the starfield (loading / empty states).
  static Color get glassPanelFill =>
      const Color(0xFF050818).withOpacity(0.62);

  static const Color textMuted = Color(0xFF8E8E93);
  static const Color textSecondary = Color(0xFFB0B0B8);

  static const double cardRadius = 12;
  static const double cardRadiusLarge = 14;

  /// Focus chrome on [TvFocusable] — slightly tighter than legacy 16.
  static const double focusBorderRadius = 14;

  /// TV cards: slightly “lifted” rest state vs canvas.
  static List<BoxShadow> railCardRestShadow = [
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

  /// Extra elevation when a rail tile is focused (combined with scale in [TvFocusable]).
  static List<BoxShadow> railCardFocusShadow = [
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
      color: nebulaCyanWash.withOpacity(0.2),
      blurRadius: 28,
      spreadRadius: 0,
      offset: const Offset(-4, 8),
    ),
  ];

  static List<BoxShadow> heroPanelShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.65),
      blurRadius: 36,
      spreadRadius: -8,
      offset: const Offset(0, 18),
    ),
  ];

  /// Outer neon bloom — mixed hues (not a flat single-color glow).
  static List<BoxShadow> heroNeonGlow = [
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
      color: nebulaCyanWash.withOpacity(0.18),
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

  /// Rim + bloom for [NeonGradientFrame] wrappers.
  static List<BoxShadow> neonFrameVariedShadows = [
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
      color: nebulaCyanWash.withOpacity(0.15),
      blurRadius: 18,
      spreadRadius: -1,
      offset: const Offset(-4, 0),
    ),
  ];

  /// Stronger outer bloom for Movies / Series browse heroes.
  static List<BoxShadow> neonFrameBrowseHeroShadows = [
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
      color: nebulaCyanWash.withOpacity(0.28),
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

  /// Floating glass card on starfield (catalog status, etc.).
  static List<BoxShadow> glassFloatShadow = [
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

  /// Scale when focused (rail posters, buttons).
  static const double focusScale = 1.075;

  /// Subtle vertical parallax as a fraction of child height ([AnimatedSlide]).
  static const double focusParallaxSlide = 0.014;

  static const Duration focusAnimationDuration = Duration(milliseconds: 340);
  static const Curve focusAnimationCurve = Curves.easeOutCubic;

  /// Hero / row content cross-fades (slightly slower than focus for a cinematic feel).
  static const Duration contentCrossFadeDuration = Duration(milliseconds: 420);
  static const Curve contentCrossFadeCurve = Curves.easeInOutCubic;

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: surface,
      primary: accent,
      secondary: accent,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      error: Color(0xFFFF5252),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.6,
          height: 1.12,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.15,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.25,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFE8E8EC),
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.42,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: textMuted,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.35,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Theme + [TeamPaletteTheme] for the active visual team.
  static ThemeData themeForPalette(TeamPalette palette) {
    final scheme = ColorScheme.dark(
      surface: palette.surface,
      primary: palette.accent,
      secondary: palette.accent,
      onPrimary: Colors.white,
      onSurface: Colors.white,
      error: const Color(0xFFFF5252),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
      extensions: <ThemeExtension<dynamic>>[
        TeamPaletteTheme(palette: palette),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: TextTheme(
        displaySmall: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.6,
          height: 1.12,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.15,
          height: 1.2,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.25,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          color: Color(0xFFE8E8EC),
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: TeamPalette.textSecondary,
          height: 1.42,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          color: TeamPalette.textMuted,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.35,
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
