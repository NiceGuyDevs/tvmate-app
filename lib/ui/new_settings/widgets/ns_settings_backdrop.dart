import 'package:flutter/material.dart';

import '../new_settings_theme.dart';

/// Port of the new-settings `body` background (see `settings.html`):
/// `var(--bg)` plus the two ambient radial gradients. Used by
/// [NewSettingsScreen] and by full-screen routes (Appearance, hero editor)
/// so the look matches the sealed island.
class NsSettingsBackdrop extends StatelessWidget {
  const NsSettingsBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: NsColors.bg),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.72, -1.2),
                radius: 0.7,
                colors: [NsColors.accentGlow, Color(0x00000000)],
                stops: [0.0, 0.6],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-1.2, 1.2),
                radius: 0.75,
                colors: [Color(0x147AA2F7), Color(0x00000000)],
                stops: [0.0, 0.6],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
