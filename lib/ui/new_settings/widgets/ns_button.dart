/// Shared button — 1:1 port of the HTML `.btn`, `.btn.primary`,
/// `.btn.ghost`, and `.btn.danger` rules (settings.html lines 384–406).
///
/// Exactly the surface + focus + hover treatment of the stylesheet, with
/// no density scaling. Every page that needs a page-level action button
/// (Add playlist, Sync now, Edit URL, Cancel, Save, Delete…) renders
/// through here so the button chrome never drifts from the reference.
library;

import 'package:flutter/material.dart';

import '../new_settings_theme.dart';
import 'ns_focusable.dart';

enum NsButtonVariant {
  /// `.btn` — default surface pill.
  defaultVariant,

  /// `.btn.primary` — accent gradient.
  primary,

  /// `.btn.ghost` — transparent, grows a surface on hover/focus.
  ghost,

  /// `.btn.danger` — red on danger-soft bg.
  danger,
}

class NsButton extends StatelessWidget {
  const NsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = NsButtonVariant.defaultVariant,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.tooltip,
    this.onKeyIntercept,
    /// In [Row]/[Expanded], [NsButton] would otherwise only size to the
    /// label, leaving the rest of the cell with no hit targets — taps land
    /// "behind" the control. When true, stretch the surface to the available
    /// max width and center the label.
    this.fillWidth = false,
    /// Slightly smaller padding and text for dense toolbars and inline panels.
    this.dense = false,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusUpNeighbor,
    this.focusDownNeighbor,
    this.focusAccentRadius = 8,
  });

  /// Hugging-L corner radius; match [BorderRadius] on the button surface (8).
  final double focusAccentRadius;

  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusUpNeighbor;
  final FocusNode? focusDownNeighbor;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final NsButtonVariant variant;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? tooltip;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;
  final bool fillWidth;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: _fgFor(variant, enabled),
      fontSize: dense ? 10.5 : 12.5,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0.0,
      decoration: TextDecoration.none,
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 12.5 : 14, color: _fgFor(variant, enabled)),
          SizedBox(width: dense ? 4 : 6),
        ],
        Text(label, style: textStyle),
      ],
    );
    final surfacePad = dense
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    Widget buildSurface(bool focused) {
      Widget surface(Widget w) {
        return _Surface(
          variant: variant,
          focused: focused,
          enabled: enabled,
          padding: surfacePad,
          child: w,
        );
      }

      if (!fillWidth) {
        return surface(row);
      }
      return LayoutBuilder(
        builder: (context, c) {
          if (!c.hasBoundedWidth) {
            return surface(row);
          }
          return SizedBox(
            width: c.maxWidth,
            child: surface(
              Center(child: row),
            ),
          );
        },
      );
    }

    final button = NsFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: enabled,
      onActivate: enabled ? onPressed : null,
      onKeyIntercept: onKeyIntercept,
      semanticLabel: label,
      focusLeftNeighbor: focusLeftNeighbor,
      focusRightNeighbor: focusRightNeighbor,
      focusUpNeighbor: focusUpNeighbor,
      focusDownNeighbor: focusDownNeighbor,
      focusAccentRadius: focusAccentRadius,
      builder: (context, focused) => buildSurface(focused),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }

  static Color _fgFor(NsButtonVariant v, bool enabled) {
    if (!enabled) return NsColors.text4;
    switch (v) {
      case NsButtonVariant.primary:
        return const Color(0xFF001017); // CSS `color: #001017;`
      case NsButtonVariant.danger:
        return NsColors.danger;
      case NsButtonVariant.ghost:
        return NsColors.text2;
      case NsButtonVariant.defaultVariant:
        return NsColors.text;
    }
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.variant,
    required this.focused,
    required this.enabled,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });
  final NsButtonVariant variant;
  final bool focused;
  final bool enabled;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // CSS `.btn { padding: 8px 12px; border-radius: 8px; }`
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: NsEase.ease,
      padding: padding,
      decoration: _decorationFor(variant, focused, enabled),
      child: child,
    );
  }

  BoxDecoration _decorationFor(
    NsButtonVariant v,
    bool focused,
    bool enabled,
  ) {
    switch (v) {
      case NsButtonVariant.primary:
        // `.btn.primary` — accent gradient, transparent border, accent glow.
        final shadow = focused
            ? const [
                BoxShadow(
                  color: NsColors.accentGlow,
                  offset: Offset(0, 10),
                  blurRadius: 28,
                ),
              ]
            : const [
                BoxShadow(
                  color: NsColors.accentGlow,
                  offset: Offset(0, 8),
                  blurRadius: 22,
                ),
              ];
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [NsColors.accent2, NsColors.accent]
                : const [Color(0xFF3A4350), Color(0xFF323A46)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: enabled ? shadow : null,
        );

      case NsButtonVariant.danger:
        return BoxDecoration(
          color: NsColors.dangerSoft,
          border: Border.all(
            color: focused ? NsColors.danger : const Color(0x40F87171),
          ),
          borderRadius: BorderRadius.circular(8),
        );

      case NsButtonVariant.ghost:
        return BoxDecoration(
          color: focused ? NsColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        );

      case NsButtonVariant.defaultVariant:
        return BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(8),
        );
    }
  }
}
