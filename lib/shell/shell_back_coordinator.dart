/// Two-step system Back on TV: active browse screen can consume the first Back
/// (e.g. move focus from grid to category chips) before the shell opens the menu.
class ShellBackCoordinator {
  ShellBackCoordinator._();

  static Object? _owner;
  static bool Function()? _handler;

  /// [owner] should be the State instance; avoids stale handlers after dispose.
  static void register(Object owner, bool Function() onTryConsumeBack) {
    _owner = owner;
    _handler = onTryConsumeBack;
  }

  static void unregister(Object owner) {
    if (identical(_owner, owner)) {
      _owner = null;
      _handler = null;
    }
  }

  /// Returns true if the current browse screen handled Back (focus escalation).
  static bool tryConsumeBack() => _handler?.call() ?? false;
}
