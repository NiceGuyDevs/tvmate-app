import 'package:flutter/material.dart';

/// Uniform tint over the whole hero — same [wash] and [intensity01] as brush,
/// but covers the entire area (no stroke texture). Use for “color on color”.
class HeroSolidWashOverlay extends StatelessWidget {
  const HeroSolidWashOverlay({
    super.key,
    required this.wash,
    required this.intensity01,
  });

  final Color wash;
  final double intensity01;

  @override
  Widget build(BuildContext context) {
    final t = intensity01.clamp(0.0, 1.0);
    if (t <= 0.001) return const SizedBox.shrink();
    return ClipRect(
      child: CustomPaint(
        painter: _HeroSolidWashPainter(
          wash: wash,
          intensity: t,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeroSolidWashPainter extends CustomPainter {
  _HeroSolidWashPainter({
    required this.wash,
    required this.intensity,
  });

  final Color wash;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Stronger than brush strokes so a dark base can read a full second color.
    final a = (0.14 + 0.82 * intensity).clamp(0.0, 0.96);
    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = wash.withValues(alpha: a)
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(rect, paint);
    final soft = Paint()
      ..color = wash.withValues(alpha: a * 0.45)
      ..blendMode = BlendMode.softLight;
    canvas.drawRect(rect, soft);
  }

  @override
  bool shouldRepaint(covariant _HeroSolidWashPainter oldDelegate) {
    return oldDelegate.wash != wash || oldDelegate.intensity != intensity;
  }
}
