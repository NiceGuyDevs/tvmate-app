/// D-pad focus primitive used across the new settings surface.
///
/// Deliberately minimal — zero visual treatment of its own (no border, no
/// scale, no slide, no elevation, no shadows, no reads of `context.teamPalette`).
/// The ONLY thing this widget does is:
///
///   * wire a [FocusNode] (owned or external),
///   * accept D-pad Select / Enter / Space as activation keys,
///   * accept mouse tap as activation (with a click cursor on desktop),
///   * expose the focused state to the caller through the [builder] callback,
///   * forward [onKeyIntercept] so callers can handle arrow keys etc.
///
/// This is a 1:1 port of the HTML's interaction model: the HTML uses plain
/// buttons / tiles with `:focus-visible` styling; no scale, no slide, no
/// parallax — just color / background / box-shadow transitions. By keeping
/// visuals entirely in the caller's hands we guarantee every element paints
/// exactly like the `settings.html` reference.
///
/// NOT a replacement for [TvFocusable] in the rest of the app — this is
/// scoped to the new settings subtree where HTML-exact fidelity trumps
/// app-wide chrome consistency.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_theme.dart';
import 'ns_new_settings_nav.dart';
import 'ns_new_settings_root_left.dart';

typedef NsFocusableBuilder = Widget Function(BuildContext context, bool focused);

/// Whether this platform has a mouse pointer that should show a click cursor.
final bool _nsIsDesktop =
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// True only on Android — the custom "Hugging U" focus indicator is
/// gated to Android TV (where remote navigation is the primary input
/// and seeing focus at a glance is critical). Desktop keeps stock
/// focus styling.
final bool _nsFocusAccentPlatform = !kIsWeb && Platform.isAndroid;

/// Inherited widget that opts a subtree into the custom Android focus
/// accent. We keep it scoped (rather than global) so we can roll the
/// effect out one page at a time — start with Playlists + rail, then
/// enable everywhere once the user approves.
///
/// Usage:
///   NsFocusAccentScope(
///     child: ... my page / rail ...,
///   )
///
/// Nested scopes are a no-op — the first ancestor wins.
class NsFocusAccentScope extends InheritedWidget {
  const NsFocusAccentScope({
    super.key,
    this.enabled = true,
    /// When true, the orange "Hugging L" shows for [NsFocusable] children
    /// even on non-Android, as long as [enabled] is true. Use in overlay
    /// routes (e.g. [showDialog]) that are outside the New Settings subtree,
    /// where the normal platform gate would hide the TV focus accent.
    this.overridePlatformGate = false,
    required super.child,
  });

  /// Master toggle — child focusables consult this alongside
  /// [_nsFocusAccentPlatform] (unless [overridePlatformGate] is set).
  final bool enabled;

  final bool overridePlatformGate;

  static bool isActiveFor(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NsFocusAccentScope>();
    if (scope == null) return false;
    if (!scope.enabled) return false;
    if (scope.overridePlatformGate) return true;
    return _nsFocusAccentPlatform;
  }

  @override
  bool updateShouldNotify(NsFocusAccentScope old) =>
      old.enabled != enabled ||
      old.overridePlatformGate != overridePlatformGate;
}

class NsFocusable extends StatefulWidget {
  const NsFocusable({
    super.key,
    required this.builder,
    this.onActivate,
    this.onKeyIntercept,
    this.onFocusedChange,
    this.focusNode,
    this.autofocus = false,
    this.canRequestFocus = true,
    this.includeSemantics = true,
    this.semanticLabel,
    this.isButton = true,
    this.skipTraversal = false,
    this.focusAccentRadius = 10,
    this.showFocusAccent = true,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusUpNeighbor,
    this.focusDownNeighbor,
  });

  /// When set, D-pad **Left** moves focus here before the global
  /// [newSettingsRootLeftFromNsFocusable] rail handoff (which only runs when
  /// this is `null` and spatial [focusInDirection] does not move).
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusUpNeighbor;
  final FocusNode? focusDownNeighbor;

  /// Renders the focusable's body. Receives the current focused state so the
  /// caller can paint hover/focus styling exactly as the HTML reference does.
  final NsFocusableBuilder builder;

  /// Fired when D-pad Select/Enter/Space/NumpadEnter is pressed while focused,
  /// or when the child is tapped by mouse / touch.
  final VoidCallback? onActivate;

  /// Return [KeyEventResult.handled] / [KeyEventResult.ignored] to stop event
  /// propagation, or `null` to fall through to default activation handling.
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  /// Fired whenever this focusable gains or loses focus.
  final ValueChanged<bool>? onFocusedChange;

