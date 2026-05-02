import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// Left/right chevrons when the horizontal category list overflows (Windows only).
class WindowsCategoryScrollArrows extends StatefulWidget {
  const WindowsCategoryScrollArrows({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  State<WindowsCategoryScrollArrows> createState() =>
      _WindowsCategoryScrollArrowsState();
}

class _WindowsCategoryScrollArrowsState
    extends State<WindowsCategoryScrollArrows> {
  static const double _arrowTapWidth = 36;
  static const double _nudge = 160;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant WindowsCategoryScrollArrows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _showLeft {
    if (!widget.controller.hasClients) return false;
    return widget.controller.offset > 2;
  }

  bool get _showRight {
    if (!widget.controller.hasClients) return false;
    final c = widget.controller;
    return c.offset < c.position.maxScrollExtent - 2;
  }

  bool get _scrollable {
    if (!widget.controller.hasClients) return false;
    return widget.controller.position.maxScrollExtent > 2;
  }

  Future<void> _nudgeLeft() async {
    if (!widget.controller.hasClients) return;
    final c = widget.controller;
    final t = (c.offset - _nudge).clamp(0.0, c.position.maxScrollExtent);
    await c.animateTo(
      t,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _nudgeRight() async {
    if (!widget.controller.hasClients) return;
    final c = widget.controller;
    final t = (c.offset + _nudge).clamp(0.0, c.position.maxScrollExtent);
    await c.animateTo(
      t,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) return widget.child;

    final showChrome = _scrollable;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showChrome ? _arrowTapWidth : 0,
              ),
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _onScroll());
                  return false;
                },
                child: widget.child,
              ),
            ),
            if (showChrome && _showLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _arrowTapWidth,
                child: _ArrowFade(
                  alignEnd: false,
                  onTap: _nudgeLeft,
                ),
              ),
            if (showChrome && _showRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _arrowTapWidth,
                child: _ArrowFade(
                  alignEnd: true,
                  onTap: _nudgeRight,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ArrowFade extends StatelessWidget {
  const _ArrowFade({
    required this.alignEnd,
    required this.onTap,
  });

  final bool alignEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      end: alignEnd ? Alignment.centerLeft : Alignment.centerRight,
      colors: [
        Colors.black.withValues(alpha: 0.55),
        Colors.black.withValues(alpha: 0),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: alignEnd ? Radius.zero : const Radius.circular(8),
          right: alignEnd ? const Radius.circular(8) : Radius.zero,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: Center(
            child: Icon(
              alignEnd
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
