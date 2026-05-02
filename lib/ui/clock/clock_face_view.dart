import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../data/clock_overlay_settings_store.dart';

/// Time (+ optional date) using the same typography as the floating overlay.
class ClockFaceView extends StatelessWidget {
  const ClockFaceView({
    super.key,
    required this.now,
    required this.store,
    this.showDateLine = true,
    /// Scales [store.size.fontSize] (e.g. 0.9 for the top bar).
    this.fontSizeFactor = 1.0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textAlign = TextAlign.center,
  });

  final DateTime now;
  final ClockOverlaySettingsStore store;
  final bool showDateLine;
  final double fontSizeFactor;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  static String formatTime(DateTime now, ClockOverlaySettingsStore store) {
    if (store.use24Hour) {
      final h = now.hour.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final h12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final suf = now.hour < 12 ? 'AM' : 'PM';
    return '$h12:$m $suf';
  }

  static double _dateFontSize(ClockOverlaySettingsStore store) {
    return switch (store.size) {
      ClockSizePreset.small => 9.5,
      ClockSizePreset.medium => 11,
      ClockSizePreset.large => 13,
    };
  }

  static List<Shadow> _neonGlow(Color c) {
    return [
      Shadow(
        color: c.withOpacity(0.9),
        blurRadius: 10,
        offset: Offset.zero,
      ),
      Shadow(
        color: c.withOpacity(0.35),
        blurRadius: 22,
        offset: Offset.zero,
      ),
    ];
  }

  TextStyle _timeStyle(Color color) {
    final fs = store.size.fontSize * fontSizeFactor;
    if (store.useSegmentDigitFont) {
      return TextStyle(
        fontFamily: 'DSEG7Classic',
        fontSize: fs * 1.08,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 1.6,
        height: 1.05,
        decoration: TextDecoration.none,
        shadows: _neonGlow(color),
      );
    }
    return TextStyle(
      fontSize: fs,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.4,
      height: 1.05,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      shadows: null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  TextStyle _dateNumericSegmentStyle(Color color) {
    return TextStyle(
      fontFamily: 'DSEG7Classic',
      fontSize: _dateFontSize(store) * 1.06 * fontSizeFactor,
      fontWeight: FontWeight.w400,
      color: color.withOpacity(0.88),
      letterSpacing: 1.4,
      height: 1.1,
      decoration: TextDecoration.none,
      shadows: _neonGlow(color.withOpacity(0.92)),
    );
  }

  TextStyle _dateWeekdayCapsStyle(Color color) {
    return TextStyle(
      fontFamily: 'Roboto',
      fontSize: _dateFontSize(store) * 1.06 * fontSizeFactor,
      fontWeight: FontWeight.w800,
      color: color.withOpacity(0.88),
      letterSpacing: 0.6,
      height: 1.1,
      decoration: TextDecoration.none,
    );
  }

  TextStyle _dateStylePlain(Color color) {
    return TextStyle(
      fontFamily: 'Roboto',
      fontSize: _dateFontSize(store) * fontSizeFactor,
      fontWeight: FontWeight.w600,
      color: color.withOpacity(0.82),
      letterSpacing: 0.8,
      height: 1.1,
      decoration: TextDecoration.none,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  Widget _buildDateLine(Color color) {
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    const wds = <String>[
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ];
    final wd = wds[now.weekday - 1].toUpperCase();
    if (store.useSegmentDigitFont) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$d/$m ',
              style: _dateNumericSegmentStyle(color),
            ),
            TextSpan(
              text: wd,
              style: _dateWeekdayCapsStyle(color),
            ),
          ],
        ),
        textAlign: textAlign,
      );
    }
    return Text(
      '$d/$m $wd',
      style: _dateStylePlain(color),
      textAlign: textAlign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = store.textColor;
    final color = base.withOpacity(store.opacity);
    final time = Text(
      formatTime(now, store),
      style: _timeStyle(color),
      textAlign: textAlign,
    );

    if (!showDateLine) {
      return time;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        time,
        SizedBox(height: 2 * fontSizeFactor.clamp(0.85, 1.0)),
        _buildDateLine(color),
      ],
    );
  }
}
