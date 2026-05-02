import 'shell_destination.dart';

/// Routes deep links (e.g. after “Add playlist” success) to the main shell sidebar.
/// [MainShellScreen] calls [bind] / [unbind] around its lifecycle.
class ShellNavigationHub {
  ShellNavigationHub._();
  static final ShellNavigationHub instance = ShellNavigationHub._();

  void Function(ShellDestination)? _go;

  void bind(void Function(ShellDestination destination) go) {
    _go = go;
  }

  void unbind() {
    _go = null;
  }

  void goTo(ShellDestination destination) {
    _go?.call(destination);
  }
}
