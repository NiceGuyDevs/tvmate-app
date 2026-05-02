/// Row renderer — handles every `NsRowKind`: toggle / choice / page / action.
///
/// Port of the rendering logic in `renderCategory` (line 4944) + the
/// companion row builders at ~4970 and ~5011 of settings.html. Sub-pages
/// are not navigated here — `kind: page` rows call the [onOpenPage]
/// callback which the owning screen uses to push onto the internal
/// `NewSettingsState.stack`.
///
/// Every focusable is built on [NsFocusable] so no team palette bleeds in
/// and no scale / slide / parallax is added beyond what the HTML does.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/parental_control_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/parental_pin_dialog.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

// Exact HTML timings (see settings.html CSS at the referenced line numbers).
const Duration _rowTransition = Duration(milliseconds: 100); // .row — line 434
const Duration _optTransition = Duration(milliseconds: 120); // .opt — line 551
const Duration _sheetTransition = Duration(milliseconds: 180); // caret rotate
const Duration _switchTransition = Duration(milliseconds: 180); // toggle pill

class NsSettingsRow extends StatelessWidget {
  const NsSettingsRow({
    super.key,
    required this.row,
    required this.state,
    required this.categoryId,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onOpenPage,
    required this.onAction,
    this.focusNode,
  });

  final NsRow row;
  final NewSettingsState state;
  final String categoryId;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final void Function(String pageId) onOpenPage;
  final void Function(String actionId) onAction;

  /// Optional external focus node — bound to this row's outer
  /// [NsFocusable] so the category rail can hand focus off to this
  /// specific row on activation.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return switch (row.kind) {
      NsRowKind.toggle => _ToggleRow(
          row: row,
          state: state,
          categoryId: categoryId,
          focusNode: focusNode,
        ),
      NsRowKind.choice => _ChoiceRow(
          row: row,
          state: state,
          categoryId: categoryId,
          isExpanded: isExpanded,
          onToggleExpanded: onToggleExpanded,
          focusNode: focusNode,
        ),
      NsRowKind.page => _PageRow(
          row: row,
          state: state,
          onOpen: () => onOpenPage(row.page ?? ''),
          focusNode: focusNode,
        ),
      NsRowKind.action => _ActionRow(
          row: row,
          onActivate: () => onAction(row.action ?? ''),
          focusNode: focusNode,
        ),
    };
  }
}

/// Shared info (title + badge + subtitle) — the `.info` block in the HTML.
class _RowInfo extends StatelessWidget {
  const _RowInfo({required this.row});

  final NsRow row;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final baseTitle = NsType.rowTitle.copyWith(fontSize: d.rowTitleSize);
    final titleStyle = row.danger
        ? baseTitle.copyWith(color: NsColors.danger)
        : baseTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                row.title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (row.badge != null) ...[
              const SizedBox(width: 8),
              _Badge(text: row.badge!),
            ],
          ],
        ),
        if (row.sub != null) ...[
          SizedBox(height: d.rowGapTitleSub),
          Text(
            row.sub!,
            style: NsType.rowSub.copyWith(
              fontSize: d.rowSubSize,
              height: d.rowSubLh,
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: NsColors.accentSoft,
        border: Border.all(color: NsColors.accentLine),
        borderRadius: BorderRadius.circular(NsRadius.pill),
      ),
      child: Text(text, style: NsType.badge),
    );
  }
}

