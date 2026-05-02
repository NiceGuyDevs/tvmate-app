import 'package:flutter/material.dart';

import '../../shell/team_shell_backdrop.dart';

/// Scrim opacity over live video (keep in sync with [PlayerSettingsOverlayPageShell]).
const double kPlayerSettingsOverlayScrimOpacity = 0.48;

/// Provided above the settings tree when opened as an overlay on live TV.
/// Sub-routes pushed with [pushSettingsRoute] also wrap this scope so
/// [playerSettingsRouteBackdrop] and transparent scaffolds apply.
class PlayerSettingsOverlayScope extends InheritedWidget {
  const PlayerSettingsOverlayScope({
    super.key,
    required super.child,
    this.isActive = true,
  });

  final bool isActive;

  static PlayerSettingsOverlayScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlayerSettingsOverlayScope>();
  }

  static bool isActiveContext(BuildContext context) =>
      maybeOf(context)?.isActive ?? false;

  @override
  bool updateShouldNotify(PlayerSettingsOverlayScope oldWidget) =>
      isActive != oldWidget.isActive;
}

/// Same team backdrop as [MainShellScreen]; empty over live TV (route supplies scrim).
Widget playerSettingsRouteBackdrop(BuildContext context) {
  if (PlayerSettingsOverlayScope.isActiveContext(context)) {
    return const SizedBox.shrink();
  }
  return const SizedBox.expand(
    child: TeamShellBackdrop(),
  );
}

/// Dim layer + transparent [Material] — same look as the root settings overlay.
class PlayerSettingsOverlayPageShell extends StatelessWidget {
  const PlayerSettingsOverlayPageShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(kPlayerSettingsOverlayScrimOpacity),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(child: child),
          ),
        ),
      ],
    );
  }
}

/// Shell: [push] uses the same transparent overlay treatment as the main
/// settings-over-live route when [PlayerSettingsOverlayScope] is active.
Future<T?> pushSettingsRoute<T>(
  BuildContext context,
  Widget Function(BuildContext context) builder, {
  bool fullscreenDialog = false,
}) {
  if (PlayerSettingsOverlayScope.isActiveContext(context)) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: PlayerSettingsOverlayScope(
              isActive: true,
              child: PlayerSettingsOverlayPageShell(
                child: Builder(builder: builder),
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }
  return Navigator.of(context).push<T>(
    fullscreenDialog
        ? MaterialPageRoute<T>(
            builder: builder,
            fullscreenDialog: true,
          )
        : MaterialPageRoute<T>(builder: builder),
  );
}
