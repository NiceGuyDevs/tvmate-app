/// Fused “Wide” auth shell + on-screen keyboard for Android TVs that do not get a
/// usable system IME (Chromecast / `DeviceMemoryChannel.useInAppTextPadOnly`).
///
/// Visual 1:1 with `settings_auth_modal_with_keyboard.html` **Wide** layout: single
/// card, form column left, keyboard right (stacks vertically when narrow).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_theme.dart';
import 'ns_focusable.dart';

/// Form column width for the wide split. **Never** use `.clamp(280, 360)` on
/// the form alone: for small dialog widths (common on TV overlays / split
/// constraints) that steals the entire row — keyboard width becomes 0px, so
/// only the OSK header paints and keys disappear.
double _tvAuthFormColumnWidth(double shellWidth) {
  const divider = 1.0;
  const minKeyboard = 280.0;
  const minForm = 220.0;
  final available = shellWidth - divider;
  if (available <= minForm + minKeyboard) {
    final kb = math.max(200.0, available * 0.55);
    return math.max(160.0, available - kb);
  }
  final maxForm = available - minKeyboard;
  final target = (shellWidth * 0.34).clamp(minForm, 360.0);
  return math.min(target, maxForm);
}

/// Vertical split using only [Positioned] — avoids [Column]/[Expanded] height
/// negotiation on leanback (Chromecast) where the bottom pane could get 0px.
class _TvSplitStackVertical extends StatelessWidget {
  const _TvSplitStackVertical({
    required this.topFraction,
    required this.top,
    required this.bottom,
  });

  final double topFraction;
  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final topH = math.min(
          math.max(h * topFraction, 120.0),
          math.max(h - 121.0, 120.0),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(left: 0, right: 0, top: 0, height: topH, child: top),
            Positioned(
              left: 0,
              right: 0,
              top: topH,
              height: 1,
              child: const ColoredBox(color: NsColors.line),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: topH + 1,
              bottom: 0,
              child: bottom,
            ),
          ],
        );
      },
    );
  }
}

/// Horizontal split: form | divider | keyboard with explicit [top]/[bottom] on
/// the keyboard pane so it always receives the full card height.
class _TvSplitStackHorizontal extends StatelessWidget {
  const _TvSplitStackHorizontal({
    required this.leftWidth,
    required this.left,
    required this.right,
  });

  final double leftWidth;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final formW = leftWidth;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: formW,
          child: left,
        ),
        Positioned(
          left: formW,
          top: 0,
          bottom: 0,
          width: 1,
          child: const ColoredBox(color: NsColors.line),
        ),
        Positioned(
          left: formW + 1,
          top: 0,
          right: 0,
          bottom: 0,
          child: right,
        ),
      ],
    );
  }
}

/// Shell: one border, one shadow, optional radial glow — matches HTML `.modal-stack`.
class NsAuthTvWideShell extends StatelessWidget {
  const NsAuthTvWideShell({
    super.key,
    required this.width,
    required this.height,
    required this.form,
    required this.keyboard,
  });

  /// Total size of the fused card (caller must pass explicit dimensions — see
  /// [showNsAuthModal] TV path).
  final double width;
  final double height;
  final Widget form;
  final Widget keyboard;

  @override
  Widget build(BuildContext context) {
    // Match `settings_*_with_keyboard.html` / `body.layout-side`:
    // stack form above keyboard only when the *viewport* is narrow
    // (`@media (max-width: 780px)`), not when the fused card is narrow
    // because it sits in a split pane beside the rail.
    final viewportW = MediaQuery.sizeOf(context).width;
    final narrow = viewportW < 780;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: NsColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NsColors.line2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              offset: Offset(0, 18),
              blurRadius: 42,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: narrow
              ? _TvSplitStackVertical(
                  topFraction: 56 / 100,
                  top: form,
                  bottom: keyboard,
                )
              : _TvSplitStackHorizontal(
                  leftWidth: _tvAuthFormColumnWidth(width),
                  left: form,
                  right: keyboard,
                ),
        ),
      ),
    );
  }
}

