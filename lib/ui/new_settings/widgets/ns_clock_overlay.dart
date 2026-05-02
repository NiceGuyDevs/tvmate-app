/// Floating real-clock overlay — ports the `#realClock` fixed-positioned
/// element at settings.html line 3916.
///
/// Paints the current time inside whichever corner [state.clock.corner]
/// points at, with [state.clock] controlling size, color, opacity, frame,
/// format, and per-corner offsets. Uses the DSEG7Classic 7-segment font
/// when the active color is one of the LED presets.
///
/// Rendered inside the [NewSettingsScreen]'s backdrop [Stack] so it always
/// floats above the surface (header + rail + detail + sub-pages + dialogs)
/// without inserting itself into a route — exactly like the HTML's fixed
/// overlay.
///
/// Ticks once per second via a lightweight [Timer.periodic].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_state.dart';

class NsRealClockOverlay extends StatefulWidget {
  const NsRealClockOverlay({super.key, required this.state});

  final NewSettingsState state;

  @override
  State<NsRealClockOverlay> createState() => _NsRealClockOverlayState();
}

class _NsRealClockOverlayState extends State<NsRealClockOverlay> {
  late final Timer _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // One repaint per second — aligned to the next wall-clock second so
    // the digits flip at the same moment as the OS clock.
    final delay = Duration(
      milliseconds: 1000 - DateTime.now().millisecond,
    );
    _tick = Timer(delay, () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _startPeriodic();
    });
  }

  Timer? _periodic;
  void _startPeriodic() {
    _periodic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    _periodic?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime t, String fmt) {
    final m = t.minute.toString().padLeft(2, '0');
    if (fmt == '12') {
      var h = t.hour % 12;
      if (h == 0) h = 12;
      final ampm = t.hour < 12 ? 'AM' : 'PM';
      return '${h.toString().padLeft(2, '0')}:$m $ampm';
    }
    return '${t.hour.toString().padLeft(2, '0')}:$m';
  }

  Color _parseHex(String hex) {
    final v = int.parse(hex.replaceAll('#', ''), radix: 16);
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final clock = widget.state.clock;
        if (!clock.enabled) return const SizedBox.shrink();

        final color = _parseHex(clock.color).withValues(
          alpha: clock.opacity / 100.0,
        );
        final led = nsClockIsLed(clock.color);
        final offset = clock.offsets[clock.corner] ?? (x: 0, y: 0);
        final text = _formatTime(_now, clock.fmt);

        // Map the four corners to Alignment + inset.
        final isTop = clock.corner.startsWith('t');
        final isLeft = clock.corner.endsWith('l');
        // Base inset from the edge — enough to avoid the header/rail.
        const baseInset = 16.0;
        final topInset = isTop ? baseInset + offset.y : null;
        final bottomInset = !isTop ? baseInset - offset.y : null;
        final leftInset = isLeft ? baseInset + offset.x : null;
        final rightInset = !isLeft ? baseInset - offset.x : null;

        final child = Container(
          padding: clock.framed
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
              : EdgeInsets.zero,
          decoration: clock.framed
              ? BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: clock.sizePx.toDouble(),
              fontFamily: led ? 'DSEG7Classic' : null,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
              height: 1,
              shadows: led
                  ? [
                      Shadow(
                        color: color,
                        blurRadius: 14,
                      ),
                      const Shadow(
                        color: Color(0x40000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : const [
                      Shadow(
                        color: Color(0x80000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
            ),
          ),
        );

        return Positioned(
          top: topInset,
          bottom: bottomInset,
          left: leftInset,
          right: rightInset,
          child: IgnorePointer(child: child),
        );
      },
    );
  }
}

/// Compact floating version rendered *inside* the Clock sub-page's
/// preview card so users with the master switch OFF can still see what
/// their current setup would look like. Functionally identical to
/// [NsRealClockOverlay] but renders unconditionally (no `enabled` gate)
/// and drops the outer [Positioned] wrapper so it can be composed inside
/// any parent layout.
class NsClockFacePreview extends StatelessWidget {
  const NsClockFacePreview({super.key, required this.state});

  final NewSettingsState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final clock = state.clock;
        final led = nsClockIsLed(clock.color);
        final v = int.parse(clock.color.replaceAll('#', ''), radix: 16);
        final color = Color(0xFF000000 | v).withValues(
          alpha: clock.opacity / 100.0,
        );
        return Container(
          padding: clock.framed
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
              : EdgeInsets.zero,
          decoration: clock.framed
              ? BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            _exampleTime(clock.fmt),
            style: TextStyle(
              color: color,
              fontSize: (clock.sizePx + 6).toDouble(),
              fontFamily: led ? 'DSEG7Classic' : null,
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
              height: 1,
              shadows: led
                  ? [
                      Shadow(
                        color: color,
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }

  // Static 21:00 / 09:00 PM so the preview doesn't visually update every
  // second while the user is adjusting the controls.
  static String _exampleTime(String fmt) =>
      fmt == '12' ? '09:00 PM' : '21:00';
}
