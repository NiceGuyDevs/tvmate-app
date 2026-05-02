import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';

/// Soft black/gray shifting washes with slow yellow ↔ pink motion (no starfield).
class MistBackdrop extends StatefulWidget {
  const MistBackdrop({super.key, required this.palette});

  final TeamPalette palette;

  @override
  State<MistBackdrop> createState() => _MistBackdropState();
}

class _MistBackdropState extends State<MistBackdrop>
    with TickerProviderStateMixin {
  late AnimationController _drift;
  late AnimationController _hue;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat(reverse: true);
    _hue = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    _hue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_drift, _hue]),
        builder: (context, _) {
          final td = _drift.value * 2 * math.pi;
          final th = _hue.value * 2 * math.pi;
          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              final c0 = p.canvas;
              final c1 = Color.lerp(p.canvas, p.surface, 0.55)!;
              final c2 = Color.lerp(p.surface, p.surfaceElevated, 0.5)!;
              final c3 = Color.lerp(p.canvas, p.surfaceElevated, 0.35)!;

              return Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: c0),
                  ...List<Widget>.generate(5, (i) {
                    final phase = td + i * 1.1;
                    final cx = w * (0.2 + 0.6 * math.sin(phase * 0.31 + i * 0.4));
                    final cy = h * (0.15 + 0.7 * math.cos(phase * 0.27 + i * 0.65));
                    final blobColors = [c1, c2, c3, c2, c1];
                    return Positioned(
                      left: cx - w * 0.48,
                      top: cy - h * 0.42,
                      width: w * 0.96,
                      height: h * 0.84,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                blobColors[i % 5].withValues(alpha: 0.42),
                                blobColors[i % 5].withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              math.sin(th * 0.9),
                              math.cos(th * 0.75),
                            ),
                            end: Alignment(
                              -math.sin(th * 0.85 + 0.4),
                              -math.cos(th * 0.8 + 0.3),
                            ),
                            colors: [
                              p.accent.withValues(
                                alpha: 0.045 + 0.035 * math.sin(th),
                              ),
                              p.nebulaMagenta.withValues(
                                alpha: 0.04 + 0.03 * math.cos(th * 1.15),
                              ),
                              p.accent.withValues(
                                alpha: 0.025 + 0.02 * math.sin(th * 1.3),
                              ),
                            ],
                            stops: const [0.0, 0.52, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                              math.cos(td * 0.5 + 1.0),
                              math.sin(td * 0.45),
                            ),
                            end: Alignment(
                              math.sin(td * 0.55),
                              -math.cos(td * 0.48 + 0.8),
                            ),
                            colors: [
                              p.nebulaMagenta.withValues(
                                alpha: 0.028 + 0.022 * math.sin(td * 1.2),
                              ),
                              p.accent.withValues(
                                alpha: 0.032 + 0.024 * math.cos(td),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
