/// New settings surface — phase 1.
///
/// A 1:1 Flutter port of the two-pane shell from `settings.html` (the PC
/// design preview at the repo root). Phase 1 ships:
///
///   * a `ShellDestination.newSettings` top-menu tab (labeled **Settings**)
///     as the main settings entry; the legacy settings screen is reached from
///     the rail (see [kNsCats] `oldSettings`),
///   * the persistent shell top menu is **always visible** above this
///     surface — sub-page navigation happens entirely inside the internal
///     state stack, never via `Navigator.push`,
///   * the header row (brand + search + palette button) from the HTML,
///   * the full left rail of categories populated from [kNsCats],
///   * full rendering of the **Playback** category (3 rows — performance
///     mode, lightning switch, default subtitle language) with working
///     toggles and choice sheets,
///   * a "Coming next" placeholder for every other category and every
///     sub-page referenced by a `kind: page` row.
///
/// **TV navigation contract (scoped to this tab only)** — predictable D-pad:
///
///   * **OK / SELECT** is the **only** action that changes which category’s
///     content is **active** (loaded on the right). Moving **UP/DOWN** on
///     the rail changes **focus / highlight** only.
///   * **RIGHT** always enters the detail pane of the **currently active**
///     category (never the merely highlighted row).
///   * **LEFT** returns focus from the detail pane to the categories rail
///     **only** from the **root** of that page at the **left edge** — not
///     from deeper internal pages / stacks.
///   * **BACK** is strictly stepwise: pop one level on the internal stack
///     when deep; from the category’s **main** page, move focus to the
///     categories rail; **only** when focus is **already on the rail** may
///     Back surface the top menu — and the shell must focus the **New
///     Setting** tab, not Home. Back must **not** jump to the top menu from
///     anywhere else in this surface.
///
/// State is fully local to this screen (see [NewSettingsState]) — none of
/// the real app stores are read or written.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/parental_control_store.dart';
import '../../data/stored_playlist.dart';
import '../../shell/shell_back_coordinator.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../shell/shell_destination.dart';
import 'new_settings_data.dart';
import 'new_settings_density.dart';
import 'new_settings_palette.dart';
import 'new_settings_state.dart';
import 'new_settings_theme.dart';
import 'pages/account_page.dart';
import 'pages/add_playlist_page.dart';
import 'pages/appearance_page.dart';
import 'pages/backup_page.dart';
import 'pages/category_page.dart';
import 'pages/channels_categories_page.dart';
import 'pages/channels_list_page.dart';
import 'pages/clock_page.dart';
import 'pages/favorites_editor_page.dart';
import 'pages/favorites_page.dart';
import 'pages/group_section_page.dart';
import 'pages/groups_page.dart';
import 'pages/pin_page.dart';
import 'pages/placeholder_page.dart';
import 'pages/playlist_detail_page.dart';
import '../settings/parental_pin_dialog.dart';
import '../settings/settings_screen.dart';
import 'pages/playlists_page.dart';
import 'pages/recording_categories_page.dart';
import 'pages/recording_channels_page.dart';
import 'pages/rules_page.dart';
import 'pages/top_menu_page.dart';
import 'widgets/ns_chrome.dart';
import 'widgets/ns_clock_overlay.dart';
import 'widgets/ns_confirm_dialog.dart';
import 'widgets/ns_focusable.dart';
import 'widgets/ns_new_settings_nav.dart';
import 'widgets/ns_new_settings_root_left.dart';
import 'widgets/ns_settings_backdrop.dart';

class NewSettingsScreen extends StatefulWidget {
  const NewSettingsScreen({super.key});

  @override
  State<NewSettingsScreen> createState() => _NewSettingsScreenState();
}

class _NewSettingsScreenState extends State<NewSettingsScreen> {
  late final NewSettingsState _state;
  late final TextEditingController _searchCtrl;
  late final FocusNode _shellPrimaryFocus;
  late final FocusNode _searchFocus;

  /// One focus node per rail tile — indexed by category id — so the shell's
  /// top-menu → body focus handoff can land on the currently-selected rail
  /// entry, and the category page itself can shift focus back to the rail
  /// without recreating nodes on every rebuild.
  late final Map<String, FocusNode> _railFocus;

  /// Focus node for the Account tile in the rail (below the Categories
  /// list). Kept separate because the Account tile isn't part of
  /// [kNsCats] — it has its own rail section.
  late final FocusNode _accountRailFocus;

  /// One focus node per category id — claimed by the first focusable
  /// row in that category's content page (e.g. "Performance mode" in
  /// Playback, "Team" in Look & Feel). The rail uses this to hand focus
  /// off to the detail pane when a tile is activated so the user lands
  /// on the first option instead of staying on the rail tile.
  ///
  /// Keyed by category id rather than per-row so the node survives page
  /// rebuilds and can be re-bound by each category page's first
  /// focusable primitive.
  late final Map<String, FocusNode> _categoryFirstFocus;

  /// One focus node per playlist card's **Manage** button — owned by
  /// the screen so back-from-detail restores focus to the correct
  /// card's primary CTA (the Manage button is the visible "entry
  /// point" to detail, exactly matching the HTML's click-to-open
  /// behaviour).
  final Map<String, FocusNode> _playlistManageFocus = {};

