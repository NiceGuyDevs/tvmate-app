import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_session_restore_store.dart';
import '../../data/library_controller.dart';
import '../../data/media_card_style_store.dart';
import '../../data/movie_vod_label_store.dart';
import '../../data/movie_rail_page_size_store.dart';
import '../../data/my_list_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/shell_search_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../shell/shell_back_coordinator.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../l10n/app_localizations.dart';
import '../../player/player_navigation.dart';
import '../../ui/parental/parental_playback_guard.dart';
import '../../shell/shell_destination.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../catalog/catalog_status_widgets.dart';
import '../catalog/vod_unified_entry.dart';
import '../catalog/vod_unified_poster_strip.dart';
import '../focus/tv_focusable.dart';
import '../focus/vod_live_tv_style_focus.dart';
import '../tv_template_category_pill.dart';
import '../tv_template_pill_layout.dart';
import '../series/series_browse_hero_card.dart';
import '../widgets/movie_watched_badge.dart';
import '../widgets/vod_imdb_rating_badge.dart';
import '../widgets/browse_rail_horizontal_swipe_overlay.dart';
import '../widgets/browse_rail_touch_vertical_step_listener.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import '../series/mock_series_data.dart';
import '../series/series_details_screen.dart';
import '../windows/windows_browse_rail_layout.dart';
import '../windows/windows_browse_rail_flip_switcher.dart';
import '../windows/windows_category_scroll_arrows.dart';
import '../windows/windows_desktop_scale.dart';
import 'mock_movies_data.dart';
import 'movie_browse_hero_card.dart';
import 'movie_details_screen.dart';

// ── Movies screen only: background & motion tokens ─────────────────────────
const double _kPosterRadius = 13;
const double _kHeroRadius = 16;
int get _kRailPageSize => movieRailPageSizeStore.size;
String get _moviesSearchQuery => shellSearchStore.queryFor(ShellDestination.movies);

/// Theatrical one-sheet–style portrait: height = width × (3/2).
const double _kBrowsePosterHeightOverWidth = 3 / 2;

String _moviesHiResPosterUrl(String url) {
  final t = url.trim();
  if (catalogArtIsBundledAsset(t)) return t;
  if (!url.contains('image.tmdb.org/t/p/')) return url;
  return url.replaceFirstMapped(
    RegExp(r'/t/p/[^/]+/'),
    (_) => '/t/p/w780/',
  );
}

/// Sharp network image + same loading / error treatment as catalog tiles.
class _MoviesHiResImage extends StatelessWidget {
  const _MoviesHiResImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const TvUniversalMediaPlaceholder();
    }
    if (catalogArtIsBundledAsset(trimmed)) {
      return Image.asset(
        trimmed,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const TvUniversalMediaPlaceholder(),
      );
    }
    return Image.network(
      trimmed,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const TvImageShimmer();
      },
      errorBuilder: (_, __, ___) => const TvUniversalMediaPlaceholder(),
    );
  }
}

