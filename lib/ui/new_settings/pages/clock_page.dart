/// Clock overlay sub-page — ports `renderClockPage` (settings.html lines
/// 7964–8110) as three side-by-side columns on wide canvases, matching
/// the HTML's `.clock-col` layout.
///
/// Canvas split:
///   * width ≥ 560 → 3 columns (Display · Position · Color) in a Row
///     wrapped with [IntrinsicHeight] so all three cards render at the
///     same height, exactly like the HTML's flex-row.
///   * width < 560 → columns stack vertically for phone portrait.
///
/// Every control is sized to fit a 600-logical-px TV canvas without
/// scrolling. The tallest column ends up around ~200 px at compact density.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_appearance_controls.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsClockPage extends StatelessWidget {
  const NsClockPage({
    super.key,
    required this.state,
    required this.onBack,
  });

  final NewSettingsState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final threeCol = constraints.maxWidth >= 560;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Clock overlay',
              subtitle:
                  'A small clock that floats over the player. Preview '
                  'updates live in the chosen corner.',
              onBack: onBack,
              actions: [
                _GhostButton(
                  icon: Icons.restore_rounded,
                  label: 'Reset',
                  onPressed: state.resetClockDefaults,
                ),
              ],
            ),
            ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                final columns = [
                  _DisplayColumn(state: state),
                  _PositionColumn(state: state),
                  _ColorColumn(state: state),
                ];
                if (!threeCol) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < columns.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        columns[i],
                      ],
                    ],
                  );
                }
                // IntrinsicHeight forces all three cards to match the
                // tallest column's height — HTML flex-row behaviour.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: columns[0]),
                      const SizedBox(width: 8),
                      Expanded(child: columns[1]),
                      const SizedBox(width: 8),
                      Expanded(child: columns[2]),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── Column shell ───────────────────────────────────────────────────────

class _ClockColumn extends StatelessWidget {
  const _ClockColumn({
    required this.title,
    required this.headerPill,
    required this.child,
    this.dim = false,
  });

  final String title;
  final String headerPill;
  final Widget child;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      curve: NsEase.ease,
      opacity: dim ? 0.45 : 1.0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: d.isCompact ? 8 : 10,
          vertical: d.isCompact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: NsColors.surface,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(NsRadius.card),
          boxShadow: NsShadow.s1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: NsColors.text,
                      fontSize: d.isCompact ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    headerPill,
                    style: TextStyle(
                      color: NsColors.text3,
                      fontSize: d.isCompact ? 8.5 : 9.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: d.isCompact ? 6 : 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

// ─── Field — compact label + content ────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: NsColors.text3,
            fontSize: d.isCompact ? 8 : 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            height: 1,
          ),
        ),
        SizedBox(height: d.isCompact ? 3 : 4),
        child,
      ],
    );
  }
}

Widget _gap(NsDensity d) => SizedBox(height: d.isCompact ? 6 : 8);

// ─── Display column ─────────────────────────────────────────────────────

class _DisplayColumn extends StatelessWidget {
  const _DisplayColumn({required this.state});
  final NewSettingsState state;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final c = state.clock;
    return _ClockColumn(
      title: 'Display',
      headerPill:
          '${c.fmt == '24' ? '24h' : '12h'} · ${nsClockSizeLabel(c.sizePx)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleLine(
            title: 'Show clock overlay',
            value: c.enabled,
            onChanged: (v) => state.setClock((x) => x.enabled = v),
          ),
          _gap(d),
          _Field(
            label: 'Time format',
            child: NsSegmented(
              options: kNsClockFormats,
              selectedId: c.fmt,
              onPick: (id) => state.setClock((x) => x.fmt = id),
            ),
          ),
          _gap(d),
          _Field(
            label: 'Size',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                NsSegmented(
                  options: const [
                    NsOption(id: 'S', label: 'Small'),
                    NsOption(id: 'M', label: 'Medium'),
                    NsOption(id: 'L', label: 'Large'),
                  ],
                  selectedId: c.sizePx == kNsClockSizeSmall
                      ? 'S'
                      : c.sizePx == kNsClockSizeMedium
                          ? 'M'
                          : c.sizePx == kNsClockSizeLarge
                              ? 'L'
                              : '',
                  onPick: (id) {
                    final px = switch (id) {
                      'S' => kNsClockSizeSmall,
                      'M' => kNsClockSizeMedium,
                      'L' => kNsClockSizeLarge,
                      _ => c.sizePx,
                    };
                    state.setClock((x) => x.sizePx = px);
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _CompactSlider(
                        value: c.sizePx.toDouble(),
                        min: kNsClockSizeMin.toDouble(),
                        max: kNsClockSizeMax.toDouble(),
                        divisions: kNsClockSizeMax - kNsClockSizeMin,
                        onChanged: (v) =>
                            state.setClock((x) => x.sizePx = v.round()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ValuePill(text: '${c.sizePx}px'),
                  ],
                ),
              ],
            ),
          ),
          _gap(d),
          _ToggleLine(
            title: 'Frame the clock',
            value: c.framed,
            onChanged: (v) => state.setClock((x) => x.framed = v),
          ),
        ],
      ),
    );
  }
}

