/// Theme island for the new settings surface.
///
/// Builds a [TeamPalette] whose every field is derived from the HTML tokens
/// in `new_settings_theme.dart`, so any widget inside this surface that
/// reads `context.teamPalette` (directly or transitively — e.g. via a
/// shared component that happens to pull the accent color from the theme)
/// sees the HTML's cyan look regardless of which team the user has active
/// elsewhere in the app.
///
/// We don't rely on this — the new settings surface uses its own
/// [NsFocusable] which never reads the team palette — but shipping a
/// defensive override lets us keep the "New Setting is a sealed island"
/// promise even if a future edit accidentally pulls in a shared widget
/// that reads the palette.
///
/// The override is scoped: wrap the screen body in
/// `Theme(data: nsIslandThemeData(context), child: ...)` and descendants
/// see cyan. Nothing outside that subtree changes.
library;

import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';
import 'new_settings_theme.dart';

/// HTML-accurate [TeamPalette] for the new settings subtree. All colors
/// trace back to `settings.html`'s `:root` block.
class NsIslandPalette {
  const NsIslandPalette._();

  static const TeamPalette instance = TeamPalette(
    // Surfaces — straight from the CSS root vars.
    canvas: NsColors.bg,
    surface: NsColors.surface,
    surfaceElevated: NsColors.surface2,
    topBarFill: NsColors.bg2,
    topBarFillEnd: NsColors.bg,

    // Accent — HTML cyan. All derivatives pull from the same hue so the
    // team palette's helper getters (`railCardFocusShadow` etc., which
    // build box-shadows from `accent` + `nebulaMagenta` + `nebulaWash`)
    // produce cyan-only glows without magenta / violet contamination.
    accent: NsColors.accent,
    neonLine: NsColors.accentLine,
    nebulaViolet: NsColors.accent2,
    nebulaMagenta: NsColors.accent2,
    nebulaWash: NsColors.accentSoft,

    // Backdrop gradients — these feed the app-wide [TeamShellBackdrop],
    // which we explicitly draw over with our own HTML radial-gradients
    // inside [NewSettingsScreen]. Kept as sane cyan fallbacks so any
    // descendant that still reads them paints cyan instead of team color.
    deepSpaceColors: [NsColors.bg, NsColors.bg2],
    deepSpaceStops: [0.0, 1.0],
    neonRimColors: [NsColors.accentSoft, Color(0x00000000)],
    neonRimStops: [0.0, 1.0],

    nebulaBlobMidCyan: NsColors.accent,
    nebulaBlobTeal: NsColors.accent2,

    lightLeakAccentOpacity: 0.14,
    lightLeakMagentaOpacity: 0.08,

    brandCyan: NsColors.accent,
  );
}

/// Returns a [ThemeData] that injects the HTML-cyan [NsIslandPalette] over
/// the app's current theme, replacing only the [TeamPaletteTheme]
/// extension. Everything else on [ThemeData] (text theme, icon theme,
/// material color swatches, etc.) is inherited unchanged so the surface
/// still looks and feels native inside the shell.
ThemeData nsIslandThemeData(BuildContext context) {
  final base = Theme.of(context);
  // Keep all other extensions the ambient theme carries; only swap the
  // TeamPaletteTheme one for our cyan variant.
  //
  // Built by explicit .add() instead of a spread literal: some Flutter
  // versions infer the spread target's element type as
  // `ThemeExtension<ThemeExtension<dynamic>>` (a quirk of the recursive
  // `ThemeExtension<T extends ThemeExtension<T>>` generic bound), which
  // rejects `ThemeExtension<dynamic>` elements on release builds even
  // though the analyzer accepts it. This longer form sidesteps that.
  final List<ThemeExtension<dynamic>> kept = <ThemeExtension<dynamic>>[];
  for (final e in base.extensions.values) {
    if (e is! TeamPaletteTheme) kept.add(e);
  }
  kept.add(const TeamPaletteTheme(palette: NsIslandPalette.instance));
  return base.copyWith(
    extensions: kept,
    // Default Material SnackBar is off-theme; [NsMessageBar] draws its own
    // surface. Keep the host bar transparent so only Ns pixels show.
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
