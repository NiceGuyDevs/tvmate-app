/// Favorites editor — 1:1 port of `renderFavoritesEditorPage()` in
/// settings.html (line 6952).
///
/// Two-panel layout:
///   LEFT  — `.fav-sel-panel` — vertical stack of compact tiles for
///           the currently-selected channels, with rank + reorder/remove
///           buttons that reveal on focus.
///   RIGHT — `.fav-pick-panel` — search + playlist pill strip + category
///           pill strip + compact channel grid + bulk-action footer.
///
/// Sub-page head: title = group name, subtitle = "N channels · sort
/// #N", actions = color-swatch pill row, Rename, Sort, Delete (danger).
///
/// Wide TV screens get the HTML's 280 px fixed left + 1fr right.
/// Narrow panes (< 820 px) stack the panels vertically (matches the
/// HTML's `@media (max-width: 1100px)` rule).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_confirm_dialog.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';
import '../widgets/ns_text_prompt_dialog.dart';

class NsFavoritesEditorPage extends StatefulWidget {
  const NsFavoritesEditorPage({
    super.key,
    required this.state,
    required this.groupId,
    required this.onBack,
    required this.onDeleted,
  });

  final NewSettingsState state;
  final String groupId;
  final VoidCallback onBack;

  /// Fired after the group has been deleted — caller pops the page.
  final VoidCallback onDeleted;

  @override
  State<NsFavoritesEditorPage> createState() =>
      _NsFavoritesEditorPageState();
}

class _NsFavoritesEditorPageState extends State<NsFavoritesEditorPage> {
  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocus;

  /// First focusable inside the picker (first playlist pill). We
  /// request focus here on open so D-pad lands inside the editor
  /// immediately instead of on the back button / search field.
  late final FocusNode _firstPickFocus;

  /// Attached to the first pill in the category row — so we can
  /// explicitly route `ArrowDown` from the playlist row into the
  /// category row (Flutter's directional focus skips it otherwise
  /// because the category row lives inside a scroll viewport).
  late final FocusNode _firstCategoryFocus;

  /// Attached to the first tile in the channel grid — routes
  /// `ArrowDown` from the category row and `ArrowUp` from the grid's
  /// top row back through the scroll container cleanly.
  late final FocusNode _firstTileFocus;

