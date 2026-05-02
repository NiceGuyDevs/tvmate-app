import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/tv_focusable.dart';

/// Single brushed area: labels + masked dots on the **left**, numpad on the **right** —
/// one plate. [FocusNode]s are owned by [TvFocusable] only (no nested [Focus]).
class ParentalNumericPinPlate extends StatelessWidget {
  const ParentalNumericPinPlate({
    super.key,
    required this.fields,
    required this.onDigit,
    required this.onBackspace,
    this.dense = true,
    this.gap = 10,
  });

  final List<ParentalPinFieldData> fields;
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final bool dense;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final left = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) SizedBox(height: dense ? 6 : 8),
          _MaskedPinField(
            data: fields[i],
            dense: dense,
            focusDownTarget:
                i < fields.length - 1 ? fields[i + 1].focusNode : null,
            focusUpTarget: i > 0 ? fields[i - 1].focusNode : null,
          ),
        ],
      ],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: dense ? 148 : 160,
            maxWidth: dense ? 188 : 210,
          ),
          child: left,
        ),
        SizedBox(width: gap),
        ParentalPinNumpadGrid(
          dense: dense,
          onDigit: onDigit,
          onBackspace: onBackspace,
        ),
      ],
    );
  }
}

class ParentalPinFieldData {
  const ParentalPinFieldData({
    required this.label,
    required this.controller,
    required this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
}

class _MaskedPinField extends StatelessWidget {
  const _MaskedPinField({
    required this.data,
    required this.dense,
    this.focusDownTarget,
    this.focusUpTarget,
  });

  final ParentalPinFieldData data;
  final bool dense;
  final FocusNode? focusDownTarget;
  final FocusNode? focusUpTarget;

  String _mask(String raw) {
    if (raw.isEmpty) return '·';
    return List<String>.filled(raw.length, '•').join();
  }

  KeyEventResult? _onKeyIntercept(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown && focusDownTarget != null) {
      focusDownTarget!.requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && focusUpTarget != null) {
      focusUpTarget!.requestFocus();
      return KeyEventResult.handled;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hPad = dense ? 8.0 : 10.0;
    final vPad = dense ? 6.0 : 8.0;

    return ListenableBuilder(
      listenable: data.controller,
      builder: (context, _) {
        return TvFocusable(
          focusNode: data.focusNode,
          focusScale: 1.0,
          parallaxSlide: 0,
          showFocusElevation: false,
          focusedBorderWidth: 2,
          focusPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          onActivate: () => data.focusNode.requestFocus(),
          onKeyIntercept: _onKeyIntercept,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: dense ? 10.5 : 11,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              SizedBox(height: dense ? 3 : 4),
              Text(
                _mask(data.controller.text),
                style: theme.textTheme.titleMedium?.copyWith(
                  letterSpacing: dense ? 1.5 : 2,
                  fontSize: dense ? 16 : 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared numeric pad (3×4) for parental PIN flows — fixed column widths (no stretched empty cell).
class ParentalPinNumpadGrid extends StatelessWidget {
  const ParentalPinNumpadGrid({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.dense = false,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final h = dense ? 30.0 : 36.0;
    final pad = dense ? 2.0 : 3.0;
    final fontSize = dense ? 15.0 : 18.0;
    final colW = dense ? 40.0 : 46.0;

    Widget numKey(String d) => Padding(
          padding: EdgeInsets.all(pad),
          child: TvFocusable(
            onActivate: () => onDigit(d),
            focusScale: 1.0,
            parallaxSlide: 0,
            showFocusElevation: false,
            child: SizedBox(
              width: colW,
              height: h,
              child: Center(
                child: Container(
                  height: h,
                  width: colW,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(dense ? 6 : 8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    Widget backspaceKey() => Padding(
          padding: EdgeInsets.all(pad),
          child: TvFocusable(
            onActivate: onBackspace,
            focusScale: 1.0,
            parallaxSlide: 0,
            showFocusElevation: false,
            child: SizedBox(
              width: colW,
              height: h,
              child: Container(
                height: h,
                width: colW,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(dense ? 6 : 8),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                  ),
                  color: Colors.redAccent.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.backspace_outlined,
                  size: dense ? 17 : 20,
                  color: Colors.redAccent.shade100,
                ),
              ),
            ),
          ),
        );

    final spacer = SizedBox(width: colW + 2 * pad);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [numKey('1'), numKey('2'), numKey('3')],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [numKey('4'), numKey('5'), numKey('6')],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [numKey('7'), numKey('8'), numKey('9')],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            backspaceKey(),
            numKey('0'),
            spacer,
          ],
        ),
      ],
    );
  }
}
