/// EPG zone dropdown — one-to-one with `openEpgMenu` / `renderEpgMenuList`
/// in settings.html (lines 6423–6622).
///
/// Key behaviours ported verbatim:
///
///   * **Anchored to the trigger** via an [OverlayEntry] — appears right
///     below the clicked EPG button (flips above when there's no room
///     below), NOT a centered modal.
///   * **Two sections only**: `QUICK` (Local time + As provided) and
///     `WORLD` (every zone, flat).
///   * **DEFAULT pill** on "Local time" — styled as a small text tag.
///   * **Search** with live filter by name / iana id / chip code.
///   * **Keyboard nav**: ↑↓ cycles through filtered rows (wraps), ↵
///     selects, Esc / Back closes.
///   * **Autoscroll** the current zone into view on open.
///   * Plain text rows — no underlines, no yellow tints, no link styling.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_data.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

/// Anchored popover menu. Returns the picked mode id or null if
/// dismissed. Computes the popover position from the [anchorContext]'s
/// render box, flipping above the anchor when there isn't room below.
Future<String?> showNsEpgZoneMenu({
  required BuildContext anchorContext,
  required String playlistName,
  required String currentMode,
}) async {
  final box = anchorContext.findRenderObject();
  if (box is! RenderBox || !box.attached) return null;

  final anchorTopLeft = box.localToGlobal(Offset.zero);
  final anchorSize = box.size;
  final screenSize = MediaQuery.of(anchorContext).size;

  // Drop whatever held focus (the EPG button we were just on) so the
  // menu's own [Focus] node gets a clean slate when it autofocuses.
  // Without this, the focus manager sometimes refused to hand focus to
  // the freshly-inserted overlay on 3rd/4th opens and D-pad events fell
  // through into the page behind the dim layer.
  FocusManager.instance.primaryFocus?.unfocus();

  final completer = Completer<String?>();
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (ctx) => _EpgMenuPopover(
      anchorTopLeft: anchorTopLeft,
      anchorSize: anchorSize,
      screenSize: screenSize,
      playlistName: playlistName,
      currentMode: currentMode,
      onPicked: (mode) {
        entry?.remove();
        if (!completer.isCompleted) completer.complete(mode);
      },
      onDismiss: () {
        entry?.remove();
        if (!completer.isCompleted) completer.complete(null);
      },
    ),
  );
  Overlay.of(anchorContext, rootOverlay: true).insert(entry);
  return completer.future;
}

// ═══════════════════════════════════════════════════════════════════════
//  Data — menu items
// ═══════════════════════════════════════════════════════════════════════

class _ZoneItem {
  const _ZoneItem({
    required this.mode,
    required this.name,
    required this.group, // 'Quick' | 'World'
    this.iana,
    this.chip,
    this.offset,
    this.pin,
  });
  final String mode;
  final String name;
  final String group;
  final String? iana;
  final String? chip;
  final String? offset;
  final String? pin;
}

