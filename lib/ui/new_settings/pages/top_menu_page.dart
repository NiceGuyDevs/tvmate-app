/// "Top menu items & order" sub-page.
///
/// Ports `renderTopMenuPage` from settings.html (lines 7642–7707) and the
/// `.reorder` CSS block at lines 921–948.
///
/// Layout: a `split-2` grid on a wide canvas (1.4fr left / 0.9fr right),
/// stacking vertically on compact / narrow. Left side = the current
/// top-menu items in order, each with move up / move down / remove
/// actions. A locked "Settings always last" row caps the list. Right side
/// = available optional items that aren't in the menu, each with an "add"
/// button. When all optionals are already added the right column shows an
/// empty state.
library;

import 'package:flutter/material.dart';

import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsTopMenuPage extends StatelessWidget {
  const NsTopMenuPage({
    super.key,
    required this.state,
    required this.onBack,
  });

  final NewSettingsState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final items = state.topMenu;
    final available = state.topMenuAvailable;

    final visibleList = _ReorderList(
      title: 'Visible items',
      children: [
        for (int i = 0; i < items.length; i++)
          _ReorderItem(
            index: i + 1,
            label: items[i].label,
            fixed: items[i].fixed,
            canMoveUp: i > 0,
            canMoveDown: i < items.length - 1,
            onMoveUp: () => state.topMenuMove(i, i - 1),
            onMoveDown: () => state.topMenuMove(i, i + 1),
            onRemove: items[i].fixed
                ? null
                : () => state.topMenuRemove(items[i].id),
          ),
        // Port of the HTML's locked "Settings always last" row at
        // settings.html lines 7660–7665 — communicates that Settings
        // (and in our case the new-settings tab) is pinned to the end.
        const _LockedAlwaysLast(),
      ],
    );

    final addList = _ReorderList(
      title: 'Add to menu',
      children: [
        if (available.isEmpty)
          const _NothingToAddEmpty()
        else
          for (final a in available)
            _AddItem(
              label: a.label,
              onAdd: () => state.topMenuAdd(a),
            ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // The HTML collapses `.split-2` to a single column via
        // `@media (max-width: 1100px)`, so the decision is width-based
        // (not height-based). Android TV has a wide pane even when the
        // total canvas height is small, so the earlier `d.isCompact`
        // heuristic wrongly stacked these two columns on TVs. Using
        // detail-pane width here restores the HTML's behaviour.
        const splitBreakpoint = 680;
        final canSplit = constraints.maxWidth >= splitBreakpoint;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Top menu items & order',
              subtitle:
                  'Drag (or use the arrows) to reorder. Settings stays last.',
              onBack: onBack,
            ),
            if (canSplit)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 14, child: visibleList),
                  const SizedBox(width: 18),
                  Expanded(flex: 9, child: addList),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  visibleList,
                  SizedBox(height: d.interGroupGap + 4),
                  addList,
                ],
              ),
          ],
        );
      },
    );
  }
}

// ─── Shared list shell ──────────────────────────────────────────────────

class _ReorderList extends StatelessWidget {
  const _ReorderList({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 6, bottom: d.groupLabelBottomGap),
          child: Text(
            title.toUpperCase(),
            style: NsType.groupLabel.copyWith(
              fontSize: d.groupLabelSize,
              letterSpacing: 1.5,
            ),
          ),
        ),
        // `.reorder { display: flex; flex-direction: column; gap: 6px; }`
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              children[i],
            ],
          ],
        ),
      ],
    );
  }
}

// ─── Visible items row (draggable/reorderable) ──────────────────────────

