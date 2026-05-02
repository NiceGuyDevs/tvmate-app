import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/clock_overlay_settings_store.dart';
import '../../theme/team_palette_theme.dart';
import 'clock_face_view.dart';

/// Floating corner clock app-wide. When overlay is off, [AppTopBar] shows [ClockFaceView] in the shell.
/// Does not intercept focus or pointer events.
class ClockOverlayLayer extends StatelessWidget {
  const ClockOverlayLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clockOverlaySettingsStore,
      builder: (context, _) {
        final store = clockOverlaySettingsStore;
        if (!store.enabled) {
          return const SizedBox.shrink();
        }
        return _ClockOverlayTicking(store: store);
      },
    );
  }
}

/// Timer only rebuilds the floating clock, not the whole route tree.
class _ClockOverlayTicking extends StatefulWidget {
  const _ClockOverlayTicking({required this.store});

  final ClockOverlaySettingsStore store;

  @override
  State<_ClockOverlayTicking> createState() => _ClockOverlayTickingState();
}

class _ClockOverlayTickingState extends State<_ClockOverlayTicking> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final now = DateTime.now();
    final pad = store.size.edgePadding;
    final chrome = context.teamPalette;
    final face = ClockFaceView(
      now: now,
      store: store,
      showDateLine: true,
      fontSizeFactor: 1.0,
      textAlign: TextAlign.center,
    );
    final cornerNudge = store.offsetForCorner(store.corner);
    if (store.framed) {
      return IgnorePointer(
        child: Align(
          alignment: store.corner.alignment,
          child: Transform.translate(
            offset: cornerNudge,
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      chrome.neonLine.withOpacity(0.08),
                      Colors.black.withOpacity(0.78),
                      chrome.nebulaMagenta.withOpacity(0.06),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: chrome.neonLine.withOpacity(0.42),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: chrome.accent.withOpacity(0.22),
                      blurRadius: 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: face,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Align(
        alignment: store.corner.alignment,
        child: Transform.translate(
          offset: cornerNudge,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: ClockFaceView(
              now: now,
              store: store,
              showDateLine: false,
              fontSizeFactor: 1.0,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
