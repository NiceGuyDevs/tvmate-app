/// Shared controls for the Appearance sub-page (and reusable across the
/// rest of the phases). Ports the HTML's `.slider-row`, `.opts`/`.opt`,
/// `.ap-seg`, `.ap-swatches`/`.ap-sw`, and `.ap-tabs`/`.ap-tab` styles
/// into Flutter widgets with D-pad focus + HTML-exact colors.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

// ─── Slider row ─────────────────────────────────────────────────────────
// Ports `.slider-row` (settings.html lines 641–690).

class NsSliderRow extends StatelessWidget {
  const NsSliderRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.valueSuffix = '',
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: d.isCompact ? 12 : 16,
        vertical: d.isCompact ? 10 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label column — title + subtitle.
          SizedBox(
            width: d.isCompact ? 180 : 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: NsType.rowTitle.copyWith(
                    fontSize: d.isCompact ? 12 : 14,
                  ),
                ),
                SizedBox(height: d.isCompact ? 2 : 3),
                Text(
                  subtitle,
                  style: NsType.rowSub.copyWith(
                    fontSize: d.isCompact ? 10.5 : 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: d.isCompact ? 10 : 16),
          // Slider + value pill.
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _NsSlider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(width: d.isCompact ? 8 : 12),
                _ValuePill(text: '${value.round()}$valueSuffix'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NsSlider extends StatefulWidget {
  const _NsSlider({
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
  State<_NsSlider> createState() => _NsSliderState();
}

class _NsSliderState extends State<_NsSlider> {
  late final FocusNode _node = FocusNode(debugLabel: 'ns:slider');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  /// D-pad left / right steps the slider by one division.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final step = (widget.max - widget.min) / widget.divisions;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final next = (widget.value + step).clamp(widget.min, widget.max);
      widget.onChanged(next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final next = (widget.value - step).clamp(widget.min, widget.max);
      widget.onChanged(next);
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
            trackHeight: 4,
            activeTrackColor: NsColors.accent,
            inactiveTrackColor: NsColors.line2,
            thumbColor: focused ? NsColors.accent2 : NsColors.text,
            overlayColor: NsColors.accentSoft,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: GestureDetector(
            onTap: () => _node.requestFocus(),
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
    // `.slider .val` — min-width 48px, center text, font 700 13.5px,
    // bg bg-2, border line, radius pill, color text-2.
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

// ─── Radio-style options list ───────────────────────────────────────────
// Ports `.opts > .opt` with `.dot-radio` from settings.html lines 537–577.

class NsOptionsList extends StatelessWidget {
  const NsOptionsList({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onPick,
    this.columns = 1,
  });

  final List<NsOption> options;
  final String selectedId;
  final ValueChanged<String> onPick;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One column on narrow panes — two on wider panes when caller
        // requested it. Keeps touch targets readable at TV distance.
        final cols = constraints.maxWidth < 340 ? 1 : columns;
        final gap = 6.0;
        final itemWidth = cols <= 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final o in options)
              SizedBox(
                width: itemWidth,
                child: _OptionRow(
                  option: o,
                  selected: o.id == selectedId,
                  onPick: () => onPick(o.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onPick,
  });

  final NsOption option;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsFocusable(
      onActivate: onPick,
      semanticLabel: option.label,
      builder: (context, focused) {
        final Color bg;
        final Color borderColor;
        if (selected) {
          bg = focused ? NsColors.surface : NsColors.bg2;
          borderColor = NsColors.accentLine;
        } else if (focused) {
          bg = NsColors.surface;
          borderColor = NsColors.line2;
        } else {
          bg = NsColors.bg2;
          borderColor = NsColors.line;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: d.isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              _DotRadio(checked: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.label,
                  style: NsType.optionLabel.copyWith(
                    color: selected || focused
                        ? NsColors.text
                        : NsColors.text2,
                    fontSize: d.isCompact ? 11.5 : 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Mirrors `.dot-radio` — small outlined circle that fills with accent when
/// the option is selected.
class _DotRadio extends StatelessWidget {
  const _DotRadio({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: checked ? NsColors.accent : NsColors.text3,
                width: 1.5,
              ),
            ),
          ),
          if (checked)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: NsColors.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Segmented chip group ───────────────────────────────────────────────
// Ports `.ap-seg` from settings.html lines 801–825.

class NsSegmented extends StatelessWidget {
  const NsSegmented({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onPick,
  });

  final List<NsOption> options;
  final String selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            _SegmentedButton(
              option: options[i],
              selected: options[i].id == selectedId,
              onPick: () => onPick(options[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedButton extends StatelessWidget {
  const _SegmentedButton({
    required this.option,
    required this.selected,
    required this.onPick,
  });

  final NsOption option;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    // `.ap-seg button.is-on` — accent gradient fill, white-ish text, soft
    // accent-glow drop shadow. We approximate the gradient with solid
    // accent + a thin accent2 inset tint; the glow is a cheap BoxShadow.
    return NsFocusable(
      onActivate: onPick,
      semanticLabel: option.label,
      builder: (context, focused) {
        final Color bg;
        final Color textColor;
        List<BoxShadow> shadows = const [];
        if (selected) {
          bg = NsColors.accent;
          textColor = NsColors.bg;
          shadows = const [
            BoxShadow(
              color: Color(0x334DD0E1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ];
        } else if (focused) {
          bg = NsColors.surface;
          textColor = NsColors.text;
        } else {
          bg = Colors.transparent;
          textColor = NsColors.text3;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            boxShadow: shadows,
          ),
          child: Text(
            option.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}

// ─── Swatch picker ──────────────────────────────────────────────────────
// Ports `.ap-swatches` + `.ap-sw` from settings.html lines 785–799.

class NsSwatchGrid extends StatelessWidget {
  const NsSwatchGrid({
    super.key,
    required this.swatches,
    required this.selectedHex,
    required this.onPick,
  });

  final List<NsApSwatch> swatches;
  final String selectedHex;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in swatches)
          _SwatchButton(
            swatch: s,
            selected: _matches(s, selectedHex),
            onPick: () => onPick(_hexOf(s)),
          ),
      ],
    );
  }

  static String _hexOf(NsApSwatch s) {
    final v = s.value.toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static bool _matches(NsApSwatch s, String hex) =>
      _hexOf(s).toLowerCase() == hex.toLowerCase();
}

class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.swatch,
    required this.selected,
    required this.onPick,
  });

  final NsApSwatch swatch;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPick,
      semanticLabel: swatch.name,
      builder: (context, focused) {
        // `.ap-sw[aria-checked=true]` gets a ring: 0 0 0 2px var(--bg-2),
        // 0 0 0 3px var(--accent). We approximate with a 2 px accent
        // outer stroke so the focused + selected state reads clearly.
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: swatch.value,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? NsColors.accent
                  : focused
                      ? NsColors.text
                      : const Color(0x1AFFFFFF),
              width: selected || focused ? 2 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x664DD0E1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

// ─── Appearance top tab strip ───────────────────────────────────────────
// Ports `.ap-tabs` + `.ap-tab` from settings.html lines 731–783.

class NsAppearanceTabStrip extends StatelessWidget {
  const NsAppearanceTabStrip({
    super.key,
    required this.tabs,
    required this.selectedId,
    required this.metaFor,
    required this.onPick,
  });

  final List<NsApTab> tabs;
  final String selectedId;
  final String Function(String tabId) metaFor;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // HTML uses 4 columns on wide, 2 on narrow (<760 px).
        final narrow = constraints.maxWidth < 760;
        final cols = narrow ? 2 : 4;
        final gap = 8.0;
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Padding(
          padding: EdgeInsets.only(bottom: d.isCompact ? 12 : 16),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final t in tabs)
                SizedBox(
                  width: itemWidth,
                  child: _AppearanceTab(
                    tab: t,
                    selected: t.id == selectedId,
                    meta: metaFor(t.id),
                    onPick: () => onPick(t.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab({
    required this.tab,
    required this.selected,
    required this.meta,
    required this.onPick,
  });

  final NsApTab tab;
  final bool selected;
  final String meta;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsFocusable(
      onActivate: onPick,
      semanticLabel: tab.label,
      builder: (context, focused) {
        final Color bg;
        final Color borderColor;
        final Color iconBg;
        final Color iconBorder;
        final Color iconColor;
        if (selected) {
          bg = NsColors.surface;
          borderColor = NsColors.accentLine;
          iconBg = NsColors.accentSoft;
          iconBorder = NsColors.accentLine;
          iconColor = NsColors.accent2;
        } else if (focused) {
          bg = NsColors.surface;
          borderColor = NsColors.line2;
          iconBg = NsColors.bg2;
          iconBorder = NsColors.line;
          iconColor = NsColors.text2;
        } else {
          bg = NsColors.surface;
          borderColor = NsColors.line;
          iconBg = NsColors.bg2;
          iconBorder = NsColors.line;
          iconColor = NsColors.text3;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: NsEase.ease,
          padding: EdgeInsets.symmetric(
            horizontal: d.isCompact ? 10 : 13,
            vertical: d.isCompact ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
            // `.ap-tab[aria-selected=true]` has a secondary 1 px accent-soft
            // halo + the shadow-1 drop. Approximated with a soft accent glow.
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x224DD0E1),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : NsShadow.s1,
          ),
          child: Row(
            children: [
              Container(
                width: d.isCompact ? 26 : 30,
                height: d.isCompact ? 26 : 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  border: Border.all(color: iconBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  tab.icon,
                  size: d.isCompact ? 14 : 16,
                  color: iconColor,
                ),
              ),
              SizedBox(width: d.isCompact ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: selected || focused
                            ? NsColors.text
                            : NsColors.text3,
                        fontSize: d.isCompact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: TextStyle(
                        color: selected ? NsColors.text3 : NsColors.text4,
                        fontSize: d.isCompact ? 9.5 : 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Group-card shell used by the sub-page bodies ───────────────────────

/// Shared container used as the left-column card in every Appearance tab.
/// Matches `.card { padding: 4px 0 }` in the HTML.
class NsAppearanceCard extends StatelessWidget {
  const NsAppearanceCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.card),
        boxShadow: NsShadow.s1,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

/// Divider between `.slider-row` children — 1 px `--line`, horizontal.
class NsSliderRowDivider extends StatelessWidget {
  const NsSliderRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: NsColors.line,
    );
  }
}

/// Preview pane on the right column. `padding 16px; bg linear-gradient +
/// radial-gradient; border 1px line; radius card`. We use a solid surface2
/// fill with a subtle accent tint overlay to match the HTML's feel.
class NsPreviewCard extends StatelessWidget {
  const NsPreviewCard({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Container(
      padding: EdgeInsets.all(d.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomCenter,
          colors: [Color(0x1A4DD0E1), Color(0x00000000)],
        ),
        color: NsColors.surface2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: NsColors.text3,
              fontSize: d.isCompact ? 9.5 : 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: d.isCompact ? 10 : 14),
          child,
        ],
      ),
    );
  }
}
