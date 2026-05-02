import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/episode_vod_label_store.dart';
import '../../data/library_controller.dart';
import '../../data/parental_control_store.dart';
import '../../data/movie_vod_label_store.dart';
import '../../data/my_list_store.dart';
import '../../data/series_vod_label_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../player/mock_stream_urls.dart';
import '../../player/playback_resume_store.dart';
import '../../player/player_navigation.dart';
import '../../ui/parental/parental_playback_guard.dart';
import '../../ui/settings/parental_scope_dialogs.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/vod_live_tv_style_focus.dart';
import '../common/in_app_youtube_trailer_screen.dart';
import '../windows/windows_desktop_scale.dart';
import '../widgets/detail_actions.dart';
import '../widgets/movie_watched_badge.dart';
import '../widgets/vod_imdb_rating_badge.dart';
import '../widgets/episode_season_caption_bar.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'android_series_episode_tile.dart';
import 'mock_series_data.dart';

const double _kEpisodeTileRadius = 13;

Widget? _episodeVodLabelCornerBadge(MovieVodLabel lab) {
  if (lab == MovieVodLabel.watched) return const MovieWatchedCornerBadge();
  if (lab == MovieVodLabel.continueWatching) {
    return const MovieContinueWatchingCornerBadge();
  }
  if (lab == MovieVodLabel.watching) return const MovieWatchingCornerBadge();
  return null;
}

@immutable
class SeriesDetailsHeroSnapshot {
  const SeriesDetailsHeroSnapshot({
    required this.title,
    required this.metaLine,
    required this.description,
    required this.imageUrl,
  });

  final String title;
  final String metaLine;
  final String description;
  final String imageUrl;

  factory SeriesDetailsHeroSnapshot.series(MockSeries s) {
    return SeriesDetailsHeroSnapshot(
      title: s.title,
      metaLine: '${s.year} · ${s.genre}',
      description: s.description,
      imageUrl: catalogBackdropHiResUrl(seriesBackdropUrl(s)),
    );
  }

  factory SeriesDetailsHeroSnapshot.episode(MockSeries s, MockEpisode e) {
    final still = episodeStillUrl(s, e).trim();
    final fallbackPoster = seriesPosterUrl(s);
    return SeriesDetailsHeroSnapshot(
      title: e.title,
      metaLine: e.codename,
      description: e.description,
      imageUrl: catalogPosterHiResUrl(
        still.isNotEmpty ? still : fallbackPoster,
      ),
    );
  }
}

/// Fullscreen series details with season/episode rails and dynamic hero.
class SeriesDetailsScreen extends StatefulWidget {
  const SeriesDetailsScreen({
    super.key,
    required this.series,
    this.onReturnedFromPlayer,
  });

  final MockSeries series;

  /// Sync series browse rail/hero when the player closes.
  final ValueChanged<String>? onReturnedFromPlayer;

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  late MockSeries _series;
  late final ValueNotifier<SeriesDetailsHeroSnapshot> _hero;

  /// Same as movie details: block duplicate system-back right after player closes.
  DateTime? _ignoreSystemBackUntil;

  void _markPlayerJustClosed() {
    if (!mounted) return;
    setState(() {
      _ignoreSystemBackUntil =
          DateTime.now().add(const Duration(milliseconds: 480));
    });
  }

  bool get _shouldSwallowSystemBack {
    final t = _ignoreSystemBackUntil;
    if (t == null) return false;
    return DateTime.now().isBefore(t);
  }

  final FocusNode _backFocus = FocusNode(debugLabel: 'seriesDetailsBack');

  /// Android: first action (Play) uses this node so focus order can start on the action row.
  final FocusNode _androidFirstActionFocus =
      FocusNode(debugLabel: 'seriesDetailsAndroidAction0');

  final Map<String, ScrollController> _scrollBySeason = {};
  final Map<String, double> _savedScrollBySeason = {};
  final Map<String, FocusNode> _focusByEpisodeId = {};
  final Map<String, GlobalKey> _keysByEpisodeId = {};
  final Map<String, int> _lastEpisodeIndexBySeason = {};

