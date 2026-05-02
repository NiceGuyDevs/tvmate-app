import 'package:flutter/material.dart';

/// Full-screen background for the **Ember** theme: deep warm base + soft coral /
/// rose radials (same layout idea as [SettingsStyleBackdrop]).
class EmberFieldBackdrop extends StatelessWidget {
  const EmberFieldBackdrop({super.key});

  static const Color _kBg = Color(0xFF10080C);
  /// ~rgba(255, 138, 101, 0.22) top-tr corner wash
  static const Color _kEmberGlow = Color(0x38FF8A65);
  /// ~rgba(255, 107, 138, 0.08) opposite corner
  static const Color _kRoseWash = Color(0x14FF6B8A);

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _kBg),
        _EmberRadialLayer(
          center: Alignment(0.72, -0.9),
          radius: 1.25,
          inner: _kEmberGlow,
        ),
        _EmberRadialLayer(
          center: Alignment(-0.85, 0.95),
          radius: 1.15,
          inner: _kRoseWash,
        ),
      ],
    );
  }
}

class _EmberRadialLayer extends StatelessWidget {
  const _EmberRadialLayer({
    required this.center,
    required this.radius,
    required this.inner,
  });

  final Alignment center;
  final double radius;
  final Color inner;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [inner, const Color(0x00000000)],
          stops: const [0, 0.6],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