/// Matches `epgMenuItems()` in the HTML (line 6388):
///
///     [
///       { mode:'local',    name:'Local time',  pin:'DEFAULT', off:'±0:00', group:'Quick' },
///       { mode:'original', name:'As provided',                             group:'Quick' },
///       ...EPG_ZONES.map(z => ({ ..., group: 'World' })),
///     ]
List<_ZoneItem> _allItems() {
  return <_ZoneItem>[
    const _ZoneItem(
      mode: 'local',
      name: 'Local time',
      pin: 'DEFAULT',
      offset: '±0:00',
      group: 'Quick',
    ),
    const _ZoneItem(
      mode: 'original',
      name: 'As provided',
      group: 'Quick',
    ),
    for (final z in kNsEpgZones)
      _ZoneItem(
        mode: z.id,
        name: z.label,
        iana: z.id,
        chip: z.chip,
        offset: z.offset,
        group: 'World',
      ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════
//  Popover shell
// ═══════════════════════════════════════════════════════════════════════

class _EpgMenuPopover extends StatefulWidget {
  const _EpgMenuPopover({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.screenSize,
    required this.playlistName,
    required this.currentMode,
    required this.onPicked,
    required this.onDismiss,
  });

  final Offset anchorTopLeft;
  final Size anchorSize;
  final Size screenSize;
  final String playlistName;
  final String currentMode;
  final ValueChanged<String> onPicked;
  final VoidCallback onDismiss;

  @override
  State<_EpgMenuPopover> createState() => _EpgMenuPopoverState();
}

class _EpgMenuPopoverState extends State<_EpgMenuPopover> {
  // Compact — width matches the HTML reference, row padding is tight
  // so ~12 rows fit at max height (vs 5-6 before). Menu shrinks to
  // whatever vertical space is free around the anchor, bounded by
  // [_menuMinH]..[_menuMaxH].
  static const double _menuW = 232;
  static const double _menuMaxH = 360;
  static const double _menuMinH = 200;
  static const double _margin = 8;
  static const double _gap = 6;

  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocus;

  /// Single outer focus node. Opens with this focused (NOT the search
  /// field) so the soft keyboard stays dismissed — arrow keys drive
  /// the virtual selection in the list. ArrowUp on the first row
  /// routes focus to [_searchFocus]; the search field's ArrowDown
  /// routes focus back here.
  late final FocusNode _listFocus;

  late final ScrollController _scrollCtrl;
  late final List<_ZoneItem> _all;
  late List<_ZoneItem> _filtered;

  /// Index into [_filtered] that the virtual selection sits on. The
  /// matching row's [GlobalKey] is registered in [_rowKeys] so we can
  /// scroll it into view whenever it changes.
  int _activeIdx = 0;

  /// One [GlobalKey] per currently-filtered row. Rebuilt on each
  /// filter change so [_ensureActiveVisible] can look up the right
  /// render box and scroll it into view.
  final List<GlobalKey> _rowKeys = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _searchFocus = FocusNode(debugLabel: 'ns:epgMenu:search');
    _listFocus = FocusNode(debugLabel: 'ns:epgMenu:list');
    _scrollCtrl = ScrollController();
    _all = _allItems();
    _filtered = List.of(_all);
    _rebuildRowKeys();
    _activeIdx = _filtered.indexWhere((it) => it.mode == widget.currentMode);
    if (_activeIdx < 0) _activeIdx = 0;

    // Belt-and-suspenders focus grab. Three separate passes, because
    // a stale primary focus on the page behind the overlay has been
    // seen to swallow the autofocus request on 3rd+ opens. Each pass
    // no-ops if the list already has focus.
    WidgetsBinding.instance.addPostFrameCallback(_grabFocus);
    Future.microtask(() {
      if (!mounted) return;
      _grabFocus(Duration.zero);
      _ensureActiveVisible();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _grabFocus(Duration.zero);
    });
  }

  void _grabFocus(Duration _) {
    if (!mounted) return;
    if (_searchFocus.hasFocus) return;
    if (!_listFocus.hasFocus && _listFocus.canRequestFocus) {
      _listFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _listFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _rebuildRowKeys() {
    _rowKeys
      ..clear()
      ..addAll(List.generate(_filtered.length, (_) => GlobalKey()));
  }

  /// Scrolls the row at [_activeIdx] into view. Called on arrow-key
  /// navigation and on first show so the currently-selected zone is
  /// visible even when the list has been scrolled far down.
  void _ensureActiveVisible() {
    if (_activeIdx < 0 || _activeIdx >= _rowKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _rowKeys[_activeIdx].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void _focusSearch() {
    if (!_searchFocus.canRequestFocus) return;
    _searchFocus.requestFocus();
  }

  void _focusListFromSearch() {
    if (!_listFocus.canRequestFocus) return;
    _listFocus.requestFocus();
  }

  // ── Position the popover relative to the anchor ─────────────────

  /// Returns `(left, top, maxH)` for the popover. Flips above when the
  /// anchor sits too low, and shrinks `maxH` to whatever vertical space
  /// is actually available so the menu never overflows the viewport.
  (double, double, double) _computePosition() {
    final w = _menuW;
    final vw = widget.screenSize.width;
    final vh = widget.screenSize.height;

    double left = widget.anchorTopLeft.dx;
    if (left + w > vw - _margin) left = vw - _margin - w;
    if (left < _margin) left = _margin;

    final spaceBelow =
        vh - (widget.anchorTopLeft.dy + widget.anchorSize.height + _gap) -
            _margin;
    final spaceAbove = widget.anchorTopLeft.dy - _gap - _margin;

    double top;
    double maxH;
    if (spaceBelow >= _menuMinH || spaceBelow >= spaceAbove) {
      top = widget.anchorTopLeft.dy + widget.anchorSize.height + _gap;
      maxH = spaceBelow.clamp(_menuMinH, _menuMaxH);
    } else {
      maxH = spaceAbove.clamp(_menuMinH, _menuMaxH);
      top = widget.anchorTopLeft.dy - _gap - maxH;
    }
    return (left, top, maxH);
  }

  // ── Search / filter ─────────────────────────────────────────────

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(_all);
      } else {
        _filtered = _all.where((it) {
          return it.name.toLowerCase().contains(query) ||
              (it.iana?.toLowerCase().contains(query) ?? false) ||
              (it.chip?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
      _rebuildRowKeys();
      _activeIdx = _filtered.isNotEmpty ? 0 : -1;
    });
  }

  // ── Keyboard ────────────────────────────────────────────────────

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    if (_filtered.isEmpty) {
      // Nothing in the list — ArrowUp should still surface the search.
      if (key == LogicalKeyboardKey.arrowUp) {
        _focusSearch();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_activeIdx < _filtered.length - 1) {
          _activeIdx += 1;
        }
      });
      _ensureActiveVisible();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      // Pressing Up on the first row hands focus to the search field
      // (this is the only path that opens the soft keyboard).
      if (_activeIdx <= 0) {
        _focusSearch();
        return KeyEventResult.handled;
      }
      setState(() => _activeIdx -= 1);
      _ensureActiveVisible();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_activeIdx >= 0 && _activeIdx < _filtered.length) {
        widget.onPicked(_filtered[_activeIdx].mode);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (left, top, maxH) = _computePosition();
    return Stack(
      children: [
        // Invisible full-screen tap-to-dismiss layer.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: Color(0x66000000)),
          ),
        ),
        // The popover itself, positioned at the anchor. A single
        // [Focus] node holds the list-level key events and is
        // autofocused on insertion — no nested FocusScope, no extra
        // indirection, so focus lands the same way on every open.
        Positioned(
          left: left,
          top: top,
          width: _menuW,
          height: maxH,
          child: Focus(
            focusNode: _listFocus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Container(
              decoration: BoxDecoration(
                color: NsColors.surface,
                border: Border.all(color: NsColors.line2),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 24),
                    blurRadius: 60,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Head(
                    playlistName: widget.playlistName,
                    onClose: widget.onDismiss,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: NsColors.line,
                  ),
                  _Search(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: _applyFilter,
                    onDownArrow: _focusListFromSearch,
                    onEscape: widget.onDismiss,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: NsColors.line,
                  ),
                  Expanded(
                    child: _List(
                      items: _filtered,
                      rowKeys: _rowKeys,
                      activeIdx: _activeIdx,
                      currentMode: widget.currentMode,
                      scrollCtrl: _scrollCtrl,
                      onHover: (i) => setState(() => _activeIdx = i),
                      onPick: (m) => widget.onPicked(m),
                      emptyQuery: _searchCtrl.text,
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: NsColors.line,
                  ),
                  const _Foot(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Head ────────────────────────────────────────────────────────────────

class _Head extends StatelessWidget {
  const _Head({required this.playlistName, required this.onClose});
  final String playlistName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 11,
            color: NsColors.accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(
                  color: NsColors.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                children: [
                  const TextSpan(text: 'Time zone'),
                  const TextSpan(
                    text: '  for ',
                    style: TextStyle(
                      color: NsColors.text3,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(text: playlistName),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _CloseBtn(onPressed: onClose),
        ],
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  const _CloseBtn({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: 'Close',
      builder: (context, focused) => Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : Colors.transparent,
          border: Border.all(
            color: focused ? NsColors.line2 : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 11,
          color: focused ? NsColors.text : NsColors.text3,
        ),
      ),
    );
  }
}

// ─── Search ──────────────────────────────────────────────────────────────

class _Search extends StatelessWidget {
  const _Search({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onDownArrow,
    required this.onEscape,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// Fired when the user presses D-pad Down while the search field is
  /// focused — routes focus back into the list (closes soft keyboard).
  final VoidCallback onDownArrow;

  /// Fired on Escape / Back while the search field owns focus.
  final VoidCallback onEscape;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: NsColors.bg2,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              size: 11,
              color: NsColors.text3,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      onDownArrow,
                  const SingleActivator(LogicalKeyboardKey.escape): onEscape,
                  const SingleActivator(LogicalKeyboardKey.goBack): onEscape,
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                  cursorColor: NsColors.accent,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 5),
                    border: InputBorder.none,
                    hintText: 'Search…',
                    hintStyle: TextStyle(
                      color: NsColors.text4,
                      fontSize: 11.5,
                      decoration: TextDecoration.none,
                    ),
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

// ─── List ────────────────────────────────────────────────────────────────

class _List extends StatelessWidget {
  const _List({
    required this.items,
    required this.rowKeys,
    required this.activeIdx,
    required this.currentMode,
    required this.scrollCtrl,
    required this.onHover,
    required this.onPick,
    required this.emptyQuery,
  });

  final List<_ZoneItem> items;

  /// Same length as [items]. The row at index `i` attaches
  /// `rowKeys[i]` so the parent can call [Scrollable.ensureVisible]
  /// on whichever row is currently the [activeIdx].
  final List<GlobalKey> rowKeys;
  final int activeIdx;
  final String currentMode;
  final ScrollController scrollCtrl;
  final void Function(int idx) onHover;
  final void Function(String mode) onPick;
  final String emptyQuery;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'No matches for "$emptyQuery"',
          style: const TextStyle(
            color: NsColors.text3,
            fontSize: 11,
            height: 1.3,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final children = <Widget>[];
    String? lastGroup;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.group != lastGroup) {
        children.add(_SectionHead(label: it.group.toUpperCase()));
        lastGroup = it.group;
      }
      children.add(_Row(
        key: rowKeys[i],
        item: it,
        isActive: i == activeIdx,
        isSelected: it.mode == currentMode,
        onHover: () => onHover(i),
        onPick: () => onPick(it.mode),
      ));
    }

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: children,
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 2),
      child: Text(
        label,
        style: const TextStyle(
          color: NsColors.text4,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.item,
    required this.isActive,
    required this.isSelected,
    required this.onHover,
    required this.onPick,
  });

  final _ZoneItem item;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onHover;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final Color bg = isActive
        ? NsColors.surface2
        : isSelected
            ? NsColors.accentSoft
            : Colors.transparent;
    final Color fg = isSelected ? NsColors.accent : NsColors.text;

    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          color: bg,
          child: Row(
            children: [
              // Chip / fixed-width placeholder.
              SizedBox(
                width: 24,
                child: item.chip == null
                    ? null
                    : Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        decoration: BoxDecoration(
                          color: NsColors.bg2,
                          border: Border.all(color: NsColors.line),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.chip!,
                          style: const TextStyle(
                            color: NsColors.text3,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          color: fg,
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          height: 1.1,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.pin != null) ...[
                      const SizedBox(width: 5),
                      _PinTag(label: item.pin!),
                    ],
                  ],
                ),
              ),
              if (item.offset != null) ...[
                const SizedBox(width: 5),
                Text(
                  item.offset!,
                  style: TextStyle(
                    color: item.offset == '±0:00'
                        ? NsColors.text4
                        : NsColors.text3,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: NsColors.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "DEFAULT" — small uppercase tag next to the default row.
class _PinTag extends StatelessWidget {
  const _PinTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: NsColors.accentSoft,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NsColors.accent,
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ─── Foot ────────────────────────────────────────────────────────────────

class _Foot extends StatelessWidget {
  const _Foot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          _Kbd('↑↓'),
          SizedBox(width: 3),
          Text(
            'Move',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(width: 8),
          _Kbd('↵'),
          SizedBox(width: 3),
          Text(
            'Select',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          Spacer(),
          _Kbd('Esc'),
          SizedBox(width: 3),
          Text(
            'Close',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NsColors.text2,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
