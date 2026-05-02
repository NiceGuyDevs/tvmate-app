import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/team_palette_theme.dart';
import '../ui/focus/tv_focusable.dart';
import '../ui/widgets/tv_catalog_image.dart';
import 'live_lineup_item.dart';

/// Grid of channel icons for multiview / favorites. Each cell is a [TvFocusable]
/// with **explicit** D-pad neighbors so TV focus does not get stuck (e.g. after
/// column 4) when default traversal mis-orders targets.
class LiveMultiviewChannelIconsScreen extends StatefulWidget {
  const LiveMultiviewChannelIconsScreen({
    super.key,
    required this.lineup,
    required this.selectedIndex,
    required this.title,
  });

  final List<LiveLineupItem> lineup;
  final int selectedIndex;
  final String title;

  @override
  State<LiveMultiviewChannelIconsScreen> createState() =>
      _LiveMultiviewChannelIconsScreenState();
}

class _LiveMultiviewChannelIconsScreenState
    extends State<LiveMultiviewChannelIconsScreen> {
  static const int _gridCols = 8;
  static const double _cellHeight = 108.0;
  static const double _spacing = 10.0;

  List<FocusNode> _cellFocusNodes = [];
  List<GlobalKey> _cellKeys = [];

  @override
  void initState() {
    super.initState();
    _syncFocusResources();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitialSelection());
  }

  @override
  void didUpdateWidget(covariant LiveMultiviewChannelIconsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineup.length != widget.lineup.length) {
      _syncFocusResources();
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInitialSelection());
    }
  }

  @override
  void dispose() {
    for (final n in _cellFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _syncFocusResources() {
    for (final n in _cellFocusNodes) {
      n.dispose();
    }
    final len = widget.lineup.length;
    _cellFocusNodes = List.generate(
      len,
      (i) => FocusNode(debugLabel: 'mvPicker_$i'),
    );
    _cellKeys = List.generate(len, (_) => GlobalKey());
  }

  void _focusInitialSelection() {
    if (!mounted) return;
    final n = widget.lineup.length;
    if (n == 0) return;
    final i = widget.selectedIndex.clamp(0, n - 1);
    if (i >= _cellFocusNodes.length) return;
    _cellFocusNodes[i].requestFocus();
    final ctx = _cellKeys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: Duration.zero,
      );
    }
  }

  /// Deterministic 8-column grid: Right always moves to [index+1] when in the same row.
  KeyEventResult? _onGridCellKey(int index, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final k = event.logicalKey;
    final total = widget.lineup.length;
    const cols = _gridCols;
    final col = index % cols;
    final row = index ~/ cols;
    int? next;
    if (k == LogicalKeyboardKey.arrowRight) {
      if (col < cols - 1 && index + 1 < total) next = index + 1;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (col > 0) next = index - 1;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      final below = index + cols;
      if (below < total) next = below;
    } else if (k == LogicalKeyboardKey.arrowUp) {
      if (row > 0) next = index - cols;
    }
    if (next != null && next < _cellFocusNodes.length) {
      final idx = next;
      _cellFocusNodes[idx].requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _cellKeys[idx].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.35,
            duration: Duration.zero,
          );
        }
      });
      return KeyEventResult.handled;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lineup = widget.lineup;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.goBack ||
                    event.logicalKey == LogicalKeyboardKey.escape)) {
              Navigator.of(context).pop<int?>(null);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    TvFocusable(
                      autofocus: false,
                      onActivate: () => Navigator.of(context).pop<int?>(null),
                      focusPadding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 22),
                          const SizedBox(width: 8),
                          Text(l10n.commonBack,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 72),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridCols,
                    mainAxisExtent: _cellHeight,
                    crossAxisSpacing: _spacing,
                    mainAxisSpacing: _spacing,
                  ),
                  itemCount: lineup.length,
                  itemBuilder: (context, i) {
                    if (i >= _cellFocusNodes.length || i >= _cellKeys.length) {
                      return const SizedBox.shrink();
                    }
                    final item = lineup[i];
                    return KeyedSubtree(
                      key: _cellKeys[i],
                      child: _ChannelCell(
                        item: item,
                        index: i,
                        theme: theme,
                        focusNode: _cellFocusNodes[i],
                        onKeyIntercept: (node, event) =>
                            _onGridCellKey(i, node, event),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelCell extends StatefulWidget {
  const _ChannelCell({
    required this.item,
    required this.index,
    required this.theme,
    required this.focusNode,
    required this.onKeyIntercept,
  });

  final LiveLineupItem item;
  final int index;
  final ThemeData theme;
  final FocusNode focusNode;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onKeyIntercept;

  @override
  State<_ChannelCell> createState() => _ChannelCellState();
}

class _ChannelCellState extends State<_ChannelCell> {
  bool _focused = false;

  static const double _iconSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final p = context.teamPalette;
    final url = widget.item.iconUrl?.trim() ?? '';
    final runes = widget.item.title.trim().runes;
    final initial = runes.isEmpty
        ? '?'
        : String.fromCharCode(runes.first).toUpperCase();

    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: false,
      onKeyIntercept: widget.onKeyIntercept,
      onActivate: () => Navigator.of(context).pop<int?>(widget.index),
      onFocusedChange: (f) {
        if (f != _focused) setState(() => _focused = f);
      },
      focusPadding: const EdgeInsets.all(2),
      focusedBorderWidth: 2.5,
      showFocusElevation: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused
                    ? p.accent.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.14),
                width: _focused ? 2.5 : 1.0,
              ),
              color: Colors.white.withValues(
                alpha: _focused ? 0.1 : 0.05,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isNotEmpty
                ? TvCatalogImage(url: url)
                : Center(
                    child: Text(
                      initial,
                      style: widget.theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: widget.theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(
                alpha: _focused ? 0.95 : 0.65,
              ),
              fontWeight: _focused ? FontWeight.w800 : FontWeight.w600,
              fontSize: 10.5,
              height: 1.12,
            ),
          ),
        ],
      ),
    );
  }
}
