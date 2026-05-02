/// 1:1 port of the `state = { ... }` object defined at line 4676 of
/// `settings.html`. Field names, nesting, and default values are preserved
/// verbatim so behaviour of later sub-page ports matches the HTML reference
/// line for line.
///
/// The HTML reference and default `kNsCats` / mock-friendly fields remain
/// the structural baseline. Playlist-related mutations persist
/// through `libraryController` and the stores listed in this file;
/// Favorites are persisted via [LiveFavoriteGroupsStore] (shared with
/// the legacy Settings → Favorite setup flow).
///
/// Organised as a single `ChangeNotifier` so the screen and every row renderer
/// rebuild on any mutation, mirroring the HTML's `render()` call after each
/// state change.
///
/// **Playlists** are driven by the real [libraryController] and related
/// data stores (Xtream catalog, group visibility, channel overrides, EPG
/// preferences, live cache eviction). Favorites use [LiveFavoriteGroupsStore]
/// (shared with legacy Favorite setup). Other new-settings sub-pages may
/// still be preview/partial until individually ported to backing stores.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart' show Offset;

import '../../account/access_gate.dart';
import '../../account/account_api.dart';
import '../../account/account_store.dart';
import '../../data/clock_overlay_settings_store.dart';
import '../../data/library_controller.dart';
import '../../data/live_favorite_channel_ref.dart';
import '../../data/live_favorite_groups_store.dart';
import '../../data/lightning_switch_store.dart';
import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_grid_columns_store.dart';
import '../../data/live_tv_hero_layout_store.dart';
import '../../data/media_card_style_store.dart';
import '../../data/movie_rail_page_size_store.dart';
import '../../data/app_locale_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/performance_tier_store.dart';
import '../../data/series_rail_page_size_store.dart';
import '../../data/subtitle_settings_store.dart';
import '../../data/team_visual_store.dart';
import '../../data/playlist_channel_override_store.dart';
import '../../data/playlist_epg_timezone_store.dart';
import '../../data/playlist_live_catalog_cache.dart';
import '../../data/stored_playlist.dart' show PlaylistDraft;
import '../../data/playlist_group_visibility_store.dart';
import '../../data/recording_approval_store.dart';
import '../../data/top_menu_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../shell/shell_destination.dart';
import 'new_settings_data.dart';
import 'ns_playlist_catalog_hydrate.dart';

/// Per-row values indexed by `"<categoryId>:<rowId>"`. Choice rows store the
/// selected option id; toggle rows store a `"true"` / `"false"` string. This
/// avoids a second parallel map and matches how the HTML mutates rows in
/// place on the `CATS` array at runtime.
typedef RowValueMap = Map<String, String>;

/// Appearance sub-state — line 4683–4689 of settings.html.
class NsAppearanceState {
  NsAppearanceState();

  /// Which tab inside the Appearance page is active: 'liveTv' | 'heroBg' |
  /// 'movies' | 'series'. Default matches the HTML.
  String activeTab = 'liveTv';

  // Live TV tab (line 4685) — aligned with persisted store defaults
  int liveTvHero = 60;
  int liveTvCols = 6;
  String liveTvCardStyle = 'logoName';

  // Hero background tab (line 4686)
  int heroBgGradient = 50;
  String heroBgBgColor = '#0F1B2A';
  String heroBgWash = 'solid';
  String heroBgOverlayColor = '#4DD0E1';
  String heroBgBezel = 'cinema';

  // Movies tab (line 4687)
  int moviesPerRow = 8;
  String moviesCardStyle = 'poster';

  // Series tab (line 4688)
  int seriesPerRow = 8;
  String seriesCardStyle = 'poster';
}

/// Clock overlay sub-state — lines 4699–4708 of settings.html.
class NsClockState {
  NsClockState();

  bool enabled = false;
  String fmt = '24'; // '12' | '24'
  int sizePx = 19; // continuous; 15=Small, 19=Medium, 24=Large
  bool framed = true;
  String corner = 'tr'; // 'tl' | 'tr' | 'bl' | 'br'
  int opacity = 100; // 20..100
  String color = '#7DD3FC';

  /// Per-corner offsets so switching corner preserves each nudge.
  final Map<String, ({int x, int y})> offsets = {
    'tl': (x: 0, y: 0),
    'tr': (x: 0, y: 0),
    'bl': (x: 0, y: 0),
    'br': (x: 0, y: 0),
  };
}

/// Account sub-state — line 4690.
class NsAccountState {
  NsAccountState();

  String tab = 'profile';
  String selectedDuration = '3yr';

  /// Mock live account data — same shape as the HTML `ACCOUNT`. Kept
  /// here (not in a separate store) because the real app doesn't have
  /// an account backend yet; this is a visual + interactive port.
  late NsAccount data = nsDefaultAccount();
}

/// Favorites editor scratch state — line 4692.
class NsFavEditorState {
  NsFavEditorState();

  String search = '';
  String activePlaylist = '';
  String activeCategory = '';
}

/// Add-playlist wizard draft — ports `state.addPlaylist` at
/// settings.html line 5745. Survives sub-page re-renders during edits.
///
/// Shape matches the HTML exactly:
///
///     {
///       type: 'xtream' | 'm3u',
///       showPass: false,
///       xt:  { server, user, pass, name },
///       m3u: { name, url },
///       errors: { <fieldId>: 'message' },
///       test: null | { status: 'pending'|'ok'|'err', counts, message },
///     }
enum NsAddPlaylistTestStatus { pending, ok, error }

class NsAddPlaylistTest {
  NsAddPlaylistTest({
    required this.status,
    this.counts,
    this.message,
  });

  NsAddPlaylistTestStatus status;
  Map<String, int>? counts; // keys: 'live', 'vod', 'series'
  String? message;
}

class NsAddPlaylistDraft {
  String type = 'xtream'; // 'xtream' | 'm3u'
  bool showPass = false;

  // Xtream fields
  String xtServer = '';
  String xtUser = '';
  String xtPass = '';
  String xtName = '';

  // M3U fields
  String m3uName = '';
  String m3uUrl = '';

  /// Validation errors keyed by field id.
  Map<String, String> errors = {};

  /// Latest test-connection result (null = not run yet).
  NsAddPlaylistTest? test;

  void reset() {
    type = 'xtream';
    showPass = false;
    xtServer = '';
    xtUser = '';
    xtPass = '';
    xtName = '';
    m3uName = '';
    m3uUrl = '';
    errors = {};
    test = null;
  }
}

/// Per-playlist Manage-recording draft — ports `CATCHUP.byPlaylist[pid]`
/// (settings.html line 7385):
///
///     { categories: [catId], channels: { [catId]: [chId] },
///       filterCatchup: false, tvFrameEpg: false }
class NsRecordingState {
  NsRecordingState();

  /// Category ids currently approved for recording.
  List<String> categories = <String>[];

  /// Per-category approved channel ids.
  Map<String, List<String>> channels = <String, List<String>>{};

  /// "Catch-up filter" toggle — hides channels with no catch-up.
  bool filterCatchup = false;

  /// "TV frame on EPG" toggle.
  bool tvFrameEpg = false;
}

/// Breadcrumb stack entry — mirrors `{ page, args, title }` pushed onto
/// `state.stack` in the HTML (line 4680).
class NsStackEntry {
  const NsStackEntry({
    required this.page,
    this.args = const {},
    required this.title,
  });

  final String page;
  final Map<String, Object?> args;
  final String title;
}

/// Root state bundle. A `ChangeNotifier` so the screen rebuilds on any
/// mutation without scattering `setState` calls through the tree.
///
/// Do not mutate public fields directly from outside this class — use the
/// dedicated setters below so listeners are notified.
class NewSettingsState extends ChangeNotifier {
  NewSettingsState() {
    _wireRealStores();
  }

  // ── Real-store bridges ─────────────────────────────────────────────
  // The new-settings preview originally lived on a mock row-value map.
  // As categories are "connected" to the real app, specific rows get
  // routed through their real store instead. Every other row keeps
  // using [_rowValues]. Today the Playback category is wired:
  //   * playback:perf      → performanceTierStore
  //   * playback:lightning → lightningSwitchStore
  //   * playback:subs      → SubtitleSettingsStore.instance
  // The stores already back the old settings screen, so both surfaces
  // read / write identical state — flipping a toggle on either side
  // reflects on the other without touching the legacy UI. System →
  // Interface language is bridged to [appLocaleStore] (same as legacy
  // [LanguageSettingsScreen]).