/// Shared focusable row surface. Ports `.row` from settings.html
/// (lines 427–443):
///
///   .row               { background: transparent;
///                        transition: background .1s var(--ease); }
///   .row:hover         { background: var(--surface-2); }
///   .row:focus-visible { outline: none; background: var(--surface-2);
///                        box-shadow: 0 0 0 2px var(--accent-soft) inset; }
///   .row.danger-action:hover { background: var(--danger-soft); }
///
/// Focus behaviour on TV:
///   The HTML specifies a 2 px inset accent-soft wash on focus-visible,
///   but at 14 % alpha on top of a surface-2 fill the browser renders it
///   so subtly that the user perceives the focus as "just the background
///   changes". Flutter's `Border` paints the same 2 px band with a hard
///   edge that reads as a framing line — especially at compact TV sizes.
///   So this port intentionally drops the inset stroke and keeps only the
///   background shift, which matches the HTML's real visual feel.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.child,
    required this.onActivate,
    this.focusNode,
    this.expanded = false,
    this.isDanger = false,
    this.onKeyBeforeLeft,
  });

  final Widget child;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final bool expanded;
  final bool isDanger;

  /// Runs first for every key (e.g. **Left** on an expanded choice header
  /// moves into the option grid instead of the rail).
  final KeyEventResult? Function(FocusNode node, KeyEvent event)?
      onKeyBeforeLeft;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onActivate,
      onKeyIntercept: (node, event) {
        return onKeyBeforeLeft?.call(node, event);
      },
      builder: (context, focused) {
        // Fill priority (highest wins): expanded > focused-danger > focused
        // > transparent. Matches the HTML cascade.
        final Color fill;
        if (expanded) {
          fill = NsColors.surface2;
        } else if (focused && isDanger) {
          fill = NsColors.dangerSoft;
        } else if (focused) {
          fill = NsColors.surface2;
        } else {
          fill = Colors.transparent;
        }
        return AnimatedContainer(
          duration: _rowTransition,
          curve: NsEase.ease,
          padding: EdgeInsets.symmetric(
            horizontal: d.rowHorizontalPadding,
            vertical: d.rowVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: fill,
            // `.row + .row { border-top: 1px solid --line }` — painted as
            // a bottom stroke so the first row in a card keeps the card's
            // rounded top edge clean.
            border: Border(
              bottom: BorderSide(
                color: NsColors.line.op(d.cardRowDividerOpacity),
                width: 1,
              ),
            ),
          ),
          child: child,
        );
      },
    );
  }
}

// ─── Toggle row ──────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.row,
    required this.state,
    required this.categoryId,
    this.focusNode,
  });

  final NsRow row;
  final NewSettingsState state;
  final String categoryId;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final value = state.getRowBool(
      categoryId,
      row.id,
      defaultValue: row.defaultBool,
    );
    return _RowShell(
      focusNode: focusNode,
      onActivate: () {
        if (categoryId == 'privacy' && row.id == 'parental_master') {
          unawaited(
            _nsParentalMasterToggle(
              context: context,
              state: state,
              currentValue: value,
            ),
          );
          return;
        }
        state.setRowBool(categoryId, row.id, !value);
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _RowInfo(row: row)),
          const SizedBox(width: 16),
          _SwitchPill(value: value),
        ],
      ),
    );
  }
}

Future<void> _nsParentalMasterToggle({
  required BuildContext context,
  required NewSettingsState state,
  required bool currentValue,
}) async {
  await parentalControlStore.ensureLoaded();
  if (!context.mounted) return;
  if (!parentalControlStore.isPinConfigured) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.parentalMustEnableInSettings)),
    );
    return;
  }
  final newValue = !currentValue;
  if (!newValue && parentalControlStore.enabled) {
    final ok = await showParentalPinVerifyDialog(context);
    if (!ok || !context.mounted) return;
  }
  await parentalControlStore.setEnabled(newValue);
}