  var _revealEpoch = 0;
  var _loadingXtreamDetail = false;
  String? _xtreamDetailError;
  Timer? _xtreamErrorDismissTimer;

  List<MockSeason> get _seasons => _series.seasons;

  /// Android + Windows: actions row under description, then episodes (same visuals on Windows; behavior differs by platform).
  bool get _useTopActionsEpisodeLayout =>
      Platform.isAndroid || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    _hero = ValueNotifier(
      SeriesDetailsHeroSnapshot.series(_series),
    );
    MyListStore.instance.addListener(_onMyListStoreChanged);
    SeriesVodLabelStore.instance.addListener(_onMyListStoreChanged);
    EpisodeVodLabelStore.instance.addListener(_onMyListStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeSeriesDetailsStores());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Platform.isAndroid) {
        _androidFirstActionFocus.requestFocus();
      }
    });
  }

  void _onMyListStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _primeSeriesDetailsStores() async {
    await MyListStore.instance.ensureLoaded();
    await SeriesVodLabelStore.instance.ensureLoaded();
    await EpisodeVodLabelStore.instance.ensureLoaded();
    if (!mounted) return;
    await _maybeLoadXtreamDetail();
  }

  Future<void> _maybeLoadXtreamDetail() async {
    if (!mounted) return;
    if (libraryController.useDemoData) return;
    if (_series.seasons.isNotEmpty) return;
    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) return;
    setState(() {
      _loadingXtreamDetail = true;
      _xtreamDetailError = null;
    });
    try {
      final loaded = await xtreamCatalogRepository.fetchSeriesDetail(
        libraryController,
        _series,
      );
      if (!mounted) return;
      setState(() {
        _series = loaded;
        _loadingXtreamDetail = false;
        _hero.value = SeriesDetailsHeroSnapshot.series(_series);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingXtreamDetail = false;
        _xtreamDetailError = e.toString();
      });
      _xtreamErrorDismissTimer?.cancel();
      _xtreamErrorDismissTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _xtreamDetailError = null);
      });
    }
  }

  @override
  void dispose() {
    _xtreamErrorDismissTimer?.cancel();
    MyListStore.instance.removeListener(_onMyListStoreChanged);
    SeriesVodLabelStore.instance.removeListener(_onMyListStoreChanged);
    EpisodeVodLabelStore.instance.removeListener(_onMyListStoreChanged);
    _backFocus.dispose();
    _androidFirstActionFocus.dispose();
    for (final c in _scrollBySeason.values) {
      c.dispose();
    }
    for (final n in _focusByEpisodeId.values) {
      n.dispose();
    }
    _hero.dispose();
    super.dispose();
  }

  String _seasonStorageKey(int seasonNumber) =>
      '${_series.id}_sn$seasonNumber';

  ScrollController _scrollForSeason(int seasonNumber) {
    final key = _seasonStorageKey(seasonNumber);
    return _scrollBySeason.putIfAbsent(key, () {
      final initial = _savedScrollBySeason[key] ?? 0;
      return ScrollController(initialScrollOffset: initial);
    });
  }

  void _persistSeasonScroll(int seasonNumber) {
    final key = _seasonStorageKey(seasonNumber);
    final c = _scrollBySeason[key];
    if (c != null && c.hasClients) {
      _savedScrollBySeason[key] = c.offset;
    }
  }

  FocusNode _focusForEpisode(MockEpisode e) {
    return _focusByEpisodeId.putIfAbsent(
      e.id,
      () => FocusNode(debugLabel: 'ep-${e.id}'),
    );
  }

  /// True when TV focus is on any episode tile (any season).
  bool _primaryFocusIsOnAnyEpisode() {
    final p = FocusManager.instance.primaryFocus;
    if (p == null) return false;
    for (final n in _focusByEpisodeId.values) {
      if (identical(p, n)) return true;
    }
    return false;
  }

  GlobalKey _episodeKey(String episodeId) {
    return _keysByEpisodeId.putIfAbsent(
      episodeId,
      () => GlobalKey(debugLabel: 'ep-tile-$episodeId'),
    );
  }

  void _applySeriesHero() {
    _hero.value = SeriesDetailsHeroSnapshot.series(_series);
  }

  void _applyEpisodeHero(MockEpisode e) {
    _hero.value = SeriesDetailsHeroSnapshot.episode(_series, e);
  }

  void _openEpisode(MockEpisode e) {
    unawaited(_openEpisodeAsync(e));
  }

  Future<void> _openEpisodeAsync(MockEpisode e) async {
    final allowed = await ensureParentalAllowsSeriesPlayback(
      context,
      seriesId: _series.id,
      categoryId: _series.categoryId,
    );
    if (!allowed || !mounted) return;
    final epDesc = e.description.trim();
    final seriesDesc = _series.description.trim();
    final combinedDesc = [
      if (seriesDesc.isNotEmpty) seriesDesc,
      if (epDesc.isNotEmpty) epDesc,
    ].join('\n\n');
    await openTvMatePlayer(
      context,
      title: '${_series.title} — ${e.codename}',
      streamUrl: e.streamUrl ?? mockVodStreamUrlForEpisode(e.id),
      isLive: false,
      subtitleSearchQuery: '${_series.title} ${e.codename}',
      contentDescription: combinedDesc.isEmpty ? null : combinedDesc,
      resumeContentId: 'episode_${e.id}',
      browseRestoreSeriesId: _series.id,
      vodPosterUrl: () {
        final u = catalogBackdropHiResUrl(seriesBackdropUrl(_series));
        return u.trim().isEmpty ? null : u;
      }(),
      onPlayerClosed: (r) {
        _markPlayerJustClosed();
        final id = r?.seriesId;
        if (id != null) {
          widget.onReturnedFromPlayer?.call(id);
        }
      },
    );
  }

  MockEpisode? get _firstEpisode {
    for (final s in _series.seasons) {
      if (s.episodes.isNotEmpty) return s.episodes.first;
    }
    return null;
  }

  void _playFirstEpisode() {
    final ep = _firstEpisode;
    if (ep != null) _openEpisode(ep);
  }

  Future<void> _openSeriesTrailer() async {
    await InAppYoutubeTrailerScreen.open(
      context,
      searchQuery: '${_series.title} trailer',
    );
  }

  Future<void> _openExternalPlayer() async {
    final ep = _firstEpisode;
    if (ep == null) return;
    final url = ep.streamUrl ?? mockVodStreamUrlForEpisode(ep.id);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleMyList() async {
    await MyListStore.instance.toggleSeries(_series.id);
  }

  Future<void> _toggleWatching() async {
    await SeriesVodLabelStore.instance.toggleWatching(_series.id);
  }

  Future<void> _toggleContinueWatching() async {
    final wasContinue =
        SeriesVodLabelStore.instance.labelFor(_series.id) ==
            MovieVodLabel.continueWatching;
    await SeriesVodLabelStore.instance.toggleContinueWatching(_series.id);
    if (wasContinue) {
      final episodeIds = <String>[
        for (final s in _series.seasons)
          for (final e in s.episodes) e.id,
      ];
      await PlaybackResumeStore.clearEpisodeResumes(episodeIds);
    }
  }

  Future<void> _toggleWatched() async {
    final id = _series.id;
    await SeriesVodLabelStore.instance.ensureLoaded();
    final cur = SeriesVodLabelStore.instance.labelFor(id);
    await SeriesVodLabelStore.instance.setLabel(
      id,
      cur == MovieVodLabel.watched ? MovieVodLabel.none : MovieVodLabel.watched,
    );
  }

  void _scheduleRevealEpisode(String episodeId, {required bool animated}) {
    final gen = ++_revealEpoch;
    void run() {
      if (!mounted || gen != _revealEpoch) return;
      final ctx = _episodeKey(episodeId).currentContext;
      if (ctx == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => run());
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        duration: animated
            ? const Duration(milliseconds: 260)
            : Duration.zero,
        curve: animated ? AppTheme.focusAnimationCurve : Curves.linear,
        alignment: 0.35,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  void _requestFocusEpisode(MockEpisode e, {bool animatedReveal = true}) {
    void attempt() {
      if (!mounted) return;
      final n = _focusForEpisode(e);
      if (n.canRequestFocus) {
        n.requestFocus();
        if (animatedReveal) {
          _scheduleRevealEpisode(e.id, animated: true);
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  MockEpisode _episodeAt(int seasonIndex, int epIndex) {
    final eps = _seasons[seasonIndex].episodes;
    return eps[epIndex.clamp(0, eps.length - 1)];
  }

  void _focusEpisodeIndexInSeason(
    int seasonIndex,
    int epIndexClamped, {
    bool animated = true,
  }) {
    final ep = _episodeAt(seasonIndex, epIndexClamped);
    final season = _seasons[seasonIndex];
    final key = _seasonStorageKey(season.number);
    _lastEpisodeIndexBySeason[key] = epIndexClamped;
    _applyEpisodeHero(ep);
    _requestFocusEpisode(ep, animatedReveal: animated);
  }

  KeyEventResult? _episodeVerticalKeys(
    FocusNode node,
    KeyEvent event,
    MockEpisode ep,
    int seasonIndex,
    int epIndex,
  ) {
    if (event is! KeyDownEvent) return null;
    final season = _seasons[seasonIndex];

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (seasonIndex == 0) {
        if (Platform.isAndroid) {
          _persistSeasonScroll(season.number);
          _applySeriesHero();
          if (_androidFirstActionFocus.canRequestFocus) {
            _androidFirstActionFocus.requestFocus();
          }
        } else if (_backFocus.canRequestFocus) {
          _persistSeasonScroll(season.number);
          _applySeriesHero();
          _backFocus.requestFocus();
        }
        return KeyEventResult.handled;
      }

      _persistSeasonScroll(season.number);
      final prev = _seasons[seasonIndex - 1];
      final prevKey = _seasonStorageKey(prev.number);
      final idx = (_lastEpisodeIndexBySeason[prevKey] ?? 0)
          .clamp(0, prev.episodes.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusEpisodeIndexInSeason(seasonIndex - 1, idx);
      });
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (seasonIndex >= _seasons.length - 1) return null;

      _persistSeasonScroll(season.number);
      final next = _seasons[seasonIndex + 1];
      final nextKey = _seasonStorageKey(next.number);
      final idx = (_lastEpisodeIndexBySeason[nextKey] ?? 0)
          .clamp(0, next.episodes.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusEpisodeIndexInSeason(seasonIndex + 1, idx);
      });
      return KeyEventResult.handled;
    }

    return null;
  }

  KeyEventResult? _backKeyIntercept(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (Platform.isAndroid) {
        if (_androidFirstActionFocus.canRequestFocus) {
          _androidFirstActionFocus.requestFocus();
        }
        return KeyEventResult.handled;
      }
      if (_seasons.isEmpty) return null;
      final s0 = _seasons.first;
      final key = _seasonStorageKey(s0.number);
      final idx = (_lastEpisodeIndexBySeason[key] ?? 0)
          .clamp(0, s0.episodes.length - 1);
      _focusEpisodeIndexInSeason(0, idx);
      return KeyEventResult.handled;
    }
    return null;
  }

  KeyEventResult? _androidDetailActionBarKey(
    FocusNode node,
    KeyEvent event,
    int index,
  ) {
    if (event is! KeyDownEvent) return null;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _applySeriesHero();
      if (_backFocus.canRequestFocus) {
        _backFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_seasons.isEmpty) return KeyEventResult.handled;
      final s0 = _seasons.first;
      final key = _seasonStorageKey(s0.number);
      final idx = (_lastEpisodeIndexBySeason[key] ?? 0)
          .clamp(0, s0.episodes.length - 1);
      _focusEpisodeIndexInSeason(0, idx);
      return KeyEventResult.handled;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final chrome = context.teamPalette;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final layoutScale = windowsDetailLayoutScale(w, h);
    final bottomInset = mq.padding.bottom;
    final nSeasons = _seasons.length;
    final inList = MyListStore.instance.containsSeries(_series.id);
    final vodLabel = SeriesVodLabelStore.instance.labelFor(_series.id);
    final watching = vodLabel == MovieVodLabel.watching;
    final continueWatching =
        vodLabel == MovieVodLabel.continueWatching;
    final watched = vodLabel == MovieVodLabel.watched;

    final metaParts = <String>[
      if (_series.year > 0) '${_series.year}',
      if (_series.genre.isNotEmpty) _series.genre,
      if (nSeasons > 0) '$nSeasons season${nSeasons == 1 ? '' : 's'}',
    ];

    final detailActions = <DetailCompactAction>[
      DetailCompactAction(
        label: l10n.actionPlay,
        icon: Icons.play_arrow_rounded,
        onPressed: hasEpisode ? _playFirstEpisode : () {},
      ),
      DetailCompactAction(
        label: l10n.parentalPlayerParental,
        icon: Icons.lock_outline_rounded,
        onPressed: () async {
          await parentalControlStore.ensureLoaded();
          if (!parentalControlStore.enabled ||
              !parentalControlStore.isPinConfigured) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.parentalMustEnableInSettings,
                ),
              ),
            );
            return;
          }
          final pid = libraryController.activePlaylistId ??
              ParentalControlStore.kDemoPlaylistId;
          if (!context.mounted) return;
          await showSeriesParentalScopeDialog(
            context,
            playlistId: pid,
            seriesId: _series.id,
            categoryId: _series.categoryId,
          );
        },
      ),
      DetailCompactAction(
        label: l10n.actionExternal,
        icon: Icons.open_in_new_rounded,
        onPressed:
            hasEpisode ? () => unawaited(_openExternalPlayer()) : () {},
      ),
      DetailCompactAction(
        label: l10n.actionTrailer,
        icon: Icons.movie_filter_outlined,
        onPressed: () => unawaited(_openSeriesTrailer()),
      ),
      DetailCompactAction(
        label: inList ? l10n.actionRemove : l10n.actionMyList,
        icon: inList ? Icons.playlist_remove : Icons.playlist_add,
        onPressed: () => unawaited(_toggleMyList()),
      ),
      DetailCompactAction(
        label: watching ? l10n.actionWatchingOff : l10n.actionWatching,
        icon: watching
            ? Icons.bookmark_remove_outlined
            : Icons.bookmark_add_outlined,
        onPressed: () => unawaited(_toggleWatching()),
      ),
      DetailCompactAction(
        label: continueWatching
            ? l10n.actionContinueWatchingOff
            : l10n.actionContinueWatching,
        icon: continueWatching
            ? Icons.play_disabled_outlined
            : Icons.play_circle_outline,
        onPressed: () => unawaited(_toggleContinueWatching()),
      ),
      DetailCompactAction(
        label: watched ? l10n.actionUnwatch : l10n.actionWatched,
        icon: watched
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        onPressed: () => unawaited(_toggleWatched()),
      ),
    ];

    final actionBar = Padding(
      padding: EdgeInsets.only(left: w * 0.04),
      child: DetailCompactActionBar(
        layoutScale: layoutScale,
        autofocusIndex: Platform.isAndroid ? null : 0,
        firstActionFocusNode: Platform.isAndroid ? _androidFirstActionFocus : null,
        onActionKeyIntercept:
            Platform.isAndroid ? _androidDetailActionBarKey : null,
        actions: detailActions,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_shouldSwallowSystemBack) return;
        // Android: first Back from an episode → action row; second Back → browse.
        if (Platform.isAndroid && _primaryFocusIsOnAnyEpisode()) {
          _applySeriesHero();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_androidFirstActionFocus.canRequestFocus) {
              _androidFirstActionFocus.requestFocus();
            }
          });
          return;
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: TeamShellBackdrop(),
            ),

            // Dynamic backdrop image (changes on episode focus)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: w * 0.65,
              child: ValueListenableBuilder<SeriesDetailsHeroSnapshot>(
                valueListenable: _hero,
                builder: (context, snap, _) {
                  return ShaderMask(
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
                        url: snap.imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topRight,
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_series.rating != null && _series.rating!.trim().isNotEmpty)
              Positioned(
                top: mq.padding.top + 4,
                right: 6,
                child: IgnorePointer(
                  child: VodImdbRatingBadge(
                    rating: _series.rating!,
                    size: VodImdbRatingBadgeSize.detail,
                  ),
                ),
              ),

            if (watched)
              Positioned(
                right: w * 0.05,
                bottom: h * 0.08,
                child: const MovieWatchedBackdropStamp(),
              )
            else if (continueWatching)
              Positioned(
                right: w * 0.05,
                bottom: h * 0.08,
                child: const MovieContinueWatchingBackdropStamp(),
              )
            else if (watching)
              Positioned(
                right: w * 0.05,
                bottom: h * 0.08,
                child: const MovieWatchingBackdropStamp(),
              ),

            // Full-width content: info top-left, episode rails full width
            Positioned(
              left: 0,
              top: mq.padding.top + 18,
              bottom: bottomInset + 16,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info section constrained to left side
                  Padding(
                    padding: EdgeInsets.only(left: w * 0.04, right: w * 0.48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DetailIconBack(
                          focusNode: _backFocus,
                          onPressed: () => Navigator.of(context).pop(),
                          onFocusedChange: (has) {
                            if (has) _applySeriesHero();
                          },
                          onKeyIntercept: _backKeyIntercept,
                          layoutScale: layoutScale,
                        ),
                        SizedBox(height: 14 * layoutScale),

                        Text(
                          _series.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 36 * layoutScale,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.6,
                          ),
                        ),
                        SizedBox(height: 10 * layoutScale),

                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                metaParts.join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15 * layoutScale,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10 * layoutScale),

                        if (_series.cast != null &&
                            _series.cast!.isNotEmpty) ...[
                          _SeriesMetaLabel(
                            label: 'Cast:',
                            value: _series.cast!,
                            theme: theme,
                            layoutScale: layoutScale,
                          ),
                          SizedBox(height: 4 * layoutScale),
                        ],

                        if (_series.director != null &&
                            _series.director!.isNotEmpty) ...[
                          _SeriesMetaLabel(
                            label: 'Director:',
                            value: _series.director!,
                            theme: theme,
                            layoutScale: layoutScale,
                          ),
                          SizedBox(height: 10 * layoutScale),
                        ],

                        if ((_series.cast == null ||
                                _series.cast!.isEmpty) &&
                            (_series.director == null ||
                                _series.director!.isEmpty))
                          SizedBox(height: 4 * layoutScale),

                        Text(
                          _series.description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                            fontSize: 14 * layoutScale,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14 * layoutScale),

                  if (_useTopActionsEpisodeLayout) ...[
                    actionBar,
                    SizedBox(height: 10 * layoutScale),
                  ],

                  // Season/episode rails: full width, scrollable
                  Expanded(
                    child: FocusTraversalGroup(
                      child: Padding(
                        padding: EdgeInsets.only(left: w * 0.04),
                        child: CustomScrollView(
                          clipBehavior: Clip.none,
                          physics: const ClampingScrollPhysics(),
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, si) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 22),
                                  child: _SeasonEpisodesBlock(
                                    series: _series,
                                    season: _seasons[si],
                                    useAndroidTvTiles:
                                        Platform.isAndroid ||
                                            Platform.isWindows,
                                    scrollController:
                                        _scrollForSeason(
                                      _seasons[si].number,
                                    ),
                                    focusForEpisode: _focusForEpisode,
                                    episodeKey: _episodeKey,
                                    onEpisodeFocusChanged:
                                        (e, epIndex, has) {
                                      final key = _seasonStorageKey(
                                          _seasons[si].number);
                                      if (has) {
                                        _lastEpisodeIndexBySeason[key] =
                                            epIndex;
                                        _applyEpisodeHero(e);
                                        _scheduleRevealEpisode(
                                          e.id,
                                          animated: true,
                                        );
                                      }
                                    },
                                    onEpisodeKey: (n, e, ep, epIdx) =>
                                        _episodeVerticalKeys(
                                      n,
                                      e,
                                      ep,
                                      si,
                                      epIdx,
                                    ),
                                    onEpisodePlay: _openEpisode,
                                  ),
                                ),
                                childCount: _seasons.length,
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (!_useTopActionsEpisodeLayout) ...[
                    SizedBox(height: 6 * layoutScale),
                    actionBar,
                  ],
                ],
              ),
            ),

            if (_loadingXtreamDetail)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: chrome.accent,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              ),
            if (_xtreamDetailError != null)
              Positioned(
                left: 24,
                right: 24,
                top: 18,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _xtreamErrorDismissTimer?.cancel();
                    setState(() => _xtreamDetailError = null);
                  },
                  child: Material(
                    color: Colors.red.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _xtreamDetailError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

  bool get hasEpisode => _firstEpisode != null;
}

