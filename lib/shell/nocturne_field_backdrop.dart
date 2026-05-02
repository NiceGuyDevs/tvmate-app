import 'package:flutter/material.dart';

/// Full-screen background for the **Nocturne** theme: near-black base + soft
/// magenta / violet radials (dark shell; same layout as [EmberFieldBackdrop]).
class NocturneFieldBackdrop extends StatelessWidget {
  const NocturneFieldBackdrop({super.key});

  static const Color _kBg = Color(0xFF080510);
  static const Color _kMagentaGlow = Color(0x38FF2A9A);
  static const Color _kVioletWash = Color(0x1A7A4A9A);

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _kBg),
        _NocturneRadialLayer(
          center: Alignment(0.75, -0.88),
          radius: 1.22,
          inner: _kMagentaGlow,
        ),
        _NocturneRadialLayer(
          center: Alignment(-0.82, 0.92),
          radius: 1.1,
          inner: _kVioletWash,
        ),
      ],
    );
  }
}

class _NocturneRadialLayer extends StatelessWidget {
  const _NocturneRadialLayer({
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
