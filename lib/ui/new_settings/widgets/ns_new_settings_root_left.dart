import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ns_new_settings_nav.dart';

/// `true` if [child] is [target] or an **ancestor** of [child] is [target].
bool nsContextIsDescendantOrSelf(BuildContext? child, BuildContext? target) {
  if (child == null || target == null) return false;
  if (identical(child, target)) return true;
  var found = false;
  (child as Element).visitAncestorElements((a) {
    if (identical(a, target as Element?)) {
      found = true;
      return false; // stop walking — [target] is an ancestor
    }
    return true; // keep walking up
  });
  return found;
}

/// Uniform **root main** (see [NsNewSettingsNav.railCanRequestFocus]) D-pad
/// **Left** for every [NsFocusable] under the New Settings surface: try a
/// spatial [TraversalDirection.left] first; if focus lands on the
/// **categories rail** (or nothing moves at the in-pane left edge), hand off
/// to the **active** rail entry.
KeyEventResult? newSettingsRootLeftFromNsFocusable({
  required FocusNode node,
  required KeyEvent event,
  required NsNewSettingsNav nav,
  required GlobalKey categoriesRailKey,
}) {
  if (event is! KeyDownEvent) return null;
  if (event.logicalKey != LogicalKeyboardKey.arrowLeft) return null;
  if (!nav.railCanRequestFocus) return null;
  if (!node.hasFocus) return null;
  if (node.context == null) return null;
  if (!node.context!.mounted) return null;

  final before = node;

  // Use the **injected** detail [_detailScope] from [NsNewSettingsNav], not
  // [FocusScope.of] (which can pick a **nearer** scope on the ancestor chain
  // and make [focusInDirection] "escape" the grid to the rail). We only
  // [onLeftFromRootMainToRail] when there is no focusable further left
  // **within** the full right pane.
  final moved = nav.detailPaneScope.focusInDirection(TraversalDirection.left);
  final after = FocusManager.instance.primaryFocus;

  final railContext = categoriesRailKey.currentContext;

  if (!moved || after == null || after == before) {
    nav.onLeftFromRootMainToRail();
    return KeyEventResult.handled;
  }

  if (railContext != null &&
      after.context != null &&
      nsContextIsDescendantOrSelf(after.context, railContext)) {
    if (before.canRequestFocus) {
      before.requestFocus();
    }
    nav.onLeftFromRootMainToRail();
    return KeyEventResult.handled;
  }

  // In-scope move succeeded (another item to the left in the detail pane).
  return KeyEventResult.handled;
}
