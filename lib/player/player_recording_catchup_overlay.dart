import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../ui/recording/recording_screen.dart';
import '../ui/settings/player_settings_overlay_scope.dart';

/// Slightly stronger than [kPlayerSettingsOverlayScrimOpacity] so dates / EPG
/// rows stay readable over bright video; live picture still visible.
const double kRecordingCatchupBaseScrimOpacity = 0.52;

/// Extra panel behind the Recording column (on top of base scrim).
const double kRecordingCatchupPanelOpacity = 0.42;

/// Catch-up / Recording **over** fullscreen live TV — same [RecordingScreen] as
/// the shell tab, stacked on the **root** navigator like Settings. Back pops
/// this route first (see [_PlayerScreenState._recordingCatchupOverlayOpen]).
Future<void> openRecordingCatchupOverlay(
  BuildContext context, {
  required String channelId,
}) {
  final backToLiveWindowsOnly =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: PlayerSettingsOverlayScope(
            isActive: true,
            child: RecordingCatchupOverlayShell(
              showBackToLiveButton: backToLiveWindowsOnly,
              child: RecordingScreen(
                embeddedInPlayerOverlay: true,
                initialChannelIdForOverlay: channelId,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Base dim + rounded translucent panel so white text and unfocused EPG rows
/// stay legible while video remains visible at the edges.
///
/// Shared by catch-up ([openRecordingCatchupOverlay]) and live EPG overlay.
class RecordingCatchupOverlayShell extends StatelessWidget {
  const RecordingCatchupOverlayShell({
    super.key,
    required this.child,
    this.showBackToLiveButton = false,
  });

  final Widget child;

  /// Windows desktop catch-up only — Android / other platforms: `false` (unchanged UI).
  final bool showBackToLiveButton;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black
                    .withValues(alpha: kRecordingCatchupBaseScrimOpacity),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black
                      .withValues(alpha: kRecordingCatchupPanelOpacity),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              ),
            ),
          ),
        ),
        if (showBackToLiveButton)
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              minimum: const EdgeInsets.only(left: 10, top: 8),
              child: Tooltip(
                message: 'Back to live TV',
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
