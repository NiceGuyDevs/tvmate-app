/// Group section list — 1:1 port of `renderGroupSectionPage()` and
/// `renderGroupRow()` in settings.html (lines 6289 + 6304).
///
/// Per-section list of groups with a visibility toggle pill, inline
/// rename editor, and (Live only) a reorder action that opens the same
/// before/after Favorites + position panel as legacy Manage groups.
/// Head exposes Show-all / Hide-all bulk actions.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/playlist_group_visibility_store.dart';
import '../../../l10n/app_localizations.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_chips.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsGroupSectionPage extends StatefulWidget {
  const NsGroupSectionPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.section,
    required this.onBack,
  });

  final NewSettingsState state;
  final String playlistId;

  /// `'live' | 'vod' | 'series'`.
  final String section;

  final VoidCallback onBack;

  @override
  State<NsGroupSectionPage> createState() => _NsGroupSectionPageState();
}

class _NsGroupSectionPageState extends State<NsGroupSectionPage> {
  // One persistent inline-edit controller per group id (only the one
  // currently being edited is rendered; created lazily).
  final Map<String, TextEditingController> _aliasCtrls = {};
  final Map<String, FocusNode> _aliasFocus = {};

  /// Live TV: same “pill order vs Favorites” panel as legacy Manage groups.
  String? _orderPanelGid;
  bool _orderPanelBeforeFav = false;
  late final TextEditingController _orderPosCtrl;

  @override
  void initState() {
    super.initState();
    _orderPosCtrl = TextEditingController(text: '1');
    unawaited(playlistGroupVisibilityStore.ensureLoaded());
  }

