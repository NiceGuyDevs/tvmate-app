import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_session_restore_store.dart';
import '../../data/library_controller.dart';
import '../../data/live_favorite_channel_ref.dart';
import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_grid_columns_store.dart';
import '../../data/live_tv_name_horizontal_bias_store.dart';
import '../../data/live_tv_name_vertical_bias_store.dart';
import '../../data/live_epg_controller.dart';
import '../../data/live_favorite_groups_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/playlist_channel_override_store.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../l10n/app_localizations.dart';
import '../parental/parental_playback_guard.dart';
import '../settings/parental_scope_dialogs.dart';
import '../../data/playlist_live_catalog_cache.dart';
import '../../data/shell_search_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../player/live_lineup_item.dart';
import '../../player/player_navigation.dart';
import '../../shell/live_tv_session_snapshot.dart';
import '../../shell/shell_back_coordinator.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../shell/shell_destination.dart';
import '../catalog/catalog_status_widgets.dart';
import '../focus/tv_focusable.dart';
import '../tv_template_category_pill.dart';
import '../tv_template_pill_layout.dart';
import 'live_tv_channel_browse_tile.dart';
import 'live_tv_hero_audio_focus.dart';
import 'live_tv_hero_panel.dart';
import 'mock_live_tv_data.dart';

/// Channel grid columns (D-pad: row-major L/R, column-locked U/D).
/// Reads from [liveTvGridColumnsStore]; range 4–12, default 6.
int get _kLiveTvGridCrossAxisCount => liveTvGridColumnsStore.columns;
String get _liveSearchQuery => shellSearchStore.queryFor(ShellDestination.liveTv);

/// Sentinel for [LiveChannelBrowseTile.onDesktopTap] on Windows/macOS: enables
/// [TvFocusable] two-step mouse; hero still comes from focus via [onFocused].
void _liveTvGridDesktopTwoStepMouse() {}

