import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_session_restore_store.dart';
import '../../data/library_controller.dart';
import '../../data/media_card_style_store.dart';
import '../../data/movie_vod_label_store.dart';
import '../../data/my_list_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/series_vod_label_store.dart';
import '../../data/series_rail_page_size_store.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/shell_search_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../player/player_navigation.dart';
import '../../ui/parental/parental_playback_guard.dart';
import '../../shell/shell_back_coordinator.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../l10n/app_localizations.dart';
import '../../shell/shell_destination.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../catalog/catalog_status_widgets.dart';
import '../catalog/vod_unified_entry.dart';
import '../catalog/vod_unified_poster_strip.dart';
import '../windows/windows_browse_rail_layout.dart';
import '../windows/windows_browse_rail_flip_switcher.dart';
import '../windows/windows_category_scroll_arrows.dart';
import '../focus/tv_focusable.dart';
import '../tv_template_category_pill.dart';
import '../tv_template_pill_layout.dart';
import '../movies/movie_browse_hero_card.dart';
import '../widgets/vod_imdb_rating_badge.dart';
import '../widgets/browse_rail_horizontal_swipe_overlay.dart';
import '../widgets/browse_rail_touch_vertical_step_listener.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import '../movies/mock_movies_data.dart';
import '../movies/movie_details_screen.dart';
import 'mock_series_data.dart';
import 'series_browse_hero_card.dart';
import 'series_details_screen.dart';
import 'series_poster_rail.dart';

// ── Series browse: match Movies layout + 7-slot paged rail ─────────────────
const double _kHeroRadius = 16;
int get _kRailPageSize => seriesRailPageSizeStore.size;
String get _seriesSearchQuery => shellSearchStore.queryFor(ShellDestination.series);

/// Theatrical one-sheet–style portrait: height = width × (3/2).
const double _kBrowsePosterHeightOverWidth = 3 / 2;

