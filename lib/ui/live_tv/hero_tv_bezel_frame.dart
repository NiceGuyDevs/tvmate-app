import 'package:flutter/material.dart';

/// Outer shell around the hero video — style + metallic “finish”.
class HeroTvBezelFrame extends StatelessWidget {
  const HeroTvBezelFrame({
    super.key,
    required this.child,
    this.style = 0,
    this.finish = 0,
  });

  final Widget child;

  /// 0 slim, 1 classic, 2 bold, 3 minimal.
  final int style;

  /// 0 graphite … 5 chrome — outer gradient only.
  final int finish;

  static const int styleMax = 3;
  static const int finishMax = 5;

  double get _padding => switch (style.clamp(0, styleMax)) {
        0 => 3,
        1 => 5,
        2 => 8,
        _ => 2,
      };

  double get _outerRadius => switch (style.clamp(0, styleMax)) {
        0 => 9,
        1 => 10,
        2 => 12,
        _ => 8,
      };

  List<Color> get _outerGradient => heroBezelOuterGradientColors(finish);

  /// Swatch / preview — same stops as the bezel shell.
  static List<Color> heroBezelOuterGradientColors(int finish) {
    switch (finish.clamp(0, finishMax)) {
      case 1:
        return const [Color(0xFF4A3828), Color(0xFF1C1410)];
      case 2:
        return const [Color(0xFF2C3A48), Color(0xFF101820)];
      case 3:
        return const [Color(0xFF403040), Color(0xFF180F18)];
      case 4:
        return const [Color(0xFF2A2A2E), Color(0xFF0E0E10)];
      case 5:
        return const [Color(0xFF5A5A68), Color(0xFF222228)];
      default:
        return const [Color(0xFF3d3d45), Color(0xFF1a1a1f)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = _padding;
    final outerR = _outerRadius;
    final g = _outerGradient;
    final blur = style == 2 ? 14.0 : 10.0;
    final offY = style == 2 ? 7.0 : 5.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(outerR),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: blur,
            offset: Offset(0, offY),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12 + style * 0.02),
          width: style == 3 ? 0.8 : 1,
        ),
      ),
      padding: EdgeInsets.all(pad),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(outerR - pad * 0.5),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.85),
            width: style == 2 ? 2.5 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04 + style * 0.015),
              blurRadius: 0,
              spreadRadius: 0,
              offset: const Offset(0, -0.5),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
