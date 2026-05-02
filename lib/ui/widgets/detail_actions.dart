import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import '../tv_template_pill_layout.dart';

/// Compact circular back control (TV).
class DetailIconBack extends StatelessWidget {
  const DetailIconBack({
    super.key,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.onKeyIntercept,
    this.onFocusedChange,
    /// Windows: scales hit target + icon with [windowsDetailLayoutScale].
    this.layoutScale = 1.0,
  });

  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;
  final ValueChanged<bool>? onFocusedChange;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final s = layoutScale;
    final dim = 44.0 * s;
    final icon = 22.0 * s;
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      showFocusElevation: false,
      focusPadding: EdgeInsets.all(4 * s),
      onActivate: onPressed,
      onFocusedChange: onFocusedChange,
      onKeyIntercept: onKeyIntercept,
      child: Container(
        width: dim,
        height: dim,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 12 * s,
              offset: Offset(0, 4 * s),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_back_rounded,
          size: icon,
          color: Colors.white.withOpacity(0.95),
        ),
      ),
    );
  }
}

/// Four compact actions: primary icon + short label.
class DetailCompactActionBar extends StatelessWidget {
  const DetailCompactActionBar({
    super.key,
    required this.actions,
    /// When set, that action tile requests initial TV focus (e.g. 0 = Play).
    this.autofocusIndex,
    /// Windows: scales label, icon, padding with detail layout scale.
    this.layoutScale = 1.0,
    /// Optional [FocusNode] for the first action (e.g. Android series details).
    this.firstActionFocusNode,
    /// Per-tile key handler (e.g. Android: Down → episode list). Index is action index.
    this.onActionKeyIntercept,
  });

  final List<DetailCompactAction> actions;

  /// Index into [actions] for [TvFocusable.autofocus], or null for none.
  final int? autofocusIndex;

  final double layoutScale;

  /// When set, the first tile uses this node instead of an internal one.
  final FocusNode? firstActionFocusNode;

  final KeyEventResult? Function(FocusNode node, KeyEvent event, int index)?
      onActionKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i != 0) const SizedBox(width: 6),
          _CompactActionTile(
            action: actions[i],
            autofocus: autofocusIndex == i,
            focusNode: i == 0 ? firstActionFocusNode : null,
            onKeyIntercept: onActionKeyIntercept == null
                ? null
                : (n, e) => onActionKeyIntercept!(n, e, i),
          ),
        ],
      ],
    );
  }
}

class DetailCompactAction {
  const DetailCompactAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class _CompactActionTile extends StatefulWidget {
  const _CompactActionTile({
    required this.action,
    this.autofocus = false,
    this.focusNode,
    this.onKeyIntercept,
  });

  final DetailCompactAction action;
  final bool autofocus;
  final FocusNode? focusNode;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  @override
  State<_CompactActionTile> createState() => _CompactActionTileState();
}

class _CompactActionTileState extends State<_CompactActionTile> {
  bool _focused = false;

  static const _bgColor = Color(0xFF131822);
  static const _borderDefault = Color(0xFF1B2330);
  static const _fgDefault = Color(0xFFA8B0BD);
  static const _fgFocused = Color(0xFFEEF2F7);

  @override
  Widget build(BuildContext context) {
    final pal = context.teamPalette;
    final a = pal.accent;
    final fg = _focused ? _fgFocused : _fgDefault;
    final border = _focused ? a.withValues(alpha: 0.5) : _borderDefault;

    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      focusPadding: EdgeInsets.zero,
      focusedBorderWidth: 0,
      showFocusElevation: false,
      focusBorderColor: pal.defaultFocusRingColor,
      onActivate: widget.action.onPressed,
      onKeyIntercept: widget.onKeyIntercept,
      onFocusedChange: (f) => setState(() => _focused = f),
      child: SizedBox(
        height: kTvTemplateCategoryPillHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _bgColor,
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.action.icon,
                size: 13,
                color: fg,
              ),
              const SizedBox(width: 5),
              Text(
                widget.action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.0,
                  letterSpacing: -0.005 * 11,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
