import 'package:flutter/material.dart';

import '../../theme/team_palette_theme.dart';
import 'tv_focusable.dart';

/// [TvFocusable] + card fill, border, accent glow from [TeamPalette.accent];
/// used for Movies / Series poster and episode focus.
class VodLiveTvStyleFocus extends StatefulWidget {
  const VodLiveTvStyleFocus({
    super.key,
    required this.child,
    required this.focusNode,
    this.autofocus = false,
    this.onActivate,
    this.onLongPress,
    this.onFocusedChange,
    this.onKeyIntercept,
    this.onDesktopTap,
    this.borderRadius = 13,
    this.canRequestFocus = true,
  });

  final Widget child;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback? onActivate;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusedChange;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;
  final VoidCallback? onDesktopTap;
  final double borderRadius;
  final bool canRequestFocus;

  @override
  State<VodLiveTvStyleFocus> createState() => _VodLiveTvStyleFocusState();
}

class _VodLiveTvStyleFocusState extends State<VodLiveTvStyleFocus> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    final a = p.accent;
    final r = widget.borderRadius;
    return TvFocusable(
      focusNode: widget.focusNode,
      onDesktopTap: widget.onDesktopTap,
      onLongPress: widget.onLongPress,
      parallaxSlide: 0,
      focusScale: 1.0,
      showFocusElevation: false,
      focusedBorderWidth: 0,
      focusBorderColor: p.defaultFocusRingColor,
      focusPadding: EdgeInsets.zero,
      canRequestFocus: widget.canRequestFocus,
      autofocus: widget.autofocus,
      onFocusedChange: (hasFocus) {
        setState(() => _focused = hasFocus);
        widget.onFocusedChange?.call(hasFocus);
      },
      onActivate: widget.onActivate,
      onKeyIntercept: widget.onKeyIntercept,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        clipBehavior: Clip.hardEdge,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            color: _focused
                ? const Color(0xFF181F2C)
                : const Color(0xFF131822),
            border: Border.all(
              color: _focused
                  ? a.withValues(alpha: 0.7)
                  : const Color(0xFF1B2330),
              width: _focused ? 1.45 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 40,
                spreadRadius: -20,
                offset: const Offset(0, 16),
              ),
              if (_focused) ...[
                BoxShadow(
                  color: a.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: a.withValues(alpha: 0.28),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
      ),
    );
  }
}