class _SeasonEpisodesBlock extends StatelessWidget {
  const _SeasonEpisodesBlock({
    required this.series,
    required this.season,
    required this.scrollController,
    required this.focusForEpisode,
    required this.episodeKey,
    required this.onEpisodeFocusChanged,
    required this.onEpisodeKey,
    required this.onEpisodePlay,
    this.useAndroidTvTiles = false,
  });

  final MockSeries series;
  final MockSeason season;
  final ScrollController scrollController;
  final FocusNode Function(MockEpisode e) focusForEpisode;
  final GlobalKey Function(String episodeId) episodeKey;
  final void Function(MockEpisode e, int epIndex, bool hasFocus)
      onEpisodeFocusChanged;
  final KeyEventResult? Function(
    FocusNode node,
    KeyEvent event,
    MockEpisode ep,
    int epIndex,
  ) onEpisodeKey;
  final void Function(MockEpisode e) onEpisodePlay;
  final bool useAndroidTvTiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eps = season.episodes;

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        const focusPad = 6.0;
        const androidTvFocusVerticalInset = 0.0;
        final rowW = c.maxWidth;
        late final double tileW;
        late final double innerTileH;
        late final double listRowHeight;
        late final double androidTvSlotH;
        if (useAndroidTvTiles) {
          const slots = 5;
          tileW = (rowW - gap * (slots - 1)) / slots;
          innerTileH =
              tileW * 9 / 16 + kAndroidEpisodeCaptionStripHeight;
          androidTvSlotH = innerTileH + androidTvFocusVerticalInset;
          listRowHeight = androidTvSlotH + focusPad * 2;
        } else {
          tileW = (rowW - gap * 6) / 7;
          innerTileH = tileW * 1.5;
          androidTvSlotH = innerTileH;
          listRowHeight = innerTileH + focusPad * 2;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Season ${season.number}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: listRowHeight,
              child: FocusTraversalGroup(
                child: ListView.builder(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: focusPad),
                  itemCount: eps.length,
                  itemBuilder: (context, index) {
                    final ep = eps[index];
                    if (useAndroidTvTiles) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == eps.length - 1 ? 0 : gap,
                        ),
                        child: SizedBox(
                          key: episodeKey(ep.id),
                          width: tileW,
                          height: androidTvSlotH,
                          child: _AndroidSeriesEpisodeFocusTile(
                            series: series,
                            episode: ep,
                            focusNode: focusForEpisode(ep),
                            onFocusedChange: (has) =>
                                onEpisodeFocusChanged(ep, index, has),
                            onKeyIntercept: (n, e) =>
                                onEpisodeKey(n, e, ep, index),
                            onActivate: () => onEpisodePlay(ep),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == eps.length - 1 ? 0 : gap,
                      ),
                      child: SizedBox(
                        key: episodeKey(ep.id),
                        width: tileW,
                        height: innerTileH,
                        child: RepaintBoundary(
                          child: VodLiveTvStyleFocus(
                            focusNode: focusForEpisode(ep),
                            borderRadius: _kEpisodeTileRadius,
                            onFocusedChange: (has) =>
                                onEpisodeFocusChanged(ep, index, has),
                            onKeyIntercept: (n, e) =>
                                onEpisodeKey(n, e, ep, index),
                            onActivate: () => onEpisodePlay(ep),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                _kEpisodeTileRadius,
                              ),
                              child: ListenableBuilder(
                                listenable: EpisodeVodLabelStore.instance,
                                builder: (context, _) {
                                  final lab = EpisodeVodLabelStore.instance
                                      .labelFor(ep.id);
                                  final badge =
                                      _episodeVodLabelCornerBadge(lab);
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      TvCatalogImage(
                                        url: seriesPosterUrl(series),
                                        fit: BoxFit.cover,
                                      ),
                                      if (badge != null)
                                        Positioned(
                                          left: 6,
                                          bottom: 44,
                                          child: badge,
                                        ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: EpisodeSeasonCaptionBar(
                                          label: ep.codename,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tracks focus for [AndroidSeriesEpisodeTile] caption + still styling.
class _AndroidSeriesEpisodeFocusTile extends StatefulWidget {
  const _AndroidSeriesEpisodeFocusTile({
    required this.series,
    required this.episode,
    required this.focusNode,
    required this.onFocusedChange,
    required this.onKeyIntercept,
    required this.onActivate,
  });

  final MockSeries series;
  final MockEpisode episode;
  final FocusNode focusNode;
  final ValueChanged<bool> onFocusedChange;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)
      onKeyIntercept;
  final VoidCallback onActivate;

  @override
  State<_AndroidSeriesEpisodeFocusTile> createState() =>
      _AndroidSeriesEpisodeFocusTileState();
}

class _AndroidSeriesEpisodeFocusTileState
    extends State<_AndroidSeriesEpisodeFocusTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return VodLiveTvStyleFocus(
      focusNode: widget.focusNode,
      borderRadius: kAndroidSeriesEpisodeTileRadius,
      onFocusedChange: (has) {
        setState(() => _focused = has);
        widget.onFocusedChange(has);
      },
      onKeyIntercept: widget.onKeyIntercept,
      onActivate: widget.onActivate,
      child: ListenableBuilder(
        listenable: EpisodeVodLabelStore.instance,
        builder: (context, _) {
          final lab =
              EpisodeVodLabelStore.instance.labelFor(widget.episode.id);
          final badge = _episodeVodLabelCornerBadge(lab);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              AndroidSeriesEpisodeTile(
                series: widget.series,
                episode: widget.episode,
                focused: _focused,
              ),
              if (badge != null)
                Positioned(
                  left: 6,
                  top: 8,
                  child: badge,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesMetaLabel extends StatelessWidget {
  const _SeriesMetaLabel({
    required this.label,
    required this.value,
    required this.theme,
    this.layoutScale = 1.0,
  });

  final String label;
  final String value;
  final ThemeData theme;
  final double layoutScale;

  @override
  Widget build(BuildContext context) {
    final fs = 13.5 * layoutScale;
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: fs,
            ),
          ),
          TextSpan(
            text: value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.82),
              fontSize: fs,
            ),
          ),
        ],
      ),
    );
  }
}
