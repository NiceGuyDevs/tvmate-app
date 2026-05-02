import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// One vertical “step” on finger swipe (touch only), for poster rails where
/// horizontal paging is handled separately — mirrors D-pad Up/Down without
/// joining the horizontal gesture arena.
class BrowseRailTouchVerticalStepListener extends StatefulWidget {
  const BrowseRailTouchVerticalStepListener({
    super.key,
    required this.child,
    required this.onStepTowardNextRow,
    required this.onStepTowardPreviousRow,
  });

  final Widget child;

  /// Finger moves **down** (next row / same as Arrow Down).
  final VoidCallback onStepTowardNextRow;

  /// Finger moves **up** (previous row / same as Arrow Up).
  final VoidCallback onStepTowardPreviousRow;

  @override
  State<BrowseRailTouchVerticalStepListener> createState() =>
      _BrowseRailTouchVerticalStepListenerState();
}

class _BrowseRailTouchVerticalStepListenerState
    extends State<BrowseRailTouchVerticalStepListener> {
  int? _pointer;
  Offset? _origin;

  void _reset() {
    _pointer = null;
    _origin = null;
  }

  bool _isTouch(PointerEvent e) => e.kind == PointerDeviceKind.touch;

  void _onPointerDown(PointerDownEvent e) {
    if (!_isTouch(e)) return;
    if (_pointer != null) return;
    _pointer = e.pointer;
    _origin = e.localPosition;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointer || _origin == null) {
      _reset();
      return;
    }
    final o = _origin!;
    final p = e.localPosition;
    final dx = p.dx - o.dx;
    final dy = p.dy - o.dy;
    _reset();

    const minTravel = 52.0;
    if (dy.abs() < minTravel) return;
    if (dy.abs() < dx.abs() * 1.35) return;

    if (dy > 0) {
      widget.onStepTowardNextRow();
    } else {
      widget.onStepTowardPreviousRow();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
