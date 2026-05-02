import 'package:flutter/material.dart';

import 'brushed_slate_panel_fill.dart';

/// [BrushedSlatePanelFill] plus the same stacked grain as the VOD subtitle panels.
/// Shared so picker + style editor match the reference brushed-metal look.
class VodBrushedPanelFill extends StatelessWidget {
  const VodBrushedPanelFill({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const BrushedSlatePanelFill(),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.76,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.085),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.13),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.065),
                      Colors.black.withValues(alpha: 0.11),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.18, 0.34, 0.5, 0.62, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.66,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1.0, -0.15),
                    end: const Alignment(1.0, 0.2),
                    colors: [
                      Colors.transparent,
                      const Color(0xFF8B93A8).withValues(alpha: 0.16),
                      Colors.transparent,
                      const Color(0xFF1a1d24).withValues(alpha: 0.21),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.085),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.12, 0.28, 0.44, 0.58, 0.76, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0.4, -1.0),
                    end: const Alignment(-0.35, 1.0),
                    colors: [
                      Colors.transparent,
                      const Color(0xFF4a5060).withValues(alpha: 0.24),
                      Colors.transparent,
                      const Color(0xFF2a2f3a).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 0.52, 0.72, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.065),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.095),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.052),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.075),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.28, 0.4, 0.52, 0.64, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.85, 0.15),
                    end: const Alignment(0.75, -0.1),
                    colors: [
                      Colors.transparent,
                      const Color(0xFF9aa0b0).withValues(alpha: 0.06),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.09),
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.22, 0.4, 0.55, 0.68, 0.82, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