// ─── Position column ────────────────────────────────────────────────────

class _PositionColumn extends StatelessWidget {
  const _PositionColumn({required this.state});
  final NewSettingsState state;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final c = state.clock;
    return _ClockColumn(
      title: 'Position',
      headerPill:
          '${kNsClockCornerLabels[c.corner] ?? c.corner} · ${c.opacity}%',
      dim: !c.enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Field(
            label: 'Corner & nudge',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _NudgePad(
                  state: state,
                  cellSize: d.isCompact ? 20.0 : 24.0,
                ),
                const SizedBox(height: 4),
                _LinkButton(
                  label: 'Recenter',
                  onPressed: state.clockRecenterActiveCorner,
                ),
              ],
            ),
          ),
          _gap(d),
          _Field(
            label: 'Opacity',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CompactSlider(
                        value: c.opacity.toDouble(),
                        min: 20,
                        max: 100,
                        divisions: 80,
                        onChanged: (v) =>
                            state.setClock((x) => x.opacity = v.round()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ValuePill(text: '${c.opacity}%'),
                  ],
                ),
                const SizedBox(height: 4),
                _SnapChips(
                  selected: c.opacity,
                  onPick: (op) => state.setClock((x) => x.opacity = op),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Color column ───────────────────────────────────────────────────────

class _ColorColumn extends StatelessWidget {
  const _ColorColumn({required this.state});
  final NewSettingsState state;

  @override
  Widget build(BuildContext context) {
    final c = state.clock;
    final name = nsClockColorByHex(c.color)?.name ?? 'Custom';
    return _ClockColumn(
      title: 'Color',
      headerPill: name,
      dim: !c.enabled,
      child: Center(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final cc in kNsClockColors)
              _ColorSwatch(
                color: cc,
                selected: cc.hex.toLowerCase() == c.color.toLowerCase(),
                onPick: () => state.setClock((x) => x.color = cc.hex),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle line (horizontal mini row) ─────────────────────────────────

class _ToggleLine extends StatelessWidget {
  const _ToggleLine({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsFocusable(
      onActivate: () => onChanged(!value),
      semanticLabel: title,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: NsEase.ease,
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: d.isCompact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: NsType.rowTitle.copyWith(
                  fontSize: d.isCompact ? 10.5 : 12,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _SwitchPill(value: value),
          ],
        ),
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    const w = 26.0;
    const h = 16.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: NsEase.ease,
      width: w,
      height: h,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? NsColors.accent : NsColors.surface3,
        border: Border.all(
          color: value ? NsColors.accentLine : NsColors.line2,
        ),
        borderRadius: BorderRadius.circular(NsRadius.pill),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: NsEase.ease,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: h - 6,
          height: h - 6,
          decoration: BoxDecoration(
            color: value ? Colors.white : NsColors.text2,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─── Nudge pad (3×3) ────────────────────────────────────────────────────

class _NudgePad extends StatelessWidget {
  const _NudgePad({required this.state, required this.cellSize});
  final NewSettingsState state;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final c = state.clock;
    const pad = 3.0;

    Widget corner(String id) => _CpCell(
          size: cellSize,
          selected: c.corner == id,
          semanticLabel: kNsClockCornerLabels[id] ?? id,
          onPressed: () => state.setClock((x) => x.corner = id),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.corner == id ? NsColors.accent : NsColors.line2,
            ),
          ),
        );

    Widget arrow({required IconData icon, required VoidCallback onPressed}) =>
        _CpCell(
          size: cellSize,
          semanticLabel: 'Nudge',
          onPressed: onPressed,
          child: Icon(icon, size: 11, color: NsColors.text2),
        );

    final hubLabel = switch (c.corner) {
      'tl' => 'TL',
      'tr' => 'TR',
      'bl' => 'BL',
      'br' => 'BR',
      _ => '',
    };

    return SizedBox(
      width: cellSize * 3 + pad * 2,
      height: cellSize * 3 + pad * 2,
      child: Column(
        children: [
          Row(children: [
            corner('tl'),
            const SizedBox(width: pad),
            arrow(
              icon: Icons.keyboard_arrow_up_rounded,
              onPressed: () => state.clockNudge(dy: -4),
            ),
            const SizedBox(width: pad),
            corner('tr'),
          ]),
          const SizedBox(height: pad),
          Row(children: [
            arrow(
              icon: Icons.keyboard_arrow_left_rounded,
              onPressed: () => state.clockNudge(dx: -4),
            ),
            const SizedBox(width: pad),
            Container(
              width: cellSize,
              height: cellSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NsColors.accentSoft,
                border: Border.all(color: NsColors.accentLine),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                hubLabel,
                style: const TextStyle(
                  color: NsColors.accent,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: pad),
            arrow(
              icon: Icons.keyboard_arrow_right_rounded,
              onPressed: () => state.clockNudge(dx: 4),
            ),
          ]),
          const SizedBox(height: pad),
          Row(children: [
            corner('bl'),
            const SizedBox(width: pad),
            arrow(
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: () => state.clockNudge(dy: 4),
            ),
            const SizedBox(width: pad),
            corner('br'),
          ]),
        ],
      ),
    );
  }
}

class _CpCell extends StatelessWidget {
  const _CpCell({
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    required this.size,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String semanticLabel;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? NsColors.accentSoft
              : focused
                  ? NsColors.surface2
                  : NsColors.bg2,
          border: Border.all(
            color: selected
                ? NsColors.accentLine
                : focused
                    ? NsColors.line2
                    : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: child,
      ),
    );
  }
}

// ─── Opacity snap chips ────────────────────────────────────────────────

class _SnapChips extends StatelessWidget {
  const _SnapChips({required this.selected, required this.onPick});
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final op in const [25, 50, 75, 100])
          _SnapChip(
            label: '$op',
            selected: selected == op,
            onPick: () => onPick(op),
          ),
      ],
    );
  }
}

class _SnapChip extends StatelessWidget {
  const _SnapChip({
    required this.label,
    required this.selected,
    required this.onPick,
  });
  final String label;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPick,
      semanticLabel: '$label%',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? NsColors.accentSoft
              : focused
                  ? NsColors.surface2
                  : Colors.transparent,
          border: Border.all(
            color: selected
                ? NsColors.accentLine
                : focused
                    ? NsColors.line2
                    : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? NsColors.accent : NsColors.text3,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ─── Color swatches ────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onPick,
  });
  final NsClockColor color;
  final bool selected;
  final VoidCallback onPick;

  Color _c() {
    final v = int.parse(color.hex.replaceAll('#', ''), radix: 16);
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPick,
      semanticLabel: color.name,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: _c(),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected
                ? NsColors.accent
                : focused
                    ? NsColors.text
                    : const Color(0x33FFFFFF),
            width: selected || focused ? 2 : 1,
          ),
          boxShadow: color.led
              ? [
                  BoxShadow(
                    color: _c().withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

// ─── Compact slider ────────────────────────────────────────────────────

class _CompactSlider extends StatefulWidget {
  const _CompactSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  State<_CompactSlider> createState() => _CompactSliderState();
}

class _CompactSliderState extends State<_CompactSlider> {
  late final FocusNode _node = FocusNode(debugLabel: 'ns:clockSlider');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final step = (widget.max - widget.min) / widget.divisions;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onChanged((widget.value + step).clamp(widget.min, widget.max));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onChanged((widget.value - step).clamp(widget.min, widget.max));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onKeyEvent: _handleKey,
      child: Builder(builder: (context) {
        final focused = Focus.maybeOf(context)?.hasFocus ?? false;
        return SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: NsColors.accent,
            inactiveTrackColor: NsColors.line2,
            thumbColor: focused ? NsColors.accent2 : NsColors.text,
            overlayColor: NsColors.accentSoft,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 5,
              elevation: 0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
          ),
          child: SizedBox(
            height: 18,
            child: Slider(
              value: widget.value,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (v) {
                _node.requestFocus();
                widget.onChanged(v);
              },
            ),
          ),
        );
      }),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: NsColors.text2,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

// ─── Buttons ───────────────────────────────────────────────────────────

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: label,
      builder: (context, focused) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          label,
          style: TextStyle(
            color: focused ? NsColors.accent : NsColors.text3,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: focused ? NsColors.accent : NsColors.text4,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: label,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface : Colors.transparent,
          border: Border.all(
            color: focused ? NsColors.line : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: focused ? NsColors.text : NsColors.text2,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: focused ? NsColors.text : NsColors.text2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
