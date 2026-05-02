import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/team_palette_theme.dart';
import 'focus/tv_focusable.dart';
import 'tv_template_pill_layout.dart';

/// Live TV / Movies / Series category chip — one shared visual and behavior
/// (colors, ~12.5pt label, [kTvTemplateCategoryPillHeight] body, [AppTheme] focus).
class TvTemplateCategoryPill extends StatefulWidget {
  const TvTemplateCategoryPill({
    super.key,
    required this.label,
    required this.selected,
    this.autofocus = false,
    this.canRequestFocus = true,
    required this.focusNode,
    this.onActivate,
    this.onKeyIntercept,
    this.onFocusChanged,
  });

  final String label;
  final bool selected;
  final bool autofocus;
  final bool canRequestFocus;
  final FocusNode focusNode;
  final VoidCallback? onActivate;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;
  final void Function(bool hasFocus)? onFocusChanged;

  @override
  State<TvTemplateCategoryPill> createState() => _TvTemplateCategoryPillState();
}

class _TvTemplateCategoryPillState extends State<TvTemplateCategoryPill> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final focused = _focused;
    final selected = widget.selected;
    final p = context.teamPalette;
    final a = p.accent;
    final restBorder = Color.lerp(p.surface, p.canvas, 0.42) ?? p.canvas;
    final accentColor = a;
    final accentLine = a.withValues(alpha: 0.5);
    final accentSoft = a.withValues(alpha: 0.14);
    final accentGlow = a.withValues(alpha: 0.22);

    final Color bgColor;
    final Color borderColor;
    final List<BoxShadow> shadows;
    final Color textColor;

    if (focused && selected) {
      bgColor = accentSoft;
      borderColor = accentLine;
      shadows = [
        BoxShadow(
          color: accentGlow,
          blurRadius: 18,
          spreadRadius: -4,
        ),
        BoxShadow(
          color: accentSoft,
          blurRadius: 3,
          spreadRadius: 3,
        ),
      ];
      textColor = accentColor;
    } else if (focused) {
      bgColor = p.surface;
      borderColor = accentLine;
      shadows = [
        BoxShadow(
          color: accentSoft,
          blurRadius: 3,
          spreadRadius: 3,
        ),
      ];
      textColor = p.shellTitleColor;
    } else if (selected) {
      bgColor = accentSoft;
      borderColor = accentLine;
      shadows = [
        BoxShadow(
          color: accentGlow,
          blurRadius: 18,
          spreadRadius: -4,
        ),
      ];
      textColor = accentColor;
    } else {
      bgColor = p.surface;
      borderColor = restBorder;
      shadows = const [];
      textColor = p.onShellTextSecondary;
    }

    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.canRequestFocus,
      showFocusElevation: false,
      focusScale: 1.0,
      parallaxSlide: 0,
      focusPadding: EdgeInsets.zero,
      focusedBorderWidth: 0,
      focusBorderColor: p.defaultFocusRingColor,
      onActivate: widget.onActivate,
      onKeyIntercept: widget.onKeyIntercept,
      onFocusedChange: (f) {
        setState(() => _focused = f);
        widget.onFocusChanged?.call(f);
      },
      child: SizedBox(
        height: kTvTemplateCategoryPillHeight,
        child: AnimatedContainer(
          duration: AppTheme.focusAnimationDuration,
          curve: AppTheme.focusAnimationCurve,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: shadows,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12.5,
                        height: 1.0,
                        letterSpacing: -0.005 * 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