/// Keyboard panel: gradient header + pill hint + key grid — matches HTML Wide `.osk-panel`.
class NsAuthTvKeyboard extends StatefulWidget {
  const NsAuthTvKeyboard({
    super.key,
    required this.activeFieldLabel,
    required this.linkFocus,
    required this.onInsert,
    required this.onBackspace,
    required this.onClearField,
    required this.onToggleObscure,
    required this.onNextField,
    required this.onFirstKeyReady,
  });

  final String activeFieldLabel;
  final FocusNode linkFocus;
  final void Function(String ch) onInsert;
  final VoidCallback onBackspace;
  final VoidCallback onClearField;
  final VoidCallback onToggleObscure;
  /// Moves focus to the next form field (or primary action), like Enter / Next.
  final VoidCallback onNextField;
  final ValueChanged<FocusNode> onFirstKeyReady;

  @override
  State<NsAuthTvKeyboard> createState() => _NsAuthTvKeyboardState();
}

enum _KeyKind { normal, action, danger, sub, space, shift, next }

class _KeyDef {
  const _KeyDef(this.label, this.value, this.kind, this.flex);
  final String label;
  final String value;
  final _KeyKind kind;
  final double flex;
}

class _NsAuthTvKeyboardState extends State<NsAuthTvKeyboard> {
  /// Isolated controller so this pane never attaches to
  /// [PrimaryScrollController] (Account [ListView] behind the route).
  final ScrollController _kbdScroll = ScrollController();

  /// Sticky shift — letters a–z type uppercase until turned off (TV passwords).
  bool _shiftOn = false;

  static final List<List<_KeyDef>> _layout = [
    '1234567890'
        .split('')
        .map((c) => _KeyDef(c, c, _KeyKind.normal, 1))
        .toList(),
    'qwertyuiop'
        .split('')
        .map((c) => _KeyDef(c, c, _KeyKind.normal, 1))
        .toList(),
    'asdfghjkl'
        .split('')
        .map((c) => _KeyDef(c, c, _KeyKind.normal, 1))
        .toList(),
    [
      const _KeyDef('⇧ Shift', '', _KeyKind.shift, 1.35),
      ...'zxcvbnm'
          .split('')
          .map((c) => _KeyDef(c, c, _KeyKind.normal, 1)),
    ],
    [
      const _KeyDef('@', '@', _KeyKind.normal, 1),
      const _KeyDef('.', '.', _KeyKind.normal, 1),
      const _KeyDef('_', '_', _KeyKind.normal, 1),
      const _KeyDef('-', '-', _KeyKind.normal, 1),
      const _KeyDef('/', '/', _KeyKind.normal, 1),
      const _KeyDef(':', ':', _KeyKind.normal, 1),
      const _KeyDef('Space', ' ', _KeyKind.space, 4),
    ],
    [
      const _KeyDef('⌫ Backspace', '', _KeyKind.danger, 1.35),
      const _KeyDef('Clear field', '', _KeyKind.sub, 1.15),
      const _KeyDef('Show / hide password', '', _KeyKind.action, 1.05),
      const _KeyDef('Next ↓', '', _KeyKind.next, 1.1),
    ],
  ];

  late final List<FocusNode> _nodes;
  bool _announcedFirst = false;

