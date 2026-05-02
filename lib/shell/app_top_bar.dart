import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../account/account_overlay.dart';
import '../account/account_store.dart';
import '../data/clock_overlay_settings_store.dart';
import '../data/device_memory_channel.dart';
import '../data/live_hero_preview_audio_store.dart';
import '../l10n/app_localizations.dart';
import '../data/library_controller.dart';
import '../data/shell_search_store.dart';
import '../data/top_menu_store.dart';
import '../data/xtream_catalog_repository.dart';
import '../ui/clock/clock_face_view.dart';
import '../ui/focus/tv_focusable.dart';
import '../ui/live_tv/live_preview_channel.dart';
import '../ui/settings/tv_remote_char_pad_overlay.dart';
import '../ui/settings/tv_remote_keys.dart';
import 'shell_content_focus_registry.dart';
import 'shell_destination.dart';
import 'shell_navigation_hub.dart';
import '../theme/team_palette_theme.dart';

/// Live TV only: mute / unmute hero preview audio (same store as in-app hero).
class _LiveHeroMuteNavChip extends StatelessWidget {
  const _LiveHeroMuteNavChip({
    required this.focusNode,
    required this.onFocusedChange,
  });

  final FocusNode focusNode;
  final ValueChanged<bool> onFocusedChange;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: liveHeroPreviewAudioStore,
      builder: (context, _) {
        final a = context.teamPalette.accent;
        final pal = context.teamPalette;
        final muted = liveHeroPreviewAudioStore.muted;
        return TvFocusable(
          focusNode: focusNode,
          focusScale: 1.0,
          parallaxSlide: 0,
          showFocusElevation: false,
          focusPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          focusedBorderWidth: 0,
          focusBorderColor: pal.defaultFocusRingColor,
          onFocusedChange: onFocusedChange,
          onActivate: () async {
            await liveHeroPreviewAudioStore.toggleMuted();
            if (LivePreviewChannel.supported) {
              await LivePreviewChannel.setUserMuted(
                liveHeroPreviewAudioStore.muted,
              );
            }
          },
          onKeyIntercept: (node, event) {
            if (event is! KeyDownEvent) return null;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              ShellContentFocusRegistry.request(ShellDestination.liveTv);
              return KeyEventResult.handled;
            }
            return null;
          },
          child: Builder(
            builder: (context) {
              final focused = Focus.of(context).hasFocus;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: focused
                      ? const Color(0xFF181F2C)
                      : Colors.transparent,
                  border: Border.all(
                    color: focused
                        ? a.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: a.withValues(alpha: 0.14),
                            blurRadius: 0,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: muted
                        ? Colors.white.withValues(alpha: 0.72)
                        : a,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Account chip — opens the account overlay when activated.
class _AccountNavChip extends StatelessWidget {
  const _AccountNavChip();

  @override
  Widget build(BuildContext context) {
    final a = context.teamPalette.accent;
    final pal = context.teamPalette;
    return TvFocusable(
      focusScale: 1.0,
      parallaxSlide: 0,
      showFocusElevation: false,
      focusPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      focusedBorderWidth: 1.4,
      focusBorderColor: pal.defaultFocusRingColor,
      onActivate: () => AccountOverlay.show(context),
      onKeyIntercept: (node, event) {
        if (event is! KeyDownEvent) return null;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          ShellContentFocusRegistry.request(ShellDestination.liveTv);
          return KeyEventResult.handled;
        }
        return null;
      },
      child: ListenableBuilder(
        listenable: accountStore,
        builder: (context, _) {
          return SizedBox(
            height: 36,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_rounded,
                    color: accountStore.isLoggedIn
                        ? a.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.72),
                    size: 20,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Acc',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Top shell bar: text-style nav + [ClockFaceView] (always), trailing Search.
class AppTopBar extends StatefulWidget {
  const AppTopBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.navFocusByDestination,
    required this.liveHeroMuteNavFocus,
  });

  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;

  /// One focus node per top-bar destination (Back -> focus current section tab).
  final Map<ShellDestination, FocusNode> navFocusByDestination;

  /// Hero preview mute control (shown first in the nav row on Live TV only).
  final FocusNode liveHeroMuteNavFocus;

  static const double barHeight = 48;

  /// Reserved width for the clock column (kept tight so categories sit beside the clock).
  static const double clockLeadingReserveWidth = 96;

  /// Right inset for bar *content* (search, etc.): was shell 18 + 2.
  static const double barContentInsetRight = 20;

  /// Left inset for bar *content*: was shell 8 + 4.
  static const double barContentInsetLeft = 12;

  /// Space between the clock column and the first category (0 = flush against the clock slot).
  static const double navListLeadingAfterClock = 0.0;

  /// Horizontal gap **between** categories in the ListView (original was 6).
  static const double navCategoryGapBetweenItems = 4.0;

  /// Outer horizontal padding on each nav tab (was 8).
  static const double navTabOuterHorizontalPadding = 0;

  /// Inner horizontal padding around icon+label inside the glow (was 10).
  static const double navTabInnerHorizontalPadding = 12.0;

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  /// Horizontal scroll for many top destinations (tabs keep natural width).
  final ScrollController _navScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    topMenuStore.addListener(_onMenuChanged);
  }

  void _onMenuChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    topMenuStore.removeListener(_onMenuChanged);
    _navScrollController.dispose();
    super.dispose();
  }

  static void _ensureTabVisible(BuildContext tabContext) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!tabContext.mounted) return;
      Scrollable.ensureVisible(
        tabContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        // Keep focused tab in view for any index (incl. 7+); bias slightly left of center.
        alignment: 0.42,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final destinations = topMenuStore.fullMenu;
    final listLeadingPad = AppTopBar.navListLeadingAfterClock;
    final showLiveMute =
        widget.selected == ShellDestination.liveTv;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEB080B11),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1B2330)),
        ),
      ),
      foregroundDecoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x06FFFFFF), Colors.transparent],
          stops: [0.0, 0.7],
        ),
      ),
      child: SizedBox(
        height: AppTopBar.barHeight,
        child: FocusTraversalGroup(
          policy: _TopBarTraversalPolicy(),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppTopBar.barContentInsetLeft,
              right: AppTopBar.barContentInsetRight,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _TopBarLeadingClock(),
                Expanded(
                  child: ListView.builder(
                    controller: _navScrollController,
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.hardEdge,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: listLeadingPad,
                      right: AppTopBar.navCategoryGapBetweenItems,
                    ),
                    // Old Account entry chip has been removed from the top
                    // bar — the new "Account" rail tile inside New Settings
                    // is now the single entry point for account features.
                    // The [_AccountNavChip] widget and `AccountOverlay` file
                    // are kept on disk for a clean deletion pass later.
                    itemCount: (showLiveMute ? 1 : 0) + destinations.length,
                    itemBuilder: (context, i) {
                      if (showLiveMute && i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: AppTopBar.navCategoryGapBetweenItems,
                          ),
                          child: Builder(
                            builder: (tabContext) {
                              void onFocused(bool focused) {
                                if (focused) {
                                  _AppTopBarState._ensureTabVisible(tabContext);
                                }
                              }
                              return _LiveHeroMuteNavChip(
                                focusNode: widget.liveHeroMuteNavFocus,
                                onFocusedChange: onFocused,
                              );
                            },
                          ),
                        );
                      }
                      final destIndex = showLiveMute ? i - 1 : i;
                      final d = destinations[destIndex];
                      const flushToClock = false;
                      return Padding(
                        padding: EdgeInsets.only(
                          left: AppTopBar.navCategoryGapBetweenItems,
                        ),
                        child: Builder(
                          builder: (tabContext) {
                            void onFocused(bool focused) {
                              if (focused) {
                                _AppTopBarState._ensureTabVisible(tabContext);
                              }
                            }
                            return ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 78),
                              child: d == ShellDestination.playlist
                                  ? _PlaylistNavLink(
                                      l10n: l10n,
                                      focusNode:
                                          widget.navFocusByDestination[d]!,
                                      onFocusedChange: onFocused,
                                      flushToClock: flushToClock,
                                    )
                                  : _TopNavLink(
                                      l10n: l10n,
                                      destination: d,
                                      selected: widget.selected == d,
                                      onActivate: () => widget.onSelect(d),
                                      focusNode: widget.navFocusByDestination[d],
                                      onFocusedChange: onFocused,
                                      flushToClock: flushToClock,
                                    ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                Center(
                  child: ListenableBuilder(
                    listenable: shellSearchStore,
                    builder: (context, _) => _TrailingSearchPill(
                      l10n: l10n,
                      destination: widget.selected,
                      labelStyle: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clock tick isolated from [AppTopBar] so the nav row / search pill are not rebuilt every second.
class _TopBarLeadingClock extends StatefulWidget {
  const _TopBarLeadingClock();

  @override
  State<_TopBarLeadingClock> createState() => _TopBarLeadingClockState();
}

class _TopBarLeadingClockState extends State<_TopBarLeadingClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clockOverlaySettingsStore,
      builder: (context, _) {
        final a = context.teamPalette.accent;
        return SizedBox(
          width: AppTopBar.clockLeadingReserveWidth,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(a, Colors.white, 0.22)!,
                        a,
                        Color.lerp(a, Colors.black, 0.12)!,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: a.withValues(alpha: 0.22),
                        blurRadius: 12,
                        spreadRadius: -3,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'TV',
                      style: TextStyle(
                        color: Color(0xFF0A0D13),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TVMate',
                  style: TextStyle(
                    color: Color(0xFFEEF2F7),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Traversal policy that clamps at both ends — LEFT at the first item
/// and RIGHT at the last item stay put instead of escaping the group.
class _TopBarTraversalPolicy extends ReadingOrderTraversalPolicy {
  @override
  FocusNode? findFirstFocusInDirection(FocusNode currentNode, TraversalDirection direction) {
    return super.findFirstFocusInDirection(currentNode, direction);
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final sorted = sortDescendants(
      currentNode.nearestScope!.traversalDescendants,
      currentNode,
    ).toList();
    if (sorted.isEmpty) return false;

    if (direction == TraversalDirection.left) {
      if (currentNode == sorted.first) return true;
    } else if (direction == TraversalDirection.right) {
      if (currentNode == sorted.last) return true;
    }
    return super.inDirection(currentNode, direction);
  }
}

bool _topNavActivateKey(KeyDownEvent event) {
  final k = event.logicalKey;
  return k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.space ||
      k == LogicalKeyboardKey.numpadEnter;
}

class _TopNavLink extends StatelessWidget {
  const _TopNavLink({
    required this.l10n,
    required this.destination,
    required this.selected,
    required this.onActivate,
    this.focusNode,
    this.onFocusedChange,
    this.flushToClock = false,
  });

  final AppLocalizations l10n;
  final ShellDestination destination;
  final bool selected;
  final VoidCallback onActivate;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusedChange;
  /// When true, no left outer padding so the first tab sits flush after the clock.
  final bool flushToClock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusedChange,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_topNavActivateKey(event)) {
          onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          focusNode?.requestFocus();
          onActivate();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final a = context.teamPalette.accent;

          const defaultColor = Color(0xFF6F7889);
          const focusedColor = Color(0xFFA8B0BD);
          final accentColor = a;

          final Color fg;
          final Color bg;
          final Color borderColor;
          final List<BoxShadow> shadows;
          if (selected && focused) {
            fg = accentColor;
            bg = a.withValues(alpha: 0.14);
            borderColor = a.withValues(alpha: 0.5);
            shadows = [
              BoxShadow(
                color: a.withValues(alpha: 0.22),
                blurRadius: 18,
                spreadRadius: -6,
              ),
              BoxShadow(
                color: a.withValues(alpha: 0.14),
                blurRadius: 0,
                spreadRadius: 3,
              ),
            ];
          } else if (selected) {
            fg = accentColor;
            bg = a.withValues(alpha: 0.14);
            borderColor = a.withValues(alpha: 0.5);
            shadows = [
              BoxShadow(
                color: a.withValues(alpha: 0.22),
                blurRadius: 18,
                spreadRadius: -6,
              ),
            ];
          } else if (focused) {
            fg = focusedColor;
            bg = const Color(0xFF181F2C);
            borderColor = a.withValues(alpha: 0.5);
            shadows = [
              BoxShadow(
                color: a.withValues(alpha: 0.14),
                blurRadius: 0,
                spreadRadius: 3,
              ),
            ];
          } else {
            fg = defaultColor;
            bg = Colors.transparent;
            borderColor = Colors.transparent;
            shadows = const [];
          }

          final labelStyle = theme.textTheme.labelLarge?.copyWith(
            color: fg,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.06,
          );

          return Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: bg,
                border: Border.all(color: borderColor),
                boxShadow: shadows,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(destination.icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    destination.labelL10n(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          );
        },
      )),
      ),
    );
  }
}

/// Playlist quick-switcher button in the top bar. Opens a dropdown overlay
/// listing all playlists; selecting one activates it immediately.
class _PlaylistNavLink extends StatefulWidget {
  const _PlaylistNavLink({
    required this.l10n,
    required this.focusNode,
    this.onFocusedChange,
    this.flushToClock = false,
  });

  final AppLocalizations l10n;
  final FocusNode focusNode;
  final ValueChanged<bool>? onFocusedChange;
  final bool flushToClock;

  @override
  State<_PlaylistNavLink> createState() => _PlaylistNavLinkState();
}

class _PlaylistNavLinkState extends State<_PlaylistNavLink> {
  void _showPlaylistDropdown() {
    final context = this.context;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    Navigator.of(context).push<void>(
      _PlaylistDropdownRoute(
        l10n: widget.l10n,
        anchorRect: Rect.fromLTWH(
          offset.dx,
          offset.dy + size.height,
          size.width,
          0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: widget.onFocusedChange,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_topNavActivateKey(event)) {
          _showPlaylistDropdown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.focusNode.requestFocus();
          _showPlaylistDropdown();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          final a = context.teamPalette.accent;

          const defaultColor = Color(0xFF6F7889);
          const focusedColor = Color(0xFFA8B0BD);

          final Color fg;
          final Color bg;
          final Color borderColor;
          final List<BoxShadow> shadows;
          if (focused) {
            fg = focusedColor;
            bg = const Color(0xFF181F2C);
            borderColor = a.withValues(alpha: 0.5);
            shadows = [
              BoxShadow(
                color: a.withValues(alpha: 0.14),
                blurRadius: 0,
                spreadRadius: 3,
              ),
            ];
          } else {
            fg = defaultColor;
            bg = Colors.transparent;
            borderColor = Colors.transparent;
            shadows = const [];
          }

          final labelStyle = theme.textTheme.labelLarge?.copyWith(
            color: fg,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.06,
          );

          return Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: bg,
                border: Border.all(color: borderColor),
                boxShadow: shadows,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_play_rounded,
                      size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(widget.l10n.navPlaylist,
                      maxLines: 1, style: labelStyle),
                ],
              ),
            ),
          );
        },
      )),
      ),
    );
  }
}

class _PlaylistDropdownRoute extends PopupRoute<void> {
  _PlaylistDropdownRoute({required this.l10n, required this.anchorRect});

  final AppLocalizations l10n;
  final Rect anchorRect;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => l10n.playlistDismissBarrier;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: _PlaylistDropdownContent(
        l10n: l10n,
        anchorRect: anchorRect,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Same playlist quick-switcher as the top-bar **Playlist** tab (e.g. Settings when the tab is hidden).
void showPlaylistQuickSwitcher(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final mq = MediaQuery.of(context);
  const dropdownWidth = 280.0;
  final left = ((mq.size.width - dropdownWidth) / 2)
      .clamp(12.0, mq.size.width - dropdownWidth - 12);
  Navigator.of(context).push<void>(
    _PlaylistDropdownRoute(
      l10n: l10n,
      anchorRect: Rect.fromLTWH(left, 100, dropdownWidth, 0),
    ),
  );
}

class _PlaylistDropdownContent extends StatelessWidget {
  const _PlaylistDropdownContent({
    required this.l10n,
    required this.anchorRect,
    required this.onDismiss,
  });

  final AppLocalizations l10n;
  final Rect anchorRect;
  final VoidCallback onDismiss;

  Future<void> _switchPlaylist(BuildContext context, String id) async {
    onDismiss();
    await libraryController.setActivePlaylist(id);
    unawaited(xtreamCatalogRepository.syncFromLibrary(libraryController));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = context.teamPalette.accent;
    final p = context.teamPalette;
    final onShell = theme.colorScheme.onSurface;
    final playlists = libraryController.playlists;
    final activeId = libraryController.activePlaylistId;
    final screenWidth = MediaQuery.of(context).size.width;

    final accentColor = a;

    const dropdownWidth = 280.0;
    final left = anchorRect.left.clamp(12.0, screenWidth - dropdownWidth - 12);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: anchorRect.bottom + 6,
          width: dropdownWidth,
          child: Material(
            type: MaterialType.transparency,
            child: FocusTraversalGroup(
                child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: a.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: a.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: playlists.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.playlist_add_rounded,
                                size: 28,
                                color: onShell.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.playlistEmptyTitle,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: onShell.withValues(alpha: 0.88),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.playlistEmptySubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10.5,
                                  color: onShell.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TvFocusable(
                                autofocus: true,
                                onActivate: () {
                                  onDismiss();
                                  ShellNavigationHub.instance
                                      .goTo(ShellDestination.newSettings);
                                },
                                focusPadding: const EdgeInsets.all(3),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: a.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.playlistGoToSettings,
                                    style:
                                        theme.textTheme.labelLarge?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: onShell.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: playlists.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 2),
                          itemBuilder: (context, i) {
                            final pl = playlists[i];
                            final isActive = pl.id == activeId;
                            final stats = l10n.playlistStatsLine(
                              pl.liveCount,
                              pl.moviesCount,
                              pl.seriesCount,
                            );
                            return TvFocusable(
                              autofocus: i == 0,
                              onActivate: () {
                                if (isActive) {
                                  onDismiss();
                                } else {
                                  _switchPlaylist(context, pl.id);
                                }
                              },
                              focusPadding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isActive
                                      ? a.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: isActive
                                          ? accentColor
                                          : onShell.withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pl.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                              fontSize: 12,
                                              fontWeight: isActive
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isActive
                                                  ? onShell
                                                  : onShell
                                                      .withValues(alpha: 0.88),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            stats,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontSize: 9.5,
                                              color: onShell
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Titles/channels from the loaded catalog matching [query] (for search autocomplete).
List<String> _shellSearchAutocomplete(ShellDestination destination, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final repo = xtreamCatalogRepository;
  final candidates = <String>[];
  switch (destination) {
    case ShellDestination.movies:
    case ShellDestination.series:
      for (final m in repo.vodMoviesAll) {
        if (m.title.toLowerCase().contains(q)) candidates.add(m.title);
      }
      for (final s in repo.seriesAll) {
        if (s.title.toLowerCase().contains(q)) candidates.add(s.title);
      }
      break;
    case ShellDestination.liveTv:
    case ShellDestination.recording:
      for (final c in repo.liveChannelsAll) {
        if (c.name.toLowerCase().contains(q)) candidates.add(c.name);
      }
      break;
    default:
      break;
  }
  final seen = <String>{};
  final unique = <String>[];
  for (final t in candidates) {
    final trimmed = t.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) continue;
    unique.add(trimmed);
  }
  unique.sort((a, b) {
    final al = a.toLowerCase();
    final bl = b.toLowerCase();
    final ap = al.startsWith(q);
    final bp = bl.startsWith(q);
    if (ap != bp) return ap ? -1 : 1;
    return al.compareTo(bl);
  });
  const maxItems = 8;
  if (unique.length <= maxItems) return unique;
  return unique.sublist(0, maxItems);
}

class _ShellSearchDialog extends StatefulWidget {
  const _ShellSearchDialog({
    required this.controller,
    required this.destination,
    required this.searchTitle,
    required this.hintText,
    required this.clearLabel,
    required this.applyLabel,
  });

  final TextEditingController controller;
  final ShellDestination destination;
  final String searchTitle;
  final String hintText;
  final String clearLabel;
  final String applyLabel;

  @override
  State<_ShellSearchDialog> createState() => _ShellSearchDialogState();
}

class _ShellSearchDialogState extends State<_ShellSearchDialog>
    with WidgetsBindingObserver {
  static const int _kMaxSuggestionFocusNodes = 8;

  late final FocusNode _fieldFocus;
  late final FocusNode _clearFocus;
  late final FocusNode _applyFocus;
  late final List<FocusNode> _suggestionFocuses;

  bool _handleHardwareKey(KeyEvent event) {
    final inAppOnly = DeviceMemoryChannel.useInAppTextPadOnly;
    // Same as Add Playlist: D-pad OK opens in-app pad (system IME is unreliable on Chromecast).
    if (inAppOnly &&
        _fieldFocus.hasFocus &&
        tvRemoteIsActivate(event)) {
      unawaited(
        showTvRemoteCharPad(
          context,
          controller: widget.controller,
          fieldLabel: widget.hintText,
        ),
      );
      return true;
    }
    // While the IME is visible, D-pad must reach the on-screen keyboard (Chromecast, Shield, …).
    if (mounted &&
        DeviceMemoryChannel.imeLikelyOpenForTvTextInput(context)) {
      return false;
    }
    final suggestions = _shellSearchAutocomplete(
      widget.destination,
      widget.controller.text,
    );
    final n = suggestions.length > _kMaxSuggestionFocusNodes
        ? _kMaxSuggestionFocusNodes
        : suggestions.length;

    if (_fieldFocus.hasFocus) {
      if (tvRemoteIsDpadDown(event)) {
        if (n > 0) {
          _suggestionFocuses[0].requestFocus();
        } else {
          _clearFocus.requestFocus();
        }
        return true;
      }
      return false;
    }

    for (var i = 0; i < n; i++) {
      if (_suggestionFocuses[i].hasFocus) {
        if (tvRemoteIsDpadDown(event)) {
          if (i + 1 < n) {
            _suggestionFocuses[i + 1].requestFocus();
          } else {
            _clearFocus.requestFocus();
          }
          return true;
        }
        if (tvRemoteIsDpadUp(event)) {
          if (i > 0) {
            _suggestionFocuses[i - 1].requestFocus();
          } else {
            _fieldFocus.requestFocus();
          }
          return true;
        }
        return false;
      }
    }

    if (_clearFocus.hasFocus) {
      if (tvRemoteIsDpadRight(event)) {
        _applyFocus.requestFocus();
        return true;
      }
      if (tvRemoteIsDpadUp(event)) {
        if (n > 0) {
          _suggestionFocuses[n - 1].requestFocus();
        } else {
          _fieldFocus.requestFocus();
        }
        return true;
      }
      return false;
    }

    if (_applyFocus.hasFocus) {
      if (tvRemoteIsDpadLeft(event)) {
        _clearFocus.requestFocus();
        return true;
      }
      if (tvRemoteIsDpadUp(event)) {
        if (n > 0) {
          _suggestionFocuses[n - 1].requestFocus();
        } else {
          _fieldFocus.requestFocus();
        }
        return true;
      }
      return false;
    }

    return false;
  }

  void _onControllerChanged() => setState(() {});

  void _onSearchFieldFocusChange() {
    if (_fieldFocus.hasFocus && !DeviceMemoryChannel.useInAppTextPadOnly) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _fieldFocus.hasFocus &&
            !DeviceMemoryChannel.useInAppTextPadOnly) {
          DeviceMemoryChannel.requestShowSoftInput();
        }
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fieldFocus = FocusNode(debugLabel: 'shellSearchField');
    _fieldFocus.addListener(_onSearchFieldFocusChange);
    _clearFocus = FocusNode(debugLabel: 'shellSearchClear');
    _applyFocus = FocusNode(debugLabel: 'shellSearchApply');
    _suggestionFocuses = List.generate(
      _kMaxSuggestionFocusNodes,
      (i) => FocusNode(debugLabel: 'shellSearchSug$i'),
    );
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    widget.controller.removeListener(_onControllerChanged);
    _fieldFocus.removeListener(_onSearchFieldFocusChange);
    _fieldFocus.dispose();
    _clearFocus.dispose();
    _applyFocus.dispose();
    for (final n in _suggestionFocuses) {
      n.dispose();
    }
    super.dispose();
  }

  void _popWith(String? value) {
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = context.teamPalette.accent;
    final l10n = AppLocalizations.of(context)!;
    final inAppOnly = DeviceMemoryChannel.useInAppTextPadOnly;
    final suggestions = _shellSearchAutocomplete(
      widget.destination,
      widget.controller.text,
    );
    final n = suggestions.length > _kMaxSuggestionFocusNodes
        ? _kMaxSuggestionFocusNodes
        : suggestions.length;

    return AlertDialog(
      title: Text(widget.searchTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (inAppOnly) ...[
              TvFocusable(
                onActivate: () {
                  unawaited(
                    showTvRemoteCharPad(
                      context,
                      controller: widget.controller,
                      fieldLabel: widget.hintText,
                    ),
                  );
                },
                focusPadding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.tvRemoteTypingButton,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: a.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: a.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.tvRemoteGoogleTvKeyboardHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.55),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            TextField(
              controller: widget.controller,
              focusNode: _fieldFocus,
              autofocus: true,
              readOnly: inAppOnly,
              keyboardType:
                  inAppOnly ? TextInputType.none : TextInputType.text,
              textInputAction: TextInputAction.search,
              onTap: inAppOnly
                  ? () {
                      unawaited(
                        showTvRemoteCharPad(
                          context,
                          controller: widget.controller,
                          fieldLabel: widget.hintText,
                        ),
                      );
                    }
                  : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
              ),
              onSubmitted: _popWith,
            ),
            if (n > 0) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: n,
                  itemBuilder: (context, i) {
                    final title = suggestions[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: TvFocusable(
                        focusNode: _suggestionFocuses[i],
                        onActivate: () => _popWith(title),
                        focusPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        showFocusElevation: false,
                        focusedBorderWidth: 1.6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TvFocusable(
                    focusNode: _clearFocus,
                    onActivate: () => _popWith(''),
                    focusPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Center(
                      child: Text(
                        widget.clearLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TvFocusable(
                    focusNode: _applyFocus,
                    onActivate: () => _popWith(widget.controller.text),
                    focusPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Center(
                      child: Text(
                        widget.applyLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: a,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailingSearchPill extends StatelessWidget {
  const _TrailingSearchPill({
    required this.l10n,
    required this.destination,
    this.labelStyle,
  });

  final AppLocalizations l10n;
  final ShellDestination destination;
  final TextStyle? labelStyle;

  bool get _searchSupported =>
      destination == ShellDestination.liveTv ||
      destination == ShellDestination.movies ||
      destination == ShellDestination.series ||
      destination == ShellDestination.recording;

  Future<void> _openSearchDialog(BuildContext context) async {
    if (!_searchSupported) return;
    final initial = shellSearchStore.queryFor(destination);
    final controller = TextEditingController(text: initial);
    final loc = l10n;
    final searchTitle = destination == ShellDestination.movies ||
            destination == ShellDestination.series
        ? loc.searchMoviesAndSeries
        : switch (destination) {
            ShellDestination.liveTv => loc.searchLiveTv,
            ShellDestination.recording => loc.searchRecording,
            _ => loc.searchLabel,
          };
    final submitted = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ShellSearchDialog(
        controller: controller,
        destination: destination,
        searchTitle: searchTitle,
        hintText: loc.searchHint,
        clearLabel: loc.searchClear,
        applyLabel: loc.searchApply,
      ),
    );
    controller.dispose();
    if (submitted == null) return;
    shellSearchStore.setQuery(destination, submitted);
  }

  @override
  Widget build(BuildContext context) {
    final a = context.teamPalette.accent;
    final activeQuery = shellSearchStore.queryFor(destination);
    final hasQuery = activeQuery.isNotEmpty;
    final enabled = _searchSupported;
    final queryPreview = hasQuery && activeQuery.length > 18
        ? '${activeQuery.substring(0, 18)}...'
        : activeQuery;
    final style = labelStyle?.copyWith(
      color: enabled
          ? Colors.white.withOpacity(0.88)
          : Colors.white.withOpacity(0.45),
      fontSize: 12,
      fontWeight: hasQuery ? FontWeight.w800 : FontWeight.w600,
    );

    return TvFocusable(
      canRequestFocus: enabled,
      onActivate: () => _openSearchDialog(context),
      showFocusElevation: false,
      focusPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: hasQuery
              ? a.withValues(alpha: 0.14)
              : const Color(0xFF0D1119),
          border: Border.all(
            color: hasQuery
                ? a.withValues(alpha: 0.5)
                : const Color(0xFF1B2330),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: enabled
                  ? Colors.white.withOpacity(0.85)
                  : Colors.white.withOpacity(0.45),
            ),
            const SizedBox(width: 6),
            Text(
              hasQuery
                  ? l10n.searchPrefixWithQuery(queryPreview)
                  : l10n.searchLabel,
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
