import 'package:flutter/material.dart';

import '../../data/live_tv_hero_appearance_store.dart';

/// Brushed wash layer on top of the hero base gradient ([wash] alpha × intensity).
class HeroBrushOverlay extends StatelessWidget {
  const HeroBrushOverlay({
    super.key,
    required this.wash,
    required this.intensity01,
    required this.style,
  });

  final Color wash;
  final double intensity01;
  final int style;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(
        painter: _HeroBrushPainter(
          wash: wash,
          intensity: intensity01.clamp(0.0, 1.0),
          style: style.clamp(0, LiveTvHeroAppearanceStore.brushStyleMax),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeroBrushPainter extends CustomPainter {
  _HeroBrushPainter({
    required this.wash,
    required this.intensity,
    required this.style,
  });

  final Color wash;
  final double intensity;
  final int style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || intensity <= 0.001) return;
    final alphaCap = 0.52 * intensity;

    void stroke(
      double cx,
      double cy,
      double rw,
      double rh,
      double angle,
      double a,
      BlendMode mode,
      double blur,
    ) {
      canvas.save();
      canvas.translate(cx * size.width, cy * size.height);
      canvas.rotate(angle);
      final paint = Paint()
        ..color = wash.withValues(alpha: a)
        ..blendMode = mode
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      final w = size.width * rw;
      final h = size.height * rh;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.circular(h * 0.45),
        ),
        paint,
      );
      canvas.restore();
    }

    final s = style;
    final a1 = alphaCap * 0.9;
    final a2 = alphaCap * 0.55;
    if (s == 0) {
      stroke(0.15, 0.2, 0.92, 0.2, -0.38, a1, BlendMode.softLight, 14);
      stroke(0.72, 0.55, 0.78, 0.18, 0.2, a2, BlendMode.plus, 12);
      stroke(0.48, 0.75, 0.85, 0.12, -0.15, a2 * 0.8, BlendMode.softLight, 10);
    } else if (s == 1) {
      stroke(0.85, 0.15, 0.55, 0.22, 0.5, a1, BlendMode.softLight, 13);
      stroke(0.12, 0.72, 0.6, 0.2, -0.55, a2, BlendMode.plus, 11);
      stroke(0.5, 0.45, 0.7, 0.11, 0.1, a2 * 0.75, BlendMode.softLight, 9);
    } else if (s == 2) {
      stroke(0.5, 0.5, 0.95, 0.25, 0.0, a1 * 0.85, BlendMode.plus, 16);
      stroke(0.25, 0.35, 0.5, 0.15, 0.7, a2, BlendMode.softLight, 10);
      stroke(0.75, 0.65, 0.5, 0.14, -0.65, a2, BlendMode.softLight, 10);
    } else if (s == 3) {
      stroke(0.1, 0.55, 0.88, 0.14, -0.45, a1, BlendMode.softLight, 18);
      stroke(0.65, 0.25, 0.72, 0.2, 0.35, a2, BlendMode.plus, 14);
      stroke(0.42, 0.82, 0.8, 0.12, 0.25, a2 * 0.7, BlendMode.softLight, 11);
      stroke(0.88, 0.68, 0.45, 0.1, -0.2, a2 * 0.6, BlendMode.softLight, 8);
    } else if (s == 4) {
      stroke(0.22, 0.18, 0.35, 0.28, 0.85, a1 * 0.9, BlendMode.softLight, 11);
      stroke(0.78, 0.82, 0.38, 0.26, -0.75, a2, BlendMode.plus, 12);
      stroke(0.5, 0.48, 0.55, 0.16, 0.12, a2 * 0.8, BlendMode.softLight, 9);
    } else if (s == 5) {
      stroke(0.5, 0.12, 0.7, 0.14, 0.0, a1, BlendMode.plus, 13);
      stroke(0.12, 0.88, 0.55, 0.2, -0.4, a2 * 0.95, BlendMode.softLight, 14);
      stroke(0.88, 0.5, 0.4, 0.12, 0.55, a2 * 0.65, BlendMode.softLight, 8);
    } else if (s == 6) {
      stroke(0.35, 0.65, 0.9, 0.1, -0.9, a1 * 0.88, BlendMode.softLight, 20);
      stroke(0.62, 0.38, 0.65, 0.22, 0.95, a2, BlendMode.plus, 11);
      stroke(0.08, 0.42, 0.5, 0.18, 0.25, a2 * 0.72, BlendMode.softLight, 10);
      stroke(0.92, 0.72, 0.35, 0.1, -0.35, a2 * 0.55, BlendMode.softLight, 7);
    } else {
      stroke(0.48, 0.22, 0.88, 0.2, -0.25, a1 * 0.92, BlendMode.softLight, 15);
      stroke(0.18, 0.78, 0.72, 0.16, 0.42, a2, BlendMode.plus, 13);
      stroke(0.72, 0.55, 0.62, 0.14, -0.55, a2 * 0.78, BlendMode.softLight, 10);
      stroke(0.55, 0.88, 0.48, 0.11, 0.18, a2 * 0.62, BlendMode.softLight, 9);
      stroke(0.3, 0.45, 0.45, 0.1, 1.1, a2 * 0.5, BlendMode.softLight, 12);
    }
  }

  @override
  bool shouldRepaint(covariant _HeroBrushPainter oldDelegate) {
    return oldDelegate.wash != wash ||
        oldDelegate.intensity != intensity ||
        oldDelegate.style != style;
  }
}
