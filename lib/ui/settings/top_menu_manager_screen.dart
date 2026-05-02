import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/top_menu_store.dart';
import '../../l10n/app_localizations.dart';
import '../../shell/shell_destination.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';

class TopMenuManagerScreen extends StatefulWidget {
  const TopMenuManagerScreen({super.key});

  @override
  State<TopMenuManagerScreen> createState() => _TopMenuManagerScreenState();
}

class _TopMenuManagerScreenState extends State<TopMenuManagerScreen> {
  int? _movingIndex;

  List<ShellDestination> get _order => topMenuStore.order;

  /// All optional items that are NOT currently in the menu.
  List<ShellDestination> get _availableOptionals {
    return ShellDestination.values
        .where((d) => d.isOptional && !_order.contains(d))
        .toList();
  }

  void _onActivateItem(int index) {
    setState(() {
      if (_movingIndex == index) {
        _movingIndex = null;
      } else {
        _movingIndex = index;
      }
    });
  }

  KeyEventResult? _onItemKey(int index, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _movingIndex == null) return null;
    final k = event.logicalKey;
    if (_movingIndex != index) return null;

    if (k == LogicalKeyboardKey.arrowUp && index > 0) {
      topMenuStore.reorder(index, index - 1);
      setState(() => _movingIndex = index - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown && index < _order.length - 1) {
      topMenuStore.reorder(index, index + 1);
      setState(() => _movingIndex = index + 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      setState(() => _movingIndex = null);
      return KeyEventResult.handled;
    }
    return null;
  }

  /// Right on an optional row removes it from the bar (no separate remove control — avoids stealing OK).
  KeyEventResult? _onOrderRowKey(int index, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (index < 0 || index >= _order.length) return null;
    final d = _order[index];
    if (d.isOptional && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _removeFromMenu(index);
      return KeyEventResult.handled;
    }
    return _onItemKey(index, node, event);
  }

  void _toggleOptional(ShellDestination d) {
    topMenuStore.toggleOptional(d);
    setState(() => _movingIndex = null);
  }

  void _removeFromMenu(int index) {
    final d = _order[index];
    if (!d.isOptional) return;
    topMenuStore.toggleOptional(d);
    setState(() => _movingIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final order = _order;
    final optionals = _availableOptionals;
    final startup = topMenuStore.startup;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          playerSettingsRouteBackdrop(context),
          Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TvFocusable(
                  onActivate: () => Navigator.of(context).pop(),
                  focusPadding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white.withOpacity(0.85),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.topMenuManagerTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: reorder list ──
                  Expanded(
                    flex: 3,
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(0),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.topMenuOrderSection,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.topMenuReorderHelp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.topMenuRemoveHelp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            itemCount: order.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              if (i < order.length) {
                                return _MenuOrderTile(
                                  destination: order[i],
                                  index: i,
                                  isMoving: _movingIndex == i,
                                  isOptional: order[i].isOptional,
                                  autofocus: i == 0,
                                  onActivate: () => _onActivateItem(i),
                                  onKey: (node, event) =>
                                      _onOrderRowKey(i, node, event),
                                );
                              }
                              // Settings (locked last)
                              return _LockedSettingsTile();
                            },
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // ── Right column: optionals + startup ──
                  Expanded(
                    flex: 2,
                    child: FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (optionals.isNotEmpty) ...[
                          Text(
                            l10n.topMenuAddToMenu,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...optionals.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: _OptionalToggleTile(
                                  destination: d,
                                  onActivate: () => _toggleOptional(d),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          l10n.topMenuStartupSection,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.topMenuStartupHelp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: topMenuStore.fullMenu.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 3),
                            itemBuilder: (context, i) {
                              final d = topMenuStore.fullMenu[i];
                              final isSelected = d == startup;
                              return _StartupChoiceTile(
                                destination: d,
                                isSelected: isSelected,
                                onActivate: () {
                                  topMenuStore.setStartup(d);
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        ],
      ),
    );
  }
}

class _MenuOrderTile extends StatelessWidget {
  const _MenuOrderTile({
    required this.destination,
    required this.index,
    required this.isMoving,
    required this.isOptional,
    required this.onActivate,
    required this.onKey,
    this.autofocus = false,
  });

  final ShellDestination destination;
  final int index;
  final bool isMoving;
  final bool isOptional;
  final VoidCallback onActivate;
  final KeyEventResult? Function(FocusNode, KeyEvent) onKey;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final p = context.teamPalette;
    return TvFocusable(
      autofocus: autofocus,
      onActivate: onActivate,
      onKeyIntercept: onKey,
      focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isMoving
              ? p.accent.withOpacity(0.18)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isMoving
                ? p.accent.withOpacity(0.7)
                : Colors.white.withOpacity(0.1),
            width: isMoving ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: p.accent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(destination.icon, size: 18, color: Colors.white.withOpacity(0.85)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                destination.labelL10n(l10n),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isMoving)
              Icon(
                Icons.open_with_rounded,
                size: 17,
                color: p.accent.withOpacity(0.9),
              ),
            if (!isMoving && destination.isFixed)
              Icon(Icons.lock_outline_rounded,
                  size: 14, color: Colors.white.withOpacity(0.3)),
            if (!isMoving && isOptional)
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: Colors.white.withOpacity(0.28),
              ),
          ],
        ),
      ),
    );
  }
}

class _LockedSettingsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 22),
          const SizedBox(width: 6),
          Icon(Icons.settings_rounded,
              size: 18, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.topMenuSettingsLocked,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          Text(
            l10n.topMenuAlwaysLast,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9.5,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.lock_rounded,
              size: 13, color: Colors.white.withOpacity(0.25)),
        ],
      ),
    );
  }
}

class _OptionalToggleTile extends StatelessWidget {
  const _OptionalToggleTile({
    required this.destination,
    required this.onActivate,
  });

  final ShellDestination destination;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final p = context.teamPalette;
    return TvFocusable(
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                size: 16, color: p.accent.withOpacity(0.7)),
            const SizedBox(width: 8),
            Icon(destination.icon,
                size: 16, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                destination.labelL10n(l10n),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupChoiceTile extends StatelessWidget {
  const _StartupChoiceTile({
    required this.destination,
    required this.isSelected,
    required this.onActivate,
  });

  final ShellDestination destination;
  final bool isSelected;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final p = context.teamPalette;
    return TvFocusable(
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? p.accent.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isSelected
                ? p.accent.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected
                  ? p.accent
                  : Colors.white.withOpacity(0.4),
            ),
            const SizedBox(width: 8),
            Icon(destination.icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.65)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                destination.labelL10n(l10n),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