  @override
  void initState() {
    super.initState();
    var n = 0;
    for (final row in _layout) {
      n += row.length;
    }
    _nodes = List.generate(
      n,
      (i) => FocusNode(debugLabel: 'nsAuthKbd:$i'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _announcedFirst) return;
      _announcedFirst = true;
      widget.onFirstKeyReady(_nodes.first);
    });
  }

  @override
  void dispose() {
    _kbdScroll.dispose();
    for (final f in _nodes) {
      f.dispose();
    }
    super.dispose();
  }

  _KeyDef _effectiveKeyDef(_KeyDef def) {
    if (!_shiftOn || def.kind != _KeyKind.normal) return def;
    if (def.value.length != 1) return def;
    final v = def.value;
    final code = v.codeUnitAt(0);
    if (code >= 0x61 && code <= 0x7A) {
      final u = v.toUpperCase();
      return _KeyDef(u, u, def.kind, def.flex);
    }
    return def;
  }

  String _shiftKeyLabel(_KeyDef def) {
    if (def.kind != _KeyKind.shift) return def.label;
    return _shiftOn ? '⇧ CAPS' : '⇧ Shift';
  }

  /// Explicit cell widths (no [Expanded]): [Row]+[Expanded] inside scaled /
  /// tight TV layouts has produced zero-width cells on some leanback devices.
  List<Widget> _buildKeyboardRowsMeasured(double rowWidth, double keyHeight) {
    const gap = 9.0;
    var idx = 0;
    final out = <Widget>[];
    for (var r = 0; r < _layout.length; r++) {
      final row = _layout[r];
      final n = row.length;
      final gapsTotal = gap * (n - 1);
      final flexSum = row.fold<double>(0, (a, d) => a + d.flex);
      final netRowW = math.max(40.0, rowWidth - gapsTotal);
      final cells = <Widget>[];
      for (var k = 0; k < n; k++) {
        final def = row[k];
        final flat = idx++;
        final w = netRowW * (def.flex / flexSum);
        if (k > 0) {
          cells.add(const SizedBox(width: gap));
        }
        final effective = _effectiveKeyDef(def);
        cells.add(
          SizedBox(
            width: w,
            height: keyHeight,
            child: _TvKey(
              def: effective,
              displayLabel: def.kind == _KeyKind.shift
                  ? _shiftKeyLabel(def)
                  : effective.label,
              shiftLatched: def.kind == _KeyKind.shift && _shiftOn,
              focusNode: _nodes[flat],
              traversalOrder: 100 + flat,
              onKeyIntercept: (k == 0 || flat == 0)
                  ? (n, ev) {
                      if (ev is! KeyDownEvent) return null;
                      if (flat == 0 &&
                          ev.logicalKey == LogicalKeyboardKey.arrowUp) {
                        widget.linkFocus.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (k == 0 &&
                          ev.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        widget.linkFocus.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return null;
                    }
                  : null,
              onActivate: () => _onKey(def),
            ),
          ),
        );
      }
      out.add(
        SizedBox(
          height: keyHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
      if (r < _layout.length - 1) {
        out.add(const SizedBox(height: 11));
      }
    }
    return out;
  }

  static const double _headerHeight = 76.0;

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NsColors.line),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.045),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: NsColors.accent.withValues(alpha: 0.08),
            offset: const Offset(0, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'ON-SCREEN KEYBOARD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: NsColors.accent,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: NsColors.surface3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NsColors.line),
            ),
            child: Text(
              'Editing: ${widget.activeFieldLabel}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NsColors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x0F4DD0E1),
            Colors.transparent,
          ],
          stops: [0.0, 0.42],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              NsColors.surface2,
              NsColors.surface.withValues(alpha: 0.92),
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final maxH = c.maxHeight.isFinite ? c.maxHeight : 400.0;
            final headerUsed = math
                .min(_headerHeight, maxH * 0.38)
                .clamp(40.0, _headerHeight);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: headerUsed,
                  child: ClipRect(child: _buildHeader(context)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                    child: LayoutBuilder(
                      builder: (context, bc) {
                        final innerW = math.max(120.0, bc.maxWidth);
                        final innerH = math.max(64.0, bc.maxHeight);
                        const rowGap = 11.0;
                        const nRows = 6;
                        const afterGridGap = 16.0;
                        const hintReserve = 100.0;
                        final rowGaps = rowGap * (nRows - 1);
                        final rowBudget = innerH -
                            rowGaps -
                            afterGridGap -
                            hintReserve;
                        final keyH =
                            (rowBudget / nRows).clamp(30.0, 56.0);
                        return SingleChildScrollView(
                          controller: _kbdScroll,
                          primary: false,
                          physics: const ClampingScrollPhysics(),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ..._buildKeyboardRowsMeasured(innerW, keyH),
                              const SizedBox(height: afterGridGap),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: NsColors.line2,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Text(
                                  'Chromecast / leanback: there is often no usable system '
                                  'keyboard — this pad types into the highlighted field. '
                                  'Next ↓ acts like Enter — moves to the next field. '
                                  'Use the D-pad to move between fields and keys.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.55,
                                    color: NsColors.text3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _onKey(_KeyDef def) {
    switch (def.kind) {
      case _KeyKind.danger:
        if (def.label.startsWith('⌫')) widget.onBackspace();
        break;
      case _KeyKind.sub:
        widget.onClearField();
        break;
      case _KeyKind.action:
        if (def.label.contains('password')) {
          widget.onToggleObscure();
        } else {
          widget.onInsert(_effectiveKeyDef(def).value);
        }
        break;
      case _KeyKind.space:
        widget.onInsert(' ');
        break;
      case _KeyKind.shift:
        setState(() => _shiftOn = !_shiftOn);
        break;
      case _KeyKind.next:
        widget.onNextField();
        break;
      case _KeyKind.normal:
        widget.onInsert(_effectiveKeyDef(def).value);
        break;
    }
  }
}

class _TvKey extends StatelessWidget {
  const _TvKey({
    required this.def,
    required this.focusNode,
    required this.traversalOrder,
    required this.onActivate,
    this.displayLabel,
    this.shiftLatched = false,
    this.onKeyIntercept,
  });

  final _KeyDef def;
  final String? displayLabel;
  /// When true, [def] is the Shift key and caps mode is on.
  final bool shiftLatched;
  final FocusNode focusNode;
  final int traversalOrder;
  final VoidCallback onActivate;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)? onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    final isSpace = def.kind == _KeyKind.space;
    final isDanger = def.kind == _KeyKind.danger;
    final isSub = def.kind == _KeyKind.sub;
    final isShift = def.kind == _KeyKind.shift;
    final isNext = def.kind == _KeyKind.next;
    final isAction = def.kind == _KeyKind.action && !isSpace;
    final label = displayLabel ?? def.label;

    return FocusTraversalOrder(
      order: NumericFocusOrder(traversalOrder.toDouble()),
      child: NsFocusable(
        focusNode: focusNode,
        onActivate: onActivate,
        onKeyIntercept: onKeyIntercept,
        semanticLabel: label,
        builder: (ctx, focused) {
          Color fg = NsColors.text;
          List<Color> bgGrad = const [NsColors.surface3, NsColors.surface2];
          Color border = NsColors.line2;
          if (isShift && shiftLatched) {
            fg = NsColors.accent;
            bgGrad = [
              NsColors.accent.withValues(alpha: 0.18),
              NsColors.accentSoft,
            ];
            border = NsColors.accentLine;
          } else if (isAction && def.label.contains('password')) {
            fg = NsColors.accent;
            bgGrad = [
              NsColors.accent.withValues(alpha: 0.18),
              NsColors.accentSoft,
            ];
            border = NsColors.accentLine;
          } else if (isNext) {
            if (focused) {
              // Match new-settings TV focus (orange) instead of cyan when focused.
              fg = NsColors.focusAccent;
              bgGrad = [
                NsColors.focusAccent.withValues(alpha: 0.2),
                NsColors.focusAccent.withValues(alpha: 0.08),
              ];
              border = NsColors.focusAccent.withValues(alpha: 0.55);
            } else {
              fg = NsColors.accent;
              bgGrad = [
                NsColors.accent.withValues(alpha: 0.16),
                NsColors.accentSoft,
              ];
              border = NsColors.accentLine;
            }
          } else if (isDanger) {
            fg = NsColors.danger;
            bgGrad = [NsColors.dangerSoft, NsColors.dangerSoft];
            border = NsColors.danger.withValues(alpha: 0.4);
          } else if (isSub) {
            fg = NsColors.text2;
            bgGrad = [NsColors.surface3, NsColors.surface2];
          } else if (isSpace) {
            fg = NsColors.text2;
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: NsEase.ease,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: focused ? NsColors.focusAccent : border,
                width: focused ? 1.5 : 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bgGrad,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: focused ? 0.08 : 0.06),
                  offset: const Offset(0, 1),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  offset: const Offset(0, 4),
                  blurRadius: 14,
                ),
                if (focused)
                  BoxShadow(
                    color: NsColors.focusAccentGlow,
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
              ],
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSub || isNext
                    ? 12
                    : (isSpace || isShift ? 12 : 15),
                fontWeight: FontWeight.w700,
                letterSpacing: isSpace ? 0.5 : 0.3,
                color: fg,
                height: 1.1,
                decoration: TextDecoration.none,
              ),
            ),
          );
        },
      ),
    );
  }
}
