import 'package:flutter/material.dart';

import '../ui/settings/player_settings_overlay_scope.dart';
import '../ui/settings/settings_screen.dart';

/// Fullscreen Settings over the live player: dim scrim so video stays visible;
/// same [SettingsScreen] as the shell (sub-routes use [pushSettingsRoute]).
Future<void> openPlayerSettingsOverlay(BuildContext context) {
  return Navigator.of(context).push<void>(
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
          child: const _PlayerSettingsOverlayBody(),
        );
      },
    ),
  );
}

class _PlayerSettingsOverlayBody extends StatelessWidget {
  const _PlayerSettingsOverlayBody();

  @override
  Widget build(BuildContext context) {
    return PlayerSettingsOverlayScope(
      isActive: true,
      child: PlayerSettingsOverlayPageShell(
        child: SettingsScreen(registerShellFocus: false),
      ),
    );
  }
}