  @override
  void dispose() {
    _orderPosCtrl.dispose();
    for (final c in _aliasCtrls.values) {
      c.dispose();
    }
    for (final f in _aliasFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _openOrderPanel(String gid) {
    if (_currentlyEditingGroupId() != null) {
      widget.state.inlineEdit = null;
    }
    final pid = widget.playlistId;
    final isB = playlistGroupVisibilityStore.isLiveCategoryBeforeFavorites(
      pid,
      gid,
    );
    final pos = playlistGroupVisibilityStore.liveBeforeFavoritesOneBasedPosition(
      pid,
      gid,
    );
    setState(() {
      _orderPanelGid = gid;
      _orderPanelBeforeFav = isB;
      _orderPosCtrl.text = (pos > 0 ? pos : 1).toString();
    });
  }

  void _closeOrderPanel() {
    setState(() => _orderPanelGid = null);
  }

  Future<void> _savePillOrder() async {
    final gid = _orderPanelGid;
    if (gid == null) return;
    final pid = widget.playlistId;
    if (!_orderPanelBeforeFav) {
      await playlistGroupVisibilityStore.setLiveCategoryBeforeFavorites(
        playlistId: pid,
        categoryId: gid,
        before: false,
      );
      if (mounted) setState(() => _orderPanelGid = null);
      return;
    }
    await playlistGroupVisibilityStore.setLiveCategoryBeforeFavorites(
      playlistId: pid,
      categoryId: gid,
      before: true,
    );
    final list =
        playlistGroupVisibilityStore.liveBeforeFavoritesOrderedIds(pid);
    var p = int.tryParse(_orderPosCtrl.text.trim()) ?? 1;
    p = p.clamp(1, list.isEmpty ? 1 : list.length);
    await playlistGroupVisibilityStore.setLiveBeforeFavoritesOneBasedPosition(
      playlistId: pid,
      categoryId: gid,
      oneBasedPosition: p,
    );
    if (mounted) setState(() => _orderPanelGid = null);
  }

  String get _editKeyPrefix =>
      'group:${widget.playlistId}:${widget.section}:';

  String? _currentlyEditingGroupId() {
    final key = widget.state.inlineEdit;
    if (key == null) return null;
    if (!key.startsWith(_editKeyPrefix)) return null;
    return key.substring(_editKeyPrefix.length);
  }

  String _sectionLabel() => switch (widget.section) {
        'live' => 'TV',
        'vod' => 'Movies',
        'series' => 'Shows',
        _ => widget.section,
      };

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, playlistGroupVisibilityStore]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final p = widget.state.playlistById(widget.playlistId);
        if (p == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              d.listHorizontalPadding,
              d.listTopPadding,
              d.listHorizontalPadding,
              d.listBottomPadding,
            ),
            children: [
              NsSubPageHead(title: 'Playlist not found', onBack: widget.onBack),
            ],
          );
        }
        final arr = p.groups[widget.section] ?? const <NsPlaylistGroup>[];
        final visible = arr.where((g) => g.visible).length;
        final isLive = widget.section == 'live';
        final editingId = _currentlyEditingGroupId();

        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: '${_sectionLabel()} groups',
              subtitle: '${p.name} · $visible of ${arr.length} visible.',
              onBack: widget.onBack,
              actions: arr.isEmpty
                  ? const []
                  : [
                      NsButton(
                        label: 'Show all',
                        icon: Icons.visibility_rounded,
                        onPressed: () => widget.state.setAllGroupsVisible(
                          widget.playlistId,
                          widget.section,
                          true,
                        ),
                      ),
                      NsButton(
                        label: 'Hide all',
                        icon: Icons.visibility_off_rounded,
                        onPressed: () => widget.state.setAllGroupsVisible(
                          widget.playlistId,
                          widget.section,
                          false,
                        ),
                      ),
                    ],
            ),
            if (arr.isEmpty)
              const _EmptyState()
            // One ListView child per block — not one giant [Column] — so inner
            // [Expanded] / Material buttons get proper viewport-width constraints
            // and full-width hit targets (a single [Column] can confuse layout).
            else ...[
              for (var i = 0; i < arr.length; i++) ...[
                if (i > 0) const SizedBox(height: 5),
                _CompactRow(
                  group: arr[i],
                  isLive: isLive,
                  isEditing: arr[i].id == editingId,
                  orderPanelOpen: _orderPanelGid == arr[i].id,
                  onToggleVisible: () => widget.state.toggleGroupVisible(
                    widget.playlistId,
                    widget.section,
                    arr[i].id,
                  ),
                  onToggleEdit: () => _toggleEdit(arr[i]),
                  onOpenOrderPanel: isLive
                      ? () => _openOrderPanel(arr[i].id)
                      : null,
                  orderTooltip: l10n.playlistGroupPillOrderTitle,
                ),
                if (isLive && _orderPanelGid == arr[i].id) ...[
                  const SizedBox(height: 4),
                  _NsPillOrderPanel(
                    l10n: l10n,
                    beforeFavorites: _orderPanelBeforeFav,
                    onSelectAfter: () => setState(
                      () => _orderPanelBeforeFav = false,
                    ),
                    onSelectBefore: () => setState(
                      () => _orderPanelBeforeFav = true,
                    ),
                    positionController: _orderPosCtrl,
                    onSave: () => unawaited(_savePillOrder()),
                    onCancel: _closeOrderPanel,
                  ),
                ],
                if (arr[i].id == editingId)
                  NsInlineEdit(
                    label: 'Custom name',
                    controller: _ctrlFor(arr[i]),
                    focusNode: _focusFor(arr[i]),
                    placeholder: arr[i].name,
                    helpText: 'Empty value uses the original name.',
                    onSave: () {
                      widget.state.setGroupAlias(
                        widget.playlistId,
                        widget.section,
                        arr[i].id,
                        _ctrlFor(arr[i]).text,
                      );
                      widget.state.inlineEdit = null;
                    },
                    onCancel: () {
                      widget.state.inlineEdit = null;
                    },
                    onReset: arr[i].alias != null
                        ? () {
                            widget.state.setGroupAlias(
                              widget.playlistId,
                              widget.section,
                              arr[i].id,
                              null,
                            );
                            widget.state.inlineEdit = null;
                          }
                        : null,
                  ),
              ],
            ],
          ],
        );
      },
    );
  }

  /// Lazy-create a controller. Does **not** touch `.text` on reads —
  /// only [_toggleEdit] seeds the initial value when the inline edit
  /// opens, so the user's typing is never wiped.
  TextEditingController _ctrlFor(NsPlaylistGroup g) {
    return _aliasCtrls.putIfAbsent(
      g.id,
      () => TextEditingController(text: g.alias ?? ''),
    );
  }

  FocusNode _focusFor(NsPlaylistGroup g) {
    return _aliasFocus.putIfAbsent(
      g.id,
      () => FocusNode(debugLabel: 'ns:groupEdit:${g.id}'),
    );
  }

  void _toggleEdit(NsPlaylistGroup g) {
    if (_orderPanelGid != null) {
      setState(() => _orderPanelGid = null);
    }
    final key = '$_editKeyPrefix${g.id}';
    if (widget.state.inlineEdit == key) {
      widget.state.inlineEdit = null;
      return;
    }
    widget.state.inlineEdit = key;
    _ctrlFor(g).text = g.alias ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _focusFor(g);
      if (node.canRequestFocus) node.requestFocus();
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.compact-row` — grid auto / 1fr / auto auto auto, gap 10, padding 10/12
// (tightened for TV: 7/10).
// ═══════════════════════════════════════════════════════════════════════

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.group,
    required this.isLive,
    required this.isEditing,
    this.orderPanelOpen = false,
    required this.onToggleVisible,
    required this.onToggleEdit,
    this.onOpenOrderPanel,
    this.orderTooltip,
  });

  final NsPlaylistGroup group;
  final bool isLive;
  final bool isEditing;
  final bool orderPanelOpen;
  final VoidCallback onToggleVisible;
  final VoidCallback onToggleEdit;
  final VoidCallback? onOpenOrderPanel;
  final String? orderTooltip;

  @override
  Widget build(BuildContext context) {
    final display = group.alias ?? group.name;
    final renamed = group.alias != null;
    return Opacity(
      opacity: group.visible ? 1.0 : 0.55, // `.compact-row.dim`
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: NsColors.surface,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NsColors.bg2,
                border: Border.all(color: NsColors.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.folder_rounded,
                size: 11,
                color: NsColors.text3,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          display,
                          style: const TextStyle(
                            color: NsColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (renamed) ...[
                        const SizedBox(width: 5),
                        const NsTag(label: 'RENAMED'),
                      ],
                      if (isLive && group.beforeFav) ...[
                        const SizedBox(width: 5),
                        const NsTag(label: 'BEFORE FAVS'),
                      ],
                    ],
                  ),
                  if (renamed) ...[
                    const SizedBox(height: 1),
                    Text(
                      'Originally: ${group.name}',
                      style: const TextStyle(
                        color: NsColors.text4,
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
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
            const SizedBox(width: 8),
            NsVisPill(on: group.visible, onPressed: onToggleVisible),
            const SizedBox(width: 6),
            NsChipBtn(
              icon: Icons.edit_rounded,
              label: 'Edit',
              variant: isEditing
                  ? NsChipVariant.accent
                  : NsChipVariant.defaultVariant,
              onPressed: onToggleEdit,
            ),
            if (isLive && onOpenOrderPanel != null) ...[
              const SizedBox(width: 5),
              NsChipBtn(
                icon: Icons.move_up_rounded,
                variant: (group.beforeFav || orderPanelOpen)
                    ? NsChipVariant.accent
                    : NsChipVariant.defaultVariant,
                tooltip: orderTooltip,
                onPressed: onOpenOrderPanel!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.empty` — centered block for empty sections.
// ═══════════════════════════════════════════════════════════════════════

/// Inline panel — TV pill order vs Favorites (Settings / Manage groups / TV).
///
/// [NsFocusable] segment cells + [NsButton] Save/Cancel so focus stays inside
/// the panel (ordered traversal + D-pad from the position field) and the
/// Hugging-L accent reads clearly vs filled Material buttons.
class _NsPillOrderPanel extends StatefulWidget {
  const _NsPillOrderPanel({
    required this.l10n,
    required this.beforeFavorites,
    required this.onSelectAfter,
    required this.onSelectBefore,
    required this.positionController,
    required this.onSave,
    required this.onCancel,
  });

  final AppLocalizations l10n;
  final bool beforeFavorites;
  final VoidCallback onSelectAfter;
  final VoidCallback onSelectBefore;
  final TextEditingController positionController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  State<_NsPillOrderPanel> createState() => _NsPillOrderPanelState();
}

class _NsPillOrderPanelState extends State<_NsPillOrderPanel> {
  static const double _segRadius = 6;

  late final FocusNode _afterFocus;
  late final FocusNode _beforeFocus;
  late final FocusNode _posFocus;
  late final FocusNode _saveFocus;
  late final FocusNode _cancelFocus;

  @override
  void initState() {
    super.initState();
    _afterFocus = FocusNode(debugLabel: 'nsPillAfter');
    _beforeFocus = FocusNode(debugLabel: 'nsPillBefore');
    _posFocus = FocusNode(debugLabel: 'nsPillPos');
    _saveFocus = FocusNode(debugLabel: 'nsPillSave');
    _cancelFocus = FocusNode(debugLabel: 'nsPillCancel');
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    if (widget.beforeFavorites) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _posFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _NsPillOrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beforeFavorites && !oldWidget.beforeFavorites) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _posFocus.canRequestFocus) {
          _posFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _afterFocus.dispose();
    _beforeFocus.dispose();
    _posFocus.dispose();
    _saveFocus.dispose();
    _cancelFocus.dispose();
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_posFocus.hasFocus) return false;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_saveFocus.canRequestFocus) {
        _saveFocus.requestFocus();
        return true;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_beforeFocus.canRequestFocus) {
        _beforeFocus.requestFocus();
        return true;
      }
    }
    return false;
  }

  void _focusSaveAfterFieldInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _saveFocus.canRequestFocus) {
        _saveFocus.requestFocus();
      }
    });
  }

  Widget _segment({
    required double traversalOrder,
    required FocusNode node,
    required bool selected,
    required String label,
    required VoidCallback onTap,
    FocusNode? left,
    FocusNode? right,
    required FocusNode down,
  }) {
    return Expanded(
      child: FocusTraversalOrder(
        order: NumericFocusOrder(traversalOrder),
        child: NsFocusable(
          focusNode: node,
          onActivate: onTap,
          focusLeftNeighbor: left,
          focusRightNeighbor: right,
          focusDownNeighbor: down,
          focusAccentRadius: _segRadius,
          semanticLabel: label,
          builder: (context, focused) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: 28),
              decoration: BoxDecoration(
                color: NsColors.bg2,
                borderRadius: BorderRadius.circular(_segRadius),
                border: Border.all(
                  color: selected ? NsColors.accentLine : NsColors.line2,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  height: 1.1,
                  color: selected ? NsColors.accent : NsColors.text2,
                  decoration: TextDecoration.none,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downFromSeg =
        widget.beforeFavorites ? _posFocus : _saveFocus;
    final saveUp = widget.beforeFavorites ? _posFocus : _beforeFocus;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: NsColors.surface2,
          border: Border.all(color: NsColors.line),
        ),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.l10n.playlistGroupPillOrderTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: NsColors.text3,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.12,
                  height: 1.15,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _segment(
                    traversalOrder: 1.0,
                    node: _afterFocus,
                    selected: !widget.beforeFavorites,
                    label: widget.l10n.playlistGroupPillAfterFavorites,
                    onTap: widget.onSelectAfter,
                    left: null,
                    right: _beforeFocus,
                    down: downFromSeg,
                  ),
                  const SizedBox(width: 3),
                  _segment(
                    traversalOrder: 2.0,
                    node: _beforeFocus,
                    selected: widget.beforeFavorites,
                    label: widget.l10n.playlistGroupPillBeforeFavorites,
                    onTap: widget.onSelectBefore,
                    left: _afterFocus,
                    right: null,
                    down: downFromSeg,
                  ),
                ],
              ),
              if (widget.beforeFavorites) ...[
                const SizedBox(height: 4),
                Text(
                  widget.l10n.playlistGroupPillPositionLabel,
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3.0),
                  child: TextField(
                    controller: widget.positionController,
                    focusNode: _posFocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onEditingComplete: _focusSaveAfterFieldInput,
                    onSubmitted: (_) => _focusSaveAfterFieldInput(),
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      decoration: TextDecoration.none,
                    ),
                    cursorColor: NsColors.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: NsColors.bg2,
                      hintText: widget.l10n.playlistGroupPillPositionHint,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(color: NsColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(color: NsColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(
                          color: NsColors.accentLine,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(4.0),
                      child: NsButton(
                        label: widget.l10n.commonSave,
                        variant: NsButtonVariant.primary,
                        fillWidth: true,
                        dense: true,
                        focusNode: _saveFocus,
                        focusAccentRadius: 6,
                        focusUpNeighbor: saveUp,
                        focusRightNeighbor: _cancelFocus,
                        onPressed: widget.onSave,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(5.0),
                      child: NsButton(
                        label: widget.l10n.commonCancel,
                        variant: NsButtonVariant.ghost,
                        fillWidth: true,
                        dense: true,
                        focusNode: _cancelFocus,
                        focusAccentRadius: 6,
                        focusUpNeighbor: saveUp,
                        focusLeftNeighbor: _saveFocus,
                        onPressed: widget.onCancel,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.folder_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No groups available',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Sync this playlist first.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