/// When [previewMode] is true (e.g. Appearance rail editor), shown for layout
/// preview only: no shell focus/back registration.
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key, this.previewMode = false});

  final bool previewMode;

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  late final ValueNotifier<MockSeries> _heroSeries;

  final Map<String, int> _lastIndexByCategory = {};
  final Map<int, FocusNode> _categoryChipFocus = {};
  final ScrollController _categoryStripScroll = ScrollController();

  List<FocusNode> _seriesSlotFocus = const [];
  /// Android TV: second peek row uses separate nodes from row 1 (see [_seriesFocusNodeForWaveSlot]).
  List<FocusNode> _androidSeriesSlotFocusRow1 = const [];
  List<FocusNode> _androidSeriesSlotFocusRow2 = const [];
  String? _lastVodQueryNotified;
  static const String _unifiedVodRailKey = '__vod_unified__';

  late final ValueNotifier<MockMovie> _heroMovieUnified;
  var _vodUnifiedHeroIsMovie = false;

  /// 0 = All series; 1..n map to [_seriesCategories] indices 0..n-1.
  var _selectedCategoryIndex = 0;
  var _rowNavEpoch = 0;

  _SeriesMyListVodFilter _seriesMyListVodFilter =
      _SeriesMyListVodFilter.all;

  late final FocusNode _focusSeriesMyListPillWatched =
      FocusNode(debugLabel: 'seriesMyListPillWatched');
  late final FocusNode _focusSeriesMyListPillContinue =
      FocusNode(debugLabel: 'seriesMyListPillContinue');

  bool _myListWatchedPillFocused = false;
  bool _myListContinuePillFocused = false;

  List<MockSeriesCategory> get _seriesCategories {
    List<MockSeriesCategory> raw;
    if (libraryController.useDemoData) {
      raw = kMockSeriesCategories;
    } else {
      final playlistId = libraryController.activePlaylistId;
      if (playlistId == null) {
        raw = xtreamCatalogRepository.seriesCategories;
      } else {
        raw = xtreamCatalogRepository.seriesCategories
            .where(
              (c) => playlistGroupVisibilityStore.isCategoryVisible(
                playlistId,
                PlaylistGroupSection.series,
                c.id,
              ),
            )
            .map(
              (c) => MockSeriesCategory(
                id: c.id,
                name: playlistGroupVisibilityStore.categoryDisplayName(
                  playlistId,
                  PlaylistGroupSection.series,
                  c.id,
                  c.name,
                ),
              ),
            )
            .toList(growable: false);
      }
    }
    if (!parentalControlStore.hideRestrictedFromBrowseActive) {
      return raw;
    }
    final pid = libraryController.activePlaylistId;
    return raw
        .where((c) {
          final series = libraryController.useDemoData
              ? mockSeriesForCategory(c.id)
              : xtreamCatalogRepository.seriesForCategory(c.id);
          return series.any(
            (s) => !parentalControlStore.isSeriesHiddenFromBrowse(
              playlistId: pid,
              seriesId: s.id,
              categoryId: c.id,
            ),
          );
        })
        .toList(growable: false);
  }

  int get _categoryChipCount {
    final n = _seriesCategories.length;
    return n + 2;
  }

  List<MockSeries> _seriesInMyList() {
    final ids = MyListStore.instance.seriesIds;
    if (ids.isEmpty) return [];
    final byId = <String, MockSeries>{};
    for (final c in _seriesCategories) {
      for (final s in _seriesInCategory(c.id)) {
        byId[s.id] = s;
      }
    }
    final out = <MockSeries>[];
    for (final id in ids) {
      final s = byId[id];
      if (s != null) out.add(s);
    }
    return out;
  }

  List<MockSeries> _allSeriesDedupedForLabels() {
    final out = <MockSeries>[];
    final seen = <String>{};
    for (final c in _seriesCategories) {
      for (final s in _seriesInCategoryRaw(c.id)) {
        if (seen.add(s.id)) out.add(s);
      }
    }
    return out;
  }

  List<MockSeries> _seriesWithVodLabel(MovieVodLabel label) {
    return _allSeriesDedupedForLabels()
        .where((s) => SeriesVodLabelStore.instance.labelFor(s.id) == label)
        .toList(growable: false);
  }

  void _ensureCategoryChipFocusNodes(int count) {
    final stale = _categoryChipFocus.keys.where((k) => k >= count).toList();
    for (final k in stale) {
      _categoryChipFocus.remove(k)?.dispose();
    }
    for (var i = 0; i < count; i++) {
      _categoryChipFocus.putIfAbsent(
        i,
        () => FocusNode(debugLabel: 'seriesCatChip$i'),
      );
    }
  }

  FocusNode _focusCategoryChip(int index) => _categoryChipFocus[index]!;

  String _seriesRailStorageKey() {
    if (_seriesSearchQuery.isNotEmpty) return '__search__';
    if (_selectedCategoryIndex <= 0) return '__all__';
    if (_selectedCategoryIndex == 1) {
      switch (_seriesMyListVodFilter) {
        case _SeriesMyListVodFilter.watchedOnly:
          return '__mylist_series__w__';
        case _SeriesMyListVodFilter.continueOnly:
          return '__mylist_series__cw__';
        case _SeriesMyListVodFilter.all:
          return '__mylist_series__';
      }
    }
    final cats = _seriesCategories;
    final i = _selectedCategoryIndex - 2;
    if (i < 0 || i >= cats.length) return '__all__';
    return cats[i].id;
  }

  List<MockSeries> _visibleSeries() {
    if (_seriesSearchQuery.isNotEmpty) {
      final q = _seriesSearchQuery.toLowerCase();
      return _seriesInCategory('__all__')
          .where((s) => s.title.toLowerCase().contains(q))
          .toList(growable: false);
    }
    final cats = _seriesCategories;
    if (_selectedCategoryIndex <= 0) {
      final out = <MockSeries>[];
      final seen = <String>{};
      for (final c in cats) {
        for (final s in _seriesInCategory(c.id)) {
          if (seen.add(s.id)) out.add(s);
        }
      }
      return out;
    }
    if (_selectedCategoryIndex == 1) {
      switch (_seriesMyListVodFilter) {
        case _SeriesMyListVodFilter.watchedOnly:
          return _seriesWithVodLabel(MovieVodLabel.watched);
        case _SeriesMyListVodFilter.continueOnly:
          return _seriesWithVodLabel(MovieVodLabel.continueWatching);
        case _SeriesMyListVodFilter.all:
          return _seriesInMyList();
      }
    }
    final i = _selectedCategoryIndex - 2;
    if (i < 0 || i >= cats.length) return [];
    return _seriesInCategory(cats[i].id);
  }

  List<MockSeries> _seriesInCategory(String categoryId) {
    if (categoryId == '__all__') {
      final out = <MockSeries>[];
      final seen = <String>{};
      for (final c in _seriesCategories) {
        for (final s in _seriesInCategoryRaw(c.id)) {
          if (seen.add(s.id)) out.add(s);
        }
      }
      return out;
    }
    return _seriesInCategoryRaw(categoryId);
  }

  List<MockSeries> _seriesInCategoryRaw(String categoryId) {
    final list = libraryController.useDemoData
        ? mockSeriesForCategory(categoryId)
        : xtreamCatalogRepository.seriesForCategory(categoryId);
    if (!parentalControlStore.hideRestrictedFromBrowseActive) {
      return list;
    }
    final pid = libraryController.activePlaylistId;
    return list
        .where(
          (s) => !parentalControlStore.isSeriesHiddenFromBrowse(
            playlistId: pid,
            seriesId: s.id,
            categoryId: categoryId,
          ),
        )
        .toList(growable: false);
  }

  List<MockMovieCategory> get _movieCategoriesForVod {
    if (libraryController.useDemoData) return kMockMovieCategories;
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) return xtreamCatalogRepository.vodCategories;
    return xtreamCatalogRepository.vodCategories
        .where(
          (c) => playlistGroupVisibilityStore.isCategoryVisible(
            playlistId,
            PlaylistGroupSection.vod,
            c.id,
          ),
        )
        .toList(growable: false);
  }

  List<MockMovie> _moviesInCategoryRawVod(String categoryId) {
    if (libraryController.useDemoData) {
      return mockMoviesForCategory(categoryId);
    }
    return xtreamCatalogRepository.vodMoviesForCategory(categoryId);
  }

  List<MockMovie> _moviesInCategoryAllVod(String categoryId) {
    if (categoryId == '__all__') {
      final out = <MockMovie>[];
      final seen = <String>{};
      for (final c in _movieCategoriesForVod) {
        for (final m in _moviesInCategoryRawVod(c.id)) {
          if (seen.add(m.id)) out.add(m);
        }
      }
      return out;
    }
    return _moviesInCategoryRawVod(categoryId);
  }

  List<MockMovie> _visibleMoviesForVodSearch() {
    if (_seriesSearchQuery.isEmpty) return [];
    final q = _seriesSearchQuery.toLowerCase();
    return _moviesInCategoryAllVod('__all__')
        .where((m) => m.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// Series tab: all matching series, then all matching movies.
  List<VodUnifiedEntry> _unifiedVodEntriesForSeriesTab() {
    final ser = _visibleSeries();
    final mov = _visibleMoviesForVodSearch();
    return [
      ...ser.map(VodUnifiedEntry.series),
      ...mov.map(VodUnifiedEntry.movie),
    ];
  }

  void _applyVodUnifiedHeroAtIndex(int index) {
    final list = _unifiedVodEntriesForSeriesTab();
    if (index < 0 || index >= list.length) return;
    final e = list[index];
    if (e.isMovie) {
      _vodUnifiedHeroIsMovie = true;
      _heroMovieUnified.value = e.movie!;
    } else {
      _vodUnifiedHeroIsMovie = false;
      _heroSeries.value = e.series!;
    }
    setState(() {});
  }

  void _onUnifiedVodPosterFocused(VodUnifiedEntry entry, int index) {
    _lastIndexByCategory[_unifiedVodRailKey] = index;
    _applyVodUnifiedHeroAtIndex(index);
  }

  String _categoryChipLabel(int index) {
    if (index == 0) return 'All';
    if (index == 1) return 'My List';
    return _seriesCategories[index - 2].name;
  }

  String _seriesBrowseErrorTitle() {
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

  @override
  void initState() {
    super.initState();
    _ensureSlotFocusNodes(_kRailPageSize);
    _ensureAndroidSeriesDoubleRowNodes();
    _heroSeries = ValueNotifier(
      mockSeriesForCategory(kMockSeriesCategories.first.id).first,
    );
    _heroMovieUnified = ValueNotifier(
      mockMoviesForCategory(kMockMovieCategories.first.id).first,
    );
    libraryController.addListener(_onCatalogChanged);
    xtreamCatalogRepository.addListener(_onCatalogChanged);
    playlistGroupVisibilityStore.addListener(_onCatalogChanged);
    mediaCardStyleStore.addListener(_onCatalogChanged);
    seriesRailPageSizeStore.addListener(_onRailPageSizeChanged);
    MyListStore.instance.addListener(_onMyListChanged);
    SeriesVodLabelStore.instance.addListener(_onCatalogChanged);
    shellSearchStore.addListener(_onCatalogChanged);
    parentalControlStore.addListener(_onCatalogChanged);
    if (!widget.previewMode) {
      ShellBackCoordinator.register(this, _tryConsumeShellBack);
      ShellContentFocusRegistry.register(
        ShellDestination.series,
        _requestShellPrimaryFocus,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MyListStore.instance.ensureLoaded();
      await SeriesVodLabelStore.instance.ensureLoaded();
      await xtreamCatalogRepository.syncFromLibrary(libraryController);
      if (mounted) {
        _onCatalogChanged();
        if (!widget.previewMode) {
          _primeInitialFocus();
          await _applyVodColdRestoreIfNeeded();
        }
      }
    });
  }

  Future<void> _applyVodColdRestoreIfNeeded() async {
    if (widget.previewMode) return;
    final snap = await AppSessionRestoreStore.instance
        .consumeVodColdRestoreIf((id) => id.startsWith('episode_'));
    if (snap == null || !mounted) return;
    final sid = snap.browseRestoreSeriesId;
    if (sid != null && sid.isNotEmpty) {
      final allowed = await ensureParentalAllowsSeriesPlayback(
        context,
        seriesId: sid,
        categoryId: '',
      );
      if (!allowed || !mounted) return;
    }
    await openTvMatePlayer(
      context,
      title: snap.title,
      streamUrl: snap.streamUrl,
      isLive: false,
      resumeContentId: snap.resumeContentId,
      contentDescription: snap.contentDescription,
      subtitleSearchQuery: snap.subtitleSearchQuery,
      browseRestoreSeriesId: snap.browseRestoreSeriesId,
      suppressPreviousFocusRestore: true,
    );
  }

  void _ensureSlotFocusNodes(int count) {
    if (_seriesSlotFocus.length == count) return;
    for (final n in _seriesSlotFocus) {
      n.dispose();
    }
    _seriesSlotFocus = List.generate(
      count,
      (i) => FocusNode(debugLabel: 'seriesSlot$i'),
    );
  }

  void _disposeAndroidSeriesDoubleRowNodes() {
    for (final n in _androidSeriesSlotFocusRow1) {
      n.dispose();
    }
    for (final n in _androidSeriesSlotFocusRow2) {
      n.dispose();
    }
    _androidSeriesSlotFocusRow1 = const [];
    _androidSeriesSlotFocusRow2 = const [];
  }

  void _ensureAndroidSeriesDoubleRowNodes() {
    if (!Platform.isAndroid) {
      _disposeAndroidSeriesDoubleRowNodes();
      return;
    }
    if (!windowsBrowseUseDoubleRow(_kRailPageSize)) {
      _disposeAndroidSeriesDoubleRowNodes();
      return;
    }
    if (_androidSeriesSlotFocusRow1.length == kWindowsBrowseFirstRowSlots &&
        _androidSeriesSlotFocusRow2.length == kWindowsBrowseFirstRowSlots) {
      return;
    }
    _disposeAndroidSeriesDoubleRowNodes();
    _androidSeriesSlotFocusRow1 = List.generate(
      kWindowsBrowseFirstRowSlots,
      (i) => FocusNode(debugLabel: 'seriesSlotAr1_$i'),
    );
    _androidSeriesSlotFocusRow2 = List.generate(
      kWindowsBrowseFirstRowSlots,
      (i) => FocusNode(debugLabel: 'seriesSlotAr2_$i'),
    );
  }

  void _onRailPageSizeChanged() {
    if (!mounted) return;
    _ensureSlotFocusNodes(_kRailPageSize);
    _ensureAndroidSeriesDoubleRowNodes();
    setState(() {});
  }

  void _onMyListChanged() {
    if (!mounted) return;
    setState(() {});
    if (_selectedCategoryIndex == 1) {
      final items = _visibleSeries();
      final key = _seriesRailStorageKey();
      if (items.isNotEmpty) {
        final idx =
            (_lastIndexByCategory[key] ?? 0).clamp(0, items.length - 1);
        _heroSeries.value = items[idx];
      }
    }
  }

  void _syncHeroAfterSeriesMyListFilter() {
    if (!mounted || _selectedCategoryIndex != 1) return;
    final items = _visibleSeries();
    final key = _seriesRailStorageKey();
    if (items.isEmpty) return;
    final idx =
        (_lastIndexByCategory[key] ?? 0).clamp(0, items.length - 1);
    _lastIndexByCategory[key] = idx;
    _heroSeries.value = items[idx];
  }

  Widget _browseHeroImdbBadge(BuildContext context) {
    if (_seriesSearchQuery.isNotEmpty && _vodUnifiedHeroIsMovie) {
      return ValueListenableBuilder<MockMovie>(
        valueListenable: _heroMovieUnified,
        builder: (context, m, _) {
          final r = m.rating?.trim();
          if (r == null || r.isEmpty) return const SizedBox.shrink();
          return IgnorePointer(
            child: VodImdbRatingBadge(
              rating: r,
              size: VodImdbRatingBadgeSize.heroMeta,
            ),
          );
        },
      );
    }
    return ValueListenableBuilder<MockSeries>(
      valueListenable: _heroSeries,
      builder: (context, s, _) {
        final r = s.rating?.trim();
        if (r == null || r.isEmpty) return const SizedBox.shrink();
        return IgnorePointer(
          child: VodImdbRatingBadge(
            rating: r,
            size: VodImdbRatingBadgeSize.heroMeta,
          ),
        );
      },
    );
  }

  Widget _buildMyListSeriesPills(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.teamPalette;
    final a = p.accent;
    final wSel = _seriesMyListVodFilter == _SeriesMyListVodFilter.watchedOnly;
    final cSel =
        _seriesMyListVodFilter == _SeriesMyListVodFilter.continueOnly;

    void toggleWatched() {
      setState(() {
        if (wSel) {
          _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
        } else {
          _seriesMyListVodFilter = _SeriesMyListVodFilter.watchedOnly;
        }
      });
      _syncHeroAfterSeriesMyListFilter();
    }

    void toggleContinue() {
      setState(() {
        if (cSel) {
          _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
        } else {
          _seriesMyListVodFilter = _SeriesMyListVodFilter.continueOnly;
        }
      });
      _syncHeroAfterSeriesMyListFilter();
    }

    KeyEventResult? onWatchedKey(FocusNode n, KeyEvent e) {
      if (e is! KeyDownEvent) return null;
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        _focusSeriesMyListPillContinue.requestFocus();
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        final items = _visibleSeries();
        if (items.isEmpty) return KeyEventResult.handled;
        final epoch = _rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestSeriesSlotFocus(0, navEpoch: epoch);
        });
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusCategoryChip(1).requestFocus();
        });
        return KeyEventResult.handled;
      }
      return null;
    }

    KeyEventResult? onContinueKey(FocusNode n, KeyEvent e) {
      if (e is! KeyDownEvent) return null;
      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _focusSeriesMyListPillWatched.requestFocus();
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        final items = _visibleSeries();
        if (items.isEmpty) return KeyEventResult.handled;
        final epoch = _rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestSeriesSlotFocus(0, navEpoch: epoch);
        });
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusCategoryChip(1).requestFocus();
        });
        return KeyEventResult.handled;
      }
      return null;
    }

    Widget buildPill({
      required FocusNode focusNode,
      required bool selected,
      required bool focused,
      required VoidCallback onActivate,
      required KeyEventResult? Function(FocusNode, KeyEvent) onKeyIntercept,
      required ValueChanged<bool> onFocusedChange,
      required String label,
    }) {
      final accentColor = a;
      final accentLine = a.withValues(alpha: 0.5);
      final accentSoft = a.withValues(alpha: 0.14);
      final accentGlow = a.withValues(alpha: 0.22);

      final Color bgColor;
      final Color borderColor;
      final List<BoxShadow> shadows;
      final Color textColor;

      if (focused && selected) {
        bgColor = accentSoft;
        borderColor = accentLine;
        shadows = [
          BoxShadow(color: accentGlow, blurRadius: 18, spreadRadius: -4),
          BoxShadow(color: accentSoft, blurRadius: 3, spreadRadius: 3),
        ];
        textColor = accentColor;
      } else if (focused) {
        bgColor = const Color(0xFF131822);
        borderColor = accentLine;
        shadows = [
          BoxShadow(color: accentSoft, blurRadius: 3, spreadRadius: 3),
        ];
        textColor = const Color(0xFFEEF2F7);
      } else if (selected) {
        bgColor = accentSoft;
        borderColor = accentLine;
        shadows = [
          BoxShadow(color: accentGlow, blurRadius: 18, spreadRadius: -4),
        ];
        textColor = accentColor;
      } else {
        bgColor = const Color(0xFF131822);
        borderColor = const Color(0xFF1B2330);
        shadows = const [];
        textColor = const Color(0xFFA8B0BD);
      }

      return TvFocusable(
        focusNode: focusNode,
        focusedBorderWidth: 0,
        focusBorderColor: p.defaultFocusRingColor,
        focusPadding: EdgeInsets.zero,
        showFocusElevation: false,
        onActivate: onActivate,
        onKeyIntercept: onKeyIntercept,
        onFocusedChange: onFocusedChange,
        child: SizedBox(
          height: kTvTemplateCategoryPillHeight,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: bgColor,
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: shadows,
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 11,
                      height: 1.0,
                      letterSpacing: -0.005 * 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          buildPill(
            focusNode: _focusSeriesMyListPillWatched,
            selected: wSel,
            focused: _myListWatchedPillFocused,
            onActivate: toggleWatched,
            onKeyIntercept: onWatchedKey,
            onFocusedChange: (f) =>
                setState(() => _myListWatchedPillFocused = f),
            label: l10n.actionWatched,
          ),
          const SizedBox(width: 8),
          buildPill(
            focusNode: _focusSeriesMyListPillContinue,
            selected: cSel,
            focused: _myListContinuePillFocused,
            onActivate: toggleContinue,
            onKeyIntercept: onContinueKey,
            onFocusedChange: (f) =>
                setState(() => _myListContinuePillFocused = f),
            label: l10n.actionContinueWatching,
          ),
        ],
      ),
    );
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    final cats = _seriesCategories;
    if (cats.isEmpty) {
      setState(() {});
      return;
    }
    _ensureCategoryChipFocusNodes(_categoryChipCount);
    _selectedCategoryIndex =
        _selectedCategoryIndex.clamp(0, _categoryChipCount - 1);
    final items = _visibleSeries();
    if (items.isNotEmpty) {
      final key = _seriesRailStorageKey();
      final idx = _railIndexForKey(key, items);
      _heroSeries.value = items[idx];
    }
    final q = _seriesSearchQuery;
    if (q != (_lastVodQueryNotified ?? '')) {
      _lastVodQueryNotified = q;
      if (q.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!widget.previewMode) {
            _focusFirstVodSearchResult();
          }
        });
      }
    }
    if (_seriesSearchQuery.isNotEmpty) {
      final u = _unifiedVodEntriesForSeriesTab();
      if (u.isNotEmpty) {
        final idx =
            _railIndexForKey(_unifiedVodRailKey, u).clamp(0, u.length - 1);
        _applyVodUnifiedHeroAtIndex(idx);
      }
    }
    setState(() {});
  }

  void _focusFirstVodSearchResult() {
    final u = _unifiedVodEntriesForSeriesTab();
    if (u.isEmpty || _seriesSlotFocus.isEmpty) return;
    _lastIndexByCategory[_unifiedVodRailKey] = 0;
    _applyVodUnifiedHeroAtIndex(0);
    setState(() {});
    _requestSeriesSlotFocus(0, navEpoch: _rowNavEpoch);
  }

  void _primeInitialFocus() {
    if (!mounted) return;
    final cats = _seriesCategories;
    if (cats.isEmpty) return;
    _ensureCategoryChipFocusNodes(_categoryChipCount);
    _selectedCategoryIndex = 0;
    _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
    final items = _visibleSeries();
    if (items.isEmpty) return;
    _lastIndexByCategory[_seriesRailStorageKey()] = 0;
    _heroSeries.value = items.first;
    _requestSeriesSlotFocus(_slotForCurrentRailIndex(), navEpoch: _rowNavEpoch);
  }

  void _requestShellPrimaryFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_seriesSearchQuery.isNotEmpty) {
        _focusFirstVodSearchResult();
        return;
      }
      final items = _visibleSeries();
      if (items.isNotEmpty) {
        _requestSeriesSlotFocus(
          _slotForCurrentRailIndex(),
          navEpoch: _rowNavEpoch,
        );
        return;
      }
      final chipCount = _categoryChipCount;
      if (chipCount > 0 && _seriesCategories.isNotEmpty) {
        final n = _focusCategoryChip(0);
        if (n.canRequestFocus) n.requestFocus();
      }
    });
  }

  bool _tryConsumeShellBack() {
    if (!mounted) return false;
    if (shellSearchStore.hasQuery(ShellDestination.series)) {
      shellSearchStore.clear(ShellDestination.series);
      return true;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    for (final n in _categoryChipFocus.values) {
      if (identical(primary, n)) return false;
    }
    final count = _categoryChipCount;
    if (count <= 0 || _seriesCategories.isEmpty) return false;
    final chipIdx = _selectedCategoryIndex.clamp(0, count - 1);
    final node = _focusCategoryChip(chipIdx);
    if (node.canRequestFocus) {
      node.requestFocus();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    if (!widget.previewMode) {
      ShellContentFocusRegistry.unregister(ShellDestination.series);
      ShellBackCoordinator.unregister(this);
    }
    libraryController.removeListener(_onCatalogChanged);
    xtreamCatalogRepository.removeListener(_onCatalogChanged);
    playlistGroupVisibilityStore.removeListener(_onCatalogChanged);
    mediaCardStyleStore.removeListener(_onCatalogChanged);
    seriesRailPageSizeStore.removeListener(_onRailPageSizeChanged);
    MyListStore.instance.removeListener(_onMyListChanged);
    SeriesVodLabelStore.instance.removeListener(_onCatalogChanged);
    shellSearchStore.removeListener(_onCatalogChanged);
    parentalControlStore.removeListener(_onCatalogChanged);
    for (final n in _seriesSlotFocus) {
      n.dispose();
    }
    _disposeAndroidSeriesDoubleRowNodes();
    _categoryStripScroll.dispose();
    for (final n in _categoryChipFocus.values) {
      n.dispose();
    }
    _categoryChipFocus.clear();
    _heroSeries.dispose();
    _heroMovieUnified.dispose();
    _focusSeriesMyListPillWatched.dispose();
    _focusSeriesMyListPillContinue.dispose();
    super.dispose();
  }

  int _railIndexForKey<T>(String railKey, List<T> items) {
    if (items.isEmpty) return 0;
    return (_lastIndexByCategory[railKey] ?? 0).clamp(0, items.length - 1);
  }

  int _waveStartForIndex(int index) =>
      (index ~/ _kRailPageSize) * _kRailPageSize;

  FocusNode _seriesFocusNodeForWaveSlot(int slotInWave) {
    final s = slotInWave.clamp(0, _kRailPageSize - 1);
    if (Platform.isAndroid &&
        windowsBrowseUseDoubleRow(_kRailPageSize) &&
        _androidSeriesSlotFocusRow1.length == kWindowsBrowseFirstRowSlots &&
        _androidSeriesSlotFocusRow2.length == kWindowsBrowseFirstRowSlots) {
      if (s >= kWindowsBrowseFirstRowSlots) {
        return _androidSeriesSlotFocusRow2[s - kWindowsBrowseFirstRowSlots];
      }
      return _androidSeriesSlotFocusRow1[s];
    }
    return _seriesSlotFocus[s];
  }

  Widget _seriesRailFlipSwitcherOrPlain({
    required String segmentKey,
    required Widget child,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return BrowseRailTouchVerticalStepListener(
        onStepTowardNextRow: () => _seriesTouchVerticalRailStep(down: true),
        onStepTowardPreviousRow: () =>
            _seriesTouchVerticalRailStep(down: false),
        child: BrowseRailHorizontalSwipeOverlay(
          onHorizontalSwipeEnd: _onPosterRailSwipe,
          child: child,
        ),
      );
    }
    return WindowsBrowseRailFlipSwitcher(
      segmentKey: segmentKey,
      child: child,
    );
  }

  int _slotForCurrentRailIndex() {
    final items = _visibleSeries();
    if (items.isEmpty) return 0;
    final key = _seriesRailStorageKey();
    final idx = _railIndexForKey(key, items);
    return idx - _waveStartForIndex(idx);
  }

  void _syncHeroToSeries(MockSeries s) {
    if (_heroSeries.value.id != s.id) {
      _heroSeries.value = s;
    }
  }

  void _requestSeriesSlotFocus(int slot, {required int navEpoch}) {
    final s = slot.clamp(0, _kRailPageSize - 1);
    void attempt() {
      if (!mounted || navEpoch != _rowNavEpoch) return;
      final node = _seriesFocusNodeForWaveSlot(s);
      if (node.canRequestFocus) {
        node.requestFocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _seriesGoNextCategoryFirst(int epoch) {
    setState(() {
      _selectedCategoryIndex++;
      if (_selectedCategoryIndex != 1) {
        _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
      }
      final nk = _seriesRailStorageKey();
      final next = _visibleSeries();
      if (next.isNotEmpty) {
        _lastIndexByCategory[nk] = 0;
        _syncHeroToSeries(next.first);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _rowNavEpoch) return;
      _seriesFocusNodeForWaveSlot(0).requestFocus();
      final next = _visibleSeries();
      if (next.isNotEmpty) _syncHeroToSeries(next.first);
    });
  }

  void _seriesGoPrevCategoryLast(int epoch) {
    setState(() {
      _selectedCategoryIndex--;
      if (_selectedCategoryIndex != 1) {
        _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
      }
      final nk = _seriesRailStorageKey();
      final next = _visibleSeries();
      if (next.isNotEmpty) {
        final last = next.length - 1;
        _lastIndexByCategory[nk] = last;
        _syncHeroToSeries(next[last]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _rowNavEpoch) return;
      final next = _visibleSeries();
      if (next.isEmpty) return;
      final last = next.length - 1;
      final newSlot = last - _waveStartForIndex(last);
      _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
      _syncHeroToSeries(next[last]);
    });
  }

  KeyEventResult? _seriesRailSlotKey(int slot, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (_seriesSearchQuery.isNotEmpty) {
      return _unifiedVodRailSlotKey(slot, node, event);
    }
    final items = _visibleSeries();
    if (items.isEmpty) return KeyEventResult.ignored;
    final key = _seriesRailStorageKey();
    final idx = _railIndexForKey(key, items);

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (idx + 1 < items.length) {
        final newIdx = idx + 1;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToSeries(items[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex + 1 < _categoryChipCount) {
        final epoch = ++_rowNavEpoch;
        _seriesGoNextCategoryFirst(epoch);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (idx > 0) {
        final newIdx = idx - 1;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToSeries(items[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex > 0) {
        final epoch = ++_rowNavEpoch;
        _seriesGoPrevCategoryLast(epoch);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final ws = _waveStartForIndex(idx);
      final delta = windowsBrowseVerticalDownDelta(
        idx: idx,
        waveStart: ws,
        listLength: items.length,
        railPageSize: _kRailPageSize,
      );
      final below = idx + delta;
      if (below < items.length) {
        final newIdx = below;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToSeries(items[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex + 1 < _categoryChipCount) {
        final epoch = ++_rowNavEpoch;
        _seriesGoNextCategoryFirst(epoch);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final ws = _waveStartForIndex(idx);
      final slot = idx - ws;
      if (Platform.isWindows &&
          _kRailPageSize > kWindowsBrowseFirstRowSlots &&
          slot >= kWindowsBrowseFirstRowSlots) {
        final newIdx = idx - kWindowsBrowseFirstRowSlots;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToSeries(items[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (idx >= _kRailPageSize) {
        final newIdx = idx - _kRailPageSize;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToSeries(items[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex == 1 && _seriesSearchQuery.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusSeriesMyListPillWatched.requestFocus();
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex > 0) {
        final epoch = ++_rowNavEpoch;
        setState(() {
          _selectedCategoryIndex--;
          if (_selectedCategoryIndex != 1) {
            _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
          }
          final nk = _seriesRailStorageKey();
          final next = _visibleSeries();
          if (next.isNotEmpty) {
            _lastIndexByCategory[nk] = 0;
            _syncHeroToSeries(next.first);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(0).requestFocus();
          final next = _visibleSeries();
          if (next.isNotEmpty) _syncHeroToSeries(next.first);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return null;
  }

  KeyEventResult? _unifiedVodRailSlotKey(int slot, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final unified = _unifiedVodEntriesForSeriesTab();
    if (unified.isEmpty) return KeyEventResult.ignored;
    final key = _unifiedVodRailKey;
    final idx = _railIndexForKey(key, unified);

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (idx + 1 < unified.length) {
        final newIdx = idx + 1;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (idx > 0) {
        final newIdx = idx - 1;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final ws = _waveStartForIndex(idx);
      final delta = windowsBrowseVerticalDownDelta(
        idx: idx,
        waveStart: ws,
        listLength: unified.length,
        railPageSize: _kRailPageSize,
      );
      final below = idx + delta;
      if (below < unified.length) {
        final newIdx = below;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final ws = _waveStartForIndex(idx);
      final slot = idx - ws;
      if (Platform.isWindows &&
          _kRailPageSize > kWindowsBrowseFirstRowSlots &&
          slot >= kWindowsBrowseFirstRowSlots) {
        final newIdx = idx - kWindowsBrowseFirstRowSlots;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
        return KeyEventResult.handled;
      }
      if (idx >= _kRailPageSize) {
        final newIdx = idx - _kRailPageSize;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return null;
  }

  static const double _kSeriesWheelScrollThreshold = 24.0;

  void _onSeriesRailPointerSignal(PointerSignalEvent e) {
    if (!Platform.isWindows) return;
    if (e is! PointerScrollEvent) return;
    final dy = e.scrollDelta.dy;
    if (dy.abs() < _kSeriesWheelScrollThreshold) return;
    if (dy > 0) {
      _seriesWheelVertical(down: true);
    } else {
      _seriesWheelVertical(down: false);
    }
  }

  void _seriesWheelVertical({required bool down}) {
    if (!Platform.isWindows) return;
    if (_seriesSearchQuery.isNotEmpty) {
      _seriesWheelUnifiedVertical(down: down);
      return;
    }
    _seriesBrowseVerticalNudge(down: down);
  }

  void _seriesTouchVerticalRailStep({required bool down}) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_seriesSearchQuery.isNotEmpty) {
      _seriesWheelUnifiedVertical(down: down);
      return;
    }
    _seriesBrowseVerticalNudge(down: down);
  }

  void _seriesBrowseVerticalNudge({required bool down}) {
    final items = _visibleSeries();
    if (items.isEmpty) return;
    final key = _seriesRailStorageKey();
    final idx = _railIndexForKey(key, items);

    if (down) {
      final ws = _waveStartForIndex(idx);
      final delta = windowsBrowseVerticalDownDelta(
        idx: idx,
        waveStart: ws,
        listLength: items.length,
        railPageSize: _kRailPageSize,
      );
      final below = idx + delta;
      if (below < items.length) {
        final newIdx = below;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToSeries(items[newIdx]);
        });
        return;
      }
      if (_selectedCategoryIndex + 1 < _categoryChipCount) {
        final epoch = ++_rowNavEpoch;
        _seriesGoNextCategoryFirst(epoch);
      }
      return;
    }

    final ws = _waveStartForIndex(idx);
    final slot = idx - ws;
    if (Platform.isWindows &&
        _kRailPageSize > kWindowsBrowseFirstRowSlots &&
        slot >= kWindowsBrowseFirstRowSlots) {
      final newIdx = idx - kWindowsBrowseFirstRowSlots;
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[key] = newIdx);
      final epoch = ++_rowNavEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _rowNavEpoch) return;
        _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToSeries(items[newIdx]);
      });
      return;
    }
    if (idx >= _kRailPageSize) {
      final newIdx = idx - _kRailPageSize;
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[key] = newIdx);
      final epoch = ++_rowNavEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _rowNavEpoch) return;
        _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToSeries(items[newIdx]);
      });
      return;
    }
    if (_selectedCategoryIndex == 1 && _seriesSearchQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusSeriesMyListPillWatched.requestFocus();
      });
      return;
    }
    if (_selectedCategoryIndex > 0) {
      final epoch = ++_rowNavEpoch;
      setState(() {
        _selectedCategoryIndex--;
        if (_selectedCategoryIndex != 1) {
          _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
        }
        final nk = _seriesRailStorageKey();
        final next = _visibleSeries();
        if (next.isNotEmpty) {
          _lastIndexByCategory[nk] = 0;
          _syncHeroToSeries(next.first);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _rowNavEpoch) return;
        _seriesFocusNodeForWaveSlot(0).requestFocus();
        final next = _visibleSeries();
        if (next.isNotEmpty) _syncHeroToSeries(next.first);
      });
    }
  }

  void _seriesWheelUnifiedVertical({required bool down}) {
    final unified = _unifiedVodEntriesForSeriesTab();
    if (unified.isEmpty) return;
    final ukey = _unifiedVodRailKey;
    final idx = _railIndexForKey(ukey, unified);

    if (down) {
      final ws = _waveStartForIndex(idx);
      final delta = windowsBrowseVerticalDownDelta(
        idx: idx,
        waveStart: ws,
        listLength: unified.length,
        railPageSize: _kRailPageSize,
      );
      final below = idx + delta;
      if (below < unified.length) {
        final newIdx = below;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[ukey] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
      }
      return;
    }

    final ws = _waveStartForIndex(idx);
    final slot = idx - ws;
    if (Platform.isWindows &&
        _kRailPageSize > kWindowsBrowseFirstRowSlots &&
        slot >= kWindowsBrowseFirstRowSlots) {
      final newIdx = idx - kWindowsBrowseFirstRowSlots;
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[ukey] = newIdx);
      final epoch = ++_rowNavEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _rowNavEpoch) return;
        _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
        _applyVodUnifiedHeroAtIndex(newIdx);
      });
      return;
    }
    if (idx >= _kRailPageSize) {
      final newIdx = idx - _kRailPageSize;
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[ukey] = newIdx);
      final epoch = ++_rowNavEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _rowNavEpoch) return;
        _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
        _applyVodUnifiedHeroAtIndex(newIdx);
      });
    }
  }

  KeyEventResult? _categoryChipKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final top =
          ShellContentFocusRegistry.topNavFocus(ShellDestination.series);
      if (top != null) requestLadderFocus(top);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_seriesSearchQuery.isNotEmpty) {
        final u = _unifiedVodEntriesForSeriesTab();
        if (u.isEmpty) return KeyEventResult.handled;
        final epoch = ++_rowNavEpoch;
        final idx = _railIndexForKey(_unifiedVodRailKey, u)
            .clamp(0, u.length - 1);
        final slot = idx - _waveStartForIndex(idx);
        void scheduleFocus() {
          if (!mounted || epoch != _rowNavEpoch) return;
          _requestSeriesSlotFocus(slot, navEpoch: epoch);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => scheduleFocus());
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex == 1 && _seriesSearchQuery.isEmpty) {
        final items = _visibleSeries();
        if (items.isEmpty) return KeyEventResult.handled;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusSeriesMyListPillWatched.requestFocus();
        });
        return KeyEventResult.handled;
      }
      final items = _visibleSeries();
      if (items.isEmpty) return KeyEventResult.handled;
      final epoch = ++_rowNavEpoch;
      final key = _seriesRailStorageKey();
      final idx =
          (_lastIndexByCategory[key] ?? 0).clamp(0, items.length - 1);
      final slot = idx - _waveStartForIndex(idx);
      void scheduleFocus() {
        if (!mounted || epoch != _rowNavEpoch) return;
        _requestSeriesSlotFocus(slot, navEpoch: epoch);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => scheduleFocus());
      return KeyEventResult.handled;
    }
    return null;
  }

  void _onCategoryChipFocused(int index, bool hasFocus) {
    if (!hasFocus) return;
    if (_selectedCategoryIndex != index) {
      setState(() {
        _selectedCategoryIndex = index;
        if (index != 1) {
          _seriesMyListVodFilter = _SeriesMyListVodFilter.all;
        }
      });
    }
    final items = _visibleSeries();
    if (items.isEmpty) return;
    final key = _seriesRailStorageKey();
    final idx =
        (_lastIndexByCategory[key] ?? 0).clamp(0, items.length - 1);
    _syncHeroToSeries(items[idx]);
  }

  void _onPosterFocused(MockSeries s, int index) {
    _lastIndexByCategory[_seriesRailStorageKey()] = index;
    _syncHeroToSeries(s);
  }

  /// Horizontal swipe on mobile: page the poster rail forward or backward.
  void _onPosterRailSwipe(DragEndDetails details) {
    final items = _visibleSeries();
    if (items.isEmpty) return;
    final key = _seriesRailStorageKey();
    final idx = _railIndexForKey(key, items);
    final vx = details.velocity.pixelsPerSecond.dx;
    const threshold = 200.0;
    if (vx < -threshold && idx + _kRailPageSize < items.length) {
      final int newIdx = (idx + _kRailPageSize).clamp(0, items.length - 1);
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[key] = newIdx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToSeries(items[newIdx]);
      });
    } else if (vx > threshold && idx - _kRailPageSize >= 0) {
      final int newIdx = (idx - _kRailPageSize).clamp(0, items.length - 1);
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[key] = newIdx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seriesFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToSeries(items[newIdx]);
      });
    }
  }

  /// Does not move focus to the poster rail while series details is still on top.
  void _syncSeriesBrowseToId(String id) {
    if (!mounted) return;
    final railKey = _seriesRailStorageKey();
    final items = _visibleSeries();
    final idx = items.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    setState(() {
      _lastIndexByCategory[railKey] = idx;
    });
    _syncHeroToSeries(items[idx]);
  }

  Future<void> _openDetails(MockSeries series) async {
    final id = series.id;
    _syncHeroToSeries(series);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeriesDetailsScreen(
          series: series,
          onReturnedFromPlayer: _syncSeriesBrowseToId,
        ),
      ),
    );

    if (!mounted) return;

    final railKey = _seriesRailStorageKey();
    final items = _visibleSeries();
    final idx = items.indexWhere((s) => s.id == id);
    if (idx >= 0) {
      _lastIndexByCategory[railKey] = idx;
    }

    final restored = idx >= 0 ? items[idx] : series;
    _syncHeroToSeries(restored);

    final epoch = _rowNavEpoch;
    final slot = idx >= 0 ? idx - _waveStartForIndex(idx) : 0;
    _requestSeriesSlotFocus(slot, navEpoch: epoch);
  }

  Future<void> _openMovieDetailsFromVod(MockMovie movie) async {
    final id = movie.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MovieDetailsScreen(movie: movie),
      ),
    );
    if (!mounted) return;
    final u = _unifiedVodEntriesForSeriesTab();
    final idx = u.indexWhere((e) => e.isMovie && e.movie!.id == id);
    if (idx >= 0) {
      _lastIndexByCategory[_unifiedVodRailKey] = idx;
    }
    final slot = idx >= 0 ? idx - _waveStartForIndex(idx) : 0;
    _requestSeriesSlotFocus(slot, navEpoch: _rowNavEpoch);
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
    final theme = Theme.of(context);

    if (!libraryController.useDemoData) {
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.loading) {
        return _previewWrap(
          const CatalogLoadingBody(message: 'Loading series…'),
        );
      }
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.error) {
        return _previewWrap(
          catalogXtreamErrorBody(
            kind: xtreamCatalogRepository.errorKind,
            errorMessage: xtreamCatalogRepository.errorMessage,
            titleForKind: _seriesBrowseErrorTitle,
          ),
        );
      }
    }

    final cats = _seriesCategories;
    if (!libraryController.useDemoData &&
        cats.isEmpty &&
        xtreamCatalogRepository.phase == XtreamCatalogPhase.ready) {
      return _previewWrap(
        const CatalogEmptyBody(
          message: 'No series categories were returned for this playlist.',
        ),
      );
    }

    if (cats.isEmpty) {
      return _previewWrap(
        const CatalogEmptyBody(message: 'No categories available.'),
      );
    }

    _ensureCategoryChipFocusNodes(_categoryChipCount);
    final items = _visibleSeries();
    final railKey = _seriesRailStorageKey();

    return _previewWrap(
      LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<MockSeries>(
              valueListenable: _heroSeries,
              builder: (context, series, _) {
                final posterUrl = catalogPosterHiResUrl(
                  seriesPosterUrl(series),
                );
                final hasBackdrop = posterUrl.isNotEmpty;
                final bgColor = Color.lerp(
                  series.posterPrimary,
                  const Color(0xFF0A0E1A),
                  0.93,
                )!;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedContainer(
                          duration: kSeriesBrowseHeroMotion,
                          curve: kSeriesBrowseHeroMotionCurve,
                          color: bgColor,
                        ),
                        if (hasBackdrop)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: w * 0.58,
                            child: AnimatedSwitcher(
                              duration: kSeriesBrowseHeroMotion,
                              switchInCurve: kSeriesBrowseHeroMotionCurve,
                              switchOutCurve: kSeriesBrowseHeroMotionCurve,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                              child: SizedBox.expand(
                                key: ValueKey(posterUrl),
                                child: ShaderMask(
                                  shaderCallback: (rect) => LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.7),
                                      Colors.white,
                                      Colors.white,
                                    ],
                                    stops: const [0.0, 0.05, 0.18, 0.32, 0.45, 1.0],
                                  ).createShader(rect),
                                  blendMode: BlendMode.dstIn,
                                  child: ShaderMask(
                                    shaderCallback: (rect) => LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.5),
                                        Colors.white,
                                        Colors.white,
                                        Colors.white.withOpacity(0.4),
                                      ],
                                      stops: const [0.0, 0.1, 0.85, 1.0],
                                    ).createShader(rect),
                                    blendMode: BlendMode.dstIn,
                                    child: TvCatalogImage(
                                      url: posterUrl,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topRight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),

            Positioned(
              top: 10,
              right: 10,
              child: _browseHeroImdbBadge(context),
            ),

            Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 10, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _seriesSearchQuery.isEmpty
                            ? SeriesBrowseHeroCard(
                                listenable: _heroSeries,
                              )
                            : AnimatedSwitcher(
                                duration: AppTheme.contentCrossFadeDuration,
                                switchInCurve: AppTheme.contentCrossFadeCurve,
                                switchOutCurve: AppTheme.contentCrossFadeCurve,
                                child: _vodUnifiedHeroIsMovie
                                    ? MovieBrowseHeroCard(
                                        key: ValueKey<String>(
                                          'vodM_${_heroMovieUnified.value.id}',
                                        ),
                                        listenable: _heroMovieUnified,
                                      )
                                    : SeriesBrowseHeroCard(
                                        key: ValueKey<String>(
                                          'vodS_${_heroSeries.value.id}',
                                        ),
                                        listenable: _heroSeries,
                                      ),
                              ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Platform.isWindows
                          ? Listener(
                              onPointerSignal:
                                  _onSeriesRailPointerSignal,
                              child: LayoutBuilder(
                                builder: (context, rowConstraints) {
                            const gap = 12.0;
                            const catH = kTvTemplateCategoryStripRowHeight;
                            const pillGap = kWindowsBrowsePillToRailGap;
                            final availW = rowConstraints.maxWidth - 12;
                            final availH = rowConstraints.maxHeight
                                - catH - pillGap;

                            final catStrip = SizedBox(
                              height: catH,
                              child: _SeriesCategoryStrip(
                                itemCount: _categoryChipCount,
                                labelAt: _categoryChipLabel,
                                selectedIndex: _selectedCategoryIndex,
                                focusForIndex: _focusCategoryChip,
                                scrollController: _categoryStripScroll,
                                onChipFocused: _onCategoryChipFocused,
                                onChipKey: _categoryChipKey,
                              ),
                            );

                            final unified =
                                _unifiedVodEntriesForSeriesTab();

                            Widget wrapWithCats(Widget rail) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  catStrip,
                                  const SizedBox(height: pillGap),
                                  if (_seriesSearchQuery.isEmpty &&
                                      _selectedCategoryIndex == 1) ...[
                                    _buildMyListSeriesPills(context),
                                    const SizedBox(height: 8),
                                  ],
                                  rail,
                                ],
                              );
                            }

                            if (_seriesSearchQuery.isNotEmpty) {
                              if (unified.isEmpty) {
                                return wrapWithCats(Center(
                                  child: Text(
                                    'No results for this search.',
                                    style:
                                        theme.textTheme.bodyLarge?.copyWith(
                                      color:
                                          Colors.white.withOpacity(0.75),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ));
                              }
                                final wd =
                                    computeWindowsBrowseRailDimensions(
                                  availW: availW,
                                  availH: availH,
                                  railPageSize: _kRailPageSize,
                                  slotGap: gap,
                                  aspectHeightOverWidth:
                                      _kBrowsePosterHeightOverWidth,
                                );
                                final posterW = wd.posterWidth;
                                final posterH = wd.posterHeight;
                                final outerW =
                                    wd.contentWidth ?? wd.rowWidth;
                                final wave = _waveStartForIndex(
                                  _railIndexForKey(
                                    _unifiedVodRailKey,
                                    unified,
                                  ),
                                );
                                final listIdx = _railIndexForKey(
                                  _unifiedVodRailKey,
                                  unified,
                                );
                                final flipSeg = windowsBrowseFlipSegmentKey(
                                  listIndex: listIdx,
                                  railPageSize: _kRailPageSize,
                                  useDoubleRow: wd.useDoubleRow,
                                );
                                final stripChild = wd.useDoubleRow
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          VodUnifiedPosterStrip(
                                            key: const ValueKey<String>(
                                                'vod_unified_series_r1'),
                                            railPageSize: _kRailPageSize,
                                            categoryLabel: 'Search',
                                            entries: unified,
                                            waveStart: wave,
                                            posterWidth: posterW,
                                            posterHeight: posterH,
                                            gap: gap,
                                            slotFocusNodes:
                                                _seriesSlotFocus,
                                            onSlotKey:
                                                _unifiedVodRailSlotKey,
                                            onPosterFocused:
                                                _onUnifiedVodPosterFocused,
                                            onMovieActivate:
                                                _openMovieDetailsFromVod,
                                            onSeriesActivate:
                                                _openDetails,
                                            slotStart: 0,
                                            slotEnd:
                                                kWindowsBrowseFirstRowSlots,
                                          ),
                                          SizedBox(height: wd.rowGap),
                                          Opacity(
                                            opacity: wd.secondRowOpacity,
                                            child: VodUnifiedPosterStrip(
                                              key: const ValueKey<String>(
                                                  'vod_unified_series_r2'),
                                              railPageSize:
                                                  kWindowsBrowseFirstRowSlots,
                                              categoryLabel: 'Search',
                                              entries: unified,
                                              waveStart: wave +
                                                  kWindowsBrowseFirstRowSlots,
                                              posterWidth: posterW,
                                              posterHeight: posterH,
                                              gap: gap,
                                              slotFocusNodes:
                                                  _seriesSlotFocus,
                                              onSlotKey:
                                                  _unifiedVodRailSlotKey,
                                              onPosterFocused:
                                                  _onUnifiedVodPosterFocused,
                                              onMovieActivate:
                                                  _openMovieDetailsFromVod,
                                              onSeriesActivate:
                                                  _openDetails,
                                              slotStart: 0,
                                              slotEnd:
                                                  kWindowsBrowseFirstRowSlots,
                                              clipTopHalfOfPoster: true,
                                              peekClipHeight:
                                                  wd.secondRowVisibleHeight,
                                            ),
                                          ),
                                        ],
                                      )
                                    : VodUnifiedPosterStrip(
                                        key: const ValueKey<String>(
                                            'vod_unified_series'),
                                        railPageSize: _kRailPageSize,
                                        categoryLabel: 'Search',
                                        entries: unified,
                                        waveStart: wave,
                                        posterWidth: posterW,
                                        posterHeight: posterH,
                                        gap: gap,
                                        slotFocusNodes:
                                            _seriesSlotFocus,
                                        onSlotKey:
                                            _unifiedVodRailSlotKey,
                                        onPosterFocused:
                                            _onUnifiedVodPosterFocused,
                                        onMovieActivate:
                                            _openMovieDetailsFromVod,
                                        onSeriesActivate: _openDetails,
                                      );

                                return wrapWithCats(Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: outerW,
                                    child: WindowsBrowseRailFlipSwitcher(
                                      segmentKey: flipSeg,
                                      child: stripChild,
                                    ),
                                  ),
                                ));
                            }

                            if (items.isEmpty) {
                              return wrapWithCats(Center(
                                child: Text(
                                  'No series for this filter.',
                                  style:
                                      theme.textTheme.bodyLarge?.copyWith(
                                    color:
                                        Colors.white.withOpacity(0.75),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ));
                            }
                              final wd =
                                  computeWindowsBrowseRailDimensions(
                                availW: availW,
                                availH: availH,
                                railPageSize: _kRailPageSize,
                                slotGap: gap,
                                aspectHeightOverWidth:
                                    _kBrowsePosterHeightOverWidth,
                              );
                              final posterW = wd.posterWidth;
                              final posterH = wd.posterHeight;
                              final outerW =
                                  wd.contentWidth ?? wd.rowWidth;
                              final wave = _waveStartForIndex(
                                _railIndexForKey(railKey, items),
                              );
                              final listIdx =
                                  _railIndexForKey(railKey, items);
                              final flipSeg = windowsBrowseFlipSegmentKey(
                                listIndex: listIdx,
                                railPageSize: _kRailPageSize,
                                useDoubleRow: wd.useDoubleRow,
                              );
                              final stripChild = wd.useDoubleRow
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SeriesPosterRailStrip(
                                          key: ValueKey<String>(
                                              '${railKey}_w_r1'),
                                          railPageSize: _kRailPageSize,
                                          slotStart: 0,
                                          slotEnd:
                                              kWindowsBrowseFirstRowSlots,
                                          categoryLabel:
                                              _categoryChipLabel(
                                            _selectedCategoryIndex,
                                          ),
                                          series: items,
                                          waveStart: wave,
                                          posterWidth: posterW,
                                          posterHeight: posterH,
                                          gap: gap,
                                          slotFocusNodes:
                                              _seriesSlotFocus,
                                          onSlotKey: _seriesRailSlotKey,
                                          onPosterFocused:
                                              _onPosterFocused,
                                          onSeriesActivate: _openDetails,
                                        ),
                                        SizedBox(height: wd.rowGap),
                                        Opacity(
                                          opacity: wd.secondRowOpacity,
                                          child: SeriesPosterRailStrip(
                                            key: ValueKey<String>(
                                                '${railKey}_w_r2'),
                                            railPageSize:
                                                kWindowsBrowseFirstRowSlots,
                                            slotStart: 0,
                                            slotEnd:
                                                kWindowsBrowseFirstRowSlots,
                                            clipTopHalfOfPoster: true,
                                            peekClipHeight:
                                                wd.secondRowVisibleHeight,
                                            categoryLabel:
                                                _categoryChipLabel(
                                              _selectedCategoryIndex,
                                            ),
                                            series: items,
                                            waveStart: wave +
                                                kWindowsBrowseFirstRowSlots,
                                            posterWidth: posterW,
                                            posterHeight: posterH,
                                            gap: gap,
                                            slotFocusNodes:
                                                _seriesSlotFocus,
                                            onSlotKey:
                                                _seriesRailSlotKey,
                                            onPosterFocused:
                                                _onPosterFocused,
                                            onSeriesActivate:
                                                _openDetails,
                                          ),
                                        ),
                                      ],
                                    )
                                  : SeriesPosterRailStrip(
                                      key: ValueKey<String>(railKey),
                                      railPageSize: _kRailPageSize,
                                      categoryLabel: _categoryChipLabel(
                                          _selectedCategoryIndex),
                                      series: items,
                                      waveStart: wave,
                                      posterWidth: posterW,
                                      posterHeight: posterH,
                                      gap: gap,
                                      slotFocusNodes: _seriesSlotFocus,
                                      onSlotKey: _seriesRailSlotKey,
                                      onPosterFocused: _onPosterFocused,
                                      onSeriesActivate: _openDetails,
                                    );

                            return wrapWithCats(Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                width: outerW,
                                child: WindowsBrowseRailFlipSwitcher(
                                  segmentKey: flipSeg,
                                  child: stripChild,
                                ),
                              ),
                            ));
                                },
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, rowConstraints) {
                            const gap = 12.0;
                            const catH = kTvTemplateCategoryStripRowHeight;
                            const pillGap = 12.0;
                            final availW = rowConstraints.maxWidth - 12;
                            final availH = rowConstraints.maxHeight
                                - catH - pillGap;

                            final catStrip = SizedBox(
                              height: catH,
                              child: _SeriesCategoryStrip(
                                itemCount: _categoryChipCount,
                                labelAt: _categoryChipLabel,
                                selectedIndex: _selectedCategoryIndex,
                                focusForIndex: _focusCategoryChip,
                                scrollController: _categoryStripScroll,
                                onChipFocused: _onCategoryChipFocused,
                                onChipKey: _categoryChipKey,
                              ),
                            );

                            final unified =
                                _unifiedVodEntriesForSeriesTab();

                            Widget wrapWithCats(Widget rail) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  catStrip,
                                  const SizedBox(height: pillGap),
                                  if (_seriesSearchQuery.isEmpty &&
                                      _selectedCategoryIndex == 1) ...[
                                    _buildMyListSeriesPills(context),
                                    const SizedBox(height: 8),
                                  ],
                                  rail,
                                ],
                              );
                            }

                            if (_seriesSearchQuery.isNotEmpty) {
                              if (unified.isEmpty) {
                                return wrapWithCats(Center(
                                  child: Text(
                                    'No results for this search.',
                                    style:
                                        theme.textTheme.bodyLarge?.copyWith(
                                      color:
                                          Colors.white.withOpacity(0.75),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ));
                              }
                              final wd =
                                  computeWindowsBrowseRailDimensions(
                                availW: availW,
                                availH: availH,
                                railPageSize: _kRailPageSize,
                                slotGap: gap,
                                aspectHeightOverWidth:
                                    _kBrowsePosterHeightOverWidth,
                              );
                              final posterW = wd.posterWidth;
                              final posterH = wd.posterHeight;
                              final outerW =
                                  wd.contentWidth ?? wd.rowWidth;
                              final wave = _waveStartForIndex(
                                _railIndexForKey(
                                  _unifiedVodRailKey,
                                  unified,
                                ),
                              );
                              final listIdx = _railIndexForKey(
                                _unifiedVodRailKey,
                                unified,
                              );
                              final flipSeg =
                                  windowsBrowseFlipSegmentKey(
                                listIndex: listIdx,
                                railPageSize: _kRailPageSize,
                                useDoubleRow: wd.useDoubleRow,
                              );
                              final seriesRow1Nodes = Platform.isAndroid &&
                                      wd.useDoubleRow
                                  ? _androidSeriesSlotFocusRow1
                                  : _seriesSlotFocus;
                              final seriesRow2Nodes = Platform.isAndroid &&
                                      wd.useDoubleRow
                                  ? _androidSeriesSlotFocusRow2
                                  : _seriesSlotFocus;
                              final stripChild = wd.useDoubleRow
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        VodUnifiedPosterStrip(
                                          key: const ValueKey<String>(
                                              'vod_unified_series_r1'),
                                          railPageSize: _kRailPageSize,
                                          categoryLabel: 'Search',
                                          entries: unified,
                                          waveStart: wave,
                                          posterWidth: posterW,
                                          posterHeight: posterH,
                                          gap: gap,
                                          slotFocusNodes:
                                              seriesRow1Nodes,
                                          onSlotKey:
                                              _unifiedVodRailSlotKey,
                                          onPosterFocused:
                                              _onUnifiedVodPosterFocused,
                                          onMovieActivate:
                                              _openMovieDetailsFromVod,
                                          onSeriesActivate:
                                              _openDetails,
                                          slotStart: 0,
                                          slotEnd:
                                              kWindowsBrowseFirstRowSlots,
                                        ),
                                        SizedBox(height: wd.rowGap),
                                        Opacity(
                                          opacity: wd.secondRowOpacity,
                                          child: VodUnifiedPosterStrip(
                                            key: const ValueKey<String>(
                                                'vod_unified_series_r2'),
                                            railPageSize:
                                                kWindowsBrowseFirstRowSlots,
                                            categoryLabel: 'Search',
                                            entries: unified,
                                            waveStart: wave +
                                                kWindowsBrowseFirstRowSlots,
                                            posterWidth: posterW,
                                            posterHeight: posterH,
                                            gap: gap,
                                            slotFocusNodes:
                                                seriesRow2Nodes,
                                            onSlotKey:
                                                _unifiedVodRailSlotKey,
                                            onPosterFocused:
                                                _onUnifiedVodPosterFocused,
                                            onMovieActivate:
                                                _openMovieDetailsFromVod,
                                            onSeriesActivate:
                                                _openDetails,
                                            slotStart: 0,
                                            slotEnd:
                                                kWindowsBrowseFirstRowSlots,
                                            clipTopHalfOfPoster: true,
                                            peekClipHeight:
                                                wd.secondRowVisibleHeight,
                                          ),
                                        ),
                                      ],
                                    )
                                  : VodUnifiedPosterStrip(
                                      key: const ValueKey<String>(
                                          'vod_unified_series'),
                                      railPageSize: _kRailPageSize,
                                      categoryLabel: 'Search',
                                      entries: unified,
                                      waveStart: wave,
                                      posterWidth: posterW,
                                      posterHeight: posterH,
                                      gap: gap,
                                      slotFocusNodes:
                                          _seriesSlotFocus,
                                      onSlotKey:
                                          _unifiedVodRailSlotKey,
                                      onPosterFocused:
                                          _onUnifiedVodPosterFocused,
                                      onMovieActivate:
                                          _openMovieDetailsFromVod,
                                      onSeriesActivate: _openDetails,
                                    );

                              return wrapWithCats(Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: outerW,
                                  child: _seriesRailFlipSwitcherOrPlain(
                                    segmentKey: flipSeg,
                                    child: stripChild,
                                  ),
                                ),
                              ));
                            }

                            if (items.isEmpty) {
                              return wrapWithCats(Center(
                                child: Text(
                                  'No series for this filter.',
                                  style:
                                      theme.textTheme.bodyLarge?.copyWith(
                                    color:
                                        Colors.white.withOpacity(0.75),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ));
                            }

                            final wd =
                                computeWindowsBrowseRailDimensions(
                              availW: availW,
                              availH: availH,
                              railPageSize: _kRailPageSize,
                              slotGap: gap,
                              aspectHeightOverWidth:
                                  _kBrowsePosterHeightOverWidth,
                            );
                            final posterW = wd.posterWidth;
                            final posterH = wd.posterHeight;
                            final outerW =
                                wd.contentWidth ?? wd.rowWidth;
                            final wave = _waveStartForIndex(
                              _railIndexForKey(railKey, items),
                            );
                            final listIdx =
                                _railIndexForKey(railKey, items);
                            final flipSeg =
                                windowsBrowseFlipSegmentKey(
                              listIndex: listIdx,
                              railPageSize: _kRailPageSize,
                              useDoubleRow: wd.useDoubleRow,
                            );
                            final seriesRow1Nodes = Platform.isAndroid &&
                                    wd.useDoubleRow
                                ? _androidSeriesSlotFocusRow1
                                : _seriesSlotFocus;
                            final seriesRow2Nodes = Platform.isAndroid &&
                                    wd.useDoubleRow
                                ? _androidSeriesSlotFocusRow2
                                : _seriesSlotFocus;

                            final stripChild = wd.useDoubleRow
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SeriesPosterRailStrip(
                                        key: ValueKey<String>(
                                            '${railKey}_r1'),
                                        railPageSize: _kRailPageSize,
                                        slotStart: 0,
                                        slotEnd:
                                            kWindowsBrowseFirstRowSlots,
                                        categoryLabel:
                                            _categoryChipLabel(
                                          _selectedCategoryIndex,
                                        ),
                                        series: items,
                                        waveStart: wave,
                                        posterWidth: posterW,
                                        posterHeight: posterH,
                                        gap: gap,
                                        slotFocusNodes:
                                            seriesRow1Nodes,
                                        onSlotKey: _seriesRailSlotKey,
                                        onPosterFocused:
                                            _onPosterFocused,
                                        onSeriesActivate: _openDetails,
                                      ),
                                      SizedBox(height: wd.rowGap),
                                      Opacity(
                                        opacity: wd.secondRowOpacity,
                                        child: SeriesPosterRailStrip(
                                          key: ValueKey<String>(
                                              '${railKey}_r2'),
                                          railPageSize:
                                              kWindowsBrowseFirstRowSlots,
                                          slotStart: 0,
                                          slotEnd:
                                              kWindowsBrowseFirstRowSlots,
                                          clipTopHalfOfPoster: true,
                                          peekClipHeight:
                                              wd.secondRowVisibleHeight,
                                          categoryLabel:
                                              _categoryChipLabel(
                                            _selectedCategoryIndex,
                                          ),
                                          series: items,
                                          waveStart: wave +
                                              kWindowsBrowseFirstRowSlots,
                                          posterWidth: posterW,
                                          posterHeight: posterH,
                                          gap: gap,
                                          slotFocusNodes:
                                              seriesRow2Nodes,
                                          onSlotKey:
                                              _seriesRailSlotKey,
                                          onPosterFocused:
                                              _onPosterFocused,
                                          onSeriesActivate:
                                              _openDetails,
                                        ),
                                      ),
                                    ],
                                  )
                                : SeriesPosterRailStrip(
                                    key: ValueKey<String>(railKey),
                                    railPageSize: _kRailPageSize,
                                    categoryLabel: _categoryChipLabel(
                                        _selectedCategoryIndex),
                                    series: items,
                                    waveStart: wave,
                                    posterWidth: posterW,
                                    posterHeight: posterH,
                                    gap: gap,
                                    slotFocusNodes: _seriesSlotFocus,
                                    onSlotKey: _seriesRailSlotKey,
                                    onPosterFocused: _onPosterFocused,
                                    onSeriesActivate: _openDetails,
                                  );

                            return wrapWithCats(Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                width: outerW,
                                child: _seriesRailFlipSwitcherOrPlain(
                                  segmentKey: flipSeg,
                                  child: stripChild,
                                ),
                              ),
                            ));
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
      },
    ),
    );
  }
}