  /// Tracked to detect sub-page pushes (vs pops / same-len updates) so
  /// the focus-reset listener only fires when a NEW page appears.
  int _lastStackLen = 0;

  /// Pinned to the categories rail for [newSettingsRootLeftFromNsFocusable].
  final GlobalKey _categoriesRailKey = GlobalKey();

  /// Account page: the Profile / Subscription / Devices / Downloads row.
  final GlobalKey _accountTabStripKey = GlobalKey();

  /// Account page: tab **body** only (below the strip) — for the Back ladder.
  final GlobalKey _accountPostTabsKey = GlobalKey();

  /// Child of the detail [Focus] ([_detailScope]) so [_onStackChangePush] can
  /// call [FocusScope.of] on a context **under** the detail pane. Using
  /// [State.context] instead resolves a scope that also contains the shell
  /// [AppTopBar] — [nextFocus] then lands on **Live TV** (first top tab).
  final GlobalKey _detailTraversalKey = GlobalKey();

  /// The detail pane (right column) — rail lives **outside** this scope so
  /// D-pad Left moves within the main body first; only at the in-scope left
  /// edge does the global [NsFocusable] handler hand off to the active rail.
  final FocusScopeNode _detailScope =
      FocusScopeNode(debugLabel: 'newSettings:detailPane');

  /// First list card on Favorites (or empty-state CTA) for rail → content.
  final FocusNode _favoritesFirstContentFocus =
      FocusNode(debugLabel: 'newSettings:favoritesFirstContent');

  /// Profile tab pill on [NsAccountPage] — same pattern as other categories:
  /// rail **Right** / activate calls [_focusActiveCategoryFirstRow], which
  /// must move here (the in-page [initState] post-frame could not win over
  /// [ShellContentFocusRegistry] / rail focus on first entry).
  final FocusNode _accountProfileTabFocus =
      FocusNode(debugLabel: 'newSettings:accountProfileTab');

  final FocusNode _accountSubscriptionTabFocus =
      FocusNode(debugLabel: 'newSettings:accountSubscriptionTab');

  final FocusNode _accountDevicesTabFocus =
      FocusNode(debugLabel: 'newSettings:accountDevicesTab');

  final FocusNode _accountDownloadsTabFocus =
      FocusNode(debugLabel: 'newSettings:accountDownloadsTab');

  /// Floating real-clock overlay, inserted into the root Navigator's
  /// [Overlay] so it paints over the whole app — above the shell's
  /// top-menu tab row, above my own header, above everything. Mirrors
  /// the HTML's `position: fixed` `#realClock` element. Registered once
  /// after the first frame (when an Overlay ancestor exists in context)
  /// and torn down on dispose so the clock never outlives this tab.
  OverlayEntry? _clockOverlayEntry;