class _SwitchPill extends StatelessWidget {
  const _SwitchPill({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    const double w = 44;
    const double h = 24;
    return AnimatedContainer(
      duration: _switchTransition,
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
        duration: _switchTransition,
        curve: NsEase.ease,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: h - 6,
          height: h - 6,
          decoration: BoxDecoration(
            color: value ? Colors.white : NsColors.text2,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Choice row (collapsed + expanded option sheet) ──────────────────────

class _ChoiceRow extends StatefulWidget {
  const _ChoiceRow({
    required this.row,
    required this.state,
    required this.categoryId,
    required this.isExpanded,
    required     this.onToggleExpanded,
    this.focusNode,
  });

  final NsRow row;
  final NewSettingsState state;
  final String categoryId;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final FocusNode? focusNode;

  @override
  State<_ChoiceRow> createState() => _ChoiceRowState();
}

class _ChoiceRowState extends State<_ChoiceRow> {
  List<FocusNode> _optionNodes = const [];
  FocusNode? _ownedHeaderNode;
  int _lastOptionCount = 0;

  /// Resolved header focus node — external if provided, else internal.
  FocusNode get _rowHeaderNode =>
      widget.focusNode ?? (_ownedHeaderNode ??= FocusNode(
        debugLabel: 'ns:choice:${widget.row.id}:header',
      ));

  @override
  void initState() {
    super.initState();
    // Header node is lazily created via [_rowHeaderNode] so we only
    // allocate an internal node when an external one wasn't supplied.
  }

  @override
  void dispose() {
    for (final n in _optionNodes) {
      n.dispose();
    }
    _ownedHeaderNode?.dispose();
    super.dispose();
  }

  void _ensureNodes(int count) {
    if (count == _lastOptionCount) return;
    for (final n in _optionNodes) {
      n.dispose();
    }
    _optionNodes = List.generate(
      count,
      (i) => FocusNode(debugLabel: 'ns:choice:${widget.row.id}:$i'),
    );
    _lastOptionCount = count;
  }

  @override
  void didUpdateWidget(covariant _ChoiceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isExpanded && widget.isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _optionNodes.isEmpty) return;
        final options = widget.row.options ??
            widget.row.optionsFn?.call(widget.state) ??
            const [];
        final currentId = widget.state.getRowChoice(
          widget.categoryId,
          widget.row.id,
          defaultValue: widget.row.value ??
              (options.isNotEmpty ? options.first.id : ''),
        );
        final idx = options.indexWhere((o) => o.id == currentId);
        final target = _optionNodes[idx < 0 ? 0 : idx];
        if (target.canRequestFocus) target.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.row.options ??
        widget.row.optionsFn?.call(widget.state) ??
        const [];
    _ensureNodes(options.length);
    final currentId = widget.state.getRowChoice(
      widget.categoryId,
      widget.row.id,
      defaultValue:
          widget.row.value ?? (options.isNotEmpty ? options.first.id : ''),
    );
    final currentLabel = nsOptionLabelById(options, currentId);

    return Column(
      children: [
        _RowShell(
          focusNode: _rowHeaderNode,
          onActivate: widget.onToggleExpanded,
          expanded: widget.isExpanded,
          onKeyBeforeLeft: widget.isExpanded
              ? (node, event) {
                  if (event is! KeyDownEvent) return null;
                  if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
                    return null;
                  }
                  if (_optionNodes.isEmpty) return null;
                  _optionNodes[0].requestFocus();
                  return KeyEventResult.handled;
                }
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _RowInfo(row: widget.row)),
              const SizedBox(width: 12),
              Text(currentLabel, style: NsType.rowValue),
              const SizedBox(width: 6),
              AnimatedRotation(
                duration: _sheetTransition,
                curve: NsEase.ease,
                turns: widget.isExpanded ? 0.5 : 0,
                child: const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: NsColors.text3,
                ),
              ),
            ],
          ),
        ),
        if (widget.isExpanded)
          _OptionSheet(
            options: options,
            currentId: currentId,
            nodes: _optionNodes,
            onPick: (id) {
              widget.state.setRowChoice(widget.categoryId, widget.row.id, id);
              widget.onToggleExpanded();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_rowHeaderNode.canRequestFocus) {
                  _rowHeaderNode.requestFocus();
                }
              });
            },
            onClose: () {
              widget.onToggleExpanded();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_rowHeaderNode.canRequestFocus) {
                  _rowHeaderNode.requestFocus();
                }
              });
            },
          ),
      ],
    );
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({
    required this.options,
    required this.currentId,
    required this.nodes,
    required this.onPick,
    required this.onClose,
  });

  final List<NsOption> options;
  final String currentId;
  final List<FocusNode> nodes;
  final void Function(String id) onPick;
  final VoidCallback onClose;

  /// D-pad handler for choice options — uses Flutter's **spatial**
  /// directional traversal so Down / Up / Left / Right always move to
  /// the physical neighbour in the grid (no "right-right-right to
  /// reach Spanish" rotation). Escape / Back collapses the sheet.
  KeyEventResult? _handleKey(
    BuildContext context,
    int index,
    FocusNode _,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      onClose();
      return KeyEventResult.handled;
    }
    final scope = FocusScope.of(context);
    TraversalDirection? dir;
    if (key == LogicalKeyboardKey.arrowDown) {
      dir = TraversalDirection.down;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      dir = TraversalDirection.up;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      dir = TraversalDirection.left;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      dir = TraversalDirection.right;
    }
    if (dir == null) return null;
    final moved = scope.focusInDirection(dir);
    return moved ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      // Spatial/directional traversal: D-pad arrows go to the physical
      // neighbour in the grid rather than linear next/prev — matches
      // navigation rule 7 (free D-pad movement everywhere).
      policy: WidgetOrderTraversalPolicy(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: NsColors.bg2,
          border: Border(bottom: BorderSide(color: NsColors.line)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 6.0;
            final aw = constraints.maxWidth;
            // Fixed tile width (no [IntrinsicWidth]) so focus/selection never
            // relayouts neighbour tiles — especially important for interface
            // language and other dense choice sheets.
            final canTwo = aw >= 2 * 220 + spacing;
            final tileW = canTwo
                ? ((aw - spacing) / 2.0).clamp(220.0, 380.0)
                : aw;
            return Wrap(
              spacing: spacing,
              runSpacing: 6,
              children: [
                for (int i = 0; i < options.length; i++)
                  Builder(
                    builder: (tileCtx) => _OptionTile(
                      width: tileW,
                      option: options[i],
                      selected: options[i].id == currentId,
                      node: nodes[i],
                      onPick: () => onPick(options[i].id),
                      onKeyIntercept: (node, event) =>
                          _handleKey(tileCtx, i, node, event),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.width,
    required this.option,
    required this.selected,
    required this.node,
    required this.onPick,
    required this.onKeyIntercept,
  });

  /// Every tile in the sheet uses the same width (see [_OptionSheet]).
  final double width;
  final NsOption option;
  final bool selected;
  final FocusNode node;
  final VoidCallback onPick;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)
      onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    // Ports `.opt` (settings.html lines 542–557):
    //   base:    background: var(--bg-2);  border: 1px solid var(--line);
    //            color: var(--text-2);
    //   :hover:  background: var(--surface); border-color: var(--line-2);
    //            color: var(--text);
    //   [aria-checked="true"]: border-color: var(--accent-line);
    //                          color: var(--text);  + accent check on end.
    //
    // No outer ring — the HTML never specifies focus-visible on .opt. The
    // selected / focused state is communicated by bg + border color only.
    return SizedBox(
      width: width,
      child: NsFocusable(
        focusNode: node,
        onActivate: onPick,
        onKeyIntercept: onKeyIntercept,
        semanticLabel: option.label,
        // Option tiles use a 9 px radius (see the `.opt` CSS port at
        // line 612). Pass that to the focus painter so the orange
        // stripe's top / bottom ends curve on the same arc as the
        // tile's rounded corners.
        focusAccentRadius: 9,
        builder: (context, focused) {
          final Color bg;
          final Color borderColor;
          if (selected) {
            // Selected swatch in the HTML keeps `.opt[aria-checked=true]`'s
            // accent-line border. Background matches the focused .opt state
            // when the selection is the currently focused tile.
            bg = focused ? NsColors.surface : NsColors.bg2;
            borderColor = NsColors.accentLine;
          } else if (focused) {
            bg = NsColors.surface;
            borderColor = NsColors.line2;
          } else {
            bg = NsColors.bg2;
            borderColor = NsColors.line;
          }
          // Fixed 1.0px border in every state (only color changes) and a
          // reserved check column so the tile does not change width or height
          // when selection/focus move — the orange Ns focus accent is visual only.
          const checkColW = 20.0;
          const afterTextGap = 8.0;
          return AnimatedContainer(
            duration: _optTransition,
            curve: NsEase.ease,
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(9), // .opt uses 9px
            ),
            child: Row(
              children: [
                if (option.swatch != null) ...[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: option.swatch,
                      shape: BoxShape.circle,
                      border: Border.all(color: NsColors.line),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: NsType.optionLabel.copyWith(
                          color: selected ? NsColors.accent : NsColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (option.sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.sub!,
                          style: NsType.optionSub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: afterTextGap),
                SizedBox(
                  width: checkColW,
                  height: checkColW,
                  child: selected
                      ? const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: NsColors.accent,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Page row (navigates to internal sub-page) ──────────────────────────

class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.row,
    required this.state,
    required this.onOpen,
    this.focusNode,
  });

  final NsRow row;
  final NewSettingsState state;
  final VoidCallback onOpen;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final displayValue = row.valueFn?.call(state) ?? row.value ?? '';
    return _RowShell(
      focusNode: focusNode,
      onActivate: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _RowInfo(row: row)),
          const SizedBox(width: 12),
          if (displayValue.isNotEmpty)
            Flexible(
              child: Text(
                displayValue,
                style: NsType.rowValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: NsColors.text3,
          ),
        ],
      ),
    );
  }
}

// ─── Action row (fires a one-shot action) ───────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.row,
    required this.onActivate,
    this.focusNode,
  });

  final NsRow row;
  final VoidCallback onActivate;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      focusNode: focusNode,
      onActivate: onActivate,
      isDanger: row.danger,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _RowInfo(row: row)),
          const SizedBox(width: 12),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: row.danger ? NsColors.danger : NsColors.text3,
          ),
        ],
      ),
    );
  }
}
