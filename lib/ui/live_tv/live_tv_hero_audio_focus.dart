import 'package:flutter/material.dart';

import '../../data/live_hero_preview_audio_store.dart';

/// Live hero panel: **not** in the focus chain (mute is on the shell top bar).
/// Shows a small mute status badge (decorative only).
class LiveTvHeroAudioFocusShell extends StatelessWidget {
  const LiveTvHeroAudioFocusShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: liveHeroPreviewAudioStore,
      builder: (context, _) {
        final muted = liveHeroPreviewAudioStore.muted;
        return ExcludeFocus(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              PositionedDirectional(
                top: 6,
                end: 6,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.58),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white.withOpacity(0.92),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