  @override
  void initState() {
    super.initState();
    _state = NewSettingsState();
    _searchCtrl = TextEditingController();
    _searchCtrl.addListener(() => _state.search = _searchCtrl.text);
    _shellPrimaryFocus = FocusNode(debugLabel: 'newSettings:shellPrimary');
    _searchFocus = FocusNode(debugLabel: 'newSettings:search');
    _railFocus = {
      for (final c in kNsCats)
        c.id: FocusNode(debugLabel: 'newSettings:rail:${c.id}'),
    };
    _accountRailFocus =
        FocusNode(debugLabel: 'newSettings:rail:account');
    _categoryFirstFocus = {
      for (final c in kNsCats)
        c.id: FocusNode(debugLabel: 'newSettings:firstRow:${c.id}'),
    };
    ShellContentFocusRegistry.register(
      ShellDestination.newSettings,
      _requestShellPrimaryFocus,
    );
    // Two-step Back — our screen can consume Back before the shell-level
    // handler escalates focus to the top-menu tab row. See
    // `_consumeDetailBack` for the priority ladder.
    ShellBackCoordinator.register(this, _consumeDetailBack);
    // Keep card-focus map in sync with the live playlist list.
    _state.addListener(_pruneManageFocus);
    // Whenever a new sub-page is pushed, clear the primary focus so
    // the disposed button (Manage / tile / chip) doesn't linger as
    // stale focus and force the framework to fall back to the
    // header search field. The new page's `NsSubPageHead` back
    // button (autofocus: true) can then cleanly claim focus.
    _state.addListener(_onStackChangePush);
    // Defer overlay insertion to after first frame — this is when our
    // Overlay ancestor is guaranteed to exist in the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final entry = OverlayEntry(
        builder: (context) => Positioned.fill(
          child: IgnorePointer(
            // Stack wrapper lets [NsRealClockOverlay]'s inner Positioned
            // anchor to the full-screen rect — and anything wanting to
            // paint over the clock (dialogs/modals) lands later in the
            // overlay entry list, still on top.
            child: Stack(
              children: [NsRealClockOverlay(state: _state)],
            ),
          ),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(entry);
      _clockOverlayEntry = entry;
    });
  }

  @override
  void dispose() {
    _clockOverlayEntry?.remove();
    _clockOverlayEntry = null;
    ShellContentFocusRegistry.unregister(ShellDestination.newSettings);
    ShellBackCoordinator.unregister(this);
    _state.removeListener(_pruneManageFocus);
    _state.removeListener(_onStackChangePush);
    _shellPrimaryFocus.dispose();
    _searchFocus.dispose();
    for (final n in _railFocus.values) {
      n.dispose();
    }
    _accountRailFocus.dispose();
    for (final n in _categoryFirstFocus.values) {
      n.dispose();
    }
    for (final n in _playlistManageFocus.values) {
      n.dispose();
    }
    _favoritesFirstContentFocus.dispose();
    _accountProfileTabFocus.dispose();
    _accountSubscriptionTabFocus.dispose();
    _accountDevicesTabFocus.dispose();
    _accountDownloadsTabFocus.dispose();
    _detailScope.dispose();
    _searchCtrl.dispose();
    _state.dispose();
    super.dispose();
  }

  FocusNode _playlistManageNode(String id) {
    return _playlistManageFocus.putIfAbsent(
      id,
      () => FocusNode(debugLabel: 'ns:playlistManage:$id'),
    );
  }

  /// Detect sub-page pushes and clear stale primary focus, then advance
  /// focus into the newly-mounted sub-page. Without the clear, the
  /// focusable that just triggered the push (Manage, Rename, a tile…)
  /// gets disposed with the old page and Flutter's focus manager hunts
  /// for a fallback — which used to land on the header search field.
  ///
  /// The post-frame `nextFocus()` pairs with every sub-page's Back
  /// button opting out of traversal via `skipTraversal: true`, so the
  /// next traversable focusable is the first content row of the new
  /// page (rule 4 of the navigation rulebook).
  void _onStackChangePush() {
    final newLen = _state.stack.length;
    if (newLen > _lastStackLen) {
      FocusManager.instance.primaryFocus?.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Give the new page one extra frame to mount its focusables,
        // then advance. Without this delay `nextFocus()` occasionally
        // fires before the new tree's Focus nodes are attached.
        Future.delayed(const Duration(milliseconds: 16), () {
          if (!mounted) return;
          final detailCtx = _detailTraversalKey.currentContext;
          if (detailCtx != null && detailCtx.mounted) {
            FocusScope.of(detailCtx).nextFocus();
          }
        });
      });
    }
    _lastStackLen = newLen;
  }

  /// Garbage-collect stale Manage-button focus nodes after a delete.
  void _pruneManageFocus() {
    final ids = _state.playlists.map((p) => p.id).toSet();
    final stale = _playlistManageFocus.keys
        .where((id) => !ids.contains(id))
        .toList();
    for (final id in stale) {
      _playlistManageFocus.remove(id)?.dispose();
    }
  }

  /// When the shell hands focus off to this tab, route it to the
  /// currently-active rail tile (Account by default). Mirrors the
  /// main-app rule: entry lands on whichever rail item is marked
  /// selected, and the blue side bar follows the same rule.
  void _requestShellPrimaryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _railFocusFor(_state.active);
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
      } else if (_shellPrimaryFocus.canRequestFocus) {
        _shellPrimaryFocus.requestFocus();
      }
    });
  }

  /// Return the rail focus node for the given rail id (`'account'` or
  /// any `kNsCats.id`). A single lookup path so Account and categories
  /// are treated identically.
  FocusNode? _railFocusFor(String id) {
    if (id == 'account') return _accountRailFocus;
    return _railFocus[id];
  }

  /// **Left** on root main content at the in-cell left edge, or
  /// [NsNewSettingsNav.onLeftFromRootMainToRail].
  void _requestActiveRailFocus() {
    final n = _railFocusFor(_state.active);
    if (n != null && n.canRequestFocus) {
      n.requestFocus();
    }
  }

  void _focusActiveAccountTab() {
    final t = _state.account.tab;
    final FocusNode n;
    if (t == 'subscription') {
      n = _accountSubscriptionTabFocus;
    } else if (t == 'devices') {
      n = _accountDevicesTabFocus;
    } else if (t == 'downloads') {
      n = _accountDownloadsTabFocus;
    } else {
      n = _accountProfileTabFocus;
    }
    if (n.canRequestFocus) n.requestFocus();
  }

  /// Focus the first meaningful content item in the detail pane for the
  /// currently-active category. Called when the user *activates* a rail
  /// tile (Enter/Select) so focus moves off the rail and into the first
  /// row — rule 2 of the navigation rulebook.
  ///
  /// Account, Playlists, and Favorites use screen-owned [FocusNode]s so
  /// rail **Right** / tile activate can [requestFocus] reliably (Account
  /// is not in [_categoryFirstFocus]).
  void _focusActiveCategoryFirstRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 16), () {
        if (!mounted) return;
        final active = _state.active;
        FocusNode? target;
        if (active == 'account') {
          target = _accountProfileTabFocus;
        } else
        if (active == 'playlists') {
          final pls = _state.playlists;
          if (pls.isNotEmpty) {
            // First card's Manage button (the primary CTA on each card).
            target = _playlistManageNode(pls.first.id);
          }
          // When empty, the `Add playlist` CTA autofocuses itself on
          // mount via `_EmptyState(autofocus: true)` — nothing to do.
        } else if (active == 'favorites') {
          // Landing page — same contract as Playlists: first card or empty CTA.
          target = _favoritesFirstContentFocus;
        } else {
          // Row-based categories (Playback, Look & Feel, …) use the
          // first row's NsFocusable node bound through [NsCategoryPage].
          target = _categoryFirstFocus[active];
        }
        if (target != null && target.canRequestFocus) {
          target.requestFocus();
        }
      });
    });
  }

  // ── Navigation / action handlers ────────────────────────────────────

  void _openPage(String pageId) {
    // Phase 1: every `kind: page` row lands on the placeholder. Real
    // sub-page renderers are added in phase 3+. We still push on to the
    // internal stack so breadcrumb + Back behaviour are exercised.
    _state.pushPage(
      NsStackEntry(
        page: pageId,
        title: _titleForPage(pageId),
      ),
    );
  }

  Future<void> _fireAction(String actionId) async {
    // Every action row in the HTML is destructive (reset-all, clear-pin) —
    // port the same "confirm before running" flow via a shared dark dialog
    // so the port matches the HTML's modal pattern exactly.
    switch (actionId) {
      case 'openOldSettings':
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SettingsScreen(registerShellFocus: false),
          ),
        );
        return;
      case 'resetAll':
        final r = await showNsConfirmDialog(
          context,
          title: 'Reset all settings?',
          message:
              'Restore every setting in this preview to its factory default. '
              'Choice picks, toggles and the open option sheet will all be '
              'cleared. This cannot be undone.',
          confirmLabel: 'Reset',
          isDanger: true,
        );
        if (r == NsConfirmResult.confirmed && mounted) {
          _state.batch(() {
            _state.clearAllValues();
            _state.collapse();
            _state.clearStack();
          });
        }
        return;
      case 'clearAll':
        final r = await showNsConfirmDialog(
          context,
          title: 'Clear PIN & rules?',
          message:
              'Wipes the parental PIN and every restriction rule. This '
              'cannot be undone.',
          confirmLabel: 'Clear',
          isDanger: true,
        );
        if (r != NsConfirmResult.confirmed || !mounted) return;
        final ok = await showParentalPinVerifyDialog(context);
        if (ok && mounted) {
          await parentalControlStore.clearPinAndRules();
        }
        return;
    }
  }

  String _titleForPage(String pageId) {
    return switch (pageId) {
      'appearance' => 'Appearance',
      'topmenu' => 'Top menu items & order',
      'clock' => 'Clock overlay',
      'playlists' => 'Playlists',
      'favorites' => 'Favorites',
      'rules' => 'Restricted rules',
      'pin' => 'PIN code',
      'backup' => 'Backup & restore',
      _ => pageId,
    };
  }

  /// Two-step Back ladder (registered with [ShellBackCoordinator]):
  ///
  ///   1. An open choice-sheet / inline dropdown → close it.
  ///   2. A sub-page on the stack → pop one, and (for playlist detail)
  ///      restore focus to the Manage button on the card that opened it.
  ///   3. Focus is somewhere in the detail pane but NOT on a rail tile
  ///      yet → move focus to the active rail tile.
  ///   4. Focus is already on a rail tile → **don't consume**; return
  ///      false so the shell's handler escalates to the top-menu.
  ///
  /// Returns true if Back was consumed; false to let the shell handle it.
  bool _consumeDetailBack() {
    if (_state.expanded != null) {
      _state.collapse();
      return true;
    }
    if (_state.stack.isNotEmpty) {
      final poppingFrom = _state.stack.last.page;
      _state.popPage();
      // After popping a playlist detail, restore focus to the card the
      // user opened — prevents back from kicking them out to the rail.
      if (poppingFrom == 'playlistDetail' &&
          _state.activePlaylistId != null) {
        final node = _playlistManageFocus[_state.activePlaylistId!];
        if (node != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (node.canRequestFocus) node.requestFocus();
          });
        }
      }
      // After popping the Add Playlist wizard the user expects focus
      // to land on the rail category tile — the wizard lives inside
      // Playlists, so Back out of it should surface the Playlists
      // tab, not the grid. One more Back will then escalate to the
      // top-menu via the rail-focused branch below.
      if (poppingFrom == 'addPlaylist') {
        final railNode = _railFocusFor(_state.active);
        if (railNode != null && railNode.canRequestFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            railNode.requestFocus();
          });
        }
      }
      return true;
    }
    // No stack entries. Is focus on the rail already? If so, don't
    // consume — let the shell escalate Back to the top-menu tab row.
    // Uses the unified `_railFocusFor` lookup so Account (id 'account')
    // is treated the same as any category.
    final railNode = _railFocusFor(_state.active);
    final railAlreadyFocused = railNode?.hasFocus ?? false;
    if (railAlreadyFocused) return false;

    // Account: first Back from the tab **body** (duration row, plans,
    // profile form…) → focus the **active** tab pill, not the categories
    // rail — that felt like "dropping out" of the page.
    if (_state.active == 'account' && _state.stack.isEmpty) {
      final primary = FocusManager.instance.primaryFocus;
      final ctx = primary?.context;
      final postTabs = _accountPostTabsKey.currentContext;
      final tabStrip = _accountTabStripKey.currentContext;
      if (ctx != null && postTabs != null && tabStrip != null) {
        final onTabStrip =
            nsContextIsDescendantOrSelf(ctx, tabStrip);
        final inPostTabs =
            nsContextIsDescendantOrSelf(ctx, postTabs);
        if (inPostTabs && !onTabStrip) {
          _focusActiveAccountTab();
          return true;
        }
      }
    }

    if (railNode != null && railNode.canRequestFocus) {
      railNode.requestFocus();
      return true;
    }
    return false;
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // [Theme] override wraps the entire new settings surface so every
    // descendant that reads `context.teamPalette` (directly or via a
    // shared widget) sees the HTML-cyan [NsIslandPalette] — not the
    // user's currently-active team. This is the "sealed island"
    // guarantee: switch team from yellow to purple to green in the rest
    // of the app, and New Setting still paints the cyan reference look.
    return Theme(
      data: nsIslandThemeData(context),
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= NsSizes.wideBreakpoint;
              final railOk = _state.stack.isEmpty && _state.expanded == null;
              final activeRail = _railFocusFor(_state.active) ?? _accountRailFocus;
              return NsNewSettingsNav(
                railCanRequestFocus: railOk,
                activeRailFocus: activeRail,
                onLeftFromRootMainToRail: _requestActiveRailFocus,
                categoriesRailKey: _categoriesRailKey,
                detailPaneScope: _detailScope,
                child: NsSettingsBackdrop(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: wide ? _buildWide() : _buildNarrow(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _buildCrumb() {
    final cat = nsCategoryById(_state.active);
    if (cat == null) return '';
    if (_state.stack.isEmpty) return cat.title;
    return '${cat.title} › ${_state.stack.last.title}';
  }

  /// Pick the header variant per platform:
  ///
  ///   * Android — no search, no Ctrl+K. A HTML-faithful user chip on the
  ///     right opens the Account sub-page (same entry point as the rail
  ///     Account tile). Help + notifications icons sit next to it.
  ///   * Windows / macOS / Linux / web — unchanged desktop header with the
  ///     search field + Ctrl+K palette button.
  Widget _buildHeader() {
    if (!nsUseAndroidHeader) {
      return NsHeaderRow(
        searchController: _searchCtrl,
        searchFocusNode: _searchFocus,
        crumb: _buildCrumb(),
      );
    }
    final acc = _state.account.data;
    // Role pill mirrors the HTML's `John D. · Pro` / guest variants.
    final role = !acc.isLoggedIn
        ? 'Guest'
        : (acc.isTrial ? 'Trial' : 'Pro');
    final initials = acc.isLoggedIn ? acc.initials : 'G';
    final name = acc.isLoggedIn ? acc.name : 'Guest';
    return NsHeaderRow.android(
      crumb: _buildCrumb(),
      accountInitials: initials,
      accountName: name,
      accountRole: role,
      // Tapping the header user-chip switches to the top-level Account
      // rail tile — same code path as activating the tile directly.
      onOpenAccount: () => _activateRailTile('account'),
    );
  }

  // ── Wide layout (TV / tablet / landscape phone) ─────────────────────

  Widget _buildWide() {
    // Rail is content-driven: `IntrinsicWidth` sizes it to the widest tile's
    // natural width (icon + label + meta + padding), clamped between a
    // min (so the "CATEGORIES" label / future Account tile don't collapse)
    // and a max (so a very long future category label can't blow out the
    // whole rail). Meta pills still flush-right because tiles stretch to
    // the shared intrinsic width and each tile uses `Expanded(label)` to
    // push the pill to the right edge.
    // Focus accent scope wraps the entire body (rail + detail pane) —
    // matches the "Rail 1b" treatment from the approved preview where
    // rail tiles also show the cyan accent bar on focus. Scope stays
    // inside the new-settings screen so nothing leaks to the rest of
    // the app.
    return NsFocusAccentScope(
      enabled: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 180,
              maxWidth: 320,
            ),
            child: IntrinsicWidth(
              child: Container(
                decoration: const BoxDecoration(
                  color: NsColors.bg2,
                  border: Border(right: BorderSide(color: NsColors.line)),
                ),
                child: _buildRail(vertical: true),
              ),
            ),
          ),
          Expanded(child: _buildDetailPane()),
        ],
      ),
    );
  }

  // ── Narrow layout (phone portrait) ──────────────────────────────────

  Widget _buildNarrow() {
    return NsFocusAccentScope(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 60,
            child: Container(
              decoration: const BoxDecoration(
                color: NsColors.bg2,
                border: Border(bottom: BorderSide(color: NsColors.line)),
              ),
              child: _buildRail(vertical: false),
            ),
          ),
          Expanded(child: _buildDetailPane()),
        ],
      ),
    );
  }

  // ── Rail ────────────────────────────────────────────────────────────

  Widget _buildRail({required bool vertical}) {
    final d = NsDensity.of(context);
    final l10n = AppLocalizations.of(context);
    final railFocusOk =
        NsNewSettingsNav.maybeOf(context)?.railCanRequestFocus ?? true;
    final account = _state.account.data;
    final accStatus = !account.isLoggedIn
        ? 'GUEST'
        : (account.isTrial ? 'TRIAL' : account.role.toUpperCase());
    // Single selection rule — Account and every category are treated
    // the same way: a tile is selected iff its id matches `active`.
    // Only one rail tile can ever be blue at a time.
    final active = _state.active;
    // Rail order (vertical layout):
    //
    //   ACCOUNT  ← label
    //   [Account tile]
    //   ────────── (divider)
    //   CATEGORIES  ← label
    //   [Playback] [Look & Feel] [Playlists] …
    //
    // Same tiles / styling as before, just reordered so Account sits at
    // the top of the rail (above Categories).
    final tiles = <Widget>[
      if (vertical) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            d.railTopSectionTopPad,
            14,
            d.railTopSectionBottomPad,
          ),
          child: Text(
            'ACCOUNT',
            style: NsType.railSection.copyWith(
              fontSize: d.sectionLabelSize,
            ),
          ),
        ),
        NsRailTile(
          icon: Icons.person_rounded,
          label: account.isLoggedIn ? account.name : 'Account',
          meta: accStatus,
          selected: active == 'account',
          focusNode: _accountRailFocus,
          canRequestFocus: railFocusOk,
          onActivate: () => _activateRailTile('account'),
          onKeyIntercept: (node, event) =>
              _railKeyIntercept(node, event, vertical: vertical),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Container(
            height: 1,
            color: NsColors.line,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Text(
            'CATEGORIES',
            style: NsType.railSection.copyWith(
              fontSize: d.sectionLabelSize,
            ),
          ),
        ),
      ],
      for (final c in kNsCats)
        NsRailTile(
          icon: c.icon,
          label: c.id == 'oldSettings' ? l10n.nsCategoryOldSettings : c.title,
          meta: c.metaFn?.call(_state).toString(),
          selected: active == c.id,
          focusNode: _railFocus[c.id],
          canRequestFocus: railFocusOk,
          onActivate: () => _activateRailTile(c.id),
          onKeyIntercept: (node, event) =>
              _railKeyIntercept(node, event, vertical: vertical),
        ),
    ];

    if (vertical) {
      return KeyedSubtree(
        key: _categoriesRailKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: d.railBottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: tiles,
          ),
        ),
      );
    }
    return KeyedSubtree(
      key: _categoriesRailKey,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
        // Account tile at the START of the horizontal rail — matches the
        // vertical layout's "Account above Categories" order.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: NsRailTile(
              icon: Icons.person_rounded,
              label: account.isLoggedIn ? account.name : 'Account',
              meta: accStatus,
              selected: active == 'account',
              focusNode: _accountRailFocus,
              canRequestFocus: railFocusOk,
              onActivate: () => _activateRailTile('account'),
              onKeyIntercept: (node, event) =>
                  _railKeyIntercept(node, event, vertical: false),
            ),
          ),
        ),
        for (final c in kNsCats)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160),
              child: NsRailTile(
                icon: c.icon,
                label: c.id == 'oldSettings' ? l10n.nsCategoryOldSettings : c.title,
                meta: c.metaFn?.call(_state).toString(),
                selected: active == c.id,
                focusNode: _railFocus[c.id],
                canRequestFocus: railFocusOk,
                onActivate: () => _activateRailTile(c.id),
                onKeyIntercept: (node, event) =>
                    _railKeyIntercept(node, event, vertical: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Invoked when any rail tile is activated (Enter/Select/click).
  /// Uniform treatment for Account and all categories: switch the
  /// active rail id, clear any lingering sub-page stack, and hand
  /// focus off to the detail pane's first meaningful item.
  ///
  /// Matches the main-app pattern where every destination has one
  /// "land on first item" hook and one selected-state rule.
  void _activateRailTile(String id) {
    if (_state.active != id) {
      _state.active = id;
    }
    if (_state.stack.isNotEmpty) {
      _state.clearStack();
    }
    _focusActiveCategoryFirstRow();
  }

  /// D-pad handling for the rail. Right (vertical layout) or Down (narrow
  /// layout) jumps focus into the detail pane; Left/Up from the first
  /// tile returns focus to the shell top-menu tab — borrowing the
  /// existing `ShellContentFocusRegistry.topNavFocus` hand-off used by
  /// every other destination.
  KeyEventResult? _railKeyIntercept(
    FocusNode node,
    KeyEvent event, {
    required bool vertical,
  }) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    final intoDetail =
        vertical ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowDown;
    final outToMenu =
        vertical ? LogicalKeyboardKey.arrowUp : LogicalKeyboardKey.arrowUp;

    if (key == intoDetail) {
      // Always enter the **active** (OK-selected) category's detail —
      // never follow the merely highlighted row when focus != selection.
      _focusActiveCategoryFirstRow();
      return KeyEventResult.handled;
    }
    if (key == outToMenu) {
      // The Account tile is the first rail item. Up from it — or from
      // any tile on narrow/horizontal layouts — escalates to the shell
      // top-menu, matching the main-app rule.
      final accountTileFocused = _accountRailFocus.hasFocus;
      if (vertical && accountTileFocused) {
        final topNav =
            ShellContentFocusRegistry.topNavFocus(ShellDestination.newSettings);
        if (topNav != null && topNav.canRequestFocus) {
          topNav.requestFocus();
          return KeyEventResult.handled;
        }
      }
      // Narrow layout: rail is horizontal, Up always returns to the top
      // menu from any tile.
      if (!vertical) {
        final topNav =
            ShellContentFocusRegistry.topNavFocus(ShellDestination.newSettings);
        if (topNav != null && topNav.canRequestFocus) {
          topNav.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }
    return null;
  }

  // ── Detail pane ─────────────────────────────────────────────────────

  Widget _buildDetailPane() {
    // `skipTraversal: true` keeps this Focus node out of the tab order so
    // focus always lands on an interior row/button.
    //
    // **Hardware / TV Back** is delivered once via [MainShellScreen]'s
    // [PopScope] → [ShellBackCoordinator.tryConsumeBack] → [_consumeDetailBack]
    // only. **Do not** also handle [LogicalKeyboardKey.goBack] here — the
    // same press would be processed twice and call [_consumeDetailBack]
    // twice, popping two stack levels in one key event.
    //
    // **Escape** (desktop) is not always wired to the shell pop path; we
    // still route it to the same ladder.
    return Focus(
      focusNode: _shellPrimaryFocus,
      skipTraversal: true,
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_consumeDetailBack()) return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      // Isolate detail-pane traversal from the categories rail: spatial
      // D-pad Left in [newSettingsRootLeftFromNsFocusable] uses
      // [FocusScope.of] (nearest [FocusScopeNode] ancestor) so the rail
      // is not the next "left" hop from mid-pane focusables. Header
      // search is outside this subtree (full-width above the split).
      //
      // **Do not** set [canRequestFocus] to false here: on a
      // [FocusScopeNode] that disables *all* descendant focus (see
      // [FocusNode.canRequestFocus] docs), which would make category
      // content unfocusable. [skipTraversal] is enough to keep this
      // scope out of the ordered traversal ring.
      child: Focus(
        focusNode: _detailScope,
        skipTraversal: true,
        child: FocusTraversalGroup(
          key: _detailTraversalKey,
          // Widget-order + directional moves behave better for mixed lists
          // and inline grids than a single numeric [OrderedTraversalPolicy].
          policy: WidgetOrderTraversalPolicy(),
          // Transparent so the HTML radial-gradient backdrop shows through,
          // exactly like `.detail` in the HTML (no fill of its own).
          child: _buildDetailBody(),
        ),
      ),
    );
  }

  StoredPlaylist? _storedPlaylistById(String id) {
    for (final p in libraryController.playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Activate + sync catalog, then push the Ns tool page (no legacy routes).
  Future<void> _openPlaylistTool({
    required String page,
    required String playlistId,
    required String title,
    bool requireXtream = false,
  }) async {
    final p = _storedPlaylistById(playlistId);
    if (p == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist not found in library.')),
        );
      }
      return;
    }
    if (requireXtream && !p.isXtream) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.catchupXtreamOnly),
          ),
        );
      }
      return;
    }
    await _state.syncPlaylist(playlistId);
    if (!mounted) return;
    _state.pushPage(NsStackEntry(
      page: page,
      args: {'id': playlistId},
      title: title,
    ));
  }

  Widget _buildDetailBody() {
    // Top-level "Account" rail — treated like any category destination:
    // no sub-page stack entry, no back button, selection indicator
    // driven purely by `_state.active == 'account'`.
    if (_state.active == 'account' && _state.stack.isEmpty) {
      return NsAccountPage(
        state: _state,
        onBack: null,
        profileTabFocus: _accountProfileTabFocus,
        subscriptionTabFocus: _accountSubscriptionTabFocus,
        devicesTabFocus: _accountDevicesTabFocus,
        downloadsTabFocus: _accountDownloadsTabFocus,
        tabStripKey: _accountTabStripKey,
        postTabsKey: _accountPostTabsKey,
      );
    }

    final cat = nsCategoryById(_state.active);
    if (cat == null && _state.stack.isEmpty) return const SizedBox.shrink();

    // Sub-page is on top of the stack?
    if (_state.stack.isNotEmpty) {
      final entry = _state.stack.last;
      // Route real sub-pages first; fall through to placeholder for every
      // page not yet ported (phases 4+).
      switch (entry.page) {
        case 'topmenu':
          return NsTopMenuPage(
            state: _state,
            onBack: _state.popPage,
          );
        case 'pin':
          return NsPinPage(
            onBack: _state.popPage,
          );
        case 'appearance':
          return NsAppearancePage(
            state: _state,
            onBack: _state.popPage,
          );
        case 'clock':
          return NsClockPage(
            state: _state,
            onBack: _state.popPage,
          );
        case 'rules':
          return NsRulesPage(
            onBack: _state.popPage,
          );
        case 'backup':
          return NsBackupPage(
            state: _state,
            onBack: _state.popPage,
          );
        // Note: 'account' is no longer a sub-page route — it's a
        // top-level rail destination handled above by
        // `_state.active == 'account'`.
        case 'addPlaylist':
          return NsAddPlaylistPage(
            state: _state,
            onBack: _state.popPage,
            onAdded: () {
              // Pop the wizard; after the frame commits, drop focus on
              // the new card's Manage button if we can find it.
              _state.popPage();
            },
          );
        case 'playlistDetail':
          final pid = entry.args['id'] as String? ?? '';
          final l10n = AppLocalizations.of(context);
          return NsPlaylistDetailPage(
            state: _state,
            playlistId: pid,
            onBack: _state.popPage,
            onDeleted: _state.popPage,
            onOpenGroups: () => unawaited(_openPlaylistTool(
                  page: 'groups',
                  playlistId: pid,
                  title: 'Manage groups',
                )),
            onOpenChannels: () => unawaited(_openPlaylistTool(
                  page: 'channelsCategories',
                  playlistId: pid,
                  title: 'Manage channels',
                )),
            onOpenRecording: () => unawaited(_openPlaylistTool(
                  page: 'recordingCategories',
                  playlistId: pid,
                  title: l10n.catchupManage,
                  requireXtream: true,
                )),
          );
        case 'groups':
          final pid = entry.args['id'] as String? ?? '';
          return NsGroupsPage(
            state: _state,
            playlistId: pid,
            onBack: _state.popPage,
            onOpenSection: (section) {
              final title = switch (section) {
                'live' => 'TV groups',
                'vod' => 'Movie groups',
                'series' => 'Show groups',
                _ => 'Groups',
              };
              _state.pushPage(NsStackEntry(
                page: 'groupSection',
                args: {'id': pid, 'section': section},
                title: title,
              ));
            },
          );
        case 'groupSection':
          final pid = entry.args['id'] as String? ?? '';
          final section = entry.args['section'] as String? ?? 'live';
          return NsGroupSectionPage(
            state: _state,
            playlistId: pid,
            section: section,
            onBack: _state.popPage,
          );
        case 'channelsCategories':
          final pid = entry.args['id'] as String? ?? '';
          return NsChannelsCategoriesPage(
            state: _state,
            playlistId: pid,
            onBack: _state.popPage,
            onOpenCategory: (cat) {
              _state.pushPage(NsStackEntry(
                page: 'channelsList',
                args: {'id': pid, 'categoryId': cat.id},
                title: cat.alias ?? cat.name,
              ));
            },
          );
        case 'channelsList':
          final pid = entry.args['id'] as String? ?? '';
          final catId = entry.args['categoryId'] as String? ?? '';
          return NsChannelsListPage(
            state: _state,
            playlistId: pid,
            categoryId: catId,
            onBack: _state.popPage,
          );
        case 'recordingCategories':
          final pid = entry.args['id'] as String? ?? '';
          return NsRecordingCategoriesPage(
            state: _state,
            playlistId: pid,
            onBack: _state.popPage,
            onOpenCategory: (cat) {
              _state.pushPage(NsStackEntry(
                page: 'recordingChannels',
                args: {'id': pid, 'categoryId': cat.id},
                title: cat.alias ?? cat.name,
              ));
            },
          );
        case 'recordingChannels':
          final pid = entry.args['id'] as String? ?? '';
          final catId = entry.args['categoryId'] as String? ?? '';
          return NsRecordingChannelsPage(
            state: _state,
            playlistId: pid,
            categoryId: catId,
            onBack: _state.popPage,
          );
        case 'favoritesEditor':
          final gid = entry.args['id'] as String? ?? '';
          return NsFavoritesEditorPage(
            state: _state,
            groupId: gid,
            onBack: _state.popPage,
            onDeleted: _state.popPage,
          );
      }
      return NsComingNextPage(
        eyebrow: cat?.eyebrow ?? '',
        title: entry.title,
        desc:
            'The "${entry.title}" sub-page is not ported yet. Press Back to '
            'return to ${cat?.title ?? 'settings'}.',
        hint: _pageHint(entry.page),
      );
    }

    if (cat == null) return const SizedBox.shrink();

    // Landing categories — route to their real renderer where available.
    if (cat.landing != null) {
      switch (cat.landing!.page) {
        case 'playlists':
          return NsPlaylistsPage(
            state: _state,
            manageFocusNodeFor: _playlistManageNode,
            onOpenDetail: (p) {
              _state.activePlaylistId = p.id;
              _state.pushPage(NsStackEntry(
                page: 'playlistDetail',
                args: {'id': p.id},
                title: p.name,
              ));
            },
            onAddPlaylist: () {
              _state.addPlaylist.reset();
              _state.pushPage(const NsStackEntry(
                page: 'addPlaylist',
                title: 'Add playlist',
              ));
            },
          );
        case 'favorites':
          return NsFavoritesPage(
            state: _state,
            firstContentFocus: _favoritesFirstContentFocus,
            onOpenEditor: (g) {
              _state.favResetEditor();
              _state.pushPage(NsStackEntry(
                page: 'favoritesEditor',
                args: {'id': g.id},
                title: g.name,
              ));
            },
          );
      }
      return NsComingNextPage(
        eyebrow: cat.eyebrow,
        title: cat.title,
        desc: cat.desc,
      );
    }

    // Phase 2: every row-based category renders via [NsCategoryPage]. Rows
    // with `kind: page` still push onto the sub-page stack and show the
    // "Coming next" placeholder until their sub-page renderer ships in a
    // later phase — the breadcrumb + Back behaviour is fully exercised.
    return NsCategoryPage(
      category: cat,
      state: _state,
      onOpenPage: _openPage,
      onAction: _fireAction,
      firstRowFocusNode: _categoryFirstFocus[cat.id],
    );
  }

  String? _pageHint(String pageId) => null;
}
