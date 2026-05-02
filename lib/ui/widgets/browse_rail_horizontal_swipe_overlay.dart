import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps Movies/Series poster rails on Android: detects horizontal flings
/// without using [GestureDetector], so [TapGestureRecognizer]s on child
/// [TvFocusable] tiles do not lose the gesture arena to a parent drag.
class BrowseRailHorizontalSwipeOverlay extends StatefulWidget {
  const BrowseRailHorizontalSwipeOverlay({
    super.key,
    required this.child,
    required this.onHorizontalSwipeEnd,
  });

  final Widget child;

  /// Same contract as [GestureDetector.onHorizontalDragEnd] (velocity in px/s).
  final GestureDragEndCallback onHorizontalSwipeEnd;

  @override
  State<BrowseRailHorizontalSwipeOverlay> createState() =>
      _BrowseRailHorizontalSwipeOverlayState();
}

class _BrowseRailHorizontalSwipeOverlayState
    extends State<BrowseRailHorizontalSwipeOverlay> {
  int? _pointer;
  Offset? _downGlobal;
  Duration? _downTime;
  Offset? _lastGlobal;
  Duration? _lastTime;
  double _maxDistanceFromDown = 0;

  void _reset() {
    _pointer = null;
    _downGlobal = null;
    _downTime = null;
    _lastGlobal = null;
    _lastTime = null;
    _maxDistanceFromDown = 0;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointer = e.pointer;
    _downGlobal = e.position;
    _downTime = e.timeStamp;
    _lastGlobal = e.position;
    _lastTime = e.timeStamp;
    _maxDistanceFromDown = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || _downGlobal == null) return;
    _lastGlobal = e.position;
    _lastTime = e.timeStamp;
    final d = (e.position - _downGlobal!).distance;
    if (d > _maxDistanceFromDown) _maxDistanceFromDown = d;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointer || _downGlobal == null || _downTime == null) {
      _reset();
      return;
    }
    final downPos = _downGlobal!;
    final downT = _downTime!;
    final lastPos = _lastGlobal ?? e.position;
    final lastT = _lastTime ?? e.timeStamp;
    var maxD = _maxDistanceFromDown;
    final dEnd = (e.position - downPos).distance;
    if (dEnd > maxD) maxD = dEnd;

    _reset();

    if (maxD < 28.0) return;

    final totalUs = (e.timeStamp - downT).inMicroseconds;
    if (totalUs < 8000) return;

    final segUs = (e.timeStamp - lastT).inMicroseconds;
    final double vx;
    final double vy;
    if (segUs >= 2000 && lastPos != e.position) {
      vx = (e.position.dx - lastPos.dx) / segUs * 1e6;
      vy = (e.position.dy - lastPos.dy) / segUs * 1e6;
    } else {
      vx = (e.position.dx - downPos.dx) / totalUs * 1e6;
      vy = (e.position.dy - downPos.dy) / totalUs * 1e6;
    }
    if (vy.abs() > vx.abs() * 1.15) return;

    widget.onHorizontalSwipeEnd(
      DragEndDetails(
        primaryVelocity: vx,
        velocity: Velocity(pixelsPerSecond: Offset(vx, vy)),
      ),
    );
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer == _pointer) _reset();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
