import 'package:flutter/material.dart';

/// Root keys so background work (e.g. VOD download) can show dialogs and snack bars
/// without a [BuildContext] from the player route.
final class AppNav {
  AppNav._();

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

  static final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>(debugLabel: 'rootScaffoldMessenger');
}
