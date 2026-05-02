import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// Reference: Html Sampels/vod-cc-button-and-subtitle-picker-navigate.html
const double kVodSubtitleDcardRadius = 18;

/// [vod-subtitle-style-editor-panel.html] `.style-card` uses 16px radius.
const double kVodSubtitleStyleEditorCardRadius = 16;

const Color kVodSubtitleDcardScrimColor = Color(0xFF020308);
const double kVodSubtitleDcardScrimOpacity = 0.45;
const double kVodSubtitleDcardScrimBlurSigma = 2;

const kVodSubtitleDcardBaseGradient = LinearGradient(
  begin: Alignment(0, -1),
  end: Alignment(0, 1.05),
  colors: [
    Color(0xFF1A212E),
    Color(0xFF131A26),
    Color(0xFF0C1018),
  ],
  stops: [0.0, 0.32, 1.0],
);

const Color kVodSubtitleDcardBorder = Color(0x1AFFFFFF);

const List<BoxShadow> kVodSubtitleDcardOuterShadow = [
  BoxShadow(
    color: Color(0xA6000000),
    blurRadius: 100,
    offset: Offset(0, 40),
  ),
];

/// Full-bleed dim + blur (`.ov-scrim` in the HTML reference).
class VodSubtitleDcardScrim extends StatelessWidget {
  const VodSubtitleDcardScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: kVodSubtitleDcardScrimBlurSigma,
            sigmaY: kVodSubtitleDcardScrimBlurSigma,
          ),
          child: ColoredBox(
            color: kVodSubtitleDcardScrimColor
                .withValues(alpha: kVodSubtitleDcardScrimOpacity),
          ),
        ),
      ),
    );
  }
}

/// Shadow + glass card body (`.d-card` base, texture, top hairline) + [child] on top.
class VodSubtitleDcardLayeredShell extends StatelessWidget {
  const VodSubtitleDcardLayeredShell({
    super.key,
    this.borderRadius = kVodSubtitleDcardRadius,
    this.outerShadow = kVodSubtitleDcardOuterShadow,
    required this.child,
  });

  final double borderRadius;
  final List<BoxShadow> outerShadow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: outerShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: kVodSubtitleDcardBaseGradient,
                  border: Border.all(
                    color: kVodSubtitleDcardBorder,
                    width: 1,
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: VodSubtitleDcardTextureOverlay(),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// Html Sampels/vod-cc-button-and-subtitle-picker-navigate.html .d-card::before
class VodSubtitleDcardTextureOverlay extends StatelessWidget {
  const VodSubtitleDcardTextureOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(
        painter: VodSubtitleDcardTexturePainter(),
      ),
    );
  }
}

class VodSubtitleDcardTexturePainter extends CustomPainter {
  const VodSubtitleDcardTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = Offset.zero & size;
    final sh = ui.Gradient.linear(
      ui.Offset(0, size.height * 0.05),
      ui.Offset(size.width * 0.9, size.height * 0.5),
      const [Color(0x00000000), Color(0x0A648CC8), Color(0x00000000)],
      const [0, 0.35, 0.55],
    );
    final shPaint = Paint()..shader = sh;
    canvas.drawRect(r, shPaint);

    final st = Paint()..color = const Color(0x03FFFFFF);
    for (var x = 0.0; x < size.width; x += 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), st);
    }
  }

  @override
  bool shouldRepaint(covariant VodSubtitleDcardTexturePainter oldDelegate) =>
      false;
}

/// `.list` inset in the reference HTML (dark list wells inside the card).
BoxDecoration vodSubtitleDcardListWellDecoration({
  required bool focused,
  required Color focusColor,
  double borderRadius = 8,
}) {
  if (focused) {
    // Html Sampels/vod-subtitle-style-editor-panel.html .well.focus
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: focusColor, width: 1.2),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33000000), Color(0x59000000)],
      ),
      boxShadow: [
        BoxShadow(
          color: focusColor.withValues(alpha: 0.35),
          blurRadius: 18,
          spreadRadius: 0,
        ),
      ],
    );
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x33000000), Color(0x59000000)],
    ),
  );
}
