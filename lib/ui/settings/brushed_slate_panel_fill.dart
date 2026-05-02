import 'package:flutter/material.dart';

/// Dark slate “brushed paint” interior for appearance cards (not theme-tinted).
/// Same palette family everywhere; extra layers read as fabric / brush strokes.
class BrushedSlatePanelFill extends StatelessWidget {
  const BrushedSlatePanelFill({super.key});

  static const Color _top = Color(0xFF2E323D);
  static const Color _bottom = Color(0xFF23272F);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF343946),
                _top,
                Color(0xFF2a2e38),
                _bottom,
                Color(0xFF1c1f26),
              ],
              stops: [0.0, 0.2, 0.48, 0.76, 1.0],
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1.0, -0.85),
                  end: const Alignment(0.65, 1.0),
                  colors: [
                    Colors.white.withValues(alpha: 0.11),
                    Colors.white.withValues(alpha: 0.02),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.14),
                  ],
                  stops: const [0.0, 0.28, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0.9, -0.5),
                  end: const Alignment(-0.6, 0.95),
                  colors: [
                    const Color(0xFF3d4452).withValues(alpha: 0.35),
                    Colors.transparent,
                    const Color(0xFF181a20).withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.55),
                radius: 1.35,
                colors: [
                  Colors.white.withValues(alpha: 0.07),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.62],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.35,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.55, 0.75),
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Extra brush: subtle purple–silver streaks (same dark family, more texture).
        Positioned.fill(
          child: Opacity(
            opacity: 0.38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.2, -1.0),
                  end: const Alignment(0.4, 0.2),
                  colors: [
                    const Color(0xFF8B7A9A).withValues(alpha: 0.07),
                    Colors.transparent,
                    const Color(0xFFD8D0E8).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.38, 0.62, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(0.85, 0.1),
                  end: const Alignment(-0.5, 0.95),
                  colors: [
                    Colors.transparent,
                    const Color(0xFF6B5B78).withValues(alpha: 0.09),
                    const Color(0xFFE8E4F0).withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.9, 0.4),
                  end: const Alignment(0.2, -0.3),
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.045),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