  final FocusNode? focusNode;
  final bool autofocus;
  final bool canRequestFocus;

  final bool includeSemantics;
  final String? semanticLabel;

  /// Whether to report this to a11y as a button role.
  final bool isButton;

  /// When true the focusable is excluded from the tab / next-focus
  /// traversal ring. Direct D-pad spatial movement can still reach it
  /// (useful for the sub-page Back button — we want the user to be
  /// able to D-pad up to it, but auto-advancing focus should skip it).
  final bool skipTraversal;

  /// Corner radius used by the Hugging-L focus accent (Android only).
  /// Should roughly match the element's own `BorderRadius.circular` so
  /// the L curves along the same edge — defaults to 10 which fits the
  /// vast majority of new-settings tiles / rows / buttons.
  final double focusAccentRadius;

  /// Opt-out from the Hugging-L accent for specific focusables (e.g.
  /// very small icon buttons where the L would look oversized, or
  /// tiles that already paint their own selection indicator).
  final bool showFocusAccent;

  @override
  State<NsFocusable> createState() => _NsFocusableState();
}

class _NsFocusableState extends State<NsFocusable> {
  late FocusNode _node;
  bool _ownsNode = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? (FocusNode()..debugLabel = 'NsFocusable');
    _ownsNode = widget.focusNode == null;
  }

  @override
  void didUpdateWidget(covariant NsFocusable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      if (_ownsNode) _node.dispose();
      _node = widget.focusNode ?? (FocusNode()..debugLabel = 'NsFocusable');
      _ownsNode = widget.focusNode == null;
    }
  }

  @override
  void dispose() {
    if (_ownsNode) _node.dispose();
    super.dispose();
  }

  static bool _isActivate(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    return k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.gameButtonA;
  }

  void _handleTap() {
    if (!widget.canRequestFocus) return;
    if (!_node.hasFocus) _node.requestFocus();
    widget.onActivate?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.builder(context, _focused);

    // Android-only Hugging-L focus accent — a rounded cyan strip that
    // hugs the left and bottom of the focused element. Painted in a
    // non-clipping Stack on top of the child, without changing the
    // child's own fill or border.
    if (widget.showFocusAccent &&
        _focused &&
        NsFocusAccentScope.isActiveFor(context)) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _NsFocusAccentPainter(
                  radius: widget.focusAccentRadius,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_nsIsDesktop) {
      child = MouseRegion(
        cursor: widget.onActivate != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: child,
      );
    }

    if (widget.onActivate != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: child,
      );
    }

    final focus = Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      canRequestFocus: widget.canRequestFocus,
      skipTraversal: widget.skipTraversal,
      includeSemantics: false,
      onFocusChange: (has) {
        if (!mounted) return;
        if (_focused == has) return;
        setState(() => _focused = has);
        widget.onFocusedChange?.call(has);
      },
      onKeyEvent: (node, event) {
        final intercepted = widget.onKeyIntercept?.call(node, event);
        if (intercepted != null) return intercepted;
        if (event is KeyDownEvent) {
          final k = event.logicalKey;
          FocusNode? neighbor;
          if (k == LogicalKeyboardKey.arrowLeft) {
            neighbor = widget.focusLeftNeighbor;
          } else if (k == LogicalKeyboardKey.arrowRight) {
            neighbor = widget.focusRightNeighbor;
          } else if (k == LogicalKeyboardKey.arrowUp) {
            neighbor = widget.focusUpNeighbor;
          } else if (k == LogicalKeyboardKey.arrowDown) {
            neighbor = widget.focusDownNeighbor;
          }
          if (neighbor != null && neighbor.canRequestFocus) {
            neighbor.requestFocus();
            return KeyEventResult.handled;
          }
        }
        final ctx = node.context;
        if (ctx != null && ctx.mounted) {
          final nav = ctx.findAncestorWidgetOfExactType<NsNewSettingsNav>();
          if (nav != null) {
            final rootLeft = newSettingsRootLeftFromNsFocusable(
              node: node,
              event: event,
              nav: nav,
              categoriesRailKey: nav.categoriesRailKey,
            );
            if (rootLeft != null) return rootLeft;
          }
        }
        if (_isActivate(event)) {
          widget.onActivate?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );

    if (!widget.includeSemantics) return focus;

    return Semantics(
      button: widget.isButton,
      enabled: widget.canRequestFocus && widget.onActivate != null,
      focusable: widget.canRequestFocus,
      focused: _focused,
      label: widget.semanticLabel,
      child: focus,
    );
  }
}