/// Live TV layout: categories → hero (program preview) → 6-column channel grid.
/// Demo uses mock EPG on each channel; Xtream loads short EPG for the focused channel.
///
/// When [previewMode] is true (e.g. Appearance overlay), the screen is shown for
/// layout preview only: it does not register with the shell focus/back system, and
/// the widget must be wrapped in [ExcludeFocus] / [IgnorePointer] by the parent.
class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key, this.previewMode = false});

  /// Embedded in Appearance: visual-only; no shell focus or back handling.
  final bool previewMode;

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  late String _selectedCategoryId;
  late final ValueNotifier<MockLiveChannel> _heroChannel;
  final _gridScrollController = ScrollController();
  late List<FocusNode> _categoryFocusNodes;
  late final FocusNode _shellCategoryFallbackFocus;
  List<FocusNode> _channelGridFocusNodes = [];
  String? _lastLiveSearchNotified;
  List<GlobalKey> _channelGridItemKeys = [];
  /// True after we scheduled shell focus for the first main Live TV layout (may be before grid exists).
  var _didBootstrapShellFocus = false;

  int _categoryApplyEpoch = 0;
  Timer? _epgFocusDebounce;

  /// After switching category (e.g. D-pad Left from index 0), focus last channel.
  bool _focusLastGridItemAfterCategoryChange = false;

  /// While true, category pills cannot take focus (avoids a visible flash before
  /// the channel tile is refocused after the player closes).
  bool _suppressCategoryFocusForRestore = false;

  /// True when cold-start restore opened the live player (skip shell focus request).
  var _sessionRestoreOpenedFullscreenPlayer = false;

  /// Playlist categories only (no synthetic “My favorites” pill).
  List<MockLiveCategory> get _sourceCategories {
    const allPill = MockLiveCategory(
      id: kLiveTvAllCategoryId,
      name: 'All',
    );
    if (libraryController.useDemoData) {
      return kMockLiveCategories;
    }
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) {
      return [
        allPill,
        ...xtreamCatalogRepository.liveCategories,
      ];
    }
    final rest = xtreamCatalogRepository.liveCategories
        .where(
          (c) => playlistGroupVisibilityStore.isCategoryVisible(
            playlistId,
            PlaylistGroupSection.live,
            c.id,
          ),
        )
        .map(
          (c) => MockLiveCategory(
            id: c.id,
            name: playlistGroupVisibilityStore.categoryDisplayName(
              playlistId,
              PlaylistGroupSection.live,
              c.id,
              c.name,
            ),
          ),
        )
        .toList(growable: false);
    return [allPill, ...rest];
  }

  /// Favorite groups (sorted), optional **playlist categories before favorites**, then the rest.
  List<MockLiveCategory> get _categoryPills {
    final merged = _mergedCategoryPillsRaw();
    if (!parentalControlStore.shouldFilterLiveBrowseForParental) {
      return merged;
    }
    return merged
        .where((cat) => _channelsFor(cat.id).isNotEmpty)
        .toList(growable: false);
  }

  List<MockLiveCategory> _mergedCategoryPillsRaw() {
    final favs = LiveFavoriteGroupsStore.instance.groupsSorted
        .map(
          (g) => MockLiveCategory(id: g.id, name: g.name),
        )
        .toList(growable: false);
    final playlistId = libraryController.activePlaylistId;
    if (libraryController.useDemoData || playlistId == null) {
      return [...favs, ..._sourceCategories];
    }
    final beforeIds =
        playlistGroupVisibilityStore.liveBeforeFavoritesOrderedIds(playlistId);
    final beforeSet = beforeIds.toSet();
    final source = _sourceCategories;
    final beforeCats = <MockLiveCategory>[];
    for (final id in beforeIds) {
      for (final c in source) {
        if (c.id == id) {
          beforeCats.add(c);
          break;
        }
      }
    }
    final afterCats =
        source.where((c) => !beforeSet.contains(c.id)).toList(growable: false);
    return [...beforeCats, ...favs, ...afterCats];
  }

  MockLiveChannel? _resolveFavoriteChannel(LiveFavoriteChannelRef ref) {
    if (libraryController.useDemoData) {
      for (final c in kMockLiveChannels) {
        if (c.id == ref.channelId) return c;
      }
      return null;
    }
    if (ref.isLegacy) {
      for (final c in xtreamCatalogRepository.liveChannelsAll) {
        if (c.id == ref.channelId) return c;
      }
      return null;
    }
    final cached =
        playlistLiveCatalogCache.channelById(ref.playlistId, ref.channelId);
    if (cached != null) return cached;
    if (ref.playlistId == libraryController.activePlaylistId) {
      for (final c in xtreamCatalogRepository.liveChannelsAll) {
        if (c.id == ref.channelId) return c;
      }
    }
    return null;
  }

  List<MockLiveChannel> _channelsForFavoriteGroup(LiveFavoriteGroup g) {
    final out = <MockLiveChannel>[];
    for (final ref in g.channelRefs) {
      final ch = _resolveFavoriteChannel(ref);
      if (ch == null) continue;
      if (playlistChannelOverrideStore.isHidden(ref.playlistId, ch.id)) {
        continue;
      }
      out.add(playlistChannelOverrideStore.apply(ref.playlistId, ch));
    }
    return out;
  }

  /// Custom names / logos; drop hidden channels for Live TV (per playlist).
  List<MockLiveChannel> _applyChannelPresentation(
    List<MockLiveChannel> raw,
    String? playlistId,
  ) {
    if (playlistId == null || libraryController.useDemoData) return raw;
    return raw
        .where(
          (c) => !playlistChannelOverrideStore.isHidden(playlistId, c.id),
        )
        .map((c) => playlistChannelOverrideStore.apply(playlistId, c))
        .toList();
  }

  void _refreshEpgForChannel(MockLiveChannel ch) {
    if (ch.isCatalogLoadingPlaceholder) return;
    LiveEpgController.instance.refreshForStream(
      ch.id,
      epgChannelId: ch.epgChannelId,
    );
  }

  List<MockLiveChannel> _channelsFor(String categoryId) {
    final favGroup = LiveFavoriteGroupsStore.instance.groupById(categoryId);
    late final List<MockLiveChannel> base;
    if (favGroup != null) {
      base = _channelsForFavoriteGroup(favGroup);
    } else if (libraryController.useDemoData) {
      base = mockChannelsForCategory(categoryId);
    } else {
      final raw = categoryId == kLiveTvAllCategoryId
          ? xtreamCatalogRepository.liveChannelsAll
          : xtreamCatalogRepository.liveChannelsForCategory(categoryId);
      base = _applyChannelPresentation(
        raw,
        libraryController.activePlaylistId,
      );
    }
    return _filterParentalHiddenLive(base, categoryId);
  }

  List<MockLiveChannel> _filterParentalHiddenLive(
    List<MockLiveChannel> channels,
    String viewCategoryId,
  ) {
    if (!parentalControlStore.shouldFilterLiveBrowseForParental) {
      return channels;
    }
    final pid = libraryController.activePlaylistId;
    return channels
        .where(
          (c) => !parentalControlStore.isLiveHiddenFromBrowse(
            playlistId: pid,
            viewCategoryId: viewCategoryId,
            channelId: c.id,
            channelCategoryId: c.categoryId,
          ),
        )
        .toList(growable: false);
  }

  List<MockLiveChannel> _channelsForCurrentView() {
    if (_liveSearchQuery.isEmpty) {
      return _channelsFor(_selectedCategoryId);
    }
    final q = _liveSearchQuery.toLowerCase();
    final out = <MockLiveChannel>[];
    final seen = <String>{};
    for (final cat in _categoryPills) {
      for (final ch in _channelsFor(cat.id)) {
        if (!seen.add(ch.id)) continue;
        if (ch.name.toLowerCase().contains(q)) {
          out.add(ch);
        }
      }
    }
    return out;
  }

  void _applyHeroWhenGridEmpty() {
    final src = _sourceCategories;
    if (src.isEmpty) return;
    final chs = _channelsFor(src.first.id);
    if (chs.isNotEmpty) {
      _heroChannel.value = chs.first;
      _refreshEpgForChannel(chs.first);
    }
  }

  String _livePlayUrl(MockLiveChannel c) => heroLiveStreamUrl(c);

  @override
  void initState() {
    super.initState();
    // Must match [_categoryPills] length (includes favorite groups).
    final src = _sourceCategories;
    final nodeCount = _categoryPills.length;
    _categoryFocusNodes = List.generate(
      nodeCount,
      (i) => FocusNode(debugLabel: 'liveTvCat$i'),
    );
    _shellCategoryFallbackFocus =
        FocusNode(debugLabel: 'liveTvShellFallback');
    _selectedCategoryId = src.isNotEmpty
        ? src.first.id
        : (LiveFavoriteGroupsStore.instance.groupsSorted.isNotEmpty
            ? LiveFavoriteGroupsStore.instance.groupsSorted.first.id
            : '');
    final initialChannels = _channelsFor(_selectedCategoryId);
    final MockLiveChannel initialHero;
    if (initialChannels.isNotEmpty) {
      initialHero = initialChannels.first;
    } else if (libraryController.useDemoData) {
      initialHero = mockChannelsForCategory(kMockLiveCategories.first.id).first;
    } else {
      initialHero = kLiveTvCatalogLoadingHero;
    }
    _heroChannel = ValueNotifier(initialHero);
    _heroChannel.addListener(_syncHeroToLiveSessionSnapshot);
    libraryController.addListener(_onCatalogChanged);
    xtreamCatalogRepository.addListener(_onCatalogChanged);
    playlistGroupVisibilityStore.addListener(_onCatalogChanged);
    liveTvCardStyleStore.addListener(_onCatalogChanged);
    liveTvNameVerticalBiasStore.addListener(_onCatalogChanged);
    liveTvNameHorizontalBiasStore.addListener(_onCatalogChanged);
    liveTvGridColumnsStore.addListener(_onCatalogChanged);
    LiveFavoriteGroupsStore.instance.addListener(_onFavoriteGroupsChanged);
    shellSearchStore.addListener(_onCatalogChanged);
    playlistLiveCatalogCache.addListener(_onCatalogChanged);
    playlistChannelOverrideStore.addListener(_onCatalogChanged);
    parentalControlStore.addListener(_onCatalogChanged);
    if (!widget.previewMode) {
      ShellBackCoordinator.register(this, _tryConsumeShellBack);
      ShellContentFocusRegistry.register(
        ShellDestination.liveTv,
        _requestShellPrimaryFocus,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await playlistChannelOverrideStore.ensureLoaded();
      await LiveFavoriteGroupsStore.instance.ensureLoaded();
      await xtreamCatalogRepository.syncFromLibrary(libraryController);
      if (mounted) {
        final fav =
            LiveFavoriteGroupsStore.instance.groupById(_selectedCategoryId);
        if (fav != null && !libraryController.useDemoData) {
          final pids = fav.channelRefs
              .map((r) => r.playlistId)
              .where((p) => p.isNotEmpty)
              .toSet();
          for (final pid in pids) {
            await playlistLiveCatalogCache.ensurePlaylistLoaded(pid);
          }
        }
        _onCatalogChanged();
        _refreshEpgForChannel(_heroChannel.value);
        _prefetchEpgForVisibleChannels(_channelsFor(_selectedCategoryId));
        await _applyColdStartLiveRestoreIfNeeded();
        if (!mounted) return;
        // Same idea as [MoviesScreen._primeInitialFocus]: after catalog data exists,
        // schedule focus once layout + grid [FocusNode]s exist (cold start).
        if (!widget.previewMode && !_sessionRestoreOpenedFullscreenPlayer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ShellContentFocusRegistry.request(ShellDestination.liveTv);
            });
          });
        }
      }
    });
  }

  Future<void> _applyColdStartLiveRestoreIfNeeded() async {
    if (widget.previewMode) return;
    await AppSessionRestoreStore.instance.ensureLoaded();
    final r = AppSessionRestoreStore.instance;
    if (!r.hasLiveRestore) return;

    shellSearchStore.clear(ShellDestination.liveTv);

    final catId = r.liveCategoryId!;
    final chId = r.liveChannelId!;
    final wantFs = r.liveWasFullscreen;

    final pills = _categoryPills;
    if (pills.isEmpty || !pills.any((c) => c.id == catId)) return;

    final fav = LiveFavoriteGroupsStore.instance.groupById(catId);
    if (fav != null && !libraryController.useDemoData) {
      final pids =
          fav.channelRefs.map((r) => r.playlistId).where((p) => p.isNotEmpty).toSet();
      for (final pid in pids) {
        await playlistLiveCatalogCache.ensurePlaylistLoaded(pid);
      }
      if (!mounted) return;
      setState(() => _selectedCategoryId = catId);
      _finishCategoryActivationForRestore(catId, chId);
    } else {
      setState(() => _selectedCategoryId = catId);
      _finishCategoryActivationForRestore(catId, chId);
    }
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreLiveGridFocusByChannelId(chId);
      if (wantFs) {
        _tryOpenRestoredFullscreenPlayer(chId);
      }
    });
  }

  /// Retry up to 3 times to find the restored channel in the catalog before
  /// opening fullscreen. If the exact channel is never found, fall back to the
  /// first channel in the current category so the user still gets a live player.
  void _tryOpenRestoredFullscreenPlayer(String chId, {int attempt = 0}) {
    if (!mounted) return;
    final list = _channelsForCurrentView();
    MockLiveChannel? ch;
    for (final c in list) {
      if (c.id == chId) {
        ch = c;
        break;
      }
    }
    if (ch == null && attempt < 3) {
      // Catalog may still be loading; wait a frame and retry.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _tryOpenRestoredFullscreenPlayer(chId, attempt: attempt + 1);
        }
      });
      return;
    }
    // Fall back to the first channel in the category when the saved one is
    // no longer available (parental filter, playlist change, etc.).
    ch ??= list.isNotEmpty ? list.first : null;
    if (ch != null) {
      _sessionRestoreOpenedFullscreenPlayer = true;
      unawaited(
        _openLivePlayer(ch).then((_) {
          unawaited(
            AppSessionRestoreStore.instance.consumeLiveFullscreenRestore(),
          );
        }),
      );
    } else {
      unawaited(
        AppSessionRestoreStore.instance.consumeLiveFullscreenRestore(),
      );
    }
  }

  void _onFavoriteGroupsChanged() {
    if (!mounted) return;
    _onCatalogChanged();
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    final pills = _categoryPills;
    final newLen = pills.length;
    if (_categoryFocusNodes.length != newLen) {
      for (final n in _categoryFocusNodes) {
        n.dispose();
      }
      _categoryFocusNodes = List.generate(
        newLen,
        (i) => FocusNode(debugLabel: 'liveTvCat$i'),
      );
      _didBootstrapShellFocus = false;
    }
    if (pills.isNotEmpty) {
      if (!pills.any((c) => c.id == _selectedCategoryId)) {
        final src = _sourceCategories;
        final favs = LiveFavoriteGroupsStore.instance.groupsSorted;
        _selectedCategoryId = src.isNotEmpty
            ? src.first.id
            : (favs.isNotEmpty ? favs.first.id : '');
      }
      // After parental browse-hide, the current pill can have zero visible channels
      // while other pills still have rows — move selection so the grid stays usable.
      if (_liveSearchQuery.isEmpty &&
          _channelsFor(_selectedCategoryId).isEmpty) {
        for (final p in pills) {
          if (_channelsFor(p.id).isNotEmpty) {
            _selectedCategoryId = p.id;
            break;
          }
        }
      }
      final chs = _channelsForCurrentView();
      if (chs.isNotEmpty) {
        final cur = _heroChannel.value;
        MockLiveChannel? stillThere;
        for (final c in chs) {
          if (c.id == cur.id) {
            stillThere = c;
            break;
          }
        }
        if (stillThere == null) {
          _heroChannel.value = chs.first;
          _refreshEpgForChannel(chs.first);
        } else {
          _heroChannel.value = stillThere;
          _refreshEpgForChannel(stillThere);
        }
      } else if (LiveFavoriteGroupsStore.instance.groupById(_selectedCategoryId) !=
          null) {
        _applyHeroWhenGridEmpty();
      }
    }
    final q = _liveSearchQuery;
    if (q != (_lastLiveSearchNotified ?? '')) {
      _lastLiveSearchNotified = q;
      if (q.isNotEmpty && !widget.previewMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_channelGridFocusNodes.isNotEmpty) {
            _channelGridFocusNodes.first.requestFocus();
          }
        });
      }
    }
    setState(() {});
  }

  void _requestShellPrimaryFocus() {
    if (!mounted) return;
    resetDpadKeyRepeatTracking();
    void applyToGridOrCategory(int pass) {
      if (!mounted) return;
      final channels = _channelsForCurrentView();
      if (channels.isNotEmpty && _channelGridFocusNodes.isNotEmpty) {
        final n = _channelGridFocusNodes.first;
        if (n.canRequestFocus) n.requestFocus();
        if (!n.hasFocus && pass < 10) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => applyToGridOrCategory(pass + 1));
        } else if (!n.hasFocus) {
          requestLadderFocus(n);
        }
        return;
      }
      if (_categoryFocusNodes.isNotEmpty) {
        final n = _categoryFocusNodes.first;
        if (n.canRequestFocus) n.requestFocus();
        if (!n.hasFocus && pass < 10) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => applyToGridOrCategory(pass + 1));
        } else if (!n.hasFocus) {
          requestLadderFocus(n);
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyToGridOrCategory(0);
    });
  }

  /// Fallback when the first shell [request] ran before the grid existed.
  void _bootstrapShellFocusIfNeeded() {
    if (widget.previewMode) return;
    if (_didBootstrapShellFocus || !mounted) return;
    _didBootstrapShellFocus = true;
    resetDpadKeyRepeatTracking();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ShellContentFocusRegistry.request(ShellDestination.liveTv);
      });
    });
  }

  bool _tryConsumeShellBack() {
    if (!mounted) return false;
    if (shellSearchStore.hasQuery(ShellDestination.liveTv)) {
      shellSearchStore.clear(ShellDestination.liveTv);
      return true;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;

    // Top shell bar (tabs): let [MainShellScreen] handle Back / exit flow.
    if (ShellContentFocusRegistry.isTopNavNode(primary)) {
      return false;
    }

    // Category pill → Live TV tab (mute only via horizontal nav in top bar).
    for (final n in _categoryFocusNodes) {
      if (identical(primary, n)) {
        final top =
            ShellContentFocusRegistry.topNavFocus(ShellDestination.liveTv);
        if (top != null) requestLadderFocus(top);
        return true;
      }
    }

    // Channel tile → selected category pill.
    for (final n in _channelGridFocusNodes) {
      if (identical(primary, n)) {
        requestLadderFocus(_selectedCategoryFocusNode);
        return true;
      }
    }

    if (_categoryFocusNodes.isEmpty) return false;
    requestLadderFocus(_selectedCategoryFocusNode);
    return true;
  }

  @override
  void dispose() {
    if (!widget.previewMode) {
      ShellContentFocusRegistry.unregister(ShellDestination.liveTv);
      ShellBackCoordinator.unregister(this);
    }
    libraryController.removeListener(_onCatalogChanged);
    xtreamCatalogRepository.removeListener(_onCatalogChanged);
    playlistGroupVisibilityStore.removeListener(_onCatalogChanged);
    liveTvCardStyleStore.removeListener(_onCatalogChanged);
    liveTvNameVerticalBiasStore.removeListener(_onCatalogChanged);
    liveTvNameHorizontalBiasStore.removeListener(_onCatalogChanged);
    liveTvGridColumnsStore.removeListener(_onCatalogChanged);
    LiveFavoriteGroupsStore.instance.removeListener(_onFavoriteGroupsChanged);
    shellSearchStore.removeListener(_onCatalogChanged);
    playlistLiveCatalogCache.removeListener(_onCatalogChanged);
    playlistChannelOverrideStore.removeListener(_onCatalogChanged);
    parentalControlStore.removeListener(_onCatalogChanged);
    for (final n in _categoryFocusNodes) {
      n.dispose();
    }
    for (final n in _channelGridFocusNodes) {
      n.dispose();
    }
    _shellCategoryFallbackFocus.dispose();
    _gridScrollController.dispose();
    _heroChannel.removeListener(_syncHeroToLiveSessionSnapshot);
    _heroChannel.dispose();
    _epgFocusDebounce?.cancel();
    super.dispose();
  }

  int get _selectedCategoryIndex {
    final i = _categoryPills.indexWhere((c) => c.id == _selectedCategoryId);
    return i < 0 ? 0 : i;
  }

  FocusNode get _selectedCategoryFocusNode {
    if (_categoryFocusNodes.isEmpty) return _shellCategoryFallbackFocus;
    final i =
        _selectedCategoryIndex.clamp(0, _categoryFocusNodes.length - 1);
    return _categoryFocusNodes[i];
  }

  void _ensureChannelGridFocusResources(int count) {
    if (_channelGridFocusNodes.length == count) return;
    for (final n in _channelGridFocusNodes) {
      n.dispose();
    }
    _channelGridFocusNodes = List.generate(
      count,
      (i) => FocusNode(debugLabel: 'liveTvCh$i'),
    );
    _channelGridItemKeys = List.generate(
      count,
      (i) => GlobalKey(debugLabel: 'liveTvChK$i'),
    );
  }

  void _beginRestoreChannelFromPlayer() {
    if (_suppressCategoryFocusForRestore) return;
    setState(() => _suppressCategoryFocusForRestore = true);
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _suppressCategoryFocusForRestore = false);
    });
  }

  void _restoreLiveGridFocusByChannelId(
    String id, {
    int attempt = 0,
  }) {
    if (!mounted) return;
    if (attempt == 0) {
      _beginRestoreChannelFromPlayer();
    }
    final list = _channelsForCurrentView();
    final i = list.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _ensureChannelGridFocusResources(list.length);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (i >= _channelGridItemKeys.length) return;
      final ctx = _channelGridItemKeys[i].currentContext;
      final node = i < _channelGridFocusNodes.length
          ? _channelGridFocusNodes[i]
          : null;
      if ((ctx == null || node == null || !node.canRequestFocus) &&
          attempt < 6) {
        _restoreLiveGridFocusByChannelId(id, attempt: attempt + 1);
        return;
      }
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.0,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
      if (node != null && node.canRequestFocus) {
        node.requestFocus();
      }
      if (i < list.length) {
        _onChannelFocused(list[i]);
      }
      if (attempt == 0 && node != null) {
        scheduleSteadyChannelTileFocus(() => mounted, node);
      }
    });
  }

  Future<void> _openLivePlayer(MockLiveChannel ch) async {
    final channels = _channelsForCurrentView();
    if (channels.isEmpty) return;
    final ix = channels.indexWhere((c) => c.id == ch.id);
    final allowed = await ensureParentalAllowsLivePlayback(
      context,
      viewCategoryId: _selectedCategoryId,
      channelId: ch.id,
      channelCategoryId: ch.categoryId,
    );
    if (!allowed || !mounted) return;
    await openTvMatePlayer(
      context,
      title: ch.name,
      streamUrl: _livePlayUrl(ch),
      isLive: true,
      liveChannelId: ch.id,
      liveViewCategoryId: _selectedCategoryId,
      liveLineup: [
        for (final c in channels)
          LiveLineupItem(
            title: c.name,
            streamUrl: _livePlayUrl(c),
            channelId: c.id,
            epgChannelId: c.epgChannelId,
            iconUrl: c.iconUrl,
          ),
      ],
      initialLiveIndex: ix < 0 ? 0 : ix,
      suppressPreviousFocusRestore: true,
      onPlayerClosed: (restore) {
        if (!mounted) return;
        final id = restore?.liveChannelId;
        if (id == null) return;
        if (restore!.reopenLiveChannel) {
          _reopenLiveChannelAfterBackground(id);
          return;
        }
        _restoreLiveGridFocusByChannelId(id);
      },
    );
  }

  /// Re-opens the live player on [channelId] after the app returns from
  /// background. Finds the channel in the current view and opens it fresh.
  void _reopenLiveChannelAfterBackground(String channelId) {
    if (!mounted) return;
    final channels = _channelsForCurrentView();
    MockLiveChannel? ch;
    for (final c in channels) {
      if (c.id == channelId) {
        ch = c;
        break;
      }
    }
    ch ??= channels.isNotEmpty ? channels.first : null;
    if (ch != null) {
      unawaited(_openLivePlayer(ch));
    }
  }

  Future<void> _onParentalContextMenu(MockLiveChannel ch) async {
    await parentalControlStore.ensureLoaded();
    if (!parentalControlStore.enabled || !parentalControlStore.isPinConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).parentalMustEnableInSettings),
        ),
      );
      return;
    }
    final pid = libraryController.activePlaylistId ??
        ParentalControlStore.kDemoPlaylistId;
    await showLiveParentalScopeDialog(
      context,
      playlistId: pid,
      viewCategoryId: _selectedCategoryId,
      channelId: ch.id,
    );
  }

  String _xtreamErrorTitle() {
    switch (xtreamCatalogRepository.errorKind) {
      case XtreamBrowseErrorKind.auth:
        return 'Sign-in failed';
      case XtreamBrowseErrorKind.badUrl:
        return 'Invalid server or playlist';
      case XtreamBrowseErrorKind.network:
        return 'Connection problem';
      case XtreamBrowseErrorKind.unsupported:
        return 'Playlist not supported';
      case XtreamBrowseErrorKind.empty:
        return 'No content';
      case XtreamBrowseErrorKind.none:
        return 'Something went wrong';
    }
  }

  void _scheduleGridResetAndFocus({required bool focusLast}) {
    final epoch = ++_categoryApplyEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _categoryApplyEpoch) return;
      final channels = _channelsForCurrentView();
      if (focusLast && channels.isNotEmpty) {
        unawaited(_focusChannelGridIndex(channels.length - 1, channels));
        return;
      }
      if (_gridScrollController.hasClients) {
        _gridScrollController.jumpTo(0);
      }
      if (_channelGridFocusNodes.isNotEmpty &&
          _channelGridFocusNodes.first.canRequestFocus) {
        _channelGridFocusNodes.first.requestFocus();
      }
    });
  }

  void _onCategoryActivated(String id) {
    setState(() => _selectedCategoryId = id);
    final fav = LiveFavoriteGroupsStore.instance.groupById(id);
    if (fav != null && !libraryController.useDemoData) {
      unawaited(_preloadFavoriteThenFinish(id, fav));
      return;
    }
    _finishCategoryActivation(id);
  }

  void _finishCategoryActivation(String id) {
    final focusLast = _focusLastGridItemAfterCategoryChange;
    _focusLastGridItemAfterCategoryChange = false;
    final list = _channelsFor(id);
    if (list.isNotEmpty) {
      final ch = focusLast ? list.last : list.first;
      _heroChannel.value = ch;
      _refreshEpgForChannel(ch);
      _prefetchEpgForVisibleChannels(list);
      if (!widget.previewMode) {
        LiveTvSessionSnapshot.update(categoryId: id, channelId: ch.id);
      }
    } else {
      _applyHeroWhenGridEmpty();
    }
    _scheduleGridResetAndFocus(focusLast: focusLast);
  }

  void _prefetchEpgForVisibleChannels(List<MockLiveChannel> channels) {
    if (libraryController.useDemoData) return;
    final limit = (_kLiveTvGridCrossAxisCount * 4).clamp(0, channels.length);
    for (var i = 0; i < limit; i++) {
      final ch = channels[i];
      if (ch.isCatalogLoadingPlaceholder) continue;
      LiveEpgController.instance.prefetchForStream(
        ch.id,
        epgChannelId: ch.epgChannelId,
      );
    }
  }

  /// Session cold-start restore: pick [channelId] for hero and **do not** auto-focus
  /// tile 0 (avoids racing [ _restoreLiveGridFocusByChannelId ]).
  void _finishCategoryActivationForRestore(String categoryId, String channelId) {
    final list = _channelsFor(categoryId);
    if (list.isEmpty) {
      _applyHeroWhenGridEmpty();
      return;
    }
    MockLiveChannel hero = list.first;
    for (final c in list) {
      if (c.id == channelId) {
        hero = c;
        break;
      }
    }
    _heroChannel.value = hero;
    _refreshEpgForChannel(hero);
    _prefetchEpgForVisibleChannels(list);
    if (!widget.previewMode) {
      LiveTvSessionSnapshot.update(categoryId: categoryId, channelId: hero.id);
    }
  }

  void _syncHeroToLiveSessionSnapshot() {
    if (widget.previewMode) return;
    final ch = _heroChannel.value;
    LiveTvSessionSnapshot.update(
      categoryId: _selectedCategoryId,
      channelId: ch.id,
    );
  }

  Future<void> _preloadFavoriteThenFinish(
    String categoryId,
    LiveFavoriteGroup fav,
  ) async {
    final pids =
        fav.channelRefs.map((r) => r.playlistId).where((p) => p.isNotEmpty).toSet();
    for (final pid in pids) {
      await playlistLiveCatalogCache.ensurePlaylistLoaded(pid);
    }
    if (!mounted || _selectedCategoryId != categoryId) return;
    setState(() {});
    _finishCategoryActivation(categoryId);
  }

  void _onChannelFocused(MockLiveChannel ch) {
    if (!widget.previewMode) {
      LiveTvSessionSnapshot.update(
        categoryId: _selectedCategoryId,
        channelId: ch.id,
      );
    }
    if (_heroChannel.value.id != ch.id) {
      _heroChannel.value = ch;
    }
    // Debounce EPG/network work so rapid D-pad does not flood the main isolate
    // (Android logs: InputDispatcher waiting … unprocessed events / focus change).
    _epgFocusDebounce?.cancel();
    _epgFocusDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      if (_heroChannel.value.id != ch.id) return;
      _refreshEpgForChannel(ch);
    });
  }

  KeyEventResult? _onCategoryKey(
    FocusNode _,
    KeyEvent event, {
    required bool gridHasItems,
  }) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final top =
          ShellContentFocusRegistry.topNavFocus(ShellDestination.liveTv);
      if (top != null) requestLadderFocus(top);
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowDown) return null;
    if (!gridHasItems) return null;
    if (_channelGridFocusNodes.isEmpty) return null;
    requestLadderFocus(_channelGridFocusNodes.first);
    return KeyEventResult.handled;
  }

  Future<void> _focusChannelGridIndex(
    int i,
    List<MockLiveChannel> channels, {
    bool goingDown = false,
  }) async {
    if (!mounted || i < 0 || i >= channels.length) return;
    if (i >= _channelGridFocusNodes.length) return;
    final ctx = _channelGridItemKeys[i].currentContext;
    final node = _channelGridFocusNodes[i];
    if (ctx != null) {
      if (goingDown) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 1.0,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      } else {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.0,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      }
    }
    if (!mounted) return;
    if (node.canRequestFocus) {
      node.requestFocus();
    }
    _onChannelFocused(channels[i]);
  }

  KeyEventResult? _onGridItemKey(
    FocusNode _,
    KeyEvent event, {
    required int index,
    required List<MockLiveChannel> channels,
  }) {
    if (event is! KeyDownEvent) return null;
    final count = channels.length;
    if (count == 0) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
      unawaited(_onParentalContextMenu(channels[index]));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index + 1 < count) {
        unawaited(_focusChannelGridIndex(index + 1, channels));
        return KeyEventResult.handled;
      }
      final pills = _categoryPills;
      final ci = _selectedCategoryIndex;
      if (ci + 1 < pills.length) {
        _onCategoryActivated(pills[ci + 1].id);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        unawaited(_focusChannelGridIndex(index - 1, channels));
        return KeyEventResult.handled;
      }
      final pills = _categoryPills;
      final ci = _selectedCategoryIndex;
      if (ci > 0) {
        _focusLastGridItemAfterCategoryChange = true;
        _onCategoryActivated(pills[ci - 1].id);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final below = index + _kLiveTvGridCrossAxisCount;
      if (below < count) {
        unawaited(_focusChannelGridIndex(below, channels, goingDown: true));
        return KeyEventResult.handled;
      }
      final pills = _categoryPills;
      final ci = _selectedCategoryIndex;
      if (ci + 1 < pills.length) {
        _onCategoryActivated(pills[ci + 1].id);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (index >= _kLiveTvGridCrossAxisCount) {
        unawaited(
          _focusChannelGridIndex(index - _kLiveTvGridCrossAxisCount, channels, goingDown: false),
        );
        return KeyEventResult.handled;
      }
      // Ladder: first grid row → subcategory pills (not hero). See documentation/05-ui-shell-and-tv-patterns.md — Live TV D-pad ladder.
      requestLadderFocus(_selectedCategoryFocusNode);
      return KeyEventResult.handled;
    }
    return null;
  }

  Widget _previewWrap(Widget child) {
    if (!widget.previewMode) return child;
    return ExcludeFocus(
      excluding: true,
      child: IgnorePointer(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!libraryController.useDemoData) {
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.loading) {
        return _previewWrap(
          const CatalogLoadingBody(message: 'Loading live TV…'),
        );
      }
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.error) {
        return _previewWrap(
          catalogXtreamErrorBody(
            kind: xtreamCatalogRepository.errorKind,
            errorMessage: xtreamCatalogRepository.errorMessage,
            titleForKind: _xtreamErrorTitle,
          ),
        );
      }
    }

    final theme = Theme.of(context);
    final sourceCats = _sourceCategories;
    final hasFavoritePills =
        LiveFavoriteGroupsStore.instance.groupsSorted.isNotEmpty;
    if (!libraryController.useDemoData &&
        sourceCats.isEmpty &&
        !hasFavoritePills &&
        xtreamCatalogRepository.phase == XtreamCatalogPhase.ready) {
      return _previewWrap(
        const CatalogEmptyBody(
          message: 'No live categories were returned for this playlist.',
        ),
      );
    }

    final categoryPills = _categoryPills;
    if (categoryPills.isNotEmpty &&
        _categoryFocusNodes.length != categoryPills.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onCatalogChanged();
      });
      return _previewWrap(
        const CatalogLoadingBody(message: 'Preparing live TV…'),
      );
    }

    final channels = _channelsForCurrentView();
    final selectedFavoriteGroup =
        _liveSearchQuery.isEmpty
            ? LiveFavoriteGroupsStore.instance.groupById(_selectedCategoryId)
            : null;
    final gridHasItems = channels.isNotEmpty;
    if (gridHasItems) {
      _ensureChannelGridFocusResources(channels.length);
    }
    final emptyFavorites =
        selectedFavoriteGroup != null && channels.isEmpty;

    _bootstrapShellFocusIfNeeded();

    final content = ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero is display-only (not focusable); ladder is grid ↔ pills ↔ top bar.
            FocusTraversalOrder(
              order: NumericFocusOrder(2),
              child: LiveTvHeroAudioFocusShell(
                child: LiveTvHeroPanel(
                  channelListenable: _heroChannel,
                  viewCategoryId: _selectedCategoryId,
                  previewMode: widget.previewMode,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FocusTraversalOrder(
              order: NumericFocusOrder(1),
              child: SizedBox(
                height: kTvTemplateCategoryStripRowHeight,
                child: FocusTraversalGroup(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < categoryPills.length; i++) ...[
                          if (i != 0) const SizedBox(width: 8),
                          TvTemplateCategoryPill(
                            label: categoryPills[i].name,
                            selected: categoryPills[i].id == _selectedCategoryId,
                            autofocus: false,
                            focusNode: _categoryFocusNodes[i],
                            onActivate: () =>
                                _onCategoryActivated(categoryPills[i].id),
                            onKeyIntercept: (n, e) => _onCategoryKey(
                              n,
                              e,
                              gridHasItems: gridHasItems,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FocusTraversalOrder(
              order: NumericFocusOrder(0),
              child: Expanded(
                child: gridHasItems
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = _kLiveTvGridCrossAxisCount;
                        const spacing = 10.0;
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        final cellW =
                            (w - spacing * (crossAxisCount - 1)) /
                                crossAxisCount;
                        const targetRows = 3;
                        final cellH =
                            (h - spacing * (targetRows - 1)) / targetRows;
                        final isEpgStyle = liveTvCardStyleStore.style ==
                            LiveTvCardStyle.logoNameEpg;
                        final aspect = isEpgStyle
                            ? (cellW / cellH).clamp(1.0, 1.8)
                            : (cellW / cellH).clamp(0.85, 1.35);
                        return GridView.builder(
                            controller: _gridScrollController,
                            cacheExtent: 480,
                            clipBehavior: Clip.hardEdge,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: spacing,
                              crossAxisSpacing: spacing,
                              childAspectRatio: aspect,
                            ),
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final ch = channels[index];
                              return KeyedSubtree(
                                key: _channelGridItemKeys[index],
                                child: RepaintBoundary(
                                  child: LiveChannelBrowseTile(
                                    channel: ch,
                                    focusNode: _channelGridFocusNodes[index],
                                    favoriteOrderIndex: selectedFavoriteGroup !=
                                            null
                                        ? index + 1
                                        : null,
                                    onDesktopTap: tvmateDesktopTwoStepMouse
                                        ? _liveTvGridDesktopTwoStepMouse
                                        : null,
                                    onFocused: () => _onChannelFocused(ch),
                                    onPlay: () {
                                      unawaited(_openLivePlayer(ch));
                                    },
                                    onKeyIntercept: (n, e) => _onGridItemKey(
                                      n,
                                      e,
                                      index: index,
                                      channels: channels,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                      },
                    )
                  : Center(
                      child: Text(
                        emptyFavorites
                            ? 'No channels in this favorite yet.\nSettings → Favorite setup.'
                            : (_liveSearchQuery.isNotEmpty
                                ? 'No channels match "$_liveSearchQuery".'
                                : 'No channels in this category.'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.88),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );

    return _previewWrap(content);
  }
}
