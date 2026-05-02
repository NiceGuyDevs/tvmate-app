import 'package:flutter/material.dart';

/// Windows browse rail: short “roll / flip” when [segmentKey] changes (wave or row band).
///
/// Only used from Windows code paths; behavior is generic.
class WindowsBrowseRailFlipSwitcher extends StatelessWidget {
  const WindowsBrowseRailFlipSwitcher({
    super.key,
    required this.segmentKey,
    required this.child,
  });

  final String segmentKey;
  final Widget child;

  static const Duration _kDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _kDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final w in previousChildren) w,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: _rollFlipTransition,
      child: KeyedSubtree(
        key: ValueKey<String>(segmentKey),
        child: child,
      ),
    );
  }

  /// Subtle “tread rolling back” — small rotateX + slight drop, not a full flip.
  static Widget _rollFlipTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        const maxAngle = 0.38;
        final angle = (1.0 - t) * maxAngle;
        final dy = (1.0 - t) * 5.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0006)
              ..rotateX(angle),
            child: Opacity(
              opacity: (0.92 + 0.08 * t).clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