/// Paints the left-accent focus indicator — the HTML's
/// `border-left: 3px solid var(--focus-accent)` translated to Flutter
/// **with CSS's exact corner taper**.
///
/// When a CSS element has `border-left: 3px solid` and `border-top: 0`
/// with `border-radius: r`, the browser draws the top-left corner
/// border as a region bounded by:
///
///   * a CIRCULAR outer arc (radius = r, center = (r, r)), and
///   * an ELLIPTICAL inner arc whose horizontal radius is
///     `r - border-left-width` (= `r − 3`) and whose vertical radius
///     is `r - border-top-width` (= `r − 0` = `r`).
///
/// The result is a wedge that tapers from **0 px** thickness at the
/// very top of the corner (where the zero-width top border begins) to
/// **3 px** thickness at the left edge (where the 3 px left border is
/// in full effect). Mirrored at the bottom-left corner. That taper is
/// what makes the bar look like a natural part of the element's
/// border instead of a sliced-off straight line.
///
/// We build this shape as a single closed Path and fill it — one draw
/// call, no masking, no stroke, no ring subtraction.
class _NsFocusAccentPainter extends CustomPainter {
  _NsFocusAccentPainter({required this.radius});

  /// Corner radius of the focused element.
  final double radius;

  /// Stripe thickness — matches CSS `border-left: 3px`.
  static const double _thickness = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < _thickness * 2) return;

    // Cap radius to the element's half-height so very short elements
    // (chips, small option tiles) don't try to draw corner arcs taller
    // than themselves.
    final maxR = size.height / 2;
    final r = radius.clamp(0.0, maxR);

    // If radius is effectively zero, draw a plain 3 px rectangle —
    // no corners to taper. (Flat rows inside cards etc.)
    if (r <= _thickness * 0.5) {
      final rect = Rect.fromLTWH(0, 0, _thickness, size.height);
      canvas.drawRect(rect, Paint()..color = NsColors.focusAccent);
      return;
    }

    final h = size.height;
    final t = _thickness;

    // Inner arc radii match CSS:
    //   horizontal inner radius = r - border-left-width = r - 3
    //   vertical   inner radius = r - border-top-width  = r - 0 = r
    // (No top/bottom border, so the inner ellipse's vertical extent
    // reaches the outer arc's vertical extent — producing the 0-width
    // taper at the very top / bottom of each corner.)
    final innerRx = (r - t).clamp(0.0, r);
    final innerRy = r;

    // Single closed path outlining the entire left accent region:
    //
    //   A (r, 0)  → outer arc (circ)      → B (0, r)
    //   B (0, r)  → straight vertical     → C (0, h - r)
    //   C (0,h−r) → outer arc (circ)      → D (r, h)
    //   D (r, h)  → inner ellipse (BL)    → E (t, h − r)
    //   E (t,h−r) → straight vertical     → F (t, r)
    //   F (t, r)  → inner ellipse (TL)    → A (r, 0)
    //
    // Filling this closed region produces a tapered strip on the left
    // side — exactly the same shape CSS paints with `border-left: 3px
    // solid` plus `border-radius`.
    final path = Path()
      ..moveTo(r, 0)
      ..arcToPoint(
        Offset(0, r),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(0, h - r)
      ..arcToPoint(
        Offset(r, h),
        radius: Radius.circular(r),
        clockwise: false,
      )
      // Bottom-left inner elliptical arc, traversed clockwise to
      // close the shape back to the inner straight segment.
      ..arcToPoint(
        Offset(t, h - r),
        radius: Radius.elliptical(innerRx, innerRy),
        clockwise: true,
      )
      ..lineTo(t, r)
      // Top-left inner elliptical arc, back to the start point.
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.elliptical(innerRx, innerRy),
        clockwise: true,
      )
      ..close();

    // Soft halo behind the bar — matches the preview's
    // `box-shadow: -3px 0 14px -3px var(--focus-glow)`. A single
    // blurred draw of the same path is close enough; it reads as a
    // gentle halo spilling leftward of the crisp bar.
    canvas.drawPath(
      path,
      Paint()
        ..color = NsColors.focusAccentGlow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Crisp solid fill on top.
    canvas.drawPath(path, Paint()..color = NsColors.focusAccent);
  }

  @override
  bool shouldRepaint(covariant _NsFocusAccentPainter old) =>
      old.radius != radius;
}