  void _wireRealStores() {
    libraryController.addListener(_onLibraryOrEpgStoreChanged);
    unawaited(
      playlistEpgTimezoneStore.ensureLoaded().then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
    playlistEpgTimezoneStore.addListener(_onLibraryOrEpgStoreChanged);
    unawaited(playlistGroupVisibilityStore.ensureLoaded().then((_) {
      _rebuildPlaylistCache();
      notifyListeners();
    }));
    unawaited(playlistChannelOverrideStore.ensureLoaded().then((_) {
      _rebuildPlaylistCache();
      notifyListeners();
    }));
    xtreamCatalogRepository.addListener(_onLibraryOrEpgStoreChanged);
    playlistGroupVisibilityStore.addListener(_onLibraryOrEpgStoreChanged);
    playlistChannelOverrideStore.addListener(_onLibraryOrEpgStoreChanged);
    _rebuildPlaylistCache();

    performanceTierStore
      ..ensureLoaded()
      ..addListener(_onRealStoreChanged);
    lightningSwitchStore
      ..ensureLoaded()
      ..addListener(_onRealStoreChanged);
    SubtitleSettingsStore.instance
      ..ensureLoaded()
      ..addListener(_onRealStoreChanged);
    teamVisualStore
      ..ensureLoaded()
      ..addListener(_onRealStoreChanged);
    TopMenuStore.instance
      ..load()
      ..addListener(_onRealStoreChanged);
    clockOverlaySettingsStore
      ..ensureLoaded().then((_) => _pullClockFromStore())
      ..addListener(_onClockStoreChanged);
    // Initial sync — if the store is already loaded, this fills the
    // mock [clock] object right away; otherwise `.then(...)` above
    // repeats the sync on load.
    _pullClockFromStore();

    // ── Appearance (Live TV / Movies / Series) ─────────────────────
    liveTvHeroLayoutStore
      ..ensureLoaded().then((_) => _pullAppearanceFromStores())
      ..addListener(_onAppearanceStoreChanged);
    liveTvGridColumnsStore
      ..ensureLoaded().then((_) => _pullAppearanceFromStores())
      ..addListener(_onAppearanceStoreChanged);
    liveTvCardStyleStore
      ..ensureLoaded().then((_) => _pullAppearanceFromStores())
      ..addListener(_onAppearanceStoreChanged);
    movieRailPageSizeStore
      ..ensureLoaded().then((_) => _pullAppearanceFromStores())
      ..addListener(_onAppearanceStoreChanged);
    seriesRailPageSizeStore
      ..ensureLoaded().then((_) => _pullAppearanceFromStores())
      ..addListener(_onAppearanceStoreChanged);
    mediaCardStyleStore
      ..ensureLoaded().then((_) => _pullAppearanceFromStores())
      ..addListener(_onAppearanceStoreChanged);
    _pullAppearanceFromStores();

    // ── Real account store / API ──────────────────────────────────
    // Subscribe to auth-state flips (login / logout / token refresh)
    // and run an initial load so `account.data` is populated from the
    // live backend instead of the HTML mock. Network loads are
    // fire-and-forget: callers read `account.data` which is always a
    // valid NsAccount (mock if we haven't loaded yet, live after).
    accountStore
      ..ensureLoaded().then((_) {
        _syncAccountFromStore();
        notifyListeners();
        if (accountStore.isLoggedIn) _reloadAccountLive();
      })
      ..addListener(_onAccountStoreChanged);

    // Same persisted prefs as legacy Recording → Categories / Channels.
    unawaited(recordingApprovalStore.ensureLoaded().then((_) {
      _syncAllRecordingFromStore();
      notifyListeners();
    }));
    recordingApprovalStore.addListener(_onRecordingStoreChanged);

    // Favorites — same [LiveFavoriteGroupsStore] as Settings → Favorite setup
    // and Live TV; new settings never depends on the legacy settings route.
    LiveFavoriteGroupsStore.instance.addListener(_onLiveFavStoreChanged);
    unawaited(_bootstrapLiveFavGroups());

    unawaited(
      parentalControlStore.ensureLoaded().then((_) {
        notifyListeners();
      }),
    );
    parentalControlStore.addListener(_onParentalControlStoreChanged);

    unawaited(
      appLocaleStore.ensureLoaded().then((_) {
        notifyListeners();
      }),
    );
    appLocaleStore.addListener(_onRealStoreChanged);
  }

  void _onParentalControlStoreChanged() {
    notifyListeners();
  }

  void _onLiveFavStoreChanged() {
    _syncFavGroupsFromStore();
    notifyListeners();
  }

  Future<void> _bootstrapLiveFavGroups() async {
    await LiveFavoriteGroupsStore.instance.ensureLoaded();
    _syncFavGroupsFromStore();
    notifyListeners();
  }

  void _onRecordingStoreChanged() {
    _syncAllRecordingFromStore();
    notifyListeners();
  }

  void _syncAllRecordingFromStore() {
    if (!recordingApprovalStore.isLoaded) return;
    for (final p in libraryController.playlists) {
      _applyRecordingFromStoreToCache(p.id);
    }
  }

  void _applyRecordingFromStoreToCache(String pid) {
    if (!recordingApprovalStore.isLoaded) return;
    final r = _recordingByPlaylist.putIfAbsent(pid, NsRecordingState.new);
    final cats = recordingApprovalStore.approvedCategoryIds(pid);
    r.categories = cats.toList()..sort();
    r.channels = {
      for (final id in cats)
        id: recordingApprovalStore.approvedChannelIds(pid, id).toList(),
    };
    r.filterCatchup = recordingApprovalStore.filterCatchupOnly(pid);
    r.tvFrameEpg = recordingApprovalStore.tvFrameEpg(pid);
  }

  // ── Library + Xtream (playlists, groups, channels) ───────────────
  static final List<NsPlaylist> _favSeedPlaylists = nsDefaultPlaylists();
  final Map<String, NsPlaylist> _playlistByIdCache = <String, NsPlaylist>{};

  void _rebuildPlaylistCache() {
    for (final s in libraryController.playlists) {
      final prev = _playlistByIdCache[s.id];
      _playlistByIdCache[s.id] = buildNsPlaylistFromStored(
        s,
        epgMode: playlistEpgTimezoneStore.epgDisplayMode(s.id),
        isActive: libraryController.activePlaylistId == s.id,
        previous: prev,
      );
      hydrateNsPlaylistMapsFromCatalog(_playlistByIdCache[s.id]!, s);
    }
    _playlistByIdCache.removeWhere(
      (id, _) => !libraryController.playlists.any((p) => p.id == id),
    );
  }

  void _onLibraryOrEpgStoreChanged() {
    _rebuildPlaylistCache();
    if (recordingApprovalStore.isLoaded) {
      _syncAllRecordingFromStore();
    }
    if (LiveFavoriteGroupsStore.instance.isLoaded) {
      _syncFavGroupsFromStore();
    }
    notifyListeners();
  }

  void _onRealStoreChanged() => notifyListeners();

  /// Keep the mock [NsClockState] in sync with [clockOverlaySettingsStore]
  /// so any external write (old settings page, backup restore, …) is
  /// reflected in the new settings UI without extra plumbing.
  void _onClockStoreChanged() {
    _pullClockFromStore();
    notifyListeners();
  }

  void _pullClockFromStore() {
    final s = clockOverlaySettingsStore;
    if (!s.isLoaded) return;
    clock
      ..enabled = s.enabled
      ..fmt = s.use24Hour ? '24' : '12'
      ..sizePx = s.size.fontSize.round()
      ..framed = s.framed
      ..corner = s.corner.storageValue
      ..opacity = (s.opacity * 100).round().clamp(20, 100)
      ..color = _colorIndexToHex(s.colorIndex);
    for (final c in ClockCorner.values) {
      final o = s.offsetForCorner(c);
      clock.offsets[c.storageValue] =
          (x: o.dx.round(), y: o.dy.round());
    }
  }

  @override
  void dispose() {
    libraryController.removeListener(_onLibraryOrEpgStoreChanged);
    playlistEpgTimezoneStore.removeListener(_onLibraryOrEpgStoreChanged);
    xtreamCatalogRepository.removeListener(_onLibraryOrEpgStoreChanged);
    playlistGroupVisibilityStore.removeListener(_onLibraryOrEpgStoreChanged);
    playlistChannelOverrideStore.removeListener(_onLibraryOrEpgStoreChanged);
    recordingApprovalStore.removeListener(_onRecordingStoreChanged);
    LiveFavoriteGroupsStore.instance.removeListener(_onLiveFavStoreChanged);
    accountStore.removeListener(_onAccountStoreChanged);
    performanceTierStore.removeListener(_onRealStoreChanged);
    lightningSwitchStore.removeListener(_onRealStoreChanged);
    SubtitleSettingsStore.instance.removeListener(_onRealStoreChanged);
    teamVisualStore.removeListener(_onRealStoreChanged);
    TopMenuStore.instance.removeListener(_onRealStoreChanged);
    clockOverlaySettingsStore.removeListener(_onClockStoreChanged);
    liveTvHeroLayoutStore.removeListener(_onAppearanceStoreChanged);
    liveTvGridColumnsStore.removeListener(_onAppearanceStoreChanged);
    liveTvCardStyleStore.removeListener(_onAppearanceStoreChanged);
    movieRailPageSizeStore.removeListener(_onAppearanceStoreChanged);
    seriesRailPageSizeStore.removeListener(_onAppearanceStoreChanged);
    mediaCardStyleStore.removeListener(_onAppearanceStoreChanged);
    appLocaleStore.removeListener(_onRealStoreChanged);
    super.dispose();
  }

  // ── Rail / palette ─────────────────────────────────────────────────
  // `active`, `expanded`, `search` — lines 4677–4679.

  /// Unified "active rail tile" id. Can be `'account'` or any
  /// [kNsCats] id. `'account'` is the default landing tile so entering
  /// New Settings lands with the Account tile selected and in focus —
  /// same treatment every category gets when it's active.
  String _active = 'account';
  String get active => _active;
  set active(String id) {
    if (_active == id) return;
    _active = id;
    _expanded = null;
    _stack = const [];
    notifyListeners();
  }

  /// Row id currently expanded into its option sheet (`choice` rows).
  String? _expanded;
  String? get expanded => _expanded;
  void toggleExpanded(String rowKey) {
    _expanded = _expanded == rowKey ? null : rowKey;
    notifyListeners();
  }

  void collapse() {
    if (_expanded == null) return;
    _expanded = null;
    notifyListeners();
  }

  /// Header search query — fed into the command palette and the inline
  /// "filter rows" behaviour the HTML enables when non-empty.
  String _search = '';
  String get search => _search;
  set search(String value) {
    if (_search == value) return;
    _search = value;
    notifyListeners();
  }

  // ── Breadcrumb / sub-page stack ────────────────────────────────────
  // Line 4680 in settings.html.

  List<NsStackEntry> _stack = const [];
  List<NsStackEntry> get stack => _stack;
  NsStackEntry? get subPage => _stack.isEmpty ? null : _stack.last;

  void pushPage(NsStackEntry entry) {
    _stack = [..._stack, entry];
    notifyListeners();
  }

  void popPage() {
    if (_stack.isEmpty) return;
    _stack = _stack.sublist(0, _stack.length - 1);
    notifyListeners();
  }

  void clearStack() {
    if (_stack.isEmpty) return;
    _stack = const [];
    notifyListeners();
  }

  // ── Inline edit key (line 4681) ────────────────────────────────────

  String? _inlineEdit;
  String? get inlineEdit => _inlineEdit;
  set inlineEdit(String? key) {
    if (_inlineEdit == key) return;
    _inlineEdit = key;
    notifyListeners();
  }

  // ── Top menu (lines 4457–4463 in settings.html) ────────────────────
  // Mutable copies of the default lists so the user's reorder / add /
  // remove actions on the "Top menu items & order" sub-page are preserved
  // across rebuilds. Not connected to the real app's top_menu_store —
  // this is preview-only state, same philosophy as every other value on
  // this object.

  /// Bridged read of the current top-menu order.
  /// Maps each [ShellDestination] in [TopMenuStore.instance.order] to
  /// its matching [NsTopMenuItem] (by id = enum name). Items unknown
  /// to the new-settings UI (no NsTopMenuItem entry) are dropped.
  List<NsTopMenuItem> get topMenu {
    final order = TopMenuStore.instance.order;
    final items = <NsTopMenuItem>[];
    for (final d in order) {
      final match = _nsItemForDest(d);
      if (match != null) items.add(match);
    }
    return items;
  }

  /// Items currently not in [topMenu] but available to add.
  List<NsTopMenuItem> get topMenuAvailable {
    final inMenu = TopMenuStore.instance.order.map((d) => d.name).toSet();
    return kNsTopMenuAvailable
        .where((a) => !inMenu.contains(a.id))
        .toList();
  }

  static NsTopMenuItem? _nsItemForDest(ShellDestination d) {
    for (final x in kNsTopMenuDefault) {
      if (x.id == d.name) return x;
    }
    for (final x in kNsTopMenuAvailable) {
      if (x.id == d.name) return x;
    }
    return null;
  }

  /// Swap two entries — delegates to [TopMenuStore.reorder].
  void topMenuMove(int from, int to) {
    if (from == to) return;
    TopMenuStore.instance.reorder(from, to);
  }

  void topMenuRemove(String id) {
    final dest = _shellDestinationByName(id);
    if (dest == null) return;
    if (!dest.isOptional) return; // fixed items stay
    TopMenuStore.instance.toggleOptional(dest);
  }

  void topMenuAdd(NsTopMenuItem item) {
    final dest = _shellDestinationByName(item.id);
    if (dest == null) return;
    if (!dest.isOptional) return;
    TopMenuStore.instance.toggleOptional(dest);
  }

  // ── Row values (unified map) ───────────────────────────────────────
  // The HTML mutates `CATS[i].groups[j].rows[k].value` in place. Here we
  // keep overrides in a single `rowValues` map keyed by "categoryId:rowId";
  // absent keys mean "use the default from `kNsCats`".

  final RowValueMap _rowValues = {};

  String? getRowValue(String categoryId, String rowId) {
    final bridged = _bridgedRead(categoryId, rowId);
    if (bridged != null) return bridged;
    return _rowValues['$categoryId:$rowId'];
  }

  bool getRowBool(String categoryId, String rowId, {required bool defaultValue}) {
    final bridged = _bridgedRead(categoryId, rowId);
    if (bridged != null) return bridged == 'true';
    final raw = _rowValues['$categoryId:$rowId'];
    if (raw == null) return defaultValue;
    return raw == 'true';
  }

  String getRowChoice(
    String categoryId,
    String rowId, {
    required String defaultValue,
  }) {
    final bridged = _bridgedRead(categoryId, rowId);
    if (bridged != null) return bridged;
    return _rowValues['$categoryId:$rowId'] ?? defaultValue;
  }

  void setRowBool(String categoryId, String rowId, bool value) {
    if (_bridgedWrite(categoryId, rowId, value ? 'true' : 'false')) return;
    _rowValues['$categoryId:$rowId'] = value ? 'true' : 'false';
    notifyListeners();
  }

  void setRowChoice(String categoryId, String rowId, String optionId) {
    if (_bridgedWrite(categoryId, rowId, optionId)) return;
    _rowValues['$categoryId:$rowId'] = optionId;
    notifyListeners();
  }

  /// Returns the current value for `{category}:{row}` if it is wired
  /// to a real store, or `null` when the row still uses the local
  /// [_rowValues] map. Values are encoded as strings — `'true'` /
  /// `'false'` for toggles, option id for choice rows.
  String? _bridgedRead(String categoryId, String rowId) {
    if (categoryId == 'playback') {
      switch (rowId) {
        case 'perf':
          return performanceTierStore.mode.storageValue;
        case 'lightning':
          return lightningSwitchStore.enabled ? 'true' : 'false';
        case 'subs':
          return SubtitleSettingsStore.instance.defaultLanguageCode;
      }
    }
    if (categoryId == 'look') {
      switch (rowId) {
        case 'theme':
          return _teamToNsThemeId(teamVisualStore.team);
        case 'startup':
          return TopMenuStore.instance.startup.name;
      }
    }
    if (categoryId == 'privacy') {
      switch (rowId) {
        case 'parental_master':
          return parentalControlStore.enabled ? 'true' : 'false';
        case 'lock_live':
          return parentalControlStore.lockAllLive ? 'true' : 'false';
        case 'lock_movies':
          return parentalControlStore.lockAllMovies ? 'true' : 'false';
        case 'lock_series':
          return parentalControlStore.lockAllSeries ? 'true' : 'false';
      }
    }
    if (categoryId == 'system' && rowId == 'lang') {
      return appLocaleStore.languageCode;
    }
    return null;
  }

  /// Writes `value` through to a real store if one owns this row.
  /// Returns `true` when the write was dispatched — the caller should
  /// then NOT touch [_rowValues] (the store's own notifyListeners
  /// triggers our [_onRealStoreChanged] to rebuild the UI).
  bool _bridgedWrite(String categoryId, String rowId, String value) {
    if (categoryId == 'playback') {
      switch (rowId) {
        case 'perf':
          performanceTierStore
              .setMode(PerformanceTierMode.fromStorage(value));
          return true;
        case 'lightning':
          lightningSwitchStore.setEnabled(value == 'true');
          return true;
        case 'subs':
          SubtitleSettingsStore.instance.setDefaultLanguageCode(value);
          return true;
      }
    }
    if (categoryId == 'look') {
      switch (rowId) {
        case 'theme':
          final team = _nsThemeIdToTeam(value);
          if (team != null) teamVisualStore.setTeam(team);
          return true;
        case 'startup':
          final dest = _shellDestinationByName(value);
          if (dest != null) TopMenuStore.instance.setStartup(dest);
          return true;
      }
    }
    if (categoryId == 'privacy') {
      switch (rowId) {
        case 'parental_master':
          return true;
        case 'lock_live':
          unawaited(
            parentalControlStore.setLockAllLive(value == 'true'),
          );
          return true;
        case 'lock_movies':
          unawaited(
            parentalControlStore.setLockAllMovies(value == 'true'),
          );
          return true;
        case 'lock_series':
          unawaited(
            parentalControlStore.setLockAllSeries(value == 'true'),
          );
          return true;
      }
    }
    if (categoryId == 'system' && rowId == 'lang') {
      if (AppLocaleStore.supportedLanguageCodes.contains(value)) {
        unawaited(appLocaleStore.setLanguageCode(value));
      }
      return true;
    }
    return false;
  }

  /// Maps `AppVisualTeam` enum → the `id` used by [kNsThemes] (the
  /// option list that the new-settings UI renders).
  static String _teamToNsThemeId(AppVisualTeam t) => switch (t) {
        AppVisualTeam.settingsStyle => 'settingsStyle',
        AppVisualTeam.ember => 'ember',
        AppVisualTeam.nocturne => 'nocturne',
      };

  static AppVisualTeam? _nsThemeIdToTeam(String id) => switch (id) {
        'settingsStyle' => AppVisualTeam.settingsStyle,
        'ember' => AppVisualTeam.ember,
        'nocturne' => AppVisualTeam.nocturne,
        'daybreak' => AppVisualTeam.nocturne, // legacy → Nocturne
        'cyan' => AppVisualTeam.settingsStyle,
        'violet' => AppVisualTeam.settingsStyle,
        'solar' => AppVisualTeam.settingsStyle,
        'heritage' => AppVisualTeam.settingsStyle,
        'studio' => AppVisualTeam.settingsStyle,
        'canvas' => AppVisualTeam.settingsStyle,
        'mist' => AppVisualTeam.settingsStyle,
        'gildedBrush' => AppVisualTeam.settingsStyle,
        'inkBrush' => AppVisualTeam.settingsStyle,
        _ => null,
      };

  static ShellDestination? _shellDestinationByName(String name) {
    for (final d in ShellDestination.values) {
      if (d.name == name) return d;
    }
    return null;
  }

  void clearAllValues() {
    if (_rowValues.isEmpty) return;
    _rowValues.clear();
    notifyListeners();
  }

  // ── Nested sub-states ──────────────────────────────────────────────

  final NsAppearanceState appearance = NsAppearanceState();
  final NsAccountState account = NsAccountState();
  final NsFavEditorState favEditor = NsFavEditorState();
  final NsClockState clock = NsClockState();
  final NsAddPlaylistDraft addPlaylist = NsAddPlaylistDraft();

  /// Live rows from [libraryController] via [_playlistByIdCache]; HTML-seed
  /// playlists in [_favSeedPlaylists] only power the Favorites section.
  List<NsPlaylist> get playlists {
    final out = <NsPlaylist>[];
    for (final s in libraryController.playlists) {
      final p = _playlistByIdCache[s.id];
      if (p != null) out.add(p);
    }
    return List<NsPlaylist>.unmodifiable(out);
  }

  /// Cross-playlist favorite groups — loaded from [LiveFavoriteGroupsStore]
  /// (same disk payload as Settings → Favorite setup / Live TV favorites).
  final List<NsFavGroup> _favGroups = <NsFavGroup>[];

  /// Local backup files on disk (see [NsLocalBackupListController] on the
  /// Backup & restore page). Used for the System → Backup row subtitle.
  int _localDiskBackupCount = 0;
  String? _localDiskBackupLastDate;

  int get localDiskBackupCount => _localDiskBackupCount;

  String? get localDiskBackupLastDate => _localDiskBackupLastDate;

  void setLocalDiskBackupSummary(int count, String? lastDateLabel) {
    if (_localDiskBackupCount != count ||
        _localDiskBackupLastDate != lastDateLabel) {
      _localDiskBackupCount = count;
      _localDiskBackupLastDate = lastDateLabel;
      notifyListeners();
    }
  }

  // ── Cloud backups ──────────────────────────────────────────────────

  /// Mock sign-in status + account email for the cloud section.
  bool _cloudSignedIn = true;
  String? _cloudAccount = 'john@tvmate.app';
  bool get cloudSignedIn => _cloudSignedIn;
  String? get cloudAccount => _cloudAccount;

  void setCloudSignedIn(bool signedIn, {String? account}) {
    _cloudSignedIn = signedIn;
    _cloudAccount = signedIn ? (account ?? 'john@tvmate.app') : null;
    notifyListeners();
  }

  /// Server-stored backup files. Same shape as local — they're
  /// separate lists so user can see what lives where at a glance.
  final List<NsBackupFile> _cloudBackupFiles = nsDefaultCloudBackupFiles();
  List<NsBackupFile> get cloudBackupFiles =>
      List.unmodifiable(_cloudBackupFiles);

  /// "Upload personal" / "Upload shareable" — pushes the current
  /// settings to the mock cloud list.
  NsBackupFile uploadToCloud(NsBackupKind kind) {
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final file = NsBackupFile(
      name: 'tvmate-cloud-$stamp.tvmbk',
      size: '44 KB',
      date: 'just now',
      kind: kind,
    );
    _cloudBackupFiles.insert(0, file);
    notifyListeners();
    return file;
  }

  void deleteCloudBackup(String name) {
    final before = _cloudBackupFiles.length;
    _cloudBackupFiles.removeWhere((f) => f.name == name);
    if (_cloudBackupFiles.length != before) notifyListeners();
  }

  /// Subtitles for Parental rows — from [parentalControlStore].
  int get parentalRulesActiveCount => parentalControlStore.granularLockRuleCount;
  String get parentalPinValueLabel =>
      parentalControlStore.isPinConfigured ? 'Set' : 'Not set';

  /// Currently-inspected playlist id (set when opening a detail page).
  String? _activePlaylistId;
  String? get activePlaylistId => _activePlaylistId;
  set activePlaylistId(String? id) {
    if (_activePlaylistId == id) return;
    _activePlaylistId = id;
    notifyListeners();
  }

  NsPlaylist? playlistById(String id) {
    final c = _playlistByIdCache[id];
    if (c != null) return c;
    for (final p in _favSeedPlaylists) {
      if (p.id == id) return p;
    }
    return null;
  }

  void setPlaylist(String id, void Function(NsPlaylist p) mutate) {
    final p = playlistById(id);
    if (p == null) return;
    final beforeEpg = p.epgMode;
    mutate(p);
    if (p.epgMode != beforeEpg) {
      unawaited(
        playlistEpgTimezoneStore
            .setEpgDisplayMode(id, p.epgMode)
            .then((_) {
          _rebuildPlaylistCache();
          notifyListeners();
        }),
      );
    } else {
      notifyListeners();
    }
  }

  // ── Manage Groups helpers ──────────────────────────────────────────
  // Ported from `bindGroupSection` (settings.html line 6334).
  // Persists through [playlistGroupVisibilityStore] like the legacy UI.

  PlaylistGroupSection? _nsSectionToStore(String section) {
    return switch (section) {
      'live' => PlaylistGroupSection.live,
      'vod' => PlaylistGroupSection.vod,
      'series' => PlaylistGroupSection.series,
      _ => null,
    };
  }

  /// Flip a single group's visibility.
  void toggleGroupVisible(String pid, String section, String gid) {
    final p = playlistById(pid);
    if (p == null) return;
    final g = p.groups[section]?.firstWhere(
      (x) => x.id == gid,
      orElse: () => NsPlaylistGroup(id: '', name: ''),
    );
    if (g == null || g.id.isEmpty) return;
    final sec = _nsSectionToStore(section);
    if (sec == null) return;
    unawaited(
      playlistGroupVisibilityStore
          .setCategoryVisible(
        playlistId: pid,
        section: sec,
        categoryId: gid,
        visible: !g.visible,
      )
          .then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  /// Bulk show/hide — mirrors the `#grpShowAll` / `#grpHideAll` buttons.
  void setAllGroupsVisible(String pid, String section, bool visible) {
    final p = playlistById(pid);
    if (p == null) return;
    final list = p.groups[section];
    if (list == null || list.isEmpty) return;
    final sec = _nsSectionToStore(section);
    if (sec == null) return;
    unawaited(
      playlistGroupVisibilityStore
          .setAllVisible(
        playlistId: pid,
        section: sec,
        categoryIds: list.map((e) => e.id),
        visible: visible,
      )
          .then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  /// Save a rename alias (empty / null clears it).
  void setGroupAlias(String pid, String section, String gid, String? alias) {
    final sec = _nsSectionToStore(section);
    if (sec == null) return;
    unawaited(
      playlistGroupVisibilityStore
          .setCategoryAlias(
        playlistId: pid,
        section: sec,
        categoryId: gid,
        alias: alias,
      )
          .then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  // ── Manage Channels helpers ────────────────────────────────────────
  // Ported from `bindChannelsList` (settings.html line 6733).

  NsPlaylistChannel? _findChannel(
    String pid,
    String catId,
    String chId,
  ) {
    final p = playlistById(pid);
    if (p == null) return null;
    final list = p.channelsMap[catId];
    if (list == null) return null;
    for (final c in list) {
      if (c.id == chId) return c;
    }
    return null;
  }

  void setChannelAlias(
    String pid,
    String catId,
    String chId,
    String? alias,
  ) {
    if (_findChannel(pid, catId, chId) == null) return;
    unawaited(
      playlistChannelOverrideStore
          .setDisplayName(
        playlistId: pid,
        channelId: chId,
        displayName: alias,
      )
          .then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  void setChannelLogo(
    String pid,
    String catId,
    String chId,
    String? logo,
  ) {
    if (_findChannel(pid, catId, chId) == null) return;
    unawaited(
      playlistChannelOverrideStore
          .setLogoUrl(
        playlistId: pid,
        channelId: chId,
        logoUrl: logo,
      )
          .then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  void toggleChannelHidden(String pid, String catId, String chId) {
    final c = _findChannel(pid, catId, chId);
    if (c == null) return;
    unawaited(
      playlistChannelOverrideStore
          .setHidden(
        playlistId: pid,
        channelId: chId,
        hidden: !c.hidden,
      )
          .then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  /// Mirrors the HTML's "Reset" button — clears alias + logo.
  void resetChannel(String pid, String catId, String chId) {
    if (_findChannel(pid, catId, chId) == null) return;
    unawaited(
      Future.wait<void>([
        playlistChannelOverrideStore.setDisplayName(
          playlistId: pid,
          channelId: chId,
          displayName: null,
        ),
        playlistChannelOverrideStore.setLogoUrl(
          playlistId: pid,
          channelId: chId,
          logoUrl: null,
        ),
        playlistChannelOverrideStore.setHidden(
          playlistId: pid,
          channelId: chId,
          hidden: false,
        ),
      ]).then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  /// Un-hide every channel in a category (`#chShowAll`).
  void showAllChannels(String pid, String catId) {
    final p = playlistById(pid);
    if (p == null) return;
    final list = p.channelsMap[catId];
    if (list == null) return;
    final hidden = list.where((c) => c.hidden).toList();
    if (hidden.isEmpty) return;
    unawaited(
      Future.wait(
        [
          for (final c in hidden)
            playlistChannelOverrideStore.setHidden(
              playlistId: pid,
              channelId: c.id,
              hidden: false,
            ),
        ],
      ).then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  // ── Manage Recording state + helpers ───────────────────────────────
  // Mirrors [recordingApprovalStore] (legacy Recording → Categories / Channels)
  // so new settings and old settings read/write the same prefs.

  final Map<String, NsRecordingState> _recordingByPlaylist = {};

  NsRecordingState recordingFor(String pid) {
    return _recordingByPlaylist.putIfAbsent(pid, NsRecordingState.new);
  }

  /// Total approved channels across every approved category — used in
  /// the Detail page's Manage recording tile meta string.
  int recordingApprovedChannelsCount(String pid) {
    final r = _recordingByPlaylist[pid];
    if (r == null) return 0;
    var total = 0;
    for (final list in r.channels.values) {
      total += list.length;
    }
    return total;
  }

  int recordingApprovedCategoriesCount(String pid) {
    return _recordingByPlaylist[pid]?.categories.length ?? 0;
  }

  void toggleRecordingFilter(String pid) {
    unawaited(_toggleRecordingFilterAsync(pid));
  }

  Future<void> _toggleRecordingFilterAsync(String pid) async {
    await recordingApprovalStore.ensureLoaded();
    final v = !recordingApprovalStore.filterCatchupOnly(pid);
    await recordingApprovalStore.setFilterCatchupOnly(playlistId: pid, value: v);
  }

  void toggleRecordingTvFrame(String pid) {
    unawaited(_toggleRecordingTvFrameAsync(pid));
  }

  Future<void> _toggleRecordingTvFrameAsync(String pid) async {
    await recordingApprovalStore.ensureLoaded();
    final v = !recordingApprovalStore.tvFrameEpg(pid);
    await recordingApprovalStore.setTvFrameEpg(playlistId: pid, value: v);
  }

  /// Approve or disapprove a single category (same as legacy: approve does
  /// not auto-approve all channels; pick channels on the next screen).
  void toggleRecordingCategory(String pid, String catId) {
    unawaited(_toggleRecordingCategoryAsync(pid, catId));
  }

  Future<void> _toggleRecordingCategoryAsync(String pid, String catId) async {
    if (playlistById(pid) == null) return;
    await recordingApprovalStore.ensureLoaded();
    final on =
        recordingApprovalStore.approvedCategoryIds(pid).contains(catId);
    await recordingApprovalStore.setCategoryApproved(
      playlistId: pid,
      categoryId: catId,
      approved: !on,
    );
  }

  void recordingSelectAllCategories(String pid) {
    unawaited(_recordingSelectAllCategoriesAsync(pid));
  }

  Future<void> _recordingSelectAllCategoriesAsync(String pid) async {
    final p = playlistById(pid);
    if (p == null) return;
    final live = p.groups['live'] ?? const <NsPlaylistGroup>[];
    if (live.isEmpty) return;
    await recordingApprovalStore.ensureLoaded();
    await recordingApprovalStore.setAllCategoriesApproved(
      playlistId: pid,
      categoryIds: live.map((g) => g.id),
      approved: true,
    );
  }

  void recordingClearAll(String pid) {
    unawaited(_recordingClearAllAsync(pid));
  }

  Future<void> _recordingClearAllAsync(String pid) async {
    await recordingApprovalStore.ensureLoaded();
    final p = playlistById(pid);
    final live = p?.groups['live'] ?? const <NsPlaylistGroup>[];
    final ids = live.isNotEmpty
        ? live.map((g) => g.id)
        : recordingApprovalStore.approvedCategoryIds(pid);
    if (ids.isEmpty) return;
    await recordingApprovalStore.setAllCategoriesApproved(
      playlistId: pid,
      categoryIds: ids,
      approved: false,
    );
  }

  void recordingSelectAllChannels(String pid, String catId) {
    unawaited(_recordingSelectAllChannelsAsync(pid, catId));
  }

  Future<void> _recordingSelectAllChannelsAsync(
    String pid,
    String catId,
  ) async {
    final p = playlistById(pid);
    if (p == null) return;
    await recordingApprovalStore.ensureLoaded();
    _applyRecordingFromStoreToCache(pid);
    final r = recordingFor(pid);
    final all = p.channelsMap[catId] ?? const <NsPlaylistChannel>[];
    final visible = r.filterCatchup ? all.where((c) => c.catchup) : all;
    final ids = visible.map((c) => c.id).toList();
    if (ids.isEmpty) return;
    await recordingApprovalStore.setAllChannelsApproved(
      playlistId: pid,
      categoryId: catId,
      channelIds: ids,
      approved: true,
    );
  }

  void recordingClearVisibleChannels(String pid, String catId) {
    unawaited(_recordingClearVisibleChannelsAsync(pid, catId));
  }

  Future<void> _recordingClearVisibleChannelsAsync(
    String pid,
    String catId,
  ) async {
    final p = playlistById(pid);
    if (p == null) return;
    await recordingApprovalStore.ensureLoaded();
    _applyRecordingFromStoreToCache(pid);
    final r = recordingFor(pid);
    final all = p.channelsMap[catId] ?? const <NsPlaylistChannel>[];
    final visible = r.filterCatchup ? all.where((c) => c.catchup) : all;
    final visIds = visible.map((c) => c.id).toList();
    if (visIds.isEmpty) return;
    await recordingApprovalStore.setAllChannelsApproved(
      playlistId: pid,
      categoryId: catId,
      channelIds: visIds,
      approved: false,
    );
  }

  void toggleRecordingChannel(String pid, String catId, String chId) {
    unawaited(_toggleRecordingChannelAsync(pid, catId, chId));
  }

  Future<void> _toggleRecordingChannelAsync(
    String pid,
    String catId,
    String chId,
  ) async {
    await recordingApprovalStore.ensureLoaded();
    final on =
        recordingApprovalStore.approvedChannelIds(pid, catId).contains(chId);
    await recordingApprovalStore.setChannelApproved(
      playlistId: pid,
      categoryId: catId,
      channelId: chId,
      approved: !on,
    );
  }

  /// Re-fetch catalog for this source — same flow as the legacy playlist UI.
  Future<void> syncPlaylist(String id) async {
    if (!libraryController.playlists.any((p) => p.id == id)) return;
    await libraryController.setActivePlaylist(id);
    try {
      await xtreamCatalogRepository.syncFromLibrary(libraryController);
    } catch (e, st) {
      debugPrint('NewSettingsState.syncPlaylist: $e\n$st');
    }
    _rebuildPlaylistCache();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await libraryController.deletePlaylist(id);
    playlistLiveCatalogCache.evict(id);
    if (_activePlaylistId == id) _activePlaylistId = null;
    _rebuildPlaylistCache();
    notifyListeners();
  }

  // ── Favorites helpers ──────────────────────────────────────────────
  // Backed by [LiveFavoriteGroupsStore] (same prefs + behavior as
  // Settings → Favorite setup / [LiveTvFavoritesScreen]).

  void _syncFavGroupsFromStore() {
    final st = LiveFavoriteGroupsStore.instance;
    if (!st.isLoaded) return;
    _favGroups
      ..clear()
      ..addAll(
        st.groupsSorted.map(_liveGroupToNs),
      );
  }

  NsFavGroup _liveGroupToNs(LiveFavoriteGroup lg) {
    final color = lg.color ??
        kNsFavColors[lg.id.hashCode.abs() % kNsFavColors.length];
    return NsFavGroup(
      id: lg.id,
      name: lg.name,
      sortOrder: lg.sortOrder,
      color: color,
      refs: [for (final r in lg.channelRefs) _liveRefToNsFavRef(r)],
    );
  }

  NsFavRef _liveRefToNsFavRef(LiveFavoriteChannelRef r) {
    if (r.isLegacy) {
      for (final pl in libraryController.playlists) {
        final p = _playlistByIdCache[pl.id];
        if (p == null) continue;
        final cat = _findCategoryIdForChannel(p, r.channelId);
        if (cat != null) {
          return NsFavRef(
            playlistId: p.id,
            categoryId: cat,
            channelId: r.channelId,
          );
        }
      }
      final ap = libraryController.activePlaylistId ?? '';
      return NsFavRef(
        playlistId: ap,
        categoryId: '',
        channelId: r.channelId,
      );
    }
    final p = _playlistByIdCache[r.playlistId];
    if (p == null) {
      return NsFavRef(
        playlistId: r.playlistId,
        categoryId: '',
        channelId: r.channelId,
      );
    }
    return NsFavRef(
      playlistId: p.id,
      categoryId: _findCategoryIdForChannel(p, r.channelId) ?? '',
      channelId: r.channelId,
    );
  }

  String? _findCategoryIdForChannel(NsPlaylist p, String channelId) {
    for (final e in p.channelsMap.entries) {
      for (final c in e.value) {
        if (c.id == channelId) {
          return e.key;
        }
      }
    }
    return null;
  }

  List<LiveFavoriteChannelRef> _nsRefsToLive(Iterable<NsFavRef> refs) {
    return <LiveFavoriteChannelRef>[
      for (final r in refs)
        LiveFavoriteChannelRef(
          playlistId: r.playlistId,
          channelId: r.channelId,
        ),
    ];
  }

  void _pushFavRefsToStore(String gid, List<NsFavRef> next) {
    unawaited(
      LiveFavoriteGroupsStore.instance.setChannelRefs(
        gid,
        _nsRefsToLive(next),
      ),
    );
  }

  /// Read-only view of [_favGroups] sorted by (sortOrder, name). The
  /// landing card grid and the top-menu meta count both read this.
  List<NsFavGroup> get favGroupsSorted {
    final sorted = [..._favGroups];
    sorted.sort((a, b) {
      final bySort = a.sortOrder.compareTo(b.sortOrder);
      if (bySort != 0) return bySort;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(sorted);
  }

  int get favGroupsCount => _favGroups.length;

  int get favTotalRefs {
    var n = 0;
    for (final g in _favGroups) {
      n += g.refs.length;
    }
    return n;
  }

  NsFavGroup? favGroupById(String id) {
    for (final g in _favGroups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Create a new favorite group with auto-picked color / sort. Returns
  /// the created group so the caller can push to the editor.
  Future<NsFavGroup?> createFavGroup(String name) async {
    final store = LiveFavoriteGroupsStore.instance;
    await store.ensureLoaded();
    final color =
        kNsFavColors[store.groupsUnordered.length % kNsFavColors.length];
    final created = await store.addGroup(
      name: name,
      sortOrder: store.suggestedSortOrder(),
      channelRefs: const [],
      color: color,
    );
    return favGroupById(created.id);
  }

  Future<void> _deleteFavGroupAsync(String id) async {
    final store = LiveFavoriteGroupsStore.instance;
    await store.ensureLoaded();
    await store.removeGroup(id);
  }

  void deleteFavGroup(String id) {
    unawaited(_deleteFavGroupAsync(id));
  }

  void renameFavGroup(String id, String name) {
    final lg = LiveFavoriteGroupsStore.instance.groupById(id);
    if (lg == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == lg.name) return;
    unawaited(
      LiveFavoriteGroupsStore.instance
          .updateGroup(lg.copyWith(name: trimmed)),
    );
  }

  void setFavSortOrder(String id, int order) {
    final lg = LiveFavoriteGroupsStore.instance.groupById(id);
    if (lg == null || lg.sortOrder == order) return;
    unawaited(
      LiveFavoriteGroupsStore.instance
          .updateGroup(lg.copyWith(sortOrder: order)),
    );
  }

  void setFavColor(String id, String color) {
    final g = favGroupById(id);
    if (g == null || g.color == color) return;
    final lg = LiveFavoriteGroupsStore.instance.groupById(id);
    if (lg == null) return;
    unawaited(
      LiveFavoriteGroupsStore.instance.updateGroup(
        lg.copyWith(color: color),
      ),
    );
  }

  /// Resolve a ref to live channel / playlist / category records.
  /// Returns null when the channel has been removed.
  NsFavResolved? favResolve(NsFavRef ref) {
    final p = playlistById(ref.playlistId);
    if (p == null) return null;
    // Try the stored category first, fall back to scanning every cat.
    NsPlaylistGroup? cat;
    NsPlaylistChannel? ch;
    final stored = p.channelsMap[ref.categoryId];
    if (stored != null) {
      for (final c in stored) {
        if (c.id == ref.channelId) {
          ch = c;
          break;
        }
      }
      if (ch != null) {
        cat = (p.groups['live'] ?? const <NsPlaylistGroup>[])
            .cast<NsPlaylistGroup?>()
            .firstWhere((g) => g?.id == ref.categoryId, orElse: () => null);
      }
    }
    if (ch == null) {
      for (final entry in p.channelsMap.entries) {
        for (final c in entry.value) {
          if (c.id == ref.channelId) {
            ch = c;
            cat = (p.groups['live'] ?? const <NsPlaylistGroup>[])
                .cast<NsPlaylistGroup?>()
                .firstWhere((g) => g?.id == entry.key,
                    orElse: () => null);
            break;
          }
        }
        if (ch != null) break;
      }
    }
    if (ch == null) return null;
    return NsFavResolved(channel: ch, playlist: p, category: cat);
  }

  bool favContains(NsFavGroup g, NsFavRef ref) {
    for (final r in g.refs) {
      if (r.sameChannel(ref)) return true;
    }
    return false;
  }

  int favIndexOf(NsFavGroup g, NsFavRef ref) {
    for (var i = 0; i < g.refs.length; i++) {
      if (g.refs[i].sameChannel(ref)) return i;
    }
    return -1;
  }

  /// Click a channel in the picker: adds if absent, removes otherwise.
  void toggleFavRef(String gid, NsFavRef ref) {
    final g = favGroupById(gid);
    if (g == null) return;
    final next = List<NsFavRef>.from(g.refs);
    final i = favIndexOf(g, ref);
    if (i >= 0) {
      next.removeAt(i);
    } else {
      next.add(ref);
    }
    _pushFavRefsToStore(gid, next);
  }

  void favMoveRefUp(String gid, int idx) {
    final g = favGroupById(gid);
    if (g == null || idx <= 0 || idx >= g.refs.length) return;
    final next = List<NsFavRef>.from(g.refs);
    final tmp = next[idx - 1];
    next[idx - 1] = next[idx];
    next[idx] = tmp;
    _pushFavRefsToStore(gid, next);
  }

  void favMoveRefDown(String gid, int idx) {
    final g = favGroupById(gid);
    if (g == null || idx < 0 || idx >= g.refs.length - 1) return;
    final next = List<NsFavRef>.from(g.refs);
    final tmp = next[idx + 1];
    next[idx + 1] = next[idx];
    next[idx] = tmp;
    _pushFavRefsToStore(gid, next);
  }

  void favRemoveRefAt(String gid, int idx) {
    final g = favGroupById(gid);
    if (g == null || idx < 0 || idx >= g.refs.length) return;
    final next = List<NsFavRef>.from(g.refs)..removeAt(idx);
    _pushFavRefsToStore(gid, next);
  }

  /// Bulk add: insert every ref that isn't already present. Returns
  /// the count that actually changed.
  int favBulkAdd(String gid, Iterable<NsFavRef> refs) {
    final g = favGroupById(gid);
    if (g == null) return 0;
    var added = 0;
    final next = List<NsFavRef>.from(g.refs);
    for (final r in refs) {
      if (!next.any((x) => x.sameChannel(r))) {
        next.add(r);
        added++;
      }
    }
    if (added > 0) {
      _pushFavRefsToStore(gid, next);
    }
    return added;
  }

  /// Bulk remove: drop every ref that matches one of the given
  /// `{playlistId, channelId}` pairs.
  int favBulkRemove(String gid, Iterable<NsFavRef> refs) {
    final g = favGroupById(gid);
    if (g == null) return 0;
    final keys = refs.map((r) => r.key).toSet();
    final next =
        g.refs.where((r) => !keys.contains(r.key)).toList();
    final removed = g.refs.length - next.length;
    if (removed > 0) {
      _pushFavRefsToStore(gid, next);
    }
    return removed;
  }

  /// Default the editor's active playlist / category to sensible first
  /// values whenever the page opens. Port of `favEnsureActive`
  /// (settings.html 6856).
  void favEnsureActive() {
    final fav = favEditor;
    final pls = playlists;
    final validPl = pls.any((p) => p.id == fav.activePlaylist);
    if (!validPl) {
      fav.activePlaylist = pls.isNotEmpty ? pls.first.id : '';
    }
    final p = playlistById(fav.activePlaylist);
    final cats = p?.groups['live'] ?? const <NsPlaylistGroup>[];
    final validCat = cats.any((c) => c.id == fav.activeCategory);
    if (!validCat) {
      fav.activeCategory = cats.isNotEmpty ? cats.first.id : '';
    }
    notifyListeners();
  }

  /// Reset + ensure: call when entering the editor so the user doesn't
  /// see the previous group's filter state leaking in.
  void favResetEditor() {
    favEditor.search = '';
    favEditor.activePlaylist = '';
    favEditor.activeCategory = '';
    favEnsureActive();
  }

  void setFavEditorSearch(String q) {
    if (favEditor.search == q) return;
    favEditor.search = q;
    notifyListeners();
  }

  void setFavEditorPlaylist(String pid) {
    if (favEditor.activePlaylist == pid) return;
    favEditor.activePlaylist = pid;
    final p = playlistById(pid);
    final cats = p?.groups['live'] ?? const <NsPlaylistGroup>[];
    favEditor.activeCategory = cats.isNotEmpty ? cats.first.id : '';
    favEditor.search = '';
    notifyListeners();
  }

  void setFavEditorCategory(String catId) {
    if (favEditor.activeCategory == catId) return;
    favEditor.activeCategory = catId;
    favEditor.search = '';
    notifyListeners();
  }

  // ── Add-playlist wizard helpers ────────────────────────────────────
  // Port of `addPlValidate()` / `addPlRunTest()` / `addPlSubmit()` from
  // settings.html (lines 5754 + 5995 + 6022). Every mutation funnels
  // through [notifyListeners] so the wizard page rebuilds on each step.

  void setAddPlaylistType(String type) {
    if (addPlaylist.type == type) return;
    addPlaylist.type = type;
    addPlaylist.errors = {};
    addPlaylist.test = null;
    notifyListeners();
  }

  void setAddPlaylistField(String fieldId, String value) {
    final d = addPlaylist;
    switch (fieldId) {
      case 'server':
        d.xtServer = value;
      case 'user':
        d.xtUser = value;
      case 'pass':
        d.xtPass = value;
      case 'name':
        if (d.type == 'xtream') {
          d.xtName = value;
        } else {
          d.m3uName = value;
        }
      case 'url':
        d.m3uUrl = value;
    }
    // Typing invalidates the last test + clears the row's inline error
    // — matches `addPlBindFormFields` at line 5967 in the HTML.
    d.test = null;
    if (d.errors.containsKey(fieldId)) {
      d.errors = Map.of(d.errors)..remove(fieldId);
    }
    notifyListeners();
  }

  void setAddPlaylistShowPass(bool show) {
    if (addPlaylist.showPass == show) return;
    addPlaylist.showPass = show;
    notifyListeners();
  }

  /// Mirrors `addPlValidate()` (line 5754). Writes into [NsAddPlaylistDraft.errors]
  /// and returns true when the draft is valid.
  bool validateAddPlaylist() {
    final d = addPlaylist;
    final errs = <String, String>{};
    final urlRegex = RegExp(r'^https?://', caseSensitive: false);
    if (d.type == 'xtream') {
      if (d.xtServer.trim().isEmpty) {
        errs['server'] = 'Server URL is required';
      } else if (!urlRegex.hasMatch(d.xtServer.trim())) {
        errs['server'] = 'Must start with http:// or https://';
      }
      if (d.xtUser.trim().isEmpty) errs['user'] = 'Username is required';
      if (d.xtPass.isEmpty) errs['pass'] = 'Password is required';
      if (d.xtName.trim().isEmpty) errs['name'] = 'Give this playlist a name';
    } else {
      if (d.m3uName.trim().isEmpty) {
        errs['name'] = 'Give this playlist a name';
      }
      if (d.m3uUrl.trim().isEmpty) {
        errs['url'] = 'M3U URL is required';
      } else if (!urlRegex.hasMatch(d.m3uUrl.trim())) {
        errs['url'] = 'Must start with http:// or https://';
      }
    }
    d.errors = errs;
    notifyListeners();
    return errs.isEmpty;
  }

  /// Mock test-connection — ports `addPlRunTest()` (line 5995). If the
  /// draft is invalid, writes errors and returns `false`. Otherwise
  /// flips [NsAddPlaylistDraft.test] to pending, waits ~900 ms, then
  /// lands on a success result with fake counts.
  Future<bool> runAddPlaylistTest() async {
    if (!validateAddPlaylist()) return false;
    final d = addPlaylist;
    d.test = NsAddPlaylistTest(status: NsAddPlaylistTestStatus.pending);
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Bail if the user already dismissed the wizard.
    if (addPlaylist != d) return false;
    d.test = NsAddPlaylistTest(
      status: NsAddPlaylistTestStatus.ok,
      counts: d.type == 'xtream'
          ? const {'live': 142, 'vod': 4380, 'series': 612}
          : const {'live': 86},
    );
    notifyListeners();
    return true;
  }

  Future<void> addPlaylistFromDraft() async {
    final d = addPlaylist;
    if (!validateAddPlaylist()) return;
    final c = d.test?.counts;
    final live = c?['live'] ?? 0;
    final vod = c?['vod'] ?? 0;
    final series = c?['series'] ?? 0;
    try {
      if (d.type == 'xtream') {
        await libraryController.addPlaylist(
          draft: PlaylistDraft.xtream(
            name: d.xtName.isNotEmpty ? d.xtName : d.xtUser,
            username: d.xtUser,
            password: d.xtPass,
            serverUrl: d.xtServer,
          ),
          liveCount: live,
          moviesCount: vod,
          seriesCount: series,
        );
      } else {
        await libraryController.addPlaylist(
          draft: PlaylistDraft.m3u(
            name: d.m3uName,
            m3uUrl: d.m3uUrl,
          ),
          liveCount: live,
          moviesCount: 0,
          seriesCount: 0,
        );
      }
    } catch (e, st) {
      debugPrint('NewSettingsState.addPlaylistFromDraft: $e\n$st');
      return;
    }
    addPlaylist.reset();
    _rebuildPlaylistCache();
    notifyListeners();
  }

  /// Set a single playlist as active — mirrors legacy `plActivate`.
  void setActivePlaylist(String id) {
    unawaited(
      libraryController.setActivePlaylist(id).then((_) {
        _rebuildPlaylistCache();
        notifyListeners();
      }),
    );
  }

  /// Mutate the appearance sub-state and fire one rebuild. Example:
  ///
  ///     state.setAppearance((a) => a.liveTvHero = 42);
  ///
  /// Keeps the appearance sub-object as a plain value type while letting
  /// callers write natural mutations without worrying about change
  /// notifications.
  // ── Account helpers ────────────────────────────────────────────────
  //
  // The new account page used to drive a local `NsAccount` mock. It's
  // now bridged to the real app's [accountStore] + [accountApi] (the
  // same source of truth the old ACC overlay in `account_overlay.dart`
  // uses). UI code still reads `account.data` / `account.tab` / etc.,
  // but every mutator below calls the real API and re-pulls live data.
  //
  // The old ACC overlay file is NOT touched — both surfaces read / write
  // the same backend.

  /// Cached profile JSON from `accountApi.getMe()` and raw device list
  /// from `accountApi.getDevices()`. Re-pulled on login / logout / after
  /// every profile / device mutation. Private because callers should
  /// read through `account.data` instead.
  Map<String, dynamic>? _accountProfile;
  List<dynamic> _accountDevicesRaw = const [];

  /// True once the first load attempt has completed (success or failure).
  bool _accountLoaded = false;
  bool get accountLoaded => _accountLoaded;

  /// Last network error from `getMe()` / `getDevices()` — null on success.
  String? _accountError;
  String? get accountError => _accountError;

  /// Called when [accountStore] notifies a change (token refresh, sign
  /// in, sign out). If the logged-in state flipped, we either load live
  /// data or reset to guest immediately.
  void _onAccountStoreChanged() {
    _syncAccountFromStore();
    if (accountStore.isLoggedIn) {
      _reloadAccountLive();
    } else {
      _accountProfile = null;
      _accountDevicesRaw = const [];
      _accountError = null;
    }
    notifyListeners();
  }

  /// Pull `accessGate.lastResult` + `accountStore.user` into the
  /// exported `account.data` NsAccount without hitting the network.
  /// This paints the UI immediately based on cached auth state — the
  /// network reload below fills in `profile` / `devices` afterwards.
  void _syncAccountFromStore() {
    final isLoggedIn = accountStore.isLoggedIn;
    final user = accountStore.user ?? const {};
    final gate = accessGate.lastResult;

    String fullName;
    if (isLoggedIn) {
      final profileName = _accountProfile?['name']?.toString();
      final storedName = user['name']?.toString();
      final email = (user['email'] ?? '').toString();
      if (profileName != null && profileName.isNotEmpty) {
        fullName = profileName;
      } else if (storedName != null && storedName.isNotEmpty) {
        fullName = storedName;
      } else if (email.isNotEmpty) {
        fullName = email.split('@').first;
      } else {
        fullName = 'User';
      }
    } else {
      fullName = 'Guest';
    }

    final email = isLoggedIn
        ? (user['email']?.toString() ?? '')
        : '';
    final initials = _computeInitials(fullName);
    final role = _capitalize(
      (_accountProfile?['role'] ?? user['role'] ?? 'User').toString(),
    );
    final status = (_accountProfile?['status'] ?? 'active').toString();

    String memberSince = '—';
    final created = _accountProfile?['createdAt'] ??
        _accountProfile?['created_at'] ??
        user['createdAt'];
    if (created != null) {
      final d = DateTime.tryParse(created.toString());
      if (d != null) memberSince = _formatMemberSince(d);
    }

    final limitRaw = _accountProfile?['deviceLimit'] ?? 5;
    final deviceLimit =
        limitRaw is int ? limitRaw : int.tryParse(limitRaw.toString()) ?? 5;

    // Build live device list — labels / lastSeen / type from server,
    // `current` matched against the local deviceId from secure storage.
    final myDeviceId = accountStore.deviceId;
    final devices = <NsAccDevice>[];
    for (final d in _accountDevicesRaw) {
      if (d is! Map) continue;
      final m = Map<String, dynamic>.from(d);
      final id = (m['id'] ?? m['deviceId'] ?? '').toString();
      if (id.isEmpty) continue;
      devices.add(NsAccDevice(
        id: id,
        label: (m['label'] ?? m['name'] ?? 'Unnamed device').toString(),
        type: NsAccDeviceTypeStorage.parse(
          (m['type'] ?? m['platform'] ?? 'unknown').toString().toLowerCase(),
        ),
        lastSeen:
            (m['lastSeen'] ?? m['last_seen'] ?? '').toString(),
        current: id == myDeviceId,
      ));
    }

    // Short device id prefix (like the old ACC page: `d9f3e21a`).
    final shortId = (myDeviceId ?? '')
        .replaceAll('-', '')
        .padRight(8, '0')
        .substring(0, 8);

    // Trial vs paid — mirrors the old overlay's `_isTrial`.
    final accessUntil =
        _accountProfile?['accessGrantedUntil']?.toString() ??
            gate?.accessGrantedUntil;
    final trialEndsAt =
        _accountProfile?['trialEndsAt']?.toString() ?? gate?.trialEndsAt;
    final isTrial = accessUntil == null || accessUntil.isEmpty;

    account.data
      ..isLoggedIn = isLoggedIn
      ..name = fullName
      ..email = email
      ..initials = initials.isEmpty ? (isLoggedIn ? 'U' : 'G') : initials
      ..role = role
      ..status = status
      ..memberSince = memberSince
      ..deviceId = shortId
      ..isTrial = isTrial
      ..accessUntil = accessUntil
      ..trialEndsAt = trialEndsAt
      ..googleLinked =
          (_accountProfile?['googleLinked'] ?? false) == true ||
              user['googleLinked'] == true
      ..deviceLimit = deviceLimit
      ..devices = devices;
  }

  /// Fetch `/v1/me` + `/v1/me/devices` in parallel (exactly the same
  /// pair the old ACC overlay uses) and rebuild `account.data` from the
  /// results. Failures are captured in [_accountError] — the UI falls
  /// back to whatever we already have.
  Future<void> _reloadAccountLive() async {
    if (!accountStore.isLoggedIn) {
      _accountLoaded = true;
      notifyListeners();
      return;
    }
    try {
      final results = await Future.wait([
        accountApi.getMe(),
        accountApi.getDevices(),
      ]);
      _accountProfile = results[0] as Map<String, dynamic>;
      _accountDevicesRaw = results[1] as List<dynamic>;
      _accountError = null;
    } catch (e) {
      _accountError = e.toString();
    } finally {
      _accountLoaded = true;
      _syncAccountFromStore();
      notifyListeners();
    }
  }

  /// Manual reload, e.g. after a sign-in success callback.
  Future<void> reloadAccount() => _reloadAccountLive();

  String _computeInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0])
        .join()
        .toUpperCase();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatMemberSince(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // ── Tab / duration ────────────────────────────────────────────────

  void setAccountTab(String tab) {
    if (account.tab == tab) return;
    account.tab = tab;
    notifyListeners();
  }

  void setAccountDuration(String id) {
    if (account.selectedDuration == id) return;
    account.selectedDuration = id;
    notifyListeners();
  }

  // ── Authentication ────────────────────────────────────────────────
  //
  // Sign in itself is a navigation concern (pushes [AuthGateScreen]) so
  // it stays in the page — see `account_page.dart`. What we expose here
  // is the post-auth refresh so the UI re-paints after login, plus the
  // sign-out path that the old overlay uses.

  /// Log the user out — calls `accountApi.logout` with the stored
  /// refresh token (best-effort), then clears local auth and re-syncs
  /// the visible account state. Same flow as the old ACC overlay.
  Future<void> accountSignOut() async {
    try {
      final rt = accountStore.refreshToken;
      if (rt != null) await accountApi.logout(rt);
    } catch (_) {
      // Ignore — server-side logout is best-effort; we always clear local auth.
    }
    await accountStore.clearAuth();
    // [accountStore] fires a listener → `_onAccountStoreChanged` will
    // rebuild the account state and trigger a notify. We also trigger
    // an access re-check so paywall / freemium state updates immediately.
    unawaited(accessGate.check());
  }

  // ── Google link placeholder ───────────────────────────────────────
  //
  // The old overlay shows a "Google link coming soon" snackbar — mirror
  // that contract here: we flip the `googleLinked` flag locally so the
  // UI re-paints, but there's no real /auth/google/link endpoint yet.
  // The button's visible action is the snackbar shown at the page level.

  /// Kept for UI compatibility — sets the local flag. Real linking will
  /// be wired when the backend adds the endpoint.
  void accountSetGoogleLinked(bool linked) {
    account.data.googleLinked = linked;
    notifyListeners();
  }

  // ── Profile ───────────────────────────────────────────────────────

  /// Rename the signed-in user — `PATCH /v1/me` with `{name}`, same as
  /// `account_overlay._editName`. On success we merge the response into
  /// the stored user blob and trigger a full reload so the UI picks up
  /// any server-side normalisation (e.g. trimmed whitespace).
  Future<void> accountRenameSelf(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    if (!accountStore.isLoggedIn) {
      // Offline fallback — keep the local mock behaviour so the UI
      // still responds (e.g. during development without a backend).
      account.data.name = trimmed;
      final ini = _computeInitials(trimmed);
      if (ini.isNotEmpty) account.data.initials = ini;
      notifyListeners();
      return;
    }
    try {
      final updated = await accountApi.updateProfile(name: trimmed);
      await accountStore.saveUser({
        ...?accountStore.user,
        ...updated,
      });
      await _reloadAccountLive();
    } catch (e) {
      _accountError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Devices ───────────────────────────────────────────────────────

  /// Rename a linked device — `PATCH /v1/me/devices/:id` (same call as
  /// `account_overlay._promptRenameDevice`).
  Future<void> accountRenameDevice(String id, String newLabel) async {
    final trimmed = newLabel.trim();
    if (trimmed.isEmpty) return;
    if (!accountStore.isLoggedIn) {
      for (final d in account.data.devices) {
        if (d.id == id) {
          d.label = trimmed;
          notifyListeners();
          return;
        }
      }
      return;
    }
    try {
      await accountApi.renameDevice(id, trimmed);
      await _reloadAccountLive();
    } catch (e) {
      _accountError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Remove a linked device — `DELETE /v1/me/devices/:id` (same call as
  /// `account_overlay._confirmRemoveDevice`). Current device is
  /// protected so you can't accidentally unlink the TV you're on.
  Future<void> accountRemoveDevice(String id) async {
    if (!accountStore.isLoggedIn) {
      final before = account.data.devices.length;
      account.data.devices.removeWhere(
        (d) => d.id == id && !d.current,
      );
      if (account.data.devices.length != before) notifyListeners();
      return;
    }
    try {
      await accountApi.removeDevice(id);
      await _reloadAccountLive();
    } catch (e) {
      _accountError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void setAppearance(void Function(NsAppearanceState a) mutate) {
    mutate(appearance);
    _pushAppearanceToStores();
  }

  /// Pull appearance fields from every backing store into [appearance].
  /// Safe to call even before a store has finished [ensureLoaded] —
  /// stores simply return their default value in that window.
  void _pullAppearanceFromStores() {
    appearance
      ..liveTvHero = liveTvHeroLayoutStore.heroHeightPercent
      ..liveTvCols = liveTvGridColumnsStore.columns
      ..liveTvCardStyle = _liveTvStyleToNsId(liveTvCardStyleStore.style)
      ..moviesPerRow = movieRailPageSizeStore.size
      ..moviesCardStyle =
          _mediaStyleToNsId(mediaCardStyleStore.movieStyle)
      ..seriesPerRow = seriesRailPageSizeStore.size
      ..seriesCardStyle =
          _mediaStyleToNsId(mediaCardStyleStore.seriesStyle);
  }

  void _onAppearanceStoreChanged() {
    _pullAppearanceFromStores();
    notifyListeners();
  }

  void _pushAppearanceToStores() {
    liveTvHeroLayoutStore.setHeroHeightPercent(appearance.liveTvHero);
    liveTvGridColumnsStore.setColumns(appearance.liveTvCols);
    liveTvCardStyleStore
        .setStyle(_nsIdToLiveTvStyle(appearance.liveTvCardStyle));
    movieRailPageSizeStore.setSize(appearance.moviesPerRow);
    seriesRailPageSizeStore.setSize(appearance.seriesPerRow);
    mediaCardStyleStore
        .setMovieStyle(_nsIdToMediaStyle(appearance.moviesCardStyle));
    mediaCardStyleStore
        .setSeriesStyle(_nsIdToMediaStyle(appearance.seriesCardStyle));
  }

  // ── Appearance style mappings ──────────────────────────────────────
  // New-settings option ids ↔ real-store enums.

  static String _liveTvStyleToNsId(LiveTvCardStyle s) => switch (s) {
        LiveTvCardStyle.nameOnly => 'nameOnly',
        LiveTvCardStyle.logoNameEpg => 'logoNameEpg',
        LiveTvCardStyle.logoNameOnly => 'logoName',
        LiveTvCardStyle.logoOnly => 'logoOnly',
      };

  static LiveTvCardStyle _nsIdToLiveTvStyle(String id) => switch (id) {
        'nameOnly' => LiveTvCardStyle.nameOnly,
        'logoNameEpg' => LiveTvCardStyle.logoNameEpg,
        'logoName' => LiveTvCardStyle.logoNameOnly,
        'logoOnly' => LiveTvCardStyle.logoOnly,
        _ => LiveTvCardStyle.logoNameEpg,
      };

  /// HTML options are `poster | posterTitle | posterTitleYear`.
  /// Real store enum has four values — we map:
  ///   `poster`          → posterOnly
  ///   `posterTitle`     → posterAndName   (poster + name overlay)
  ///   `posterTitleYear` → posterAndTitle  (poster + title + year/meta)
  static String _mediaStyleToNsId(MediaPosterCardStyle s) => switch (s) {
        MediaPosterCardStyle.posterOnly => 'poster',
        MediaPosterCardStyle.posterAndName => 'posterTitle',
        MediaPosterCardStyle.posterAndTitle => 'posterTitleYear',
        MediaPosterCardStyle.titleOnly => 'posterTitleYear',
      };

  static MediaPosterCardStyle _nsIdToMediaStyle(String id) => switch (id) {
        'poster' => MediaPosterCardStyle.posterOnly,
        'posterTitle' => MediaPosterCardStyle.posterAndName,
        'posterTitleYear' => MediaPosterCardStyle.posterAndTitle,
        _ => MediaPosterCardStyle.posterAndTitle,
      };

  /// Mutate clock sub-state + push every changed field through to
  /// [clockOverlaySettingsStore]. The store's own listener will fire
  /// [_onClockStoreChanged], which notifies us in turn — we don't
  /// call [notifyListeners] directly here to avoid double-rebuilds.
  void setClock(void Function(NsClockState c) mutate) {
    mutate(clock);
    _pushClockToStore();
  }

  /// Reset the clock overlay to factory defaults.
  void resetClockDefaults() {
    clock
      ..enabled = false
      ..fmt = '24'
      ..sizePx = 19
      ..framed = true
      ..corner = 'tr'
      ..opacity = 100
      ..color = '#7DD3FC'
      ..offsets['tl'] = (x: 0, y: 0)
      ..offsets['tr'] = (x: 0, y: 0)
      ..offsets['bl'] = (x: 0, y: 0)
      ..offsets['br'] = (x: 0, y: 0);
    _pushClockToStore();
  }

  /// Re-center the clock in the currently active corner (zero the offsets).
  void clockRecenterActiveCorner() {
    clock.offsets[clock.corner] = (x: 0, y: 0);
    _pushClockToStore();
  }

  /// Nudge the active corner's offset by ±N logical px on either axis.
  /// Clamped to a sane range so the clock never sails off-screen.
  void clockNudge({int dx = 0, int dy = 0}) {
    final c = clock.offsets[clock.corner] ?? (x: 0, y: 0);
    const limit = 60;
    final nx = (c.x + dx).clamp(-limit, limit);
    final ny = (c.y + dy).clamp(-limit, limit);
    clock.offsets[clock.corner] = (x: nx, y: ny);
    _pushClockToStore();
  }

  /// Push current [clock] field values into [clockOverlaySettingsStore].
  /// Each `setX` call only fires if the value actually changed, so the
  /// store's listener doesn't thrash.
  void _pushClockToStore() {
    final s = clockOverlaySettingsStore;
    s.setEnabled(clock.enabled);
    s.setUse24Hour(clock.fmt == '24');
    s.setSize(_sizePxToPreset(clock.sizePx));
    s.setFramed(clock.framed);
    s.setCorner(_storageToCorner(clock.corner));
    s.setOpacity(clock.opacity / 100.0);
    s.setColorIndex(_colorHexToIndex(clock.color));
    for (final c in ClockCorner.values) {
      final o = clock.offsets[c.storageValue] ?? (x: 0, y: 0);
      s.setCornerOffset(
        c,
        Offset(o.x.toDouble(), o.y.toDouble()),
      );
    }
  }

  // ── Clock enum / color helpers ─────────────────────────────────────

  static ClockSizePreset _sizePxToPreset(int px) {
    if (px <= 16) return ClockSizePreset.small;
    if (px <= 21) return ClockSizePreset.medium;
    return ClockSizePreset.large;
  }

  static ClockCorner _storageToCorner(String raw) => switch (raw) {
        'tl' => ClockCorner.topLeft,
        'tr' => ClockCorner.topRight,
        'bl' => ClockCorner.bottomLeft,
        'br' => ClockCorner.bottomRight,
        _ => ClockCorner.topRight,
      };

  static String _colorIndexToHex(int i) {
    final clamped = i.clamp(
      0,
      ClockOverlaySettingsStore.presetColors.length - 1,
    );
    final c = ClockOverlaySettingsStore.presetColors[clamped];
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '#'
            '${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static int _colorHexToIndex(String hex) {
    final h = hex.replaceFirst('#', '').toUpperCase();
    if (h.length != 6) return 0;
    for (var i = 0;
        i < ClockOverlaySettingsStore.presetColors.length;
        i++) {
      final c = ClockOverlaySettingsStore.presetColors[i];
      final r = (c.r * 255.0).round().clamp(0, 255);
      final g = (c.g * 255.0).round().clamp(0, 255);
      final b = (c.b * 255.0).round().clamp(0, 255);
      final candidate = '${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
      if (candidate == h) return i;
    }
    return 0;
  }

  /// Summary string for the Look & Feel "Appearance" row. Mirrors
  /// `apSummary()` at settings.html line 5246.
  String appearanceSummary() {
    final a = appearance;
    final style = switch (a.liveTvCardStyle) {
      'nameOnly' => 'Name only',
      'logoNameEpg' => 'Logo + name + EPG',
      'logoName' => 'Logo + name',
      'logoOnly' => 'Logo only',
      _ => a.liveTvCardStyle,
    };
    return 'Live TV · Hero ${a.liveTvHero}% · ${a.liveTvCols} cols · $style';
  }

  /// Batch mutations (e.g. reset-all action) without firing a rebuild
  /// per change. Rebuilds exactly once when [batch] returns.
  void batch(VoidCallback mutate) {
    mutate();
    notifyListeners();
  }
}
