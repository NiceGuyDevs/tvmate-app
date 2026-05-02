import '../data/top_menu_store.dart';
import 'shell_destination.dart';

/// What the shell should do in response to a Back press on the top bar.
enum ShellBackAction {
  /// Navigate to the launch / home section's browse (grid + categories).
  goHome,

  /// Exit the app (only when already on the launch tab).
  exitApp,
}

/// What a browse screen should do in response to a Back press.
enum BrowseBackAction {
  /// Move focus from the grid / content to the category row.
  focusCategories,

  /// Move focus from the category row to the top tab bar.
  focusTopBar,
}

/// What a player should do in response to a Back press.
enum PlayerBackAction {
  /// Peel one overlay layer (EPG, right menu, subtitle panel, etc.).
  peelOverlay,

  /// Dismiss the chrome / bottom bar (stay in player, clean video).
  dismissChrome,

  /// Exit the player entirely (go to details or grid).
  exitPlayer,
}

/// Central authority for TV remote navigation decisions.
///
/// Pure logic — no widgets, no BuildContext. Screens call these methods and
/// act on the returned enum. This keeps all Back / double-Back / home rules
/// in one place (see `documentation/tv-remote-navigation-spec.md`).
class NavigationPolicy {
  NavigationPolicy._();

  // ── Shell (top tab bar) ──────────────────────────────────────────────

  /// The user-configured launch / home tab.
  static ShellDestination get launchTab => topMenuStore.startup;

  /// Decide what double-Back on the top bar should do.
  ///
  /// [focusedTab] is the tab that currently has focus on the shell bar.
  static ShellBackAction shellDoubleBack(ShellDestination focusedTab) {
    if (focusedTab == launchTab) return ShellBackAction.exitApp;
    return ShellBackAction.goHome;
  }

  /// Whether [destination] is the launch / home tab.
  static bool isLaunchTab(ShellDestination destination) =>
      destination == launchTab;

  // ── Browse screens (grid + categories) ───────────────────────────────

  /// Decide what Back should do on a browse screen.
  ///
  /// [focusOnCategories] — true when focus is already on the category row
  /// (pills); false when focus is on the grid / content.
  static BrowseBackAction browseBack({required bool focusOnCategories}) {
    if (focusOnCategories) return BrowseBackAction.focusTopBar;
    return BrowseBackAction.focusCategories;
  }

  // ── Player screens ───────────────────────────────────────────────────

  /// Decide what Back should do inside a player.
  ///
  /// [overlayDepth] — number of overlay layers currently open (EPG, right
  /// menu, subtitle panel, nested dialogs, etc.). 0 = nothing on top.
  /// [chromeVisible] — whether the bottom bar / info strip is showing.
  static PlayerBackAction playerBack({
    required int overlayDepth,
    required bool chromeVisible,
  }) {
    if (overlayDepth > 0) return PlayerBackAction.peelOverlay;
    if (chromeVisible) return PlayerBackAction.dismissChrome;
    return PlayerBackAction.exitPlayer;
  }
}