class _ReorderItem extends StatelessWidget {
  const _ReorderItem({
    required this.index,
    required this.label,
    required this.fixed,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final String label;
  final bool fixed;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  /// When null, the item is fixed (no remove affordance). When set,
  /// renders the trailing × button.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    // `.reorder .item` — grid-template-columns: 22px 24px 1fr auto auto;
    // padding 10 12; bg surface; 1px solid line; radius 10.
    return _ReorderItemSurface(
      dim: fixed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Column 1: accent-colored numeric index.
          SizedBox(
            width: 22,
            child: Text(
              index.toString(),
              style: TextStyle(
                color: NsColors.accent,
                fontSize: d.isCompact ? 12 : 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                height: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // Column 2: grip / lock icon.
          Icon(
            fixed ? Icons.lock_outline_rounded : Icons.drag_indicator_rounded,
            size: d.isCompact ? 14 : 16,
            color: NsColors.text4,
          ),
          const SizedBox(width: 12),
          // Column 3: label (+ "Fixed" badge if fixed).
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: NsType.rowTitle.copyWith(
                      fontSize: d.isCompact ? 12.5 : 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (fixed) ...[
                  const SizedBox(width: 8),
                  const _WarnBadge(text: 'Fixed'),
                ],
              ],
            ),
          ),
          // Column 4: up/down action buttons.
          _IconButton(
            icon: Icons.keyboard_arrow_up_rounded,
            enabled: canMoveUp && !(fixed && !canMoveUp),
            semanticLabel: 'Move up',
            onPressed: canMoveUp ? onMoveUp : null,
          ),
          const SizedBox(width: 4),
          _IconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            enabled: canMoveDown,
            semanticLabel: 'Move down',
            onPressed: canMoveDown ? onMoveDown : null,
          ),
          // Column 5: remove (or empty for fixed items).
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            _IconButton(
              icon: Icons.close_rounded,
              enabled: true,
              semanticLabel: 'Remove',
              onPressed: onRemove,
            ),
          ] else
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// Locked placeholder shown at the very end of the visible list — the HTML
/// writes it as a dashed-border item representing the fact that Settings
/// can't be reordered off the end of the menu.
class _LockedAlwaysLast extends StatelessWidget {
  const _LockedAlwaysLast();

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: d.isCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: NsColors.line,
            style: BorderStyle.solid,
            width: 1,
          ),
          // Dashed isn't built-in on Border. A solid but dim border at
          // `NsColors.line` gives the same "placeholder, not draggable"
          // read without writing a custom painter just for this row.
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '—',
                style: TextStyle(
                  color: NsColors.text4,
                  fontSize: d.isCompact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.lock_outline_rounded,
              size: d.isCompact ? 14 : 16,
              color: NsColors.text4,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Settings',
                    style: NsType.rowTitle.copyWith(
                      fontSize: d.isCompact ? 12.5 : 13.5,
                      color: NsColors.text3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _WarnBadge(text: 'Always last'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "Add to menu" tile ─────────────────────────────────────────────────

class _AddItem extends StatelessWidget {
  const _AddItem({required this.label, required this.onAdd});

  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsFocusable(
      onActivate: onAdd,
      semanticLabel: 'Add $label to menu',
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: d.isCompact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: focused ? NsColors.surface2 : NsColors.surface,
            border: Border.all(
              color: focused ? NsColors.line2 : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '+',
                  style: TextStyle(
                    color: NsColors.accent,
                    fontSize: d.isCompact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: NsType.rowTitle.copyWith(
                    fontSize: d.isCompact ? 12.5 : 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.add_rounded,
                size: d.isCompact ? 14 : 16,
                color: focused ? NsColors.text : NsColors.text3,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NothingToAddEmpty extends StatelessWidget {
  const _NothingToAddEmpty();

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: d.isCompact ? 20 : 40,
      ),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.add_rounded,
            size: d.isCompact ? 22 : 28,
            color: NsColors.text4,
          ),
          SizedBox(height: d.isCompact ? 6 : 10),
          Text(
            'Nothing to add',
            style: NsType.rowTitle.copyWith(
              fontSize: d.isCompact ? 13 : 15,
              color: NsColors.text2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All optional items are already on the menu.',
            style: NsType.rowSub.copyWith(
              fontSize: d.isCompact ? 10.5 : 12,
              color: NsColors.text3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Shared primitives ──────────────────────────────────────────────────

class _ReorderItemSurface extends StatelessWidget {
  const _ReorderItemSurface({required this.dim, required this.child});

  final bool dim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Opacity(
      opacity: dim ? 0.55 : 1.0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: d.isCompact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: dim ? NsColors.bg2 : NsColors.surface,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // `.reorder .item .iconbtn`
    //   28×28, transparent bg, 1px line border, radius 7, color text-3
    //   :hover { color: text; background: surface-2; border-color: line-2 }
    return NsFocusable(
      canRequestFocus: enabled,
      onActivate: enabled ? onPressed : null,
      semanticLabel: semanticLabel,
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? NsColors.surface2 : Colors.transparent,
            border: Border.all(
              color: focused ? NsColors.line2 : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            icon,
            size: 14,
            color: !enabled
                ? NsColors.text4
                : focused
                    ? NsColors.text
                    : NsColors.text3,
          ),
        );
      },
    );
  }
}

/// `.badge.warn` — color warn, bg rgba(251,191,36,.10), border warn@.35.
class _WarnBadge extends StatelessWidget {
  const _WarnBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x1AFBBF24), // warn at 10%
        border: Border.all(color: const Color(0x59FBBF24)), // warn at 35%
        borderRadius: BorderRadius.circular(NsRadius.pill),
      ),
      child: Text(
        text,
        style: NsType.badgeWarn.copyWith(fontSize: 9.5),
      ),
    );
  }
}
