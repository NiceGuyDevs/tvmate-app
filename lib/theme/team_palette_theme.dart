import 'package:flutter/material.dart';

import 'team_palette.dart';

/// Carries [TeamPalette] on [ThemeData] for `context.teamPalette`.
@immutable
class TeamPaletteTheme extends ThemeExtension<TeamPaletteTheme> {
  const TeamPaletteTheme({required this.palette});

  final TeamPalette palette;

  @override
  TeamPaletteTheme copyWith({TeamPalette? palette}) {
    return TeamPaletteTheme(palette: palette ?? this.palette);
  }

  @override
  TeamPaletteTheme lerp(ThemeExtension<TeamPaletteTheme>? other, double t) {
    return this;
  }
}

extension TeamPaletteContext on BuildContext {
  TeamPalette get teamPalette {
    return Theme.of(this).extension<TeamPaletteTheme>()?.palette ??
        TeamPalette.canvasTheme;
  }
}