/// Premium Movies browse: cinematic hero (~50% height) + large poster rail.
///
/// When [previewMode] is true (e.g. Appearance rail editor), shown for layout
/// preview only: no shell focus/back registration; parent should use
/// [ExcludeFocus] / [IgnorePointer] if needed.
class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key, this.previewMode = false});

  final bool previewMode;

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  late final ValueNotifier<MockMovie> _heroMovie;

  final Map<String, int> _lastIndexByCategory = {};
  final Map<int, FocusNode> _categoryChipFocus = {};
  final ScrollController _categoryStripScroll = ScrollController();

  List<FocusNode> _movieSlotFocus = const [];
  /// Android TV: second peek row must not share [FocusNode]s with row 1 (see [_movieFocusNodeForWaveSlot]).
  List<FocusNode> _androidMovieSlotFocusRow1 = const [];
  List<FocusNode> _androidMovieSlotFocusRow2 = const [];
  String? _lastVodQueryNotified;
  static const String _unifiedVodRailKey = '__vod_unified__';

  late final ValueNotifier<MockSeries> _heroSeriesUnified;
  var _vodUnifiedHeroIsSeries = false;

  /// 0 = All titles; 1..n map to [_movieCategories] indices 0..n-1.
  var _selectedCategoryIndex = 0;
  var _rowNavEpoch = 0;

  /// My List only: filter all saved titles vs watched vs continue watching.
  _MyListVodFilter _myListVodFilter = _MyListVodFilter.all;

  late final FocusNode _focusMyListPillWatched =
      FocusNode(debugLabel: 'vodMyListPillWatched');
  late final FocusNode _focusMyListPillContinue =
      FocusNode(debugLabel: 'vodMyListPillContinue');
  bool _myListPillWatchedFocused = false;
  bool _myListPillContinueFocused = false;

  List<MockMovieCategory> get _movieCategories {
    List<MockMovieCategory> raw;
    if (libraryController.useDemoData) {
      raw = kMockMovieCategories;
    } else {
      final playlistId = libraryController.activePlaylistId;
      if (playlistId == null) {
        raw = xtreamCatalogRepository.vodCategories;
      } else {
        raw = xtreamCatalogRepository.vodCategories
            .where(
              (c) => playlistGroupVisibilityStore.isCategoryVisible(
                playlistId,
                PlaylistGroupSection.vod,
                c.id,
              ),
            )
            .map(
              (c) => MockMovieCategory(
                id: c.id,
                name: playlistGroupVisibilityStore.categoryDisplayName(
                  playlistId,
                  PlaylistGroupSection.vod,
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
          final movies = libraryController.useDemoData
              ? mockMoviesForCategory(c.id)
              : xtreamCatalogRepository.vodMoviesForCategory(c.id);
          return movies.any(
            (m) => !parentalControlStore.isMovieHiddenFromBrowse(
              playlistId: pid,
              movieId: m.id,
              categoryId: c.id,
            ),
          );
        })
        .toList(growable: false);
  }

  int get _categoryChipCount {
    final n = _movieCategories.length;
    return n + 2;
  }

  List<MockMovie> _moviesInMyList() {
    final ids = MyListStore.instance.movieIds;
    if (ids.isEmpty) return [];
    final byId = <String, MockMovie>{};
    for (final c in _movieCategories) {
      for (final m in _moviesInCategory(c.id)) {
        byId[m.id] = m;
      }
    }
    final out = <MockMovie>[];
    for (final id in ids) {
      final m = byId[id];
      if (m != null) out.add(m);
    }
    return out;
  }

  /// All catalog movies (deduped) for VOD label filters on My List.
  List<MockMovie> _allMoviesDedupedForLabels() {
    final out = <MockMovie>[];
    final seen = <String>{};
    for (final c in _movieCategories) {
      for (final m in _moviesInCategoryRaw(c.id)) {
        if (seen.add(m.id)) out.add(m);
      }
    }
    return out;
  }

  List<MockMovie> _moviesWithVodLabel(MovieVodLabel label) {
    return _allMoviesDedupedForLabels()
        .where((m) => MovieVodLabelStore.instance.labelFor(m.id) == label)
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
        () => FocusNode(debugLabel: 'moviesCatChip$i'),
      );
    }
  }

  FocusNode _focusCategoryChip(int index) => _categoryChipFocus[index]!;

  String _posterRailStorageKey() {
    if (_moviesSearchQuery.isNotEmpty) return '__search__';
    if (_selectedCategoryIndex <= 0) return '__all__';
    if (_selectedCategoryIndex == 1) {
      switch (_myListVodFilter) {
        case _MyListVodFilter.watchedOnly:
          return '__mylist_movies__w__';
        case _MyListVodFilter.continueOnly:
          return '__mylist_movies__cw__';
        case _MyListVodFilter.all:
          return '__mylist_movies__';
      }
    }
    final cats = _movieCategories;
    final i = _selectedCategoryIndex - 2;
    if (i < 0 || i >= cats.length) return '__all__';
    return cats[i].id;
  }

  List<MockMovie> _visibleMovies() {
    if (_moviesSearchQuery.isNotEmpty) {
      final q = _moviesSearchQuery.toLowerCase();
      return _moviesInCategory('__all__')
          .where((m) => m.title.toLowerCase().contains(q))
          .toList(growable: false);
    }
    final cats = _movieCategories;
    if (_selectedCategoryIndex <= 0) {
      final out = <MockMovie>[];
      final seen = <String>{};
      for (final c in cats) {
        for (final m in _moviesInCategory(c.id)) {
          if (seen.add(m.id)) out.add(m);
        }
      }
      return out;
    }
    if (_selectedCategoryIndex == 1) {
      switch (_myListVodFilter) {
        case _MyListVodFilter.watchedOnly:
          return _moviesWithVodLabel(MovieVodLabel.watched);
        case _MyListVodFilter.continueOnly:
          return _moviesWithVodLabel(MovieVodLabel.continueWatching);
        case _MyListVodFilter.all:
          return _moviesInMyList();
      }
    }
    final i = _selectedCategoryIndex - 2;
    if (i < 0 || i >= cats.length) return [];
    return _moviesInCategory(cats[i].id);
  }

  List<MockMovie> _moviesInCategory(String categoryId) {
    if (categoryId == '__all__') {
      final out = <MockMovie>[];
      final seen = <String>{};
      for (final c in _movieCategories) {
        for (final m in _moviesInCategoryRaw(c.id)) {
          if (seen.add(m.id)) out.add(m);
        }
      }
      return out;
    }
    return _moviesInCategoryRaw(categoryId);
  }

  List<MockMovie> _moviesInCategoryRaw(String categoryId) {
    final list = libraryController.useDemoData
        ? mockMoviesForCategory(categoryId)
        : xtreamCatalogRepository.vodMoviesForCategory(categoryId);
    if (!parentalControlStore.hideRestrictedFromBrowseActive) {
      return list;
    }
    final pid = libraryController.activePlaylistId;
    return list
        .where(
          (m) => !parentalControlStore.isMovieHiddenFromBrowse(
            playlistId: pid,
            movieId: m.id,
            categoryId: categoryId,
          ),
        )
        .toList(growable: false);
  }

  List<MockSeriesCategory> get _seriesCategoriesForVod {
    if (libraryController.useDemoData) return kMockSeriesCategories;
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) return xtreamCatalogRepository.seriesCategories;
    return xtreamCatalogRepository.seriesCategories
        .where(
          (c) => playlistGroupVisibilityStore.isCategoryVisible(
            playlistId,
            PlaylistGroupSection.series,
            c.id,
          ),
        )
        .toList(growable: false);
  }

  List<MockSeries> _seriesInCategoryRawVod(String categoryId) {
    if (libraryController.useDemoData) {
      return mockSeriesForCategory(categoryId);
    }
    return xtreamCatalogRepository.seriesForCategory(categoryId);
  }

  List<MockSeries> _seriesInCategoryAllVod(String categoryId) {
    if (categoryId == '__all__') {
      final out = <MockSeries>[];
      final seen = <String>{};
      for (final c in _seriesCategoriesForVod) {
        for (final s in _seriesInCategoryRawVod(c.id)) {
          if (seen.add(s.id)) out.add(s);
        }
      }
      return out;
    }
    return _seriesInCategoryRawVod(categoryId);
  }

  List<MockSeries> _visibleSeriesForVodSearch() {
    if (_moviesSearchQuery.isEmpty) return [];
    final q = _moviesSearchQuery.toLowerCase();
    return _seriesInCategoryAllVod('__all__')
        .where((s) => s.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// Movies tab: all matching movies, then all matching series.
  List<VodUnifiedEntry> _unifiedVodEntriesForMoviesTab() {
    final mov = _visibleMovies();
    final ser = _visibleSeriesForVodSearch();
    return [
      ...mov.map(VodUnifiedEntry.movie),
      ...ser.map(VodUnifiedEntry.series),
    ];
  }

  void _applyVodUnifiedHeroAtIndex(int index) {
    final list = _unifiedVodEntriesForMoviesTab();
    if (index < 0 || index >= list.length) return;
    final e = list[index];
    if (e.isMovie) {
      _vodUnifiedHeroIsSeries = false;
      _heroMovie.value = e.movie!;
    } else {
      _vodUnifiedHeroIsSeries = true;
      _heroSeriesUnified.value = e.series!;
    }
    setState(() {});
  }

  void _onUnifiedVodPosterFocused(VodUnifiedEntry entry, int index) {
    _lastIndexByCategory[_unifiedVodRailKey] = index;
    if (entry.isMovie) {
      _vodUnifiedHeroIsSeries = false;
      _heroMovie.value = entry.movie!;
    } else {
      _vodUnifiedHeroIsSeries = true;
      _heroSeriesUnified.value = entry.series!;
    }
    setState(() {});
  }

  String _categoryChipLabel(int index) {
    if (index == 0) return 'All';
    if (index == 1) return 'My List';
    return _movieCategories[index - 2].name;
  }

  String _moviesBrowseErrorTitle() {
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
    _ensureAndroidMovieDoubleRowNodes();
    _heroMovie = ValueNotifier(
      mockMoviesForCategory(kMockMovieCategories.first.id).first,
    );
    _heroSeriesUnified = ValueNotifier(
      mockSeriesForCategory(kMockSeriesCategories.first.id).first,
    );
    libraryController.addListener(_onCatalogChanged);
    xtreamCatalogRepository.addListener(_onCatalogChanged);
    playlistGroupVisibilityStore.addListener(_onCatalogChanged);
    mediaCardStyleStore.addListener(_onCatalogChanged);
    movieRailPageSizeStore.addListener(_onRailPageSizeChanged);
    MyListStore.instance.addListener(_onMyListChanged);
    MovieVodLabelStore.instance.addListener(_onCatalogChanged);
    shellSearchStore.addListener(_onCatalogChanged);
    parentalControlStore.addListener(_onCatalogChanged);
    if (!widget.previewMode) {
      ShellBackCoordinator.register(this, _tryConsumeShellBack);
      ShellContentFocusRegistry.register(
        ShellDestination.movies,
        _requestShellPrimaryFocus,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MyListStore.instance.ensureLoaded();
      await MovieVodLabelStore.instance.ensureLoaded();
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
        .consumeVodColdRestoreIf((id) => id.startsWith('movie_'));
    if (snap == null || !mounted) return;
    final mid = snap.browseRestoreMovieId;
    if (mid != null && mid.isNotEmpty) {
      final allowed = await ensureParentalAllowsMoviePlayback(
        context,
        movieId: mid,
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
      browseRestoreMovieId: snap.browseRestoreMovieId,
      suppressPreviousFocusRestore: true,
    );
  }

  void _ensureSlotFocusNodes(int count) {
    if (_movieSlotFocus.length == count) return;
    for (final n in _movieSlotFocus) {
      n.dispose();
    }
    _movieSlotFocus = List.generate(
      count,
      (i) => FocusNode(debugLabel: 'moviesSlot$i'),
    );
  }

  void _disposeAndroidMovieDoubleRowNodes() {
    for (final n in _androidMovieSlotFocusRow1) {
      n.dispose();
    }
    for (final n in _androidMovieSlotFocusRow2) {
      n.dispose();
    }
    _androidMovieSlotFocusRow1 = const [];
    _androidMovieSlotFocusRow2 = const [];
  }

  /// Separate focus nodes for the two-row rail on **Android only** (Windows keeps a single list).
  void _ensureAndroidMovieDoubleRowNodes() {
    if (!Platform.isAndroid) {
      _disposeAndroidMovieDoubleRowNodes();
      return;
    }
    if (!windowsBrowseUseDoubleRow(_kRailPageSize)) {
      _disposeAndroidMovieDoubleRowNodes();
      return;
    }
    if (_androidMovieSlotFocusRow1.length == kWindowsBrowseFirstRowSlots &&
        _androidMovieSlotFocusRow2.length == kWindowsBrowseFirstRowSlots) {
      return;
    }
    _disposeAndroidMovieDoubleRowNodes();
    _androidMovieSlotFocusRow1 = List.generate(
      kWindowsBrowseFirstRowSlots,
      (i) => FocusNode(debugLabel: 'moviesSlotAr1_$i'),
    );
    _androidMovieSlotFocusRow2 = List.generate(
      kWindowsBrowseFirstRowSlots,
      (i) => FocusNode(debugLabel: 'moviesSlotAr2_$i'),
    );
  }

  void _onRailPageSizeChanged() {
    if (!mounted) return;
    _ensureSlotFocusNodes(_kRailPageSize);
    _ensureAndroidMovieDoubleRowNodes();
    setState(() {});
  }

  void _onMyListChanged() {
    if (!mounted) return;
    setState(() {});
    if (_selectedCategoryIndex == 1) {
      final movies = _visibleMovies();
      final key = _posterRailStorageKey();
      if (movies.isNotEmpty) {
        final idx =
            (_lastIndexByCategory[key] ?? 0).clamp(0, movies.length - 1);
        _heroMovie.value = movies[idx];
      }
    }
  }

  void _syncHeroAfterMyListFilter() {
    if (!mounted || _selectedCategoryIndex != 1) return;
    final movies = _visibleMovies();
    final key = _posterRailStorageKey();
    if (movies.isEmpty) return;
    final idx =
        (_lastIndexByCategory[key] ?? 0).clamp(0, movies.length - 1);
    _lastIndexByCategory[key] = idx;
    _heroMovie.value = movies[idx];
  }

  /// IMDb rating on the browse hero artwork (top-right; team-colored).
  Widget _browseHeroImdbBadge(BuildContext context) {
    if (_moviesSearchQuery.isNotEmpty && _vodUnifiedHeroIsSeries) {
      return ValueListenableBuilder<MockSeries>(
        valueListenable: _heroSeriesUnified,
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
    return ValueListenableBuilder<MockMovie>(
      valueListenable: _heroMovie,
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

  Widget _buildMyListVodPills(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = context.teamPalette;
    final a = p.accent;
    final wSel = _myListVodFilter == _MyListVodFilter.watchedOnly;
    final cSel = _myListVodFilter == _MyListVodFilter.continueOnly;
    final wFoc = _myListPillWatchedFocused;
    final cFoc = _myListPillContinueFocused;

    final accentColor = a;
    final accentLine = a.withValues(alpha: 0.5);
    final accentSoft = a.withValues(alpha: 0.14);
    final accentGlow = a.withValues(alpha: 0.22);

    Widget buildPill({
      required bool focused,
      required bool selected,
      required String label,
    }) {
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

      return SizedBox(
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
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.0,
                letterSpacing: -0.005 * 11,
                color: textColor,
              ),
            ),
          ),
        ),
      );
    }

    void toggleWatched() {
      setState(() {
        if (wSel) {
          _myListVodFilter = _MyListVodFilter.all;
        } else {
          _myListVodFilter = _MyListVodFilter.watchedOnly;
        }
      });
      _syncHeroAfterMyListFilter();
    }

    void toggleContinue() {
      setState(() {
        if (cSel) {
          _myListVodFilter = _MyListVodFilter.all;
        } else {
          _myListVodFilter = _MyListVodFilter.continueOnly;
        }
      });
      _syncHeroAfterMyListFilter();
    }

    KeyEventResult? onWatchedKey(FocusNode n, KeyEvent e) {
      if (e is! KeyDownEvent) return null;
      if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        _focusMyListPillContinue.requestFocus();
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        final movies = _visibleMovies();
        if (movies.isEmpty) return KeyEventResult.handled;
        final epoch = _rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestMovieSlotFocus(0, navEpoch: epoch);
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
        _focusMyListPillWatched.requestFocus();
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
        final movies = _visibleMovies();
        if (movies.isEmpty) return KeyEventResult.handled;
        final epoch = _rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _requestMovieSlotFocus(0, navEpoch: epoch);
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

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          TvFocusable(
            focusNode: _focusMyListPillWatched,
            showFocusElevation: false,
            focusPadding: EdgeInsets.zero,
            focusedBorderWidth: 0,
            focusBorderColor: p.defaultFocusRingColor,
            onActivate: toggleWatched,
            onKeyIntercept: onWatchedKey,
            onFocusedChange: (f) =>
                setState(() => _myListPillWatchedFocused = f),
            child: buildPill(
              focused: wFoc,
              selected: wSel,
              label: l10n.actionWatched,
            ),
          ),
          const SizedBox(width: 8),
          TvFocusable(
            focusNode: _focusMyListPillContinue,
            showFocusElevation: false,
            focusPadding: EdgeInsets.zero,
            focusedBorderWidth: 0,
            focusBorderColor: p.defaultFocusRingColor,
            onActivate: toggleContinue,
            onKeyIntercept: onContinueKey,
            onFocusedChange: (f) =>
                setState(() => _myListPillContinueFocused = f),
            child: buildPill(
              focused: cFoc,
              selected: cSel,
              label: l10n.actionContinueWatching,
            ),
          ),
        ],
      ),
    );
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    final cats = _movieCategories;
    if (cats.isEmpty) {
      setState(() {});
      return;
    }
    final chipCount = _categoryChipCount;
    _ensureCategoryChipFocusNodes(chipCount);
    _selectedCategoryIndex = _selectedCategoryIndex.clamp(0, chipCount - 1);
    final movies = _visibleMovies();
    if (movies.isNotEmpty) {
      final key = _posterRailStorageKey();
      final idx =
          (_lastIndexByCategory[key] ?? 0).clamp(0, movies.length - 1);
      _heroMovie.value = movies[idx];
    }
    final q = _moviesSearchQuery;
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
    if (_moviesSearchQuery.isNotEmpty) {
      final u = _unifiedVodEntriesForMoviesTab();
      if (u.isNotEmpty) {
        final idx =
            _railIndexForKey(_unifiedVodRailKey, u).clamp(0, u.length - 1);
        _applyVodUnifiedHeroAtIndex(idx);
      }
    }
    setState(() {});
  }

  void _focusFirstVodSearchResult() {
    final u = _unifiedVodEntriesForMoviesTab();
    if (u.isEmpty || _movieSlotFocus.isEmpty) return;
    _lastIndexByCategory[_unifiedVodRailKey] = 0;
    _applyVodUnifiedHeroAtIndex(0);
    setState(() {});
    _requestMovieSlotFocus(0, navEpoch: _rowNavEpoch);
  }

  void _primeInitialFocus() {
    if (!mounted) return;
    final cats = _movieCategories;
    if (cats.isEmpty) return;
    _ensureCategoryChipFocusNodes(_categoryChipCount);
    _selectedCategoryIndex = 0;
    _myListVodFilter = _MyListVodFilter.all;
    final movies = _visibleMovies();
    if (movies.isEmpty) return;
    final m = movies.first;
    _lastIndexByCategory[_posterRailStorageKey()] = 0;
    _heroMovie.value = m;
    _requestMovieSlotFocus(_slotForCurrentRailIndex(), navEpoch: _rowNavEpoch);
  }

  void _requestShellPrimaryFocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_moviesSearchQuery.isNotEmpty) {
        _focusFirstVodSearchResult();
        return;
      }
      final movies = _visibleMovies();
      if (movies.isNotEmpty) {
        _requestMovieSlotFocus(_slotForCurrentRailIndex(), navEpoch: _rowNavEpoch);
        return;
      }
      final chipCount = _categoryChipCount;
      if (chipCount > 0 && _movieCategories.isNotEmpty) {
        final n = _focusCategoryChip(0);
        if (n.canRequestFocus) n.requestFocus();
      }
    });
  }

  bool _tryConsumeShellBack() {
    if (!mounted) return false;
    if (shellSearchStore.hasQuery(ShellDestination.movies)) {
      shellSearchStore.clear(ShellDestination.movies);
      return true;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null) return false;
    for (final n in _categoryChipFocus.values) {
      if (identical(primary, n)) return false;
    }
    final count = _categoryChipCount;
    if (count <= 0 || _movieCategories.isEmpty) return false;
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
      ShellContentFocusRegistry.unregister(ShellDestination.movies);
      ShellBackCoordinator.unregister(this);
    }
    libraryController.removeListener(_onCatalogChanged);
    xtreamCatalogRepository.removeListener(_onCatalogChanged);
    playlistGroupVisibilityStore.removeListener(_onCatalogChanged);
    mediaCardStyleStore.removeListener(_onCatalogChanged);
    movieRailPageSizeStore.removeListener(_onRailPageSizeChanged);
    MyListStore.instance.removeListener(_onMyListChanged);
    MovieVodLabelStore.instance.removeListener(_onCatalogChanged);
    shellSearchStore.removeListener(_onCatalogChanged);
    parentalControlStore.removeListener(_onCatalogChanged);
    for (final n in _movieSlotFocus) {
      n.dispose();
    }
    _disposeAndroidMovieDoubleRowNodes();
    _heroSeriesUnified.dispose();
    _categoryStripScroll.dispose();
    for (final n in _categoryChipFocus.values) {
      n.dispose();
    }
    _categoryChipFocus.clear();
    _heroMovie.dispose();
    _focusMyListPillWatched.dispose();
    _focusMyListPillContinue.dispose();
    super.dispose();
  }

  int _railIndexForKey<T>(String railKey, List<T> items) {
    if (items.isEmpty) return 0;
    return (_lastIndexByCategory[railKey] ?? 0).clamp(0, items.length - 1);
  }

  int _waveStartForIndex(int index) =>
      (index ~/ _kRailPageSize) * _kRailPageSize;

  /// Resolves the [FocusNode] for a slot index within the current wave.
  ///
  /// On **Android** with a two-row rail, row 1 and row 2 use separate node lists
  /// so each poster has a unique focus owner. Other platforms use [_movieSlotFocus] only.
  FocusNode _movieFocusNodeForWaveSlot(int slotInWave) {
    final s = slotInWave.clamp(0, _kRailPageSize - 1);
    if (Platform.isAndroid &&
        windowsBrowseUseDoubleRow(_kRailPageSize) &&
        _androidMovieSlotFocusRow1.length == kWindowsBrowseFirstRowSlots &&
        _androidMovieSlotFocusRow2.length == kWindowsBrowseFirstRowSlots) {
      if (s >= kWindowsBrowseFirstRowSlots) {
        return _androidMovieSlotFocusRow2[s - kWindowsBrowseFirstRowSlots];
      }
      return _androidMovieSlotFocusRow1[s];
    }
    return _movieSlotFocus[s];
  }

  /// [WindowsBrowseRailFlipSwitcher] animates two stacked children and can flash on TV; Android uses a plain child.
  Widget _moviesRailFlipSwitcherOrPlain({
    required String segmentKey,
    required Widget child,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return BrowseRailTouchVerticalStepListener(
        onStepTowardNextRow: () => _moviesTouchVerticalRailStep(down: true),
        onStepTowardPreviousRow: () =>
            _moviesTouchVerticalRailStep(down: false),
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

  /// Windows 9+ slots: move down within two-row strip or to next wave.
  int _windowsMovieVerticalDownDelta(int idx, int ws, int moviesLen) {
    return windowsBrowseVerticalDownDelta(
      idx: idx,
      waveStart: ws,
      listLength: moviesLen,
      railPageSize: _kRailPageSize,
    );
  }

  int _slotForCurrentRailIndex() {
    final movies = _visibleMovies();
    if (movies.isEmpty) return 0;
    final key = _posterRailStorageKey();
    final idx = _railIndexForKey(key, movies);
    return idx - _waveStartForIndex(idx);
  }

  void _syncHeroToMovie(MockMovie movie) {
    if (_heroMovie.value.id != movie.id) {
      _heroMovie.value = movie;
    }
  }

  void _requestMovieSlotFocus(int slot, {required int navEpoch}) {
    final s = slot.clamp(0, _kRailPageSize - 1);
    void attempt() {
      if (!mounted || navEpoch != _rowNavEpoch) return;
      final node = _movieFocusNodeForWaveSlot(s);
      if (node.canRequestFocus) {
        node.requestFocus();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _moviesGoNextCategoryFirst(int epoch) {
    setState(() {
      _selectedCategoryIndex++;
      if (_selectedCategoryIndex != 1) {
        _myListVodFilter = _MyListVodFilter.all;
      }
      final nk = _posterRailStorageKey();
      final nm = _visibleMovies();
      if (nm.isNotEmpty) {
        _lastIndexByCategory[nk] = 0;
        _syncHeroToMovie(nm.first);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _rowNavEpoch) return;
      _movieFocusNodeForWaveSlot(0).requestFocus();
      final nm = _visibleMovies();
      if (nm.isNotEmpty) _syncHeroToMovie(nm.first);
    });
  }

  void _moviesGoPrevCategoryLast(int epoch) {
    setState(() {
      _selectedCategoryIndex--;
      if (_selectedCategoryIndex != 1) {
        _myListVodFilter = _MyListVodFilter.all;
      }
      final nk = _posterRailStorageKey();
      final nm = _visibleMovies();
      if (nm.isNotEmpty) {
        final last = nm.length - 1;
        _lastIndexByCategory[nk] = last;
        _syncHeroToMovie(nm[last]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _rowNavEpoch) return;
      final nm = _visibleMovies();
      if (nm.isEmpty) return;
      final last = nm.length - 1;
      final newSlot = last - _waveStartForIndex(last);
      _movieFocusNodeForWaveSlot(newSlot).requestFocus();
      _syncHeroToMovie(nm[last]);
    });
  }

  KeyEventResult? _movieRailSlotKey(int slot, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (_moviesSearchQuery.isNotEmpty) {
      return _unifiedVodRailSlotKey(slot, node, event);
    }
    final movies = _visibleMovies();
    if (movies.isEmpty) return KeyEventResult.ignored;
    final key = _posterRailStorageKey();
    final idx = _railIndexForKey(key, movies);

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (idx + 1 < movies.length) {
        final newIdx = idx + 1;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToMovie(movies[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex + 1 < _categoryChipCount) {
        final epoch = ++_rowNavEpoch;
        _moviesGoNextCategoryFirst(epoch);
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToMovie(movies[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex > 0) {
        final epoch = ++_rowNavEpoch;
        _moviesGoPrevCategoryLast(epoch);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final ws = _waveStartForIndex(idx);
      final delta = _windowsMovieVerticalDownDelta(idx, ws, movies.length);
      final below = idx + delta;
      if (below < movies.length) {
        final newIdx = below;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToMovie(movies[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex + 1 < _categoryChipCount) {
        final epoch = ++_rowNavEpoch;
        _moviesGoNextCategoryFirst(epoch);
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToMovie(movies[newIdx]);
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToMovie(movies[newIdx]);
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex == 1 && _moviesSearchQuery.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusMyListPillWatched.requestFocus();
        });
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex > 0) {
        final epoch = ++_rowNavEpoch;
        setState(() {
          _selectedCategoryIndex--;
          if (_selectedCategoryIndex != 1) {
            _myListVodFilter = _MyListVodFilter.all;
          }
          final nk = _posterRailStorageKey();
          final nm = _visibleMovies();
          if (nm.isNotEmpty) {
            _lastIndexByCategory[nk] = 0;
            _syncHeroToMovie(nm.first);
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _movieFocusNodeForWaveSlot(0).requestFocus();
          final nm = _visibleMovies();
          if (nm.isNotEmpty) _syncHeroToMovie(nm.first);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return null;
  }

  KeyEventResult? _unifiedVodRailSlotKey(int slot, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final unified = _unifiedVodEntriesForMoviesTab();
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _applyVodUnifiedHeroAtIndex(newIdx);
        });
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return null;
  }

  static const double _kMoviesWheelScrollThreshold = 24.0;

  void _onMoviesRailPointerSignal(PointerSignalEvent e) {
    if (!Platform.isWindows) return;
    if (e is! PointerScrollEvent) return;
    final dy = e.scrollDelta.dy;
    if (dy.abs() < _kMoviesWheelScrollThreshold) return;
    if (dy > 0) {
      _moviesWheelVertical(down: true);
    } else {
      _moviesWheelVertical(down: false);
    }
  }

  /// Windows: vertical wheel → same navigation as Arrow Up / Down on the poster rail.
  void _moviesWheelVertical({required bool down}) {
    if (!Platform.isWindows) return;
    if (_moviesSearchQuery.isNotEmpty) {
      _moviesWheelUnifiedVertical(down: down);
      return;
    }
    _moviesBrowseVerticalNudge(down: down);
  }

  /// Android / iOS touch: one vertical swipe step on the poster rail.
  void _moviesTouchVerticalRailStep({required bool down}) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_moviesSearchQuery.isNotEmpty) {
      _moviesWheelUnifiedVertical(down: down);
      return;
    }
    _moviesBrowseVerticalNudge(down: down);
  }

  /// Shared vertical rail navigation (D-pad Up/Down / wheel / touch swipe).
  void _moviesBrowseVerticalNudge({required bool down}) {
    final movies = _visibleMovies();
    if (movies.isEmpty) return;
    final key = _posterRailStorageKey();
    final idx = _railIndexForKey(key, movies);

    if (down) {
      final ws = _waveStartForIndex(idx);
      final delta = windowsBrowseVerticalDownDelta(
        idx: idx,
        waveStart: ws,
        listLength: movies.length,
        railPageSize: _kRailPageSize,
      );
      final below = idx + delta;
      if (below < movies.length) {
        final newIdx = below;
        final newSlot = newIdx - _waveStartForIndex(newIdx);
        setState(() => _lastIndexByCategory[key] = newIdx);
        final epoch = ++_rowNavEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || epoch != _rowNavEpoch) return;
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
          _syncHeroToMovie(movies[newIdx]);
        });
        return;
      }
      if (_selectedCategoryIndex + 1 < _categoryChipCount) {
        final epoch = ++_rowNavEpoch;
        _moviesGoNextCategoryFirst(epoch);
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
        _movieFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToMovie(movies[newIdx]);
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
        _movieFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToMovie(movies[newIdx]);
      });
      return;
    }
    if (_selectedCategoryIndex == 1 && _moviesSearchQuery.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusMyListPillWatched.requestFocus();
      });
      return;
    }
    if (_selectedCategoryIndex > 0) {
      final epoch = ++_rowNavEpoch;
      setState(() {
        _selectedCategoryIndex--;
        if (_selectedCategoryIndex != 1) {
          _myListVodFilter = _MyListVodFilter.all;
        }
        final nk = _posterRailStorageKey();
        final nm = _visibleMovies();
        if (nm.isNotEmpty) {
          _lastIndexByCategory[nk] = 0;
          _syncHeroToMovie(nm.first);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || epoch != _rowNavEpoch) return;
        _movieFocusNodeForWaveSlot(0).requestFocus();
        final nm = _visibleMovies();
        if (nm.isNotEmpty) _syncHeroToMovie(nm.first);
      });
    }
  }

  void _moviesWheelUnifiedVertical({required bool down}) {
    final unified = _unifiedVodEntriesForMoviesTab();
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
          _movieFocusNodeForWaveSlot(newSlot).requestFocus();
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
        _movieFocusNodeForWaveSlot(newSlot).requestFocus();
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
        _movieFocusNodeForWaveSlot(newSlot).requestFocus();
        _applyVodUnifiedHeroAtIndex(newIdx);
      });
    }
  }

  KeyEventResult? _categoryChipKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final top =
          ShellContentFocusRegistry.topNavFocus(ShellDestination.movies);
      if (top != null) requestLadderFocus(top);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_moviesSearchQuery.isNotEmpty) {
        final u = _unifiedVodEntriesForMoviesTab();
        if (u.isEmpty) return KeyEventResult.handled;
        final epoch = ++_rowNavEpoch;
        final idx = _railIndexForKey(_unifiedVodRailKey, u)
            .clamp(0, u.length - 1);
        final slot = idx - _waveStartForIndex(idx);
        void scheduleFocus() {
          if (!mounted || epoch != _rowNavEpoch) return;
          _requestMovieSlotFocus(slot, navEpoch: epoch);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => scheduleFocus());
        return KeyEventResult.handled;
      }
      if (_selectedCategoryIndex == 1 && _moviesSearchQuery.isEmpty) {
        final movies = _visibleMovies();
        if (movies.isEmpty) return KeyEventResult.handled;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusMyListPillWatched.requestFocus();
        });
        return KeyEventResult.handled;
      }
      final movies = _visibleMovies();
      if (movies.isEmpty) return KeyEventResult.handled;
      final epoch = ++_rowNavEpoch;
      final key = _posterRailStorageKey();
      final idx =
          (_lastIndexByCategory[key] ?? 0).clamp(0, movies.length - 1);
      final slot = idx - _waveStartForIndex(idx);
      void scheduleFocus() {
        if (!mounted || epoch != _rowNavEpoch) return;
        _requestMovieSlotFocus(slot, navEpoch: epoch);
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
          _myListVodFilter = _MyListVodFilter.all;
        }
      });
    }
    final movies = _visibleMovies();
    if (movies.isEmpty) return;
    final key = _posterRailStorageKey();
    final idx =
        (_lastIndexByCategory[key] ?? 0).clamp(0, movies.length - 1);
    final m = movies[idx];
    _syncHeroToMovie(m);
  }

  void _onPosterFocused(MockMovie movie, int index) {
    _lastIndexByCategory[_posterRailStorageKey()] = index;
    _syncHeroToMovie(movie);
  }

  /// Horizontal swipe on mobile: page the poster rail forward or backward.
  void _onPosterRailSwipe(DragEndDetails details) {
    if (_moviesSearchQuery.isNotEmpty) return;
    final movies = _visibleMovies();
    if (movies.isEmpty) return;
    final key = _posterRailStorageKey();
    final idx = _railIndexForKey(key, movies);
    final vx = details.velocity.pixelsPerSecond.dx;
    const threshold = 200.0;
    if (vx < -threshold && idx + _kRailPageSize < movies.length) {
      final int newIdx = (idx + _kRailPageSize).clamp(0, movies.length - 1);
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[key] = newIdx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _movieFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToMovie(movies[newIdx]);
      });
    } else if (vx > threshold && idx - _kRailPageSize >= 0) {
      final int newIdx = (idx - _kRailPageSize).clamp(0, movies.length - 1);
      final newSlot = newIdx - _waveStartForIndex(newIdx);
      setState(() => _lastIndexByCategory[key] = newIdx);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _movieFocusNodeForWaveSlot(newSlot).requestFocus();
        _syncHeroToMovie(movies[newIdx]);
      });
    }
  }

  /// When the fullscreen player closes (still on details), keep browse rail + hero aligned.
  /// Does not move focus to the poster rail — details is still on top; refocusing
  /// the grid would steal focus from the movie page.
  void _syncMovieBrowseToId(String id) {
    if (!mounted) return;
    final railKey = _posterRailStorageKey();
    final movies = _visibleMovies();
    final idx = movies.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    setState(() {
      _lastIndexByCategory[railKey] = idx;
    });
    _syncHeroToMovie(movies[idx]);
  }

  Future<void> _openDetails(MockMovie movie) async {
    final id = movie.id;

    // Make sure the top hero updates immediately for the activated movie.
    // This prevents a mismatch when activation happens before focus-change
    // callbacks propagate.
    _syncHeroToMovie(movie);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MovieDetailsScreen(
          movie: movie,
          onReturnedFromPlayer: _syncMovieBrowseToId,
        ),
      ),
    );

    if (!mounted) return;

    final railKey = _posterRailStorageKey();
    final movies = _visibleMovies();
    final idx = movies.indexWhere((m) => m.id == id);
    if (idx >= 0) {
      _lastIndexByCategory[railKey] = idx;
    }

    final restored = idx >= 0 ? movies[idx] : movie;
    _syncHeroToMovie(restored);

    final epoch = _rowNavEpoch;
    final slot = idx >= 0 ? idx - _waveStartForIndex(idx) : 0;
    _requestMovieSlotFocus(slot, navEpoch: epoch);
  }

  Future<void> _openSeriesDetailsFromVod(MockSeries series) async {
    final id = series.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SeriesDetailsScreen(series: series),
      ),
    );
    if (!mounted) return;
    final u = _unifiedVodEntriesForMoviesTab();
    final idx = u.indexWhere((e) => !e.isMovie && e.series!.id == id);
    if (idx >= 0) {
      _lastIndexByCategory[_unifiedVodRailKey] = idx;
    }
    final slot = idx >= 0 ? idx - _waveStartForIndex(idx) : 0;
    _requestMovieSlotFocus(slot, navEpoch: _rowNavEpoch);
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
          const CatalogLoadingBody(message: 'Loading movies…'),
        );
      }
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.error) {
        return _previewWrap(
          catalogXtreamErrorBody(
            kind: xtreamCatalogRepository.errorKind,
            errorMessage: xtreamCatalogRepository.errorMessage,
            titleForKind: _moviesBrowseErrorTitle,
          ),
        );
      }
    }

    final cats = _movieCategories;
    if (!libraryController.useDemoData &&
        cats.isEmpty &&
        xtreamCatalogRepository.phase == XtreamCatalogPhase.ready) {
      return _previewWrap(
        const CatalogEmptyBody(
          message: 'No movie categories were returned for this playlist.',
        ),
      );
    }

    if (cats.isEmpty) {
      return _previewWrap(
        const CatalogEmptyBody(message: 'No categories available.'),
      );
    }

    _ensureCategoryChipFocusNodes(_categoryChipCount);
    final movies = _visibleMovies();
    final railKey = _posterRailStorageKey();

    return _previewWrap(
      LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: color-matched background + backdrop image ──
            // Wrapped in ValueListenableBuilder so it stays in sync.
            ValueListenableBuilder<MockMovie>(
              valueListenable: _heroMovie,
              builder: (context, movie, _) {
                final posterUrl = catalogPosterHiResUrl(
                  moviePosterUrl(movie),
                );
                final hasBackdrop = posterUrl.isNotEmpty;
                final bgColor = Color.lerp(
                  movie.posterPrimary,
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
                          duration: kMovieBrowseHeroMotion,
                          curve: kMovieBrowseHeroMotionCurve,
                          color: bgColor,
                        ),
                        if (hasBackdrop)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: w * 0.58,
                            child: AnimatedSwitcher(
                              duration: kMovieBrowseHeroMotion,
                              switchInCurve: kMovieBrowseHeroMotionCurve,
                              switchOutCurve: kMovieBrowseHeroMotionCurve,
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

            // ── Layer 2: content (text info + categories + poster rail) ──
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 10, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero text info (left side)
                      Expanded(
                        flex: 5,
                        child: _moviesSearchQuery.isEmpty
                            ? MovieBrowseHeroCard(
                                listenable: _heroMovie,
                              )
                            : AnimatedSwitcher(
                                duration: AppTheme.contentCrossFadeDuration,
                                switchInCurve: AppTheme.contentCrossFadeCurve,
                                switchOutCurve: AppTheme.contentCrossFadeCurve,
                                child: _vodUnifiedHeroIsSeries
                                    ? SeriesBrowseHeroCard(
                                        key: ValueKey<String>(
                                          'vodS_${_heroSeriesUnified.value.id}',
                                        ),
                                        listenable: _heroSeriesUnified,
                                      )
                                    : MovieBrowseHeroCard(
                                        key: ValueKey<String>(
                                          'vodM_${_heroMovie.value.id}',
                                        ),
                                        listenable: _heroMovie,
                                      ),
                              ),
                      ),
                      Expanded(
                        flex: 6,
                        child: Platform.isWindows
                          ? Listener(
                                    onPointerSignal:
                                        _onMoviesRailPointerSignal,
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
                              child: _MoviesCategoryStrip(
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
                                _unifiedVodEntriesForMoviesTab();

                            Widget wrapWithCats(Widget rail) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  catStrip,
                                  const SizedBox(height: pillGap),
                                  if (_moviesSearchQuery.isEmpty &&
                                      _selectedCategoryIndex == 1) ...[
                                    _buildMyListVodPills(context),
                                    const SizedBox(height: 8),
                                  ],
                                  rail,
                                ],
                              );
                            }

                            if (_moviesSearchQuery.isNotEmpty) {
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
                                                'vod_unified_movies_r1'),
                                            railPageSize: _kRailPageSize,
                                            categoryLabel: 'Search',
                                            entries: unified,
                                            waveStart: wave,
                                            posterWidth: posterW,
                                            posterHeight: posterH,
                                            gap: gap,
                                            slotFocusNodes:
                                                _movieSlotFocus,
                                            onSlotKey:
                                                _unifiedVodRailSlotKey,
                                            onPosterFocused:
                                                _onUnifiedVodPosterFocused,
                                            onMovieActivate: _openDetails,
                                            onSeriesActivate:
                                                _openSeriesDetailsFromVod,
                                            slotStart: 0,
                                            slotEnd:
                                                kWindowsBrowseFirstRowSlots,
                                          ),
                                          SizedBox(height: wd.rowGap),
                                          Opacity(
                                            opacity: wd.secondRowOpacity,
                                            child: VodUnifiedPosterStrip(
                                              key: const ValueKey<String>(
                                                  'vod_unified_movies_r2'),
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
                                                  _movieSlotFocus,
                                              onSlotKey:
                                                  _unifiedVodRailSlotKey,
                                              onPosterFocused:
                                                  _onUnifiedVodPosterFocused,
                                              onMovieActivate:
                                                  _openDetails,
                                              onSeriesActivate:
                                                  _openSeriesDetailsFromVod,
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
                                            'vod_unified_movies'),
                                        railPageSize: _kRailPageSize,
                                        categoryLabel: 'Search',
                                        entries: unified,
                                        waveStart: wave,
                                        posterWidth: posterW,
                                        posterHeight: posterH,
                                        gap: gap,
                                        slotFocusNodes: _movieSlotFocus,
                                        onSlotKey:
                                            _unifiedVodRailSlotKey,
                                        onPosterFocused:
                                            _onUnifiedVodPosterFocused,
                                        onMovieActivate: _openDetails,
                                        onSeriesActivate:
                                            _openSeriesDetailsFromVod,
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

                            if (movies.isEmpty) {
                              return wrapWithCats(Center(
                                child: Text(
                                  'No movies for this filter.',
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
                                _railIndexForKey(railKey, movies),
                              );
                              final listIdx =
                                  _railIndexForKey(railKey, movies);
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
                                        _MoviesRowStrip(
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
                                          movies: movies,
                                          waveStart: wave,
                                          posterWidth: posterW,
                                          posterHeight: posterH,
                                          gap: gap,
                                          slotFocusNodes:
                                              _movieSlotFocus,
                                          onSlotKey: _movieRailSlotKey,
                                          onPosterFocused:
                                              _onPosterFocused,
                                          onMovieActivate: _openDetails,
                                        ),
                                        SizedBox(height: wd.rowGap),
                                        Opacity(
                                          opacity: wd.secondRowOpacity,
                                          child: _MoviesRowStrip(
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
                                            movies: movies,
                                            waveStart: wave +
                                                kWindowsBrowseFirstRowSlots,
                                            posterWidth: posterW,
                                            posterHeight: posterH,
                                            gap: gap,
                                            slotFocusNodes:
                                                _movieSlotFocus,
                                            onSlotKey: _movieRailSlotKey,
                                            onPosterFocused:
                                                _onPosterFocused,
                                            onMovieActivate: _openDetails,
                                          ),
                                        ),
                                      ],
                                    )
                                  : _MoviesRowStrip(
                                      key: ValueKey<String>(railKey),
                                      railPageSize: _kRailPageSize,
                                      categoryLabel: _categoryChipLabel(
                                          _selectedCategoryIndex),
                                      movies: movies,
                                      waveStart: wave,
                                      posterWidth: posterW,
                                      posterHeight: posterH,
                                      gap: gap,
                                      slotFocusNodes: _movieSlotFocus,
                                      onSlotKey: _movieRailSlotKey,
                                      onPosterFocused: _onPosterFocused,
                                      onMovieActivate: _openDetails,
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
                              child: _MoviesCategoryStrip(
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
                                _unifiedVodEntriesForMoviesTab();

                            Widget wrapWithCats(Widget rail) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  catStrip,
                                  const SizedBox(height: pillGap),
                                  if (_moviesSearchQuery.isEmpty &&
                                      _selectedCategoryIndex == 1) ...[
                                    _buildMyListVodPills(context),
                                    const SizedBox(height: 8),
                                  ],
                                  rail,
                                ],
                              );
                            }

                            if (_moviesSearchQuery.isNotEmpty) {
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
                              final movieRow1Nodes = Platform.isAndroid &&
                                      wd.useDoubleRow
                                  ? _androidMovieSlotFocusRow1
                                  : _movieSlotFocus;
                              final movieRow2Nodes = Platform.isAndroid &&
                                      wd.useDoubleRow
                                  ? _androidMovieSlotFocusRow2
                                  : _movieSlotFocus;
                              final stripChild = wd.useDoubleRow
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        VodUnifiedPosterStrip(
                                          key: const ValueKey<String>(
                                              'vod_unified_movies_r1'),
                                          railPageSize: _kRailPageSize,
                                          categoryLabel: 'Search',
                                          entries: unified,
                                          waveStart: wave,
                                          posterWidth: posterW,
                                          posterHeight: posterH,
                                          gap: gap,
                                          slotFocusNodes:
                                              movieRow1Nodes,
                                          onSlotKey:
                                              _unifiedVodRailSlotKey,
                                          onPosterFocused:
                                              _onUnifiedVodPosterFocused,
                                          onMovieActivate: _openDetails,
                                          onSeriesActivate:
                                              _openSeriesDetailsFromVod,
                                          slotStart: 0,
                                          slotEnd:
                                              kWindowsBrowseFirstRowSlots,
                                        ),
                                        SizedBox(height: wd.rowGap),
                                        Opacity(
                                          opacity: wd.secondRowOpacity,
                                          child: VodUnifiedPosterStrip(
                                            key: const ValueKey<String>(
                                                'vod_unified_movies_r2'),
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
                                                movieRow2Nodes,
                                            onSlotKey:
                                                _unifiedVodRailSlotKey,
                                            onPosterFocused:
                                                _onUnifiedVodPosterFocused,
                                            onMovieActivate:
                                                _openDetails,
                                            onSeriesActivate:
                                                _openSeriesDetailsFromVod,
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
                                          'vod_unified_movies'),
                                      railPageSize: _kRailPageSize,
                                      categoryLabel: 'Search',
                                      entries: unified,
                                      waveStart: wave,
                                      posterWidth: posterW,
                                      posterHeight: posterH,
                                      gap: gap,
                                      slotFocusNodes: _movieSlotFocus,
                                      onSlotKey:
                                          _unifiedVodRailSlotKey,
                                      onPosterFocused:
                                          _onUnifiedVodPosterFocused,
                                      onMovieActivate: _openDetails,
                                      onSeriesActivate:
                                          _openSeriesDetailsFromVod,
                                    );

                              return wrapWithCats(Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: outerW,
                                  child: _moviesRailFlipSwitcherOrPlain(
                                    segmentKey: flipSeg,
                                    child: stripChild,
                                  ),
                                ),
                              ));
                            }

                            if (movies.isEmpty) {
                              return wrapWithCats(Center(
                                child: Text(
                                  'No movies for this filter.',
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
                              _railIndexForKey(railKey, movies),
                            );
                            final listIdx =
                                _railIndexForKey(railKey, movies);
                            final flipSeg =
                                windowsBrowseFlipSegmentKey(
                              listIndex: listIdx,
                              railPageSize: _kRailPageSize,
                              useDoubleRow: wd.useDoubleRow,
                            );
                            final movieRow1Nodes = Platform.isAndroid &&
                                    wd.useDoubleRow
                                ? _androidMovieSlotFocusRow1
                                : _movieSlotFocus;
                            final movieRow2Nodes = Platform.isAndroid &&
                                    wd.useDoubleRow
                                ? _androidMovieSlotFocusRow2
                                : _movieSlotFocus;

                            final stripChild = wd.useDoubleRow
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _MoviesRowStrip(
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
                                        movies: movies,
                                        waveStart: wave,
                                        posterWidth: posterW,
                                        posterHeight: posterH,
                                        gap: gap,
                                        slotFocusNodes:
                                            movieRow1Nodes,
                                        onSlotKey: _movieRailSlotKey,
                                        onPosterFocused:
                                            _onPosterFocused,
                                        onMovieActivate: _openDetails,
                                      ),
                                      SizedBox(height: wd.rowGap),
                                      Opacity(
                                        opacity: wd.secondRowOpacity,
                                        child: _MoviesRowStrip(
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
                                          movies: movies,
                                          waveStart: wave +
                                              kWindowsBrowseFirstRowSlots,
                                          posterWidth: posterW,
                                          posterHeight: posterH,
                                          gap: gap,
                                          slotFocusNodes:
                                              movieRow2Nodes,
                                          onSlotKey: _movieRailSlotKey,
                                          onPosterFocused:
                                              _onPosterFocused,
                                          onMovieActivate: _openDetails,
                                        ),
                                      ),
                                    ],
                                  )
                                : _MoviesRowStrip(
                                    key: ValueKey<String>(railKey),
                                    railPageSize: _kRailPageSize,
                                    categoryLabel: _categoryChipLabel(
                                        _selectedCategoryIndex),
                                    movies: movies,
                                    waveStart: wave,
                                    posterWidth: posterW,
                                    posterHeight: posterH,
                                    gap: gap,
                                    slotFocusNodes: _movieSlotFocus,
                                    onSlotKey: _movieRailSlotKey,
                                    onPosterFocused: _onPosterFocused,
                                    onMovieActivate: _openDetails,
                                  );

                            return wrapWithCats(Align(
                              alignment: Alignment.bottomCenter,
                              child: SizedBox(
                                width: outerW,
                                child: _moviesRailFlipSwitcherOrPlain(
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

class _MoviesCategoryStrip extends StatelessWidget {
  const _MoviesCategoryStrip({
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
    // Same as Live TV: [SingleChildScrollView] + [Row] so pills are not vertically
    // centered in the strip (horizontal [ListView] added extra space above/below).
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
              onFocusChanged: (has) => onChipFocused(i, has),
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

class _MoviesRowStrip extends StatelessWidget {
  const _MoviesRowStrip({
    super.key,
    required this.categoryLabel,
    required this.movies,
    required this.waveStart,
    required this.railPageSize,
    required this.posterWidth,
    required this.posterHeight,
    required this.gap,
    required this.slotFocusNodes,
    required this.onSlotKey,
    required this.onPosterFocused,
    required this.onMovieActivate,
    this.slotStart = 0,
    this.slotEnd,
    this.clipTopHalfOfPoster = false,
    this.peekClipHeight,
  });

  final String categoryLabel;
  final List<MockMovie> movies;
  final int waveStart;
  final int railPageSize;
  final double posterWidth;
  final double posterHeight;
  final double gap;
  final List<FocusNode> slotFocusNodes;
  final KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey;
  final void Function(MockMovie movie, int index) onPosterFocused;
  final Future<void> Function(MockMovie movie) onMovieActivate;

  /// Inclusive start slot index (0 … `railPageSize` − 1).
  final int slotStart;

  /// Exclusive end slot; defaults to [railPageSize].
  final int? slotEnd;

  /// Second row on Windows: show only the top half of each poster.
  final bool clipTopHalfOfPoster;

  /// When set (Windows two-row), height of the clipped peek strip in logical px.
  final double? peekClipHeight;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return Center(
        child: Text(
          'No titles in $categoryLabel',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final end = slotEnd ?? railPageSize;
    final rowMainAxis = clipTopHalfOfPoster &&
            (end - slotStart) < kWindowsBrowseFirstRowSlots
        ? MainAxisAlignment.center
        : MainAxisAlignment.start;

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: rowMainAxis,
        children: [
          for (var slot = slotStart; slot < end; slot++)
            Padding(
              padding: EdgeInsets.only(
                right: slot == end - 1 ? 0 : gap,
              ),
              child: _moviesRailCell(
                slot: slot,
                waveStart: waveStart,
                movies: movies,
                slotFocusNodes: slotFocusNodes,
                onSlotKey: onSlotKey,
                onPosterFocused: onPosterFocused,
                onMovieActivate: onMovieActivate,
                posterWidth: posterWidth,
                posterHeight: posterHeight,
                clipTopHalfOfPoster: clipTopHalfOfPoster,
                peekClipHeight: peekClipHeight,
              ),
            ),
        ],
      ),
    );
  }
}

Widget _moviesRailCell({
  required int slot,
  required int waveStart,
  required List<MockMovie> movies,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(MockMovie movie, int index) onPosterFocused,
  required Future<void> Function(MockMovie movie) onMovieActivate,
  required double posterWidth,
  required double posterHeight,
  required bool clipTopHalfOfPoster,
  double? peekClipHeight,
}) {
  final tile = SizedBox(
    width: posterWidth,
    height: posterHeight,
              child: _moviesRailSlot(
      slot: slot,
      waveStart: waveStart,
      movies: movies,
      slotFocusNodes: slotFocusNodes,
      onSlotKey: onSlotKey,
      onPosterFocused: onPosterFocused,
      onMovieActivate: onMovieActivate,
      styleEmptyPeekSlot: clipTopHalfOfPoster,
    ),
  );
  if (!clipTopHalfOfPoster) return tile;
  final clipH = peekClipHeight ??
      posterHeight * kWindowsBrowseSecondRowHeightFraction;
  return SizedBox(
    height: clipH,
    child: ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: tile,
      ),
    ),
  );
}

Widget _moviesRailSlot({
  required int slot,
  required int waveStart,
  required List<MockMovie> movies,
  required List<FocusNode> slotFocusNodes,
  required KeyEventResult? Function(int slot, FocusNode node, KeyEvent event)
      onSlotKey,
  required void Function(MockMovie movie, int index) onPosterFocused,
  required Future<void> Function(MockMovie movie) onMovieActivate,
  bool styleEmptyPeekSlot = false,
}) {
  final gi = waveStart + slot;
  if (gi >= movies.length) {
    if (Platform.isWindows && styleEmptyPeekSlot) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kPosterRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: const SizedBox.expand(),
      );
    }
    return const SizedBox.expand();
  }
  final m = movies[gi];
  Widget tile = RepaintBoundary(
    child: _MoviePosterTile(
      movie: m,
      focusNode: slotFocusNodes[slot],
      onFocusedChange: (has) {
        if (has) onPosterFocused(m, gi);
      },
      onKeyIntercept: (node, ev) => onSlotKey(slot, node, ev),
      onActivate: () => onMovieActivate(m),
    ),
  );
  if (Platform.isWindows) {
    tile = MouseRegion(
      onEnter: (_) => onPosterFocused(m, gi),
      child: tile,
    );
  }
  return tile;
}

class _MoviePosterTile extends StatelessWidget {
  const _MoviePosterTile({
    required this.movie,
    required this.onFocusedChange,
    required this.onKeyIntercept,
    required this.onActivate,
    required this.focusNode,
  });

  final MockMovie movie;
  final ValueChanged<bool> onFocusedChange;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onKeyIntercept;
  final VoidCallback onActivate;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posterUrl =
        _moviesHiResPosterUrl(moviePosterUrl(movie));
    final style = mediaCardStyleStore.movieStyle;
    final ratingText = movie.rating?.trim();

    return ListenableBuilder(
      listenable: MovieVodLabelStore.instance,
      builder: (context, _) {
        final lab = MovieVodLabelStore.instance.labelFor(movie.id);
        Widget? cornerBadge;
        if (lab == MovieVodLabel.watched) {
          cornerBadge = const MovieWatchedCornerBadge();
        } else if (lab == MovieVodLabel.continueWatching) {
          cornerBadge = const MovieContinueWatchingCornerBadge();
        } else if (lab == MovieVodLabel.watching) {
          cornerBadge = const MovieWatchingCornerBadge();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final pm = WindowsPosterTextMetrics(constraints.maxWidth);
            return VodLiveTvStyleFocus(
              focusNode: focusNode,
              borderRadius: _kPosterRadius,
              onFocusedChange: onFocusedChange,
              onKeyIntercept: onKeyIntercept,
              onActivate: onActivate,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_kPosterRadius),
                      color: const Color(0xFF131822),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_kPosterRadius),
                      child: switch (style) {
                        MediaPosterCardStyle.posterAndTitle => Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: _MoviesHiResImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.68),
                                    ],
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: pm.overlayPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        fontSize: pm.titleFont,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: pm.titleShadows,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${movie.year}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                        fontSize: pm.metaFont,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        MediaPosterCardStyle.posterAndName => Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: _MoviesHiResImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.68),
                                    ],
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: pm.overlayPadding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Spacer(),
                                    Text(
                                      movie.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        fontSize: pm.titleFont,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: pm.titleShadows,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        MediaPosterCardStyle.posterOnly => Padding(
                            padding: EdgeInsets.all(pm.posterOnlyOuterPad),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(10 * pm.scale),
                                color: Colors.black.withOpacity(0.22),
                                border: Border.all(
                                    color:
                                        Colors.white.withOpacity(0.12)),
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(10 * pm.scale),
                                child: _MoviesHiResImage(
                                  url: posterUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        MediaPosterCardStyle.titleOnly => DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.06),
                                  Colors.black.withOpacity(0.2),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: pm.horizontalTitleOnlyPad),
                                child: Text(
                                  movie.title,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.titleSmall?.copyWith(
                                    fontSize: pm.titleOnlyFont,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      },
                    ),
                  ),
                  if (ratingText != null && ratingText.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 2,
                      child: IgnorePointer(
                        child: VodImdbRatingBadge(
                          rating: ratingText,
                          size: VodImdbRatingBadgeSize.poster,
                        ),
                      ),
                    ),
                  if (cornerBadge != null)
                    Positioned(
                      left: pm.badgeLeft,
                      bottom: pm.badgeBottom,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: cornerBadge,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum _MyListVodFilter { all, watchedOnly, continueOnly }
