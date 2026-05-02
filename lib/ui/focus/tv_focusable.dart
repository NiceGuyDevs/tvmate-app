import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';

/// True on Windows, macOS, Linux — enables mouse-first UX (click, hover, cursor).
final bool _isDesktop =
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// True on Android / iOS — enables finger-touch UX (tap, drag, long-press).
final bool _isMobile = Platform.isAndroid || Platform.isIOS;

/// Live TV–style two-step mouse: first click focuses, second click activates.
/// Same check as call sites that pass [TvFocusable.onDesktopTap].
bool get tvmateDesktopTwoStepMouse =>
    Platform.isWindows || Platform.isMacOS;

LogicalKeyboardKey? _dpadRepeatLastKey;
DateTime? _dpadRepeatLastTime;

/// Clears D-pad repeat heuristics (call when re-applying shell / grid focus).
void resetDpadKeyRepeatTracking() {
  _dpadRepeatLastKey = null;
  _dpadRepeatLastTime = null;
}

/// D-pad / TV remote: smooth scale, soft parallax slide, and elevation on focus.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    this.onActivate,
    this.onDesktopTap,
    this.onLongPress,
    this.onFocusedChange,
    this.onKeyIntercept,
    this.autofocus = false,
    this.focusNode,
    this.focusPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.focusScale,
    this.parallaxSlide,
    this.showFocusElevation = true,
    this.focusedBorderWidth = 2.2,
    this.canRequestFocus = true,
    this.focusBorderColor,
    this.focusElevationShadow,
    this.focusBackgroundColor,
  });

  final Widget child;
  final VoidCallback? onActivate;

  /// When non-null **and** [tvmateDesktopTwoStepMouse] is true, mouse tap uses
  /// two-step activation: first press only [FocusNode.requestFocus] (no
  /// [onActivate]); second press on the same focused control runs [onActivate].
  /// Hero / preview follows [onFocusedChange] as usual. Keyboard / D-pad
  /// Activate is unchanged.
  ///
  /// The reference is only checked for nullness; it is not invoked (avoiding
  /// duplicate work with focus-driven [onFocusedChange]).
  final VoidCallback? onDesktopTap;

  /// Long-press callback (mobile touch only). Wire to context menus, favorites, etc.
  final VoidCallback? onLongPress;

  final ValueChanged<bool>? onFocusedChange;

  /// Return [KeyEventResult.handled] / [KeyEventResult.ignored] to stop propagation,
  /// or `null` to fall through to default activate handling.
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  final bool autofocus;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry focusPadding;

  /// Defaults to [AppTheme.focusScale].
  final double? focusScale;

  /// Fractional [AnimatedSlide] offset when focused; defaults to [AppTheme.focusParallaxSlide].
  final double? parallaxSlide;

  /// Extra shadow under the focus ring (rail cards).
  final bool showFocusElevation;

  /// Border width when focused (default **2.2**). Use **~1.4** for dense lists.
  final double focusedBorderWidth;

  /// When false, this widget cannot take focus (e.g. block chips during restore).
  final bool canRequestFocus;

  /// When non-null, overrides the team-palette-blended focus border color.
  final Color? focusBorderColor;

  /// When non-null, replaces `chrome.railCardFocusShadow` when focused.
  final List<BoxShadow>? focusElevationShadow;

  /// When non-null, a light fill while focused (or hovered on desktop) under the
  /// child. Visible mainly in the [focusPadding] margin around the child; use
  /// a very low alpha (e.g. 0.05–0.1 on [teamPalette.accent]).
  final Color? focusBackgroundColor;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;
  late final FocusNode _node;
  var _ownsFocusNode = false;

  /// Mobile: [GestureDetector] competes with parent [ScrollView]s in the
  /// gesture arena; pointer + slop gives reliable taps after scroll swipes.
  Timer? _mobileLongPressTimer;
  Offset? _mobileDownGlobal;
  int? _mobilePointer;
  bool _mobileMovedBeyondSlop = false;
  bool _mobileLongPressFired = false;

  double get _scale => widget.focusScale ?? AppTheme.focusScale;
  double get _slide => widget.parallaxSlide ?? AppTheme.focusParallaxSlide;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _node = widget.focusNode!;
    } else {
      _node = FocusNode();
      _ownsFocusNode = true;
    }
  }

  @override
  void dispose() {
    _mobileLongPressTimer?.cancel();
    if (_ownsFocusNode) {
      _node.dispose();
    }
    super.dispose();
  }

  double _mobileTouchSlop(BuildContext context) {
    final gs = MediaQuery.maybeGestureSettingsOf(context);
    final s = gs?.touchSlop;
    if (s != null) return s.clamp(12.0, 48.0);
    return 18.0;
  }

  static bool _isActivate(KeyDownEvent event) {
    final k = event.logicalKey;
    return k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.numpadEnter;
  }

  bool _hovered = false;
  bool _pressing = false;

  void _handleTap() {
    if (!widget.canRequestFocus) return;
    final twoStepMouse =
        tvmateDesktopTwoStepMouse && widget.onDesktopTap != null;
    if (twoStepMouse) {
      if (_node.hasFocus) {
        widget.onActivate?.call();
      } else {
        _node.requestFocus();
      }
      return;
    }
    _node.requestFocus();
    widget.onActivate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.teamPalette;
    final showFocused = _focused || (_isDesktop && _hovered);
    const restBorder = Color(0x0DFFFFFF); // white @ 0.05

    Widget child = AnimatedSlide(
      duration: AppTheme.focusAnimationDuration,
      curve: AppTheme.focusAnimationCurve,
      offset: showFocused ? Offset(0, -_slide) : Offset.zero,
      child: AnimatedScale(
        scale: showFocused ? _scale : 1.0,
        duration: AppTheme.focusAnimationDuration,
        curve: AppTheme.focusAnimationCurve,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: AppTheme.focusAnimationDuration,
          curve: AppTheme.focusAnimationCurve,
          padding: widget.focusPadding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.focusBorderRadius),
            color: showFocused && widget.focusBackgroundColor != null
                ? widget.focusBackgroundColor
                : null,
            border: widget.focusedBorderWidth == 0
                ? null
                : Border.all(
                    color: showFocused
                        ? (widget.focusBorderColor ?? chrome.defaultFocusRingColor)
                        : restBorder,
                    width: showFocused
                        ? widget.focusedBorderWidth
                        : 1,
                  ),
            boxShadow: [
              if (widget.showFocusElevation && showFocused)
                ...(widget.focusElevationShadow ?? chrome.railCardFocusShadow),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: widget.child,
          ),
        ),
      ),
    );

    // Desktop: wrap with mouse region for hover highlight + click-to-activate
    if (_isDesktop) {
      child = MouseRegion(
        cursor: widget.onActivate != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) {
          if (!_hovered) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered) setState(() => _hovered = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onActivate != null ? _handleTap : null,
          child: child,
        ),
      );
    } else if (_isMobile) {
      final hasTap = widget.onActivate != null;
      final hasLongPress = widget.onLongPress != null;
      if (hasTap || hasLongPress) {
        child = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            if (_mobilePointer != null) return;
            _mobilePointer = e.pointer;
            _mobileDownGlobal = e.position;
            _mobileMovedBeyondSlop = false;
            _mobileLongPressFired = false;
            if (hasTap && !_pressing) {
              setState(() => _pressing = true);
            }
            if (hasLongPress) {
              _mobileLongPressTimer?.cancel();
              _mobileLongPressTimer = Timer(
                const Duration(milliseconds: 500),
                () {
                  if (!mounted) return;
                  if (_mobileLongPressFired) return;
                  if (_mobileMovedBeyondSlop) return;
                  _mobileLongPressFired = true;
                  widget.onLongPress?.call();
                  if (hasTap && _pressing) {
                    setState(() => _pressing = false);
                  }
                },
              );
            }
          },
          onPointerMove: (e) {
            if (e.pointer != _mobilePointer || _mobileDownGlobal == null) {
              return;
            }
            final slop = _mobileTouchSlop(context);
            if ((e.position - _mobileDownGlobal!).distance > slop) {
              if (!_mobileMovedBeyondSlop) {
                _mobileMovedBeyondSlop = true;
                _mobileLongPressTimer?.cancel();
                if (hasTap && _pressing) {
                  setState(() => _pressing = false);
                }
              }
            }
          },
          onPointerUp: (e) {
            if (e.pointer != _mobilePointer) return;
            _mobileLongPressTimer?.cancel();
            _mobilePointer = null;
            _mobileDownGlobal = null;
            if (hasTap && _pressing) {
              setState(() => _pressing = false);
            }
            if (_mobileLongPressFired) return;
            if (_mobileMovedBeyondSlop) return;
            if (hasTap) {
              _handleTap();
            }
          },
          onPointerCancel: (e) {
            if (e.pointer != _mobilePointer) return;
            _mobileLongPressTimer?.cancel();
            _mobilePointer = null;
            _mobileDownGlobal = null;
            if (hasTap && _pressing) {
              setState(() => _pressing = false);
            }
          },
          child: AnimatedScale(
            scale: _pressing ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            child: child,
          ),
        );
      }
    }

    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      canRequestFocus: widget.canRequestFocus,
      onFocusChange: (_) {
        final now = _node.hasFocus;
        setState(() => _focused = now);
        widget.onFocusedChange?.call(now);
      },
      onKeyEvent: (node, event) {
        final intercepted = widget.onKeyIntercept?.call(node, event);
        if (intercepted != null) return intercepted;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_isActivate(event)) {
          widget.onActivate?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Tries [node.requestFocus] immediately, then [scheduleMicrotask] and two
/// post-frame passes (Android TV often needs this for a single short D-pad tap),
/// then retries while [node] is not [FocusNode.hasFocus] yet.
void scheduleRequestFocusWhenReady(
  FocusNode node, {
  int maxFrames = 12,
}) {
  void apply() {
    if (node.canRequestFocus) node.requestFocus();
  }

  apply();
  scheduleMicrotask(apply);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) => apply());
  });

  void attempt(int frame) {
    if (node.hasFocus) return;
    if (node.canRequestFocus) {
      node.requestFocus();
      return;
    }
    if (frame >= maxFrames) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => attempt(frame + 1));
  }

  attempt(0);
}

