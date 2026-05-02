import 'package:flutter/material.dart';

import '../../theme/team_palette.dart';

/// Heavy “brushed metal / wash” shell behind content — same role as flat [canvas] gradient,
/// but with layered soft strokes (not a flat solid).
class BrushedCanvasBackdrop extends StatelessWidget {
  const BrushedCanvasBackdrop({
    super.key,
    required this.palette,
    required this.warmTone,
  });

  final TeamPalette palette;
  final bool warmTone;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BrushedCanvasPainter(
          palette: palette,
          warmTone: warmTone,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BrushedCanvasPainter extends CustomPainter {
  _BrushedCanvasPainter({
    required this.palette,
    required this.warmTone,
  });

  final TeamPalette palette;
  final bool warmTone;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.canvas,
          Color.lerp(palette.canvas, palette.surface, 0.55)!,
          palette.surfaceElevated,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    final strokes = warmTone ? _warmStrokes() : _coolStrokes();
    for (final s in strokes) {
      canvas.save();
      canvas.translate(s.dx * size.width, s.dy * size.height);
      canvas.rotate(s.angle);
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.alpha)
        ..blendMode = s.mode
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur);
      final w = size.width * s.w;
      final h = size.height * s.h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(h * 0.48),
        ),
        paint,
      );
      canvas.restore();
    }

    // Second pass: tighter, slightly harder strokes for “brush grain”
    final grain = warmTone ? _warmGrain() : _coolGrain();
    for (final s in grain) {
      canvas.save();
      canvas.translate(s.dx * size.width, s.dy * size.height);
      canvas.rotate(s.angle);
      final paint = Paint()
        ..color = s.color.withValues(alpha: s.alpha)
        ..blendMode = BlendMode.softLight
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur);
      final w = size.width * s.w;
      final h = size.height * s.h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(h * 0.42),
        ),
        paint,
      );
      canvas.restore();
    }

    // Veil: subtle corner depth (keeps it elegant, not noisy)
    final veil = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomRight,
        radius: 1.15,
        colors: [
          Colors.transparent,
          Color.lerp(palette.canvas, Colors.black, 0.35)!
              .withValues(alpha: 0.38),
        ],
        stops: const [0.35, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, veil);
  }

  List<_Stroke> _warmStrokes() {
    final a = palette.accent;
    final w = palette.nebulaWash;
    final u = palette.nebulaViolet;
    final m = palette.nebulaMagenta;
    return [
      _Stroke(0.12, 0.18, 0.92, 0.14, -0.35, Color.lerp(a, w, 0.4)!, 0.22, 28, BlendMode.softLight),
      _Stroke(0.55, 0.08, 0.88, 0.11, 0.22, Color.lerp(w, u, 0.35)!, 0.18, 24, BlendMode.softLight),
      _Stroke(0.78, 0.42, 0.72, 0.18, -0.18, Color.lerp(a, m, 0.5)!, 0.2, 32, BlendMode.plus),
      _Stroke(0.22, 0.62, 0.85, 0.16, 0.42, Color.lerp(u, a, 0.25)!, 0.16, 26, BlendMode.softLight),
      _Stroke(0.65, 0.72, 0.9, 0.12, -0.28, w, 0.14, 22, BlendMode.softLight),
      _Stroke(0.38, 0.38, 0.95, 0.1, 0.08, Color.lerp(a, u, 0.55)!, 0.12, 20, BlendMode.overlay),
      _Stroke(0.88, 0.78, 0.55, 0.2, 0.55, m, 0.15, 30, BlendMode.softLight),
      _Stroke(0.05, 0.85, 0.75, 0.14, -0.5, u, 0.18, 34, BlendMode.plus),
      _Stroke(0.48, 0.52, 0.82, 0.09, -0.08, a, 0.1, 18, BlendMode.softLight),
    ];
  }

  List<_Stroke> _coolStrokes() {
    final a = palette.accent;
    final w = palette.nebulaWash;
    final v = palette.nebulaViolet;
    final m = palette.nebulaMagenta;
    return [
      _Stroke(0.15, 0.22, 0.9, 0.13, 0.28, Color.lerp(a, v, 0.45)!, 0.2, 26, BlendMode.softLight),
      _Stroke(0.62, 0.12, 0.85, 0.12, -0.32, Color.lerp(w, m, 0.4)!, 0.17, 24, BlendMode.softLight),
      _Stroke(0.82, 0.48, 0.68, 0.17, 0.15, Color.lerp(a, w, 0.35)!, 0.19, 30, BlendMode.plus),
      _Stroke(0.28, 0.68, 0.88, 0.14, -0.42, v, 0.15, 28, BlendMode.softLight),
      _Stroke(0.72, 0.75, 0.78, 0.11, 0.38, m, 0.13, 22, BlendMode.softLight),
      _Stroke(0.42, 0.45, 0.92, 0.1, -0.12, Color.lerp(a, v, 0.6)!, 0.11, 19, BlendMode.overlay),
      _Stroke(0.08, 0.55, 0.7, 0.18, 0.48, w, 0.16, 32, BlendMode.softLight),
      _Stroke(0.92, 0.65, 0.52, 0.16, -0.4, Color.lerp(v, a, 0.3)!, 0.14, 26, BlendMode.plus),
      _Stroke(0.5, 0.82, 0.8, 0.1, -0.22, a, 0.09, 17, BlendMode.softLight),
    ];
  }

  List<_Stroke> _warmGrain() {
    final a = palette.accent;
    final u = palette.nebulaViolet;
    return [
      _Stroke(0.33, 0.28, 0.45, 0.04, 0.65, Color.lerp(a, u, 0.5)!, 0.08, 8, BlendMode.softLight),
      _Stroke(0.71, 0.33, 0.4, 0.035, -0.7, u, 0.07, 7, BlendMode.softLight),
      _Stroke(0.18, 0.72, 0.5, 0.038, 0.12, a, 0.075, 7, BlendMode.softLight),
      _Stroke(0.6, 0.58, 0.42, 0.032, -0.55, u, 0.065, 6, BlendMode.softLight),
    ];
  }

  List<_Stroke> _coolGrain() {
    final a = palette.accent;
    final v = palette.nebulaViolet;
    return [
      _Stroke(0.36, 0.31, 0.42, 0.038, -0.58, Color.lerp(a, v, 0.55)!, 0.075, 8, BlendMode.softLight),
      _Stroke(0.74, 0.36, 0.38, 0.034, 0.62, v, 0.068, 7, BlendMode.softLight),
      _Stroke(0.22, 0.76, 0.48, 0.036, -0.15, a, 0.072, 7, BlendMode.softLight),
      _Stroke(0.58, 0.62, 0.4, 0.03, 0.48, v, 0.06, 6, BlendMode.softLight),
    ];
  }

  @override
  bool shouldRepaint(covariant _BrushedCanvasPainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.warmTone != warmTone;
  }
}

class _Stroke {
  const _Stroke(
    this.dx,
    this.dy,
    this.w,
    this.h,
    this.angle,
    this.color,
    this.alpha,
    this.blur,
    this.mode,
  );

  final double dx;
  final double dy;
  final double w;
  final double h;
  final double angle;
  final Color color;
  final double alpha;
  final double blur;
  final BlendMode mode;
}
