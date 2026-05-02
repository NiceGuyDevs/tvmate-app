import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../focus/tv_focusable.dart';

/// TV-safe color editing: **only** [TvFocusable] − / + rows (no sliders, no gestures).
/// Small ring is decorative ([IgnorePointer]) so D-pad traversal never gets stuck.
class HeroColorTvSteppers extends StatelessWidget {
  const HeroColorTvSteppers({
    super.key,
    required this.title,
    required this.color,
    required this.onColorChanged,
    required this.hueRowLabel,
    required this.satRowLabel,
    required this.briRowLabel,
    required this.hueExplain,
    required this.satExplain,
    required this.briExplain,
    this.showPreviewRing = true,
  });

  final String title;
  final Color color;
  final ValueChanged<Color> onColorChanged;
  final String hueRowLabel;
  final String satRowLabel;
  final String briRowLabel;
  final String hueExplain;
  final String satExplain;
  final String briExplain;
  final bool showPreviewRing;

  void _apply(double h, double s, double v) {
    onColorChanged(
      HSVColor.fromAHSV(
        1,
        h.clamp(0.0, 360.0),
        s.clamp(0.0, 1.0),
        v.clamp(0.0, 1.0),
      ).toColor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    final theme = Theme.of(context);
    final satP = (hsv.saturation * 100).round();
    final valP = (hsv.value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  height: 1.05,
                ),
              ),
            ),
            if (showPreviewRing)
              IgnorePointer(
                child: CustomPaint(
                  size: const Size(26, 26),
                  painter: _MiniHueRingPainter(
                    hue: hsv.hue,
                    center: HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, hsv.value)
                        .toColor(),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        _StepRow(
          label: hueRowLabel,
          explain: hueExplain,
          value: '${hsv.hue.round()}°',
          onDec: () => _apply(hsv.hue - 4, hsv.saturation, hsv.value),
          onInc: () => _apply(hsv.hue + 4, hsv.saturation, hsv.value),
        ),
        _StepRow(
          label: satRowLabel,
          explain: satExplain,
          value: '$satP',
          onDec: () => _apply(
            hsv.hue,
            (hsv.saturation - 0.05).clamp(0.0, 1.0),
            hsv.value,
          ),
          onInc: () => _apply(
            hsv.hue,
            (hsv.saturation + 0.05).clamp(0.0, 1.0),
            hsv.value,
          ),
        ),
        _StepRow(
          label: briRowLabel,
          explain: briExplain,
          value: '$valP',
          onDec: () => _apply(
            hsv.hue,
            hsv.saturation,
            (hsv.value - 0.05).clamp(0.0, 1.0),
          ),
          onInc: () => _apply(
            hsv.hue,
            hsv.saturation,
            (hsv.value + 0.05).clamp(0.0, 1.0),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.explain,
    required this.value,
    required this.onDec,
    required this.onInc,
  });

  final String label;
  final String explain;
  final String value;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              '$label · $explain',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 8,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
          TvFocusable(
            onActivate: onDec,
            focusPadding: const EdgeInsets.all(2),
            focusedBorderWidth: 1.35,
            child: const _StepBtn(icon: Icons.remove_rounded),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
          TvFocusable(
            onActivate: onInc,
            focusPadding: const EdgeInsets.all(2),
            focusedBorderWidth: 1.35,
            child: const _StepBtn(icon: Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.92)),
    );
  }
}

class _MiniHueRingPainter extends CustomPainter {
  _MiniHueRingPainter({
    required this.hue,
    required this.center,
  });

  final double hue;
  final Color center;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - 1;
    final inner = outer * 0.45;

    final ring = Path()
      ..addOval(Rect.fromCircle(center: c, radius: outer))
      ..addOval(Rect.fromCircle(center: c, radius: inner))
      ..fillType = PathFillType.evenOdd;

    final sweep = SweepGradient(
      center: Alignment.center,
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: const [
        Color(0xFFFF0000),
        Color(0xFFFFFF00),
        Color(0xFF00FF00),
        Color(0xFF00FFFF),
        Color(0xFF0000FF),
        Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ],
    ).createShader(Rect.fromCircle(center: c, radius: outer));

    canvas.save();
    canvas.clipPath(ring);
    canvas.drawCircle(c, outer, Paint()..shader = sweep);
    canvas.restore();

    canvas.drawCircle(
      c,
      inner - 0.5,
      Paint()
        ..color = center
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniHueRingPainter oldDelegate) {
    return oldDelegate.hue != hue || oldDelegate.center != center;
  }
}
