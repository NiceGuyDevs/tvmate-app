import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Scales poster overlay typography/padding with tile width (Windows desktop only).
double windowsPosterLabelScale(double posterWidth) {
  if (!Platform.isWindows) return 1.0;
  return (posterWidth / 170.0).clamp(0.68, 1.38);
}

/// Scales detail-page typography, spacing, and action buttons with window size (Windows only).
double windowsDetailLayoutScale(double windowWidth, double windowHeight) {
  if (!Platform.isWindows) return 1.0;
  final a = windowWidth / 1280.0;
  final b = windowHeight / 720.0;
  return ((a + b) / 2.0).clamp(0.64, 1.26);
}

/// Shared metrics for title/year text on browse poster cards.
class WindowsPosterTextMetrics {
  WindowsPosterTextMetrics(double posterWidth)
      : scale = windowsPosterLabelScale(posterWidth);

  final double scale;

  EdgeInsets get overlayPadding =>
      EdgeInsets.fromLTRB(12 * scale, 12 * scale, 12 * scale, 14 * scale);

  double get titleFont => 14 * scale;

  double get metaFont => 12 * scale;

  double get titleOnlyFont => 15 * scale;

  double get horizontalTitleOnlyPad => 12 * scale;

  double get posterOnlyOuterPad => 4 * scale;

  double get badgeLeft => 8 * scale;

  double get badgeBottom => 8 * scale;

  List<Shadow> get titleShadows => [
        Shadow(blurRadius: 10 * scale, color: Colors.black87),
      ];
}