class _SeriesCategoryStrip extends StatelessWidget {
  const _SeriesCategoryStrip({
    required this.itemCount,
    required this.labelAt,
    required this.selectedIndex,
    required this.focusForIndex,
    required this.scrollController,
    required this.onChipFocused,
    required this.onChipKey,
  });

  final int itemCount;
  final String Function(int index) labelAt;
  final int selectedIndex;
  final FocusNode Function(int index) focusForIndex;
  final ScrollController scrollController;
  final void Function(int index, bool hasFocus) onChipFocused;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onChipKey;

  @override
  Widget build(BuildContext context) {
    // Same as Live TV: [SingleChildScrollView] + [Row] (not horizontal [ListView])
    // so the category pill frame matches Live TV (no extra vertical centering).
    final list = SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            TvTemplateCategoryPill(
              focusNode: focusForIndex(i),
              label: labelAt(i),
              selected: i == selectedIndex,
              onActivate: () => onChipFocused(i, true),
              onKeyIntercept: onChipKey,
              onFocusChanged: (f) => onChipFocused(i, f),
            ),
          ],
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Platform.isWindows
            ? WindowsCategoryScrollArrows(
                controller: scrollController,
                child: list,
              )
            : list,
      ),
    );
  }
}

enum _SeriesMyListVodFilter { all, watchedOnly, continueOnly }
