import 'package:flutter/material.dart';

/// Full-screen background from [Html Sampels/settings.html] `body` (v0.2):
/// - `background:`
///   `radial-gradient(900px 480px at 86% -10%, var(--accent-glow), transparent 60%),`
///   `radial-gradient(900px 600px at -10% 110%, rgba(122, 162, 247, 0.08), transparent 60%),`
///   `var(--bg);`
/// with `--bg: #0A0D13`, `--accent-glow: rgba(77, 208, 225, 0.22)`.
class SettingsStyleBackdrop extends StatelessWidget {
  const SettingsStyleBackdrop({super.key});

  static const Color _kBg = Color(0xFF0A0D13);
  /// rgba(77, 208, 225, 0.22)
  static const Color _kAccentGlow = Color(0x384DD0E1);
  /// rgba(122, 162, 247, 0.08)
  static const Color _kBlueWash = Color(0x147AA2F7);

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _kBg),
        _SettingsRadialLayer(
          center: Alignment(0.72, -0.9),
          radius: 1.25,
          inner: _kAccentGlow,
        ),
        _SettingsRadialLayer(
          center: Alignment(-0.85, 0.95),
          radius: 1.15,
          inner: _kBlueWash,
        ),
      ],
    );
  }
}

class _SettingsRadialLayer extends StatelessWidget {
  const _SettingsRadialLayer({
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
