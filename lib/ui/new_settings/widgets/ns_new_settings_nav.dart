import 'package:flutter/material.dart';

/// Injected above the New Settings body (rail + detail) so child widgets can:
///
///   * know when the **categories rail** is allowed to take focus, and
///   * return focus to the **active** rail entry with [onLeftFromRootMainToRail].
///
/// The rail is **not** focusable while a sub-page is on the internal stack or
/// while a choice option sheet is expanded, so D-pad traversal cannot
/// “fall through” to the rail from deeper UIs. See
/// [NewSettingsScreen] file-level contract.
class NsNewSettingsNav extends InheritedWidget {
  const NsNewSettingsNav({
    super.key,
    required this.railCanRequestFocus,
    required this.activeRailFocus,
    required this.onLeftFromRootMainToRail,
    required this.categoriesRailKey,
    required this.detailPaneScope,
    required super.child,
  });

  /// `false` while [NewSettingsState.stack] is non-empty or
  /// [NewSettingsState.expanded] is non-`null`.
  final bool railCanRequestFocus;

  /// Focus node of the **active** (OK-selected) rail entry — the same
  /// [FocusNode] the top bar restorer targets for this category.
  final FocusNode activeRailFocus;

  /// Call when the user presses **Left** on a **root main** page control that
  /// is at the **true left edge** of the content (so Left should not move
  /// in-page). Moves focus to [activeRailFocus].
  final VoidCallback onLeftFromRootMainToRail;

  /// Pinned to the **categories rail** [Column] / horizontal rail for
  /// [newSettingsRootLeftFromNsFocusable] to detect a mistaken spatial
  /// [TraversalDirection.left] onto a non-active tile.
  final GlobalKey categoriesRailKey;

  /// The [FocusScopeNode] for the **detail** body (right pane), **excluding**
  /// the categories rail. Used for [focusInDirection] so spatial Left never
  /// walks a nearer nested [FocusScope] (e.g. list internals) while the user
  /// is still mid-grid.
  final FocusScopeNode detailPaneScope;

  static NsNewSettingsNav? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NsNewSettingsNav>();
  }

  @override
  bool updateShouldNotify(covariant NsNewSettingsNav oldWidget) {
    return oldWidget.railCanRequestFocus != railCanRequestFocus ||
        oldWidget.activeRailFocus != activeRailFocus ||
        oldWidget.categoriesRailKey != categoriesRailKey ||
        oldWidget.detailPaneScope != detailPaneScope;
  }
}