  /// Sub-page head **Delete** action — D-pad **Up** from the right
  /// (picker) column targets this; spatial [focusInDirection] does not
  /// cross from the search field to the head row reliably.
  late final FocusNode _headDeleteFocus;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.state.favEditor.search);
    _searchFocus = FocusNode(debugLabel: 'ns:fav:search');
    _firstPickFocus = FocusNode(debugLabel: 'ns:fav:firstPill');
    _firstCategoryFocus =
        FocusNode(debugLabel: 'ns:fav:firstCategory');
    _firstTileFocus = FocusNode(debugLabel: 'ns:fav:firstTile');
    _headDeleteFocus = FocusNode(debugLabel: 'ns:fav:head:delete');
    // Post-frame + a small retry — the autofocus race we hit on the
    // EPG menu / Add Playlist wizard happens here too when a previous
    // sub-page's focus hasn't torn down yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _grabFocus();
      Future.delayed(const Duration(milliseconds: 50), _grabFocus);
    });
  }

  void _grabFocus() {
    if (!mounted) return;
    if (_searchFocus.hasFocus) return;
    if (_firstPickFocus.hasFocus) return;
    if (_firstPickFocus.canRequestFocus) {
      _firstPickFocus.requestFocus();
    }
  }

  void _focusFavHeadDelete() {
    if (!mounted) return;
    if (_headDeleteFocus.canRequestFocus) {
      _headDeleteFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _firstPickFocus.dispose();
    _firstCategoryFocus.dispose();
    _firstTileFocus.dispose();
    _headDeleteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final g = widget.state.favGroupById(widget.groupId);
        if (g == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              d.listHorizontalPadding,
              d.listTopPadding,
              d.listHorizontalPadding,
              d.listBottomPadding,
            ),
            children: [
              NsSubPageHead(
                title: 'Favorite not found',
                onBack: widget.onBack,
              ),
            ],
          );
        }
        // Keep the search field's text in sync with state without
        // fighting the user's caret.
        if (_searchCtrl.text != widget.state.favEditor.search &&
            !_searchFocus.hasFocus) {
          _searchCtrl.text = widget.state.favEditor.search;
        }

        final count = g.refs.length;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: g.name,
              subtitle:
                  '$count channel${count == 1 ? '' : 's'} · sort '
                  '#${g.sortOrder}',
              onBack: widget.onBack,
              actions: [
                _SwatchStrip(
                  selected: g.color,
                  onPick: (c) => widget.state.setFavColor(g.id, c),
                ),
                NsButton(
                  label: 'Rename',
                  icon: Icons.edit_rounded,
                  variant: NsButtonVariant.ghost,
                  onPressed: () => _rename(context, g),
                ),
                NsButton(
                  label: 'Sort #${g.sortOrder}',
                  icon: Icons.drag_indicator_rounded,
                  variant: NsButtonVariant.ghost,
                  onPressed: () => _reorder(context, g),
                ),
                NsButton(
                  focusNode: _headDeleteFocus,
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  variant: NsButtonVariant.danger,
                  onPressed: () => _confirmDelete(context, g),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // HTML uses 280 + 1fr on desktop and stacks under
                // 1100 px. On the Flutter TV pane the detail area is
                // ~800 px, so we scale the left column down (280 →
                // 200) and only fall back to stacking when the pane
                // genuinely can't fit both — < 560 px (phone portrait
                // / tiny split panes). Every real TV pane keeps the
                // side-by-side layout.
                const stackBreakpoint = 560.0;
                final stacked = constraints.maxWidth < stackBreakpoint;
                // Left panel width: 200 on typical TV panes, grows
                // toward 260 on very wide panes so it doesn't look
                // cramped relative to the right picker.
                final leftWidth =
                    constraints.maxWidth >= 1100 ? 260.0 : 200.0;
                final selPanel = _SelPanel(
                  state: widget.state,
                  group: g,
                );
                final pickPanel = _PickPanel(
                  state: widget.state,
                  group: g,
                  searchCtrl: _searchCtrl,
                  searchFocus: _searchFocus,
                  firstPillFocus: _firstPickFocus,
                  firstCategoryFocus: _firstCategoryFocus,
                  firstTileFocus: _firstTileFocus,
                  onSearchArrowUpToHead: _focusFavHeadDelete,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      selPanel,
                      const SizedBox(height: 10),
                      pickPanel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: leftWidth, child: selPanel),
                    const SizedBox(width: 10),
                    Expanded(child: pickPanel),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _rename(BuildContext context, NsFavGroup g) async {
    final name = await showNsTextPromptDialog(
      context,
      title: 'Rename favorite list',
      initial: g.name,
      confirmLabel: 'Rename',
    );
    if (name == null) return;
    widget.state.renameFavGroup(g.id, name);
  }

  Future<void> _reorder(BuildContext context, NsFavGroup g) async {
    final raw = await showNsTextPromptDialog(
      context,
      title: 'Sort order',
      initial: g.sortOrder.toString(),
      confirmLabel: 'Set',
      help:
          'Lower number = appears earlier in the live-TV pill row.',
      keyboardType: TextInputType.number,
    );
    if (raw == null) return;
    final n = int.tryParse(raw.trim());
    if (n == null) return;
    widget.state.setFavSortOrder(g.id, n);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    NsFavGroup g,
  ) async {
    final r = await showNsConfirmDialog(
      context,
      title: 'Delete "${g.name}"?',
      message:
          "Removes this favorite list. The channels themselves "
          "aren't touched.",
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (r == NsConfirmResult.confirmed && context.mounted) {
      widget.state.deleteFavGroup(g.id);
      widget.onDeleted();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  `.fav-swatches` — pill row of 16 px color dots in the header.
// ═══════════════════════════════════════════════════════════════════════

class _SwatchStrip extends StatelessWidget {
  const _SwatchStrip({required this.selected, required this.onPick});
  final String selected;
  final void Function(String color) onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < kNsFavColors.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            _Swatch(
              color: kNsFavColors[i],
              selected: kNsFavColors[i] == selected,
              onPressed: () => onPick(kNsFavColors[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onPressed,
  });
  final String color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: color,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: _hex(color),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? NsColors.text : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: NsColors.bg,
                    spreadRadius: 2,
                  ),
                ]
              : (focused
                  ? const [
                      BoxShadow(
                        color: NsColors.accentSoft,
                        spreadRadius: 2,
                      ),
                    ]
                  : null),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  LEFT panel — `.fav-sel-panel`
// ═══════════════════════════════════════════════════════════════════════

class _SelPanel extends StatelessWidget {
  const _SelPanel({required this.state, required this.group});
  final NewSettingsState state;
  final NsFavGroup group;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      title: 'In favorite',
      meta: '${group.refs.length}',
      child: group.refs.isEmpty
          ? const _SelEmpty()
          : Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < group.refs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _SelTile(
                      state: state,
                      group: group,
                      index: i,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SelTile extends StatelessWidget {
  const _SelTile({
    required this.state,
    required this.group,
    required this.index,
  });
  final NewSettingsState state;
  final NsFavGroup group;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ref = group.refs[index];
    final resolved = state.favResolve(ref);
    final missing = resolved == null;
    final display = missing
        ? 'Unknown channel'
        : (resolved.channel.alias ?? resolved.channel.name);
    final sub = missing ? 'Source removed' : resolved.playlist.name;

    return Opacity(
      opacity: missing ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: NsColors.bg2,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: NsColors.text3,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _SelChannelAvatar(
              color: _hex(group.color),
              initials: nsFavInitials(display),
              missing: missing,
              logoUrl: resolved?.channel.logo,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    display,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: NsColors.text3,
                      fontSize: 10,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (!missing)
              _RowBtn(
                icon: Icons.north_rounded,
                enabled: index > 0,
                onPressed: () => state.favMoveRefUp(group.id, index),
                tooltip: 'Move up',
              ),
            if (!missing)
              _RowBtn(
                icon: Icons.south_rounded,
                enabled: index < group.refs.length - 1,
                onPressed: () => state.favMoveRefDown(group.id, index),
                tooltip: 'Move down',
              ),
            _RowBtn(
              icon: Icons.close_rounded,
              danger: true,
              enabled: true,
              onPressed: () => state.favRemoveRefAt(group.id, index),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

/// Rank column — 26×: live logo when the playlist exposes [NsPlaylistChannel.logo],
/// otherwise the group-colored initials tile (same as the old [_Logo]).
class _SelChannelAvatar extends StatelessWidget {
  const _SelChannelAvatar({
    required this.color,
    required this.initials,
    required this.missing,
    this.logoUrl,
  });
  final Color color;
  final String initials;
  final bool missing;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (missing) {
      return _Logo(
        color: color,
        initials: initials,
        missing: true,
      );
    }
    final u = logoUrl;
    if (u != null && u.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          u,
          width: 26,
          height: 26,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            return _Logo(
              color: color,
              initials: initials,
              missing: false,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _Logo(
              color: color,
              initials: initials,
              missing: false,
            );
          },
        ),
      );
    }
    return _Logo(
      color: color,
      initials: initials,
      missing: false,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({
    required this.color,
    required this.initials,
    required this.missing,
  });
  final Color color;
  final String initials;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final bg = missing
        ? NsColors.dangerSoft
        : Color.fromRGBO(
            (color.r * 255).round(),
            (color.g * 255).round(),
            (color.b * 255).round(),
            0.18,
          );
    final border = missing
        ? NsColors.danger
        : Color.fromRGBO(
            (color.r * 255).round(),
            (color.g * 255).round(),
            (color.b * 255).round(),
            0.4,
          );
    final fg = missing ? NsColors.danger : color;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        missing ? '?' : initials,
        style: TextStyle(
          color: fg,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.2,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _RowBtn extends StatelessWidget {
  const _RowBtn({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.danger = false,
    this.tooltip,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool danger;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      canRequestFocus: enabled,
      onActivate: enabled ? onPressed : null,
      semanticLabel: tooltip,
      builder: (context, focused) {
        final base =
            danger ? NsColors.danger : NsColors.text3;
        final show = enabled && focused;
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: show
                ? (danger
                    ? NsColors.dangerSoft
                    : NsColors.surface)
                : Colors.transparent,
            border: Border.all(
              color: show
                  ? (danger ? NsColors.danger : NsColors.line)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.25,
            child: Icon(
              icon,
              size: 11,
              color:
                  show ? base : (danger ? base : NsColors.text3),
            ),
          ),
        );
      },
    );
  }
}

class _SelEmpty extends StatelessWidget {
  const _SelEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.accentSoft,
              border: Border.all(color: NsColors.accentLine),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 16,
              color: NsColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nothing here yet',
            style: TextStyle(
              color: NsColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Click any channel on the right and it lands here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 10.5,
              height: 1.45,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  RIGHT panel — `.fav-pick-panel`
// ═══════════════════════════════════════════════════════════════════════

class _PickPanel extends StatelessWidget {
  const _PickPanel({
    required this.state,
    required this.group,
    required this.searchCtrl,
    required this.searchFocus,
    required this.firstPillFocus,
    required this.firstCategoryFocus,
    required this.firstTileFocus,
    required this.onSearchArrowUpToHead,
  });
  final NewSettingsState state;
  final NsFavGroup group;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;

  /// Focus node for the first playlist pill — the page autofocuses
  /// this one on open so D-pad starts inside the picker.
  final FocusNode firstPillFocus;

  /// Attached to the first category pill + targeted by ArrowDown
  /// from any playlist pill and ArrowUp from the first grid tile.
  final FocusNode firstCategoryFocus;

  /// Attached to the first grid tile + targeted by ArrowDown from any
  /// category pill.
  final FocusNode firstTileFocus;

  /// D-pad **Up** from search — sub-page head **Delete** (swatches and
  /// other actions are **Left** from there). Spatial [focusInDirection]
  /// does not reach the head from this column.
  final VoidCallback onSearchArrowUpToHead;

  @override
  Widget build(BuildContext context) {
    final fav = state.favEditor;
    final isSearching = fav.search.trim().isNotEmpty;
    final items = _results();
    final onCount = items.where((it) => state.favContains(group, it.ref)).length;
    final meta = isSearching
        ? '${items.length} match${items.length == 1 ? '' : 'es'} · '
            '$onCount in list'
        : '${items.length} channel${items.length == 1 ? '' : 's'} · '
            '$onCount in list';

    return _PanelShell(
      title: 'Add channels',
      meta: meta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            controller: searchCtrl,
            focusNode: searchFocus,
            onChanged: state.setFavEditorSearch,
            onClear: () {
              searchCtrl.clear();
              state.setFavEditorSearch('');
            },
            // D-pad escape hatch: Down/Escape jumps to the first pill,
            // Up asks the framework to walk out of the search field
            // toward whatever focusable sits above (the sub-page
            // head's Back / swatch strip / actions).
            onArrowDown: () {
              if (firstPillFocus.canRequestFocus) {
                firstPillFocus.requestFocus();
              }
            },
            onArrowUp: onSearchArrowUpToHead,
          ),
          _PlaylistRow(
            state: state,
            muted: isSearching,
            firstPillFocus: firstPillFocus,
            onArrowDown: () => _safeFocus(firstCategoryFocus),
            onArrowUp: searchFocus.requestFocus,
          ),
          _CategoryRow(
            state: state,
            muted: isSearching,
            firstCategoryFocus: firstCategoryFocus,
            firstPillFocus: firstPillFocus,
            firstTileFocus: firstTileFocus,
          ),
          _PickGrid(
            state: state,
            group: group,
            items: items,
            isSearching: isSearching,
            firstTileFocus: firstTileFocus,
            onFirstRowArrowUp: () => _safeFocus(firstCategoryFocus),
          ),
          _PickFoot(
            isSearching: isSearching,
            onBulkAdd: () => _bulkAdd(context, items),
            onBulkClear: () => _bulkClear(context, items),
          ),
        ],
      ),
    );
  }

  void _safeFocus(FocusNode n) {
    if (n.canRequestFocus) n.requestFocus();
  }

  List<_PickItem> _results() {
    final fav = state.favEditor;
    final q = fav.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      final all = <_PickItem>[];
      for (final p in state.playlists) {
        for (final cat in p.groups['live'] ?? const <NsPlaylistGroup>[]) {
          for (final c in p.channelsMap[cat.id] ??
              const <NsPlaylistChannel>[]) {
            final name = (c.alias ?? c.name).toLowerCase();
            final orig = c.name.toLowerCase();
            final catLabel = (cat.alias ?? cat.name).toLowerCase();
            final plLabel = p.name.toLowerCase();
            if (name.contains(q) ||
                orig.contains(q) ||
                catLabel.contains(q) ||
                plLabel.contains(q)) {
              all.add(_PickItem(
                ref: NsFavRef(
                  playlistId: p.id,
                  categoryId: cat.id,
                  channelId: c.id,
                ),
                channel: c,
                playlist: p,
                category: cat,
              ));
            }
          }
        }
      }
      // HTML search sort: in-list first, then alpha.
      all.sort((a, b) {
        final ai = state.favContains(group, a.ref) ? 0 : 1;
        final bi = state.favContains(group, b.ref) ? 0 : 1;
        if (ai != bi) return ai - bi;
        return (a.channel.alias ?? a.channel.name)
            .toLowerCase()
            .compareTo((b.channel.alias ?? b.channel.name).toLowerCase());
      });
      return all;
    }
    final p = state.playlistById(fav.activePlaylist);
    if (p == null) return const <_PickItem>[];
    final cats = p.groups['live'] ?? const <NsPlaylistGroup>[];
    final cat = cats
        .cast<NsPlaylistGroup?>()
        .firstWhere((g) => g?.id == fav.activeCategory, orElse: () => null);
    if (cat == null) return const <_PickItem>[];
    final list = p.channelsMap[cat.id] ?? const <NsPlaylistChannel>[];
    return [
      for (final c in list)
        _PickItem(
          ref: NsFavRef(
            playlistId: p.id,
            categoryId: cat.id,
            channelId: c.id,
          ),
          channel: c,
          playlist: p,
          category: cat,
        ),
    ];
  }

  void _bulkAdd(BuildContext context, List<_PickItem> items) {
    final added = state.favBulkAdd(group.id, items.map((it) => it.ref));
    if (added == 0) {
      _toast(context, 'Everything visible is already in the list');
    }
  }

  void _bulkClear(BuildContext context, List<_PickItem> items) {
    if (state.favEditor.search.trim().isNotEmpty) {
      state.setFavEditorSearch('');
      return;
    }
    final removed =
        state.favBulkRemove(group.id, items.map((it) => it.ref));
    if (removed == 0) {
      _toast(context, 'No channels from this category were in the list');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _PickItem {
  const _PickItem({
    required this.ref,
    required this.channel,
    required this.playlist,
    required this.category,
  });
  final NsFavRef ref;
  final NsPlaylistChannel channel;
  final NsPlaylist playlist;
  final NsPlaylistGroup? category;
}

// `.fav-search` — rounded bg-2 field with lead magnifier + optional
// clear button.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onArrowDown,
    required this.onArrowUp,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String q) onChanged;
  final VoidCallback onClear;

  /// D-pad Down from the search field jumps into the pill rows.
  final VoidCallback onArrowDown;

  /// D-pad Up walks outward (toward the sub-page head / swatches).
  final VoidCallback onArrowUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: NsColors.bg2,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 12,
              color: NsColors.text3,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: CallbackShortcuts(
                // Intercept arrow / escape BEFORE the TextField's key
                // handler so the user never gets trapped inside the
                // search box on D-pad-only input.
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      onArrowDown,
                  const SingleActivator(LogicalKeyboardKey.arrowUp):
                      onArrowUp,
                  const SingleActivator(LogicalKeyboardKey.escape):
                      onArrowDown,
                  const SingleActivator(LogicalKeyboardKey.goBack):
                      onArrowDown,
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  cursorColor: NsColors.accent,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onArrowDown(),
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                    decoration: TextDecoration.none,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 7),
                    border: InputBorder.none,
                    hintText:
                        'Search every channel from every playlist…',
                    hintStyle: TextStyle(
                      color: NsColors.text4,
                      fontSize: 11.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: NsFocusable(
                  onActivate: onClear,
                  semanticLabel: 'Clear search',
                  builder: (context, focused) => Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: focused
                          ? NsColors.surface2
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 11,
                      color: NsColors.text3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Playlist pill row — single-select, dimmed while searching.
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.state,
    required this.muted,
    required this.firstPillFocus,
    required this.onArrowDown,
    required this.onArrowUp,
  });
  final NewSettingsState state;
  final bool muted;
  final FocusNode firstPillFocus;
  final VoidCallback onArrowDown;
  final VoidCallback onArrowUp;

  @override
  Widget build(BuildContext context) {
    final fav = state.favEditor;
    return _PillRow(
      muted: muted,
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 6),
      children: [
        for (var i = 0; i < state.playlists.length; i++)
          _Pill(
            focusNode: i == 0 ? firstPillFocus : null,
            label: state.playlists[i].name,
            count: state.playlists[i].channels,
            selected:
                !muted && state.playlists[i].id == fav.activePlaylist,
            isCategory: false,
            onPressed: () =>
                state.setFavEditorPlaylist(state.playlists[i].id),
            onArrowDown: onArrowDown,
            onArrowUp: onArrowUp,
          ),
      ],
    );
  }
}

// Category pill row — capped to ~3 rows in HTML; here we let Wrap grow.
// Greedy [Wrap]-matching widths so D-pad [Down] can move to the next
// *category row* before the channel grid.
double _measureFavCategoryPillWidth(String label, int count) {
  const padH = 7.0 * 2;
  const between = 4.0;
  final labelPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: NsColors.text2,
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        height: 1,
        decoration: TextDecoration.none,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final countPainter = TextPainter(
    text: TextSpan(
      text: '$count',
      style: const TextStyle(
        color: NsColors.text4,
        fontSize: 8.5,
        fontWeight: FontWeight.w700,
        fontFamily: 'monospace',
        letterSpacing: 0.2,
        height: 1,
        decoration: TextDecoration.none,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  const countPadH = 4.0 * 2;
  return padH + labelPainter.width + between + countPadH + countPainter.width;
}

List<List<int>> _favCategoryWrapRowIndices(
  double maxW,
  List<NsPlaylistGroup> cats,
  NsPlaylist? p,
) {
  const gap = 4.0;
  if (cats.isEmpty) return const [];
  if (maxW.isNaN || maxW.isInfinite || maxW <= 0) {
    return [List<int>.generate(cats.length, (i) => i)];
  }
  final w = <double>[];
  for (var i = 0; i < cats.length; i++) {
    final la = cats[i].alias ?? cats[i].name;
    final c = (p?.channelsMap[cats[i].id] ?? const []).length;
    w.add(_measureFavCategoryPillWidth(la, c));
  }
  final rows = <List<int>>[];
  var cur = <int>[];
  var acc = 0.0;
  for (var i = 0; i < cats.length; i++) {
    final wi = w[i];
    if (cur.isEmpty) {
      cur.add(i);
      acc = wi;
    } else if (acc + gap + wi > maxW) {
      rows.add(cur);
      cur = <int>[i];
      acc = wi;
    } else {
      cur = [...cur, i];
      acc = acc + gap + wi;
    }
  }
  if (cur.isNotEmpty) rows.add(cur);
  return rows;
}

(int, int) _favIndexRowCol(List<List<int>> rows, int i) {
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      if (rows[r][c] == i) {
        return (r, c);
      }
    }
  }
  return (0, 0);
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.state,
    required this.muted,
    required this.firstCategoryFocus,
    required this.firstPillFocus,
    required this.firstTileFocus,
  });
  final NewSettingsState state;
  final bool muted;
  final FocusNode firstCategoryFocus;
  final FocusNode firstPillFocus;
  final FocusNode firstTileFocus;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  final Map<int, FocusNode> _nodeByIndex = {};

  void _syncNodes(int len) {
    for (final k in _nodeByIndex.keys.toList()) {
      if (k >= len) {
        _nodeByIndex.remove(k)?.dispose();
      }
    }
    for (var i = 1; i < len; i++) {
      _nodeByIndex.putIfAbsent(
        i,
        () => FocusNode(debugLabel: 'ns:fav:catPill:$i'),
      );
    }
  }

  FocusNode _nodeAt(int i) {
    if (i == 0) return widget.firstCategoryFocus;
    return _nodeByIndex[i]!;
  }

  @override
  void dispose() {
    for (final n in _nodeByIndex.values) {
      n.dispose();
    }
    super.dispose();
  }

  Widget _categoryPill({
    required int i,
    required List<List<int>> rows,
    required List<NsPlaylistGroup> cats,
    required NsPlaylist? p,
    required NsFavEditorState fav,
  }) {
    final (r, c) = _favIndexRowCol(rows, i);
    final row = rows[r];
    FocusNode? nL, nR, nU, nD;
    if (c > 0) {
      nL = _nodeAt(row[c - 1]);
    }
    if (c < row.length - 1) {
      nR = _nodeAt(row[c + 1]);
    }
    if (r > 0) {
      final up = rows[r - 1];
      final tc = c < up.length ? c : up.length - 1;
      nU = _nodeAt(up[tc]);
    } else {
      nU = widget.firstPillFocus;
    }
    if (r < rows.length - 1) {
      final down = rows[r + 1];
      final tc = c < down.length ? c : down.length - 1;
      nD = _nodeAt(down[tc]);
    } else {
      nD = widget.firstTileFocus;
    }
    return _Pill(
      key: ValueKey<String>('fav-cat-$i'),
      focusNode: _nodeAt(i),
      label: cats[i].alias ?? cats[i].name,
      count: (p?.channelsMap[cats[i].id] ?? const []).length,
      selected: !widget.muted && cats[i].id == fav.activeCategory,
      isCategory: true,
      onPressed: () {
        widget.state.setFavEditorCategory(cats[i].id);
        // After picking a category, move focus to the channel grid (first
        // tile) on the next frame so the new grid has been laid out.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.firstTileFocus.canRequestFocus) {
            widget.firstTileFocus.requestFocus();
          }
        });
      },
      focusLeftNeighbor: nL,
      focusRightNeighbor: nR,
      focusUpNeighbor: nU,
      focusDownNeighbor: nD,
      categoryScrollIntoView: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fav = widget.state.favEditor;
    final p = widget.state.playlistById(fav.activePlaylist);
    final cats = p?.groups['live'] ?? const <NsPlaylistGroup>[];
    if (cats.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: const BoxDecoration(
        color: NsColors.bg2,
        border: Border(top: BorderSide(color: NsColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 96),
        child: LayoutBuilder(
          builder: (context, cons) {
            _syncNodes(cats.length);
            final rows = _favCategoryWrapRowIndices(cons.maxWidth, cats, p);
            if (rows.isEmpty) {
              return const SizedBox.shrink();
            }
            return SingleChildScrollView(
              child: _PillRow(
                muted: widget.muted,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (var i = 0; i < cats.length; i++)
                    _categoryPill(
                      i: i,
                      rows: rows,
                      cats: cats,
                      p: p,
                      fav: fav,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.muted,
    required this.padding,
    required this.children,
  });
  final bool muted;
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: muted ? 0.35 : 1.0,
        child: IgnorePointer(
          ignoring: muted,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.isCategory,
    required this.onPressed,
    this.focusNode,
    this.onArrowUp,
    this.onArrowDown,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusUpNeighbor,
    this.focusDownNeighbor,
    this.categoryScrollIntoView = false,
  });
  final String label;
  final int count;
  final bool selected;
  final bool isCategory;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusUpNeighbor;
  final FocusNode? focusDownNeighbor;
  final bool categoryScrollIntoView;

  @override
  Widget build(BuildContext context) {
    // `.fav-cat-pill` is slightly smaller than `.fav-pl-pill`.
    final padH = isCategory ? 7.0 : 8.0;
    final padV = isCategory ? 3.5 : 4.0;
    final fontSize = isCategory ? 9.5 : 10.0;
    final usePlaylistArrowCallbacks =
        onArrowUp != null || onArrowDown != null;
    return Builder(
      builder: (ctx) {
        return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: label,
      focusLeftNeighbor: focusLeftNeighbor,
      focusRightNeighbor: focusRightNeighbor,
      focusUpNeighbor: focusUpNeighbor,
      focusDownNeighbor: focusDownNeighbor,
      onFocusedChange: isCategory && categoryScrollIntoView
          ? (has) {
              if (!has) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!ctx.mounted) return;
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 200),
                  curve: NsEase.ease,
                  alignment: 0.35,
                );
              });
            }
          : null,
      onKeyIntercept: usePlaylistArrowCallbacks
          ? (node, event) {
        if (event is! KeyDownEvent) return null;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            onArrowDown != null) {
          onArrowDown!();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
            onArrowUp != null) {
          onArrowUp!();
          return KeyEventResult.handled;
        }
        return null;
      }
          : null,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: EdgeInsets.symmetric(
          horizontal: padH,
          vertical: padV,
        ),
        decoration: BoxDecoration(
          color: selected
              ? NsColors.accentSoft
              : (focused ? NsColors.surface2 : NsColors.bg2),
          border: Border.all(
            color: selected
                ? NsColors.accentLine
                : (focused ? NsColors.line2 : NsColors.line),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? NsColors.accent
                    : (focused ? NsColors.text : NsColors.text2),
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 4),
            _Cnt(count: count, selected: selected),
          ],
        ),
      ),
    );
      },
    );
  }
}

class _Cnt extends StatelessWidget {
  const _Cnt({required this.count, required this.selected});
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? const Color(0x33000000) : NsColors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: selected ? NsColors.accent : NsColors.text4,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          letterSpacing: 0.2,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// `.fav-pick-grid` — `repeat(auto-fill, minmax(108, 1fr))` + 7 gap.
class _PickGrid extends StatefulWidget {
  const _PickGrid({
    required this.state,
    required this.group,
    required this.items,
    required this.isSearching,
    required this.firstTileFocus,
    required this.onFirstRowArrowUp,
  });
  final NewSettingsState state;
  final NsFavGroup group;
  final List<_PickItem> items;
  final bool isSearching;
  final FocusNode firstTileFocus;

  /// ArrowUp from any tile in the first row — routes focus back up to
  /// the category row (directional focus skips the ConstrainedBox /
  /// ScrollView otherwise).
  final VoidCallback onFirstRowArrowUp;

  @override
  State<_PickGrid> createState() => _PickGridState();
}

class _PickGridState extends State<_PickGrid> {
  /// Per-tile nodes for indices 1..n-1; index 0 uses [firstTileFocus].
  final Map<int, FocusNode> _nodeByIndex = {};

  void _syncNodes(int len) {
    for (final k in _nodeByIndex.keys.toList()) {
      if (k >= len) {
        _nodeByIndex.remove(k)?.dispose();
      }
    }
    for (var i = 1; i < len; i++) {
      _nodeByIndex.putIfAbsent(
        i,
        () => FocusNode(debugLabel: 'ns:fav:pickTile:$i'),
      );
    }
  }

  FocusNode _nodeAt(int i) {
    if (i == 0) return widget.firstTileFocus;
    return _nodeByIndex[i]!;
  }

  @override
  void dispose() {
    for (final n in _nodeByIndex.values) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: NsColors.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NsColors.bg2,
                border: Border.all(color: NsColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.visibility_rounded,
                size: 16,
                color: NsColors.text3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isSearching ? 'No matches' : 'No channels here',
              style: const TextStyle(
                color: NsColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isSearching
                  ? 'Try a different search term.'
                  : 'This category is empty. Try another one.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 10.5,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    const cap = 240;
    final head = items.take(cap).toList();
    final remaining = items.length - head.length;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NsColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTile = 104.0;
          const gap = 6.0;
          final cols = ((constraints.maxWidth + gap) / (minTile + gap))
              .floor()
              .clamp(1, 10);
          final tileW =
              (constraints.maxWidth - gap * (cols - 1)) / cols;
          final n = head.length;
          _syncNodes(n);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < n; i++)
                    SizedBox(
                      width: tileW,
                      child: _PickTile(
                        focusNode: i == 0
                            ? widget.firstTileFocus
                            : _nodeAt(i),
                        focusLeftNeighbor: (i % cols) != 0
                            ? _nodeAt(i - 1)
                            : null,
                        focusRightNeighbor: (i + 1 < n) &&
                                (i % cols) != cols - 1
                            ? _nodeAt(i + 1)
                            : null,
                        focusUpNeighbor: i >= cols
                            ? _nodeAt(i - cols)
                            : null,
                        focusDownNeighbor: i + cols < n
                            ? _nodeAt(i + cols)
                            : null,
                        // Any tile in the first row → ArrowUp routes
                        // back to the category pill strip.
                        onArrowUp: i < cols
                            ? widget.onFirstRowArrowUp
                            : null,
                        item: head[i],
                        isOn: widget.state
                            .favContains(widget.group, head[i].ref),
                        badgeIdx: widget.state
                                .favIndexOf(widget.group, head[i].ref) +
                            1,
                        isSearching: widget.isSearching,
                        onPressed: () => widget.state.toggleFavRef(
                          widget.group.id,
                          head[i].ref,
                        ),
                      ),
                    ),
                ],
              ),
              if (remaining > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: NsColors.bg2,
                    border: Border.all(color: NsColors.line),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'Showing first $cap of ${items.length}. '
                    'Narrow your search to see the rest.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: NsColors.text3,
                      fontSize: 10.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.item,
    required this.isOn,
    required this.badgeIdx,
    required this.isSearching,
    required this.onPressed,
    this.focusNode,
    this.onArrowUp,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusUpNeighbor,
    this.focusDownNeighbor,
  });
  final _PickItem item;
  final bool isOn;
  final int badgeIdx;
  final bool isSearching;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onArrowUp;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusUpNeighbor;
  final FocusNode? focusDownNeighbor;

  @override
  Widget build(BuildContext context) {
    final display = item.channel.alias ?? item.channel.name;
    final hidden = item.channel.hidden;
    final logoU = item.channel.logo;
    final hasLogo = logoU != null && logoU.trim().isNotEmpty;
    // `Builder` gives a [context] tied to the tile; [Scrollable.ensureVisible]
    // scrolls the outer page [ListView] so rows below the fold stay on screen
    // when D-pad focus moves.
    return Builder(
      builder: (ctx) {
        return NsFocusable(
      focusNode: focusNode,
      focusLeftNeighbor: focusLeftNeighbor,
      focusRightNeighbor: focusRightNeighbor,
      focusUpNeighbor: focusUpNeighbor,
      focusDownNeighbor: focusDownNeighbor,
      onFocusedChange: (has) {
        if (!has) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!ctx.mounted) return;
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 200),
            curve: NsEase.ease,
            alignment: 0.22,
          );
        });
      },
      onActivate: onPressed,
      semanticLabel: display,
      onKeyIntercept: onArrowUp == null
          ? null
          : (node, event) {
              if (event is! KeyDownEvent) return null;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                onArrowUp!();
                return KeyEventResult.handled;
              }
              return null;
            },
      builder: (context, focused) => Opacity(
        opacity: hidden ? 0.55 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isOn
                ? const Color(0x0F4DD0E1)
                : (focused ? NsColors.surface2 : NsColors.bg2),
            border: Border.all(
              color: isOn
                  ? NsColors.accentLine
                  : (focused ? NsColors.line2 : NsColors.line),
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: isOn
                ? const [
                    BoxShadow(
                      color: NsColors.accentLine,
                      spreadRadius: 1,
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isOn ? NsColors.accentSoft : NsColors.bg,
                    border: Border.all(
                      color:
                          isOn ? NsColors.accentLine : NsColors.line,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasLogo)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              logoU,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return Center(
                                  child: Text(
                                    nsFavInitials(display),
                                    style: TextStyle(
                                      color: isOn
                                          ? NsColors.accent
                                          : NsColors.text2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.3,
                                      height: 1,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, p) {
                                if (p == null) return child;
                                return Center(
                                  child: Text(
                                    nsFavInitials(display),
                                    style: TextStyle(
                                      color: isOn
                                          ? NsColors.accent
                                          : NsColors.text2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.3,
                                      height: 1,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Text(
                            nsFavInitials(display),
                            style: TextStyle(
                              color: isOn
                                  ? NsColors.accent
                                  : NsColors.text2,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 0.3,
                              height: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 3,
                        right: 3,
                        child: _TileBadge(
                          isOn: isOn,
                          number: badgeIdx,
                          focused: focused,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                display,
                style: const TextStyle(
                  color: NsColors.text,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  decoration: TextDecoration.none,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSearching) ...[
                const SizedBox(height: 2),
                Text(
                  '${item.playlist.name}'
                  ' · '
                  '${item.category?.alias ?? item.category?.name ?? '—'}',
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 9.5,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

class _TileBadge extends StatelessWidget {
  const _TileBadge({
    required this.isOn,
    required this.number,
    required this.focused,
  });
  final bool isOn;
  final int number;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    if (isOn) {
      return Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: const BoxDecoration(
          color: NsColors.accent,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: Text(
          '#$number',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF001016),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    if (focused) {
      return Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: NsColors.accentSoft,
          border: Border.all(color: NsColors.accentLine),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 11,
          color: NsColors.accent,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// Bulk-action footer — two ghost buttons separated by a top divider.
class _PickFoot extends StatelessWidget {
  const _PickFoot({
    required this.isSearching,
    required this.onBulkAdd,
    required this.onBulkClear,
  });
  final bool isSearching;
  final VoidCallback onBulkAdd;
  final VoidCallback onBulkClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NsColors.bg2,
        border: Border(top: BorderSide(color: NsColors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          NsButton(
            label: isSearching ? 'Add all matches' : 'All in category',
            icon: Icons.add_rounded,
            variant: NsButtonVariant.ghost,
            onPressed: onBulkAdd,
          ),
          const SizedBox(width: 6),
          NsButton(
            label: isSearching ? 'Clear search' : 'Clear category',
            icon: Icons.restart_alt_rounded,
            variant: NsButtonVariant.ghost,
            onPressed: onBulkClear,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Shared panel shell — rounded card with a header row (H3 uppercase +
//  monospace meta) and a bordered body.
// ═══════════════════════════════════════════════════════════════════════

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.title,
    required this.meta,
    required this.child,
  });
  final String title;
  final String meta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
        boxShadow: NsShadow.s1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: NsColors.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: NsColors.text2,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  meta,
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

Color _hex(String hex) {
  final s = hex.replaceFirst('#', '');
  final v = int.parse(s, radix: 16);
  if (s.length == 6) return Color(0xFF000000 | v);
  return Color(v);
}