/// Grid → pills → hero → top: one D-pad step — immediate [requestFocus] plus
/// [scheduleRequestFocusWhenReady] so a single tap works on Android TV.
void requestLadderFocus(FocusNode node) {
  if (node.canRequestFocus) node.requestFocus();
  scheduleRequestFocusWhenReady(node);
}

/// D-pad repeat: one physical step per press; holding must not climb multiple
/// rungs (handled separately by returning [KeyEventResult.handled]).
///
/// Uses [KeyDownEvent.repeat] when the SDK provides it; otherwise approximates
/// repeat as the same logical key arriving twice within [repeatWindow] (older
/// Flutter builds do not expose [KeyDownEvent.repeat]).
bool isDpadKeyRepeat(
  KeyEvent event, {
  Duration repeatWindow = const Duration(milliseconds: 110),
}) {
  if (event is! KeyDownEvent) return false;
  final kd = event;
  try {
    final r = (kd as dynamic).repeat;
    if (r == true) return true;
  } catch (_) {
    // Older Flutter: no [KeyDownEvent.repeat] getter.
  }

  final now = DateTime.now();
  final k = kd.logicalKey;
  final prevT = _dpadRepeatLastTime;
  final prevK = _dpadRepeatLastKey;
  if (prevT != null && prevK == k && now.difference(prevT) < repeatWindow) {
    _dpadRepeatLastTime = now;
    return true;
  }
  _dpadRepeatLastKey = k;
  _dpadRepeatLastTime = now;
  return false;
}

/// After a fullscreen route pops, some TV stacks briefly move focus to category
/// chips or the hero. Re-apply [node] across several frames and short delays.
void scheduleSteadyChannelTileFocus(
  bool Function() mounted,
  FocusNode node,
) {
  void apply() {
    if (!mounted()) return;
    if (node.canRequestFocus) node.requestFocus();
  }

  apply();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      apply();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        apply();
      });
    });
  });
  // Short tail — category/pill focus is suppressed during restore so fewer
  // retries are needed (avoids visible focus hopping).
  for (final ms in [40, 120, 260]) {
    Future<void>.delayed(Duration(milliseconds: ms), apply);
  }
}
