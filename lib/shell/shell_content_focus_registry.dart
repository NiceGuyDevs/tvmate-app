import 'package:flutter/widgets.dart';

import 'shell_destination.dart';

/// Lets the shell move D-pad focus to each tab’s primary control after navigation.
typedef ShellPrimaryFocusRequest = void Function();

class ShellContentFocusRegistry {
  ShellContentFocusRegistry._();

  static final Map<ShellDestination, ShellPrimaryFocusRequest> _map = {};

  /// Top bar nodes (set by [MainShellScreen]) for explicit Up from Live TV content.
  static Map<ShellDestination, FocusNode>? _topNavByDestination;

  /// Hero preview mute chip in the top bar (before **Live TV**); set by [MainShellScreen].
  static FocusNode? _liveHeroMuteNavFocus;

  static void register(ShellDestination d, ShellPrimaryFocusRequest fn) {
    _map[d] = fn;
  }

  static void unregister(ShellDestination d) {
    _map.remove(d);
  }

  static void request(ShellDestination d) {
    _map[d]?.call();
  }

  static void registerTopNavFocus(Map<ShellDestination, FocusNode> nodes) {
    _topNavByDestination = Map<ShellDestination, FocusNode>.from(nodes);
  }

  static void unregisterTopNavFocus() {
    _topNavByDestination = null;
    _liveHeroMuteNavFocus = null;
  }

  static FocusNode? topNavFocus(ShellDestination d) =>
      _topNavByDestination?[d];

  /// Register the optional mute chip node (or null to clear).
  static void registerLiveHeroMuteNavFocus(FocusNode? node) {
    _liveHeroMuteNavFocus = node;
  }

  static FocusNode? get liveHeroMuteNavFocus => _liveHeroMuteNavFocus;

  /// True when [n] is a shell top-bar tab or the Live TV hero-mute chip.
  static bool isTopNavNode(FocusNode? n) {
    if (n == null) return false;
    if (identical(n, _liveHeroMuteNavFocus)) return true;
    if (_topNavByDestination == null) return false;
    for (final node in _topNavByDestination!.values) {
      if (identical(n, node)) return true;
    }
    return false;
  }
}
