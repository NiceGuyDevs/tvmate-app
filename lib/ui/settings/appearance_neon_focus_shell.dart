import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/team_palette_theme.dart';

/// TV remote: outline focus ring using the active [TeamPalette.defaultFocusRingColor].
class AppearanceNeonFocusShell extends StatefulWidget {
  const AppearanceNeonFocusShell({
    super.key,
    required this.child,
    required this.onActivate,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.onKeyIntercept,
    this.debugLabel = 'appearanceNeon',
  });

  final Widget child;
  final VoidCallback onActivate;
  final bool autofocus;
  /// When false, [onActivate] is only invoked if a parent forwards keys (e.g. rail focus).
  final bool canRequestFocus;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;
  final String debugLabel;

  @override
  State<AppearanceNeonFocusShell> createState() =>
      _AppearanceNeonFocusShellState();
}

class _AppearanceNeonFocusShellState extends State<AppearanceNeonFocusShell> {
  late final FocusNode _node = FocusNode(debugLabel: widget.debugLabel);

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  static bool _activate(KeyDownEvent event) {
    final k = event.logicalKey;
    return k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.numpadEnter;
  }

  @override
  Widget build(BuildContext context) {
    final neon = context.teamPalette.defaultFocusRingColor;
    return Focus(
      focusNode: _node,
      canRequestFocus: widget.canRequestFocus,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        final intercepted = widget.onKeyIntercept?.call(node, event);
        if (intercepted != null) return intercepted;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_activate(event)) {
          widget.onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: _node.hasFocus ? neon : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: _node.hasFocus
              ? [
                  BoxShadow(
                    color: neon.withValues(alpha: 0.32),
                    blurRadius: 14,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
