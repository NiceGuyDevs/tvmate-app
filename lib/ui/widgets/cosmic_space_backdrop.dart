import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';

/// Full-screen deep space: gradient void, nebula washes, starfield, soft light leaks.
/// Place behind transparent shell / browse content (see [MainShellScreen]).
///
/// [lite]: gradient only (no starfield/nebula) — for performance-optimized tier on weak TV devices.
class CosmicSpaceBackdrop extends StatelessWidget {
  const CosmicSpaceBackdrop({
    super.key,
    this.lite = false,
  });

  final bool lite;

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    if (lite) {
      return RepaintBoundary(
        child: _DeepSpaceBaseGradient(palette: p),
      );
    }
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          _DeepSpaceBaseGradient(palette: p),
          _NebulaLayer(palette: p),
          Positioned.fill(
            child: CustomPaint(
              painter: _StarfieldPainter(),
            ),
          ),
          _LightLeakVeil(palette: p),
        ],
      ),
    );
  }
}

class _DeepSpaceBaseGradient extends StatelessWidget {
  const _DeepSpaceBaseGradient({required this.palette});

  final TeamPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.deepSpaceColors,
          stops: palette.deepSpaceStops,
        ),
      ),
    );
  }
}

class _NebulaLayer extends StatelessWidget {
  const _NebulaLayer({required this.palette});

  final TeamPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: const Alignment(0.9, -0.55),
          child: _nebulaBlob(
            diameter: 460,
            inner: p.nebulaViolet.withOpacity(0.48),
            mid: p.nebulaViolet.withOpacity(0.18),
          ),
        ),
        Align(
          alignment: const Alignment(-0.75, 0.35),
          child: _nebulaBlob(
            diameter: 520,
            inner: p.nebulaWash.withOpacity(0.35),
            mid: p.nebulaBlobMidCyan.withOpacity(0.2),
          ),
        ),
        Align(
          alignment: const Alignment(0.2, 0.85),
          child: _nebulaBlob(
            diameter: 380,
            inner: p.nebulaMagenta.withOpacity(0.22),
            mid: Colors.transparent,
          ),
        ),
        Align(
          alignment: const Alignment(-0.2, -0.25),
          child: _nebulaBlob(
            diameter: 320,
            inner: p.nebulaBlobTeal.withOpacity(0.3),
            mid: Colors.transparent,
          ),
        ),
      ],
    );
  }

  static Widget _nebulaBlob({
    required double diameter,
    required Color inner,
    required Color mid,
  }) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              inner,
              mid,
              Colors.transparent,
            ],
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
      ),
    );
  }
}

class _LightLeakVeil extends StatelessWidget {
  const _LightLeakVeil({required this.palette});

  final TeamPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              p.accent.withOpacity(p.lightLeakAccentOpacity),
              Colors.transparent,
              p.nebulaMagenta.withOpacity(p.lightLeakMagentaOpacity),
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Deterministic star positions (normalized) — cheap, no animation.
class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter() : _stars = _buildStars();

  static const int _count = 520;
  final List<_Star> _stars;

  static List<_Star> _buildStars() {
    final r = math.Random(7);
    return List.generate(_count, (_) {
      return _Star(
        nx: r.nextDouble(),
        ny: r.nextDouble(),
        radius: r.nextDouble() * 1.35 + 0.35,
        opacity: r.nextDouble() * 0.55 + 0.12,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final o = Offset(s.nx * size.width, s.ny * size.height);
      final paint = Paint()
        ..color = Colors.white.withOpacity(s.opacity)
        ..isAntiAlias = true;
      canvas.drawCircle(o, s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Star {
  const _Star({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.opacity,
  });

  final double nx;
  final double ny;
  final double radius;
  final double opacity;
}
