import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/movie_vod_label_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/movie_watched_store.dart';
import '../../data/my_list_store.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../player/mock_stream_urls.dart';
import '../../player/player_navigation.dart';
import '../../ui/parental/parental_playback_guard.dart';
import '../../ui/settings/parental_scope_dialogs.dart';
import '../../theme/team_palette.dart';
import '../common/in_app_youtube_trailer_screen.dart';
import '../windows/windows_desktop_scale.dart';
import '../widgets/detail_actions.dart';
import '../widgets/movie_watched_badge.dart';
import '../widgets/vod_imdb_rating_badge.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'mock_movies_data.dart';

/// Split-layout movie details: backdrop right-aligned, gradient fade left.
class MovieDetailsScreen extends StatefulWidget {
  const MovieDetailsScreen({
    super.key,
    required this.movie,
    this.onReturnedFromPlayer,
  });

  final MockMovie movie;

  /// Sync browse rail/hero under this route when the player closes.
  final ValueChanged<String>? onReturnedFromPlayer;

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  MockMovie get movie => widget.movie;

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

  @override
  void initState() {
    super.initState();
    MyListStore.instance.addListener(_onListChanged);
    MovieWatchedStore.instance.addListener(_onListChanged);
    MovieVodLabelStore.instance.addListener(_onListChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MyListStore.instance.ensureLoaded();
      await MovieWatchedStore.instance.ensureLoaded();
      await MovieVodLabelStore.instance.ensureLoaded();
    });
  }

  @override
  void dispose() {
    MyListStore.instance.removeListener(_onListChanged);
    MovieWatchedStore.instance.removeListener(_onListChanged);
    MovieVodLabelStore.instance.removeListener(_onListChanged);
    super.dispose();
  }

  void _onListChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _playMovie({required bool startFromBeginning}) async {
    final allowed = await ensureParentalAllowsMoviePlayback(
      context,
      movieId: movie.id,
      categoryId: movie.categoryId,
    );
    if (!allowed || !mounted) return;
    await openTvMatePlayer(
      context,
      title: movie.title,
      streamUrl: movie.streamUrl ?? mockVodStreamUrlForMovie(movie.id),
      isLive: false,
      subtitleSearchQuery: movie.title,
      contentDescription: movie.description,
      resumeContentId: 'movie_${movie.id}',
      startFromBeginning: startFromBeginning,
      browseRestoreMovieId: movie.id,
      vodPosterUrl: () {
        final u = catalogBackdropHiResUrl(movieBackdropUrl(movie));
        return u.trim().isEmpty ? null : u;
      }(),
      onPlayerClosed: (r) {
        _markPlayerJustClosed();
        final id = r?.movieId;
        if (id != null) {
          widget.onReturnedFromPlayer?.call(id);
        }
      },
    );
  }

  Future<void> _openTrailer() async {
    await InAppYoutubeTrailerScreen.open(
      context,
      searchQuery: '${movie.title} trailer',
    );
  }

  Future<void> _openExternalPlayer() async {
    final url = movie.streamUrl ?? mockVodStreamUrlForMovie(movie.id);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleMyList() async {
    await MyListStore.instance.toggleMovie(movie.id);
  }

  Future<void> _toggleWatched() async {
    await MovieWatchedStore.instance.toggle(movie.id);
  }

  Future<void> _toggleWatching() async {
    await MovieVodLabelStore.instance.toggleWatching(movie.id);
  }

  Future<void> _toggleContinueWatching() async {
    await MovieVodLabelStore.instance.toggleContinueWatching(movie.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final h = mq.size.height;
    final w = mq.size.width;
    final layoutScale = windowsDetailLayoutScale(w, h);
    final bottomInset = mq.padding.bottom;
    final inList = MyListStore.instance.containsMovie(movie.id);
    final vodLabel = MovieVodLabelStore.instance.labelFor(movie.id);
    final watching = vodLabel == MovieVodLabel.watching;
    final continueWatching =
        vodLabel == MovieVodLabel.continueWatching;
    final watched = vodLabel == MovieVodLabel.watched;

    final posterUrl = movieBackdropUrl(movie);
    final hasPoster = posterUrl.isNotEmpty;

    final metaParts = <String>[
      if (movie.year > 0) '${movie.year}',
      if (movie.duration.isNotEmpty) movie.duration,
      if (movie.genre.isNotEmpty) movie.genre,
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_shouldSwallowSystemBack) return;
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

            // Backdrop image: right-aligned, faded into dark via ShaderMask
            if (hasPoster)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: w * 0.65,
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
                      url: catalogBackdropHiResUrl(posterUrl),
                      fit: BoxFit.cover,
                      alignment: Alignment.topRight,
                    ),
                  ),
                ),
              ),

            if (hasPoster &&
                movie.rating != null &&
                movie.rating!.trim().isNotEmpty)
              Positioned(
                top: mq.padding.top + 4,
                right: 6,
                child: IgnorePointer(
                  child: VodImdbRatingBadge(
                    rating: movie.rating!,
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

            // Text content on the left
            Positioned(
              left: w * 0.04,
              top: mq.padding.top + 18,
              bottom: bottomInset + 16,
              width: w * 0.52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailIconBack(
                    onPressed: () => Navigator.of(context).pop(),
                    layoutScale: layoutScale,
                  ),
                  SizedBox(height: 14 * layoutScale),

                  Text(
                    movie.title,
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
                            color: TeamPalette.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15 * layoutScale,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14 * layoutScale),

                  if (movie.cast != null &&
                      movie.cast!.isNotEmpty) ...[
                    _MetaLabel(
                      label: 'Cast:',
                      value: movie.cast!,
                      theme: theme,
                      layoutScale: layoutScale,
                    ),
                    SizedBox(height: 6 * layoutScale),
                  ],

                  if (movie.director != null &&
                      movie.director!.isNotEmpty) ...[
                    _MetaLabel(
                      label: 'Director:',
                      value: movie.director!,
                      theme: theme,
                      layoutScale: layoutScale,
                    ),
                    SizedBox(height: 14 * layoutScale),
                  ],

                  if ((movie.cast == null || movie.cast!.isEmpty) &&
                      (movie.director == null ||
                          movie.director!.isEmpty))
                    SizedBox(height: 6 * layoutScale),

                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.white.withOpacity(0),
                        ],
                        stops: const [0.0, 0.82, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: 12 * layoutScale, bottom: 24 * layoutScale),
                          child: Text(
                            movie.description,
                            style:
                                theme.textTheme.bodyLarge?.copyWith(
                              height: 1.55,
                              fontSize: 15 * layoutScale,
                              color: Colors.white.withOpacity(0.88),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 8 * layoutScale),

                  FocusTraversalGroup(
                    child: DetailCompactActionBar(
                      layoutScale: layoutScale,
                      autofocusIndex: 0,
                      actions: [
                        DetailCompactAction(
                          label: l10n.actionPlay,
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => unawaited(
                              _playMovie(startFromBeginning: false)),
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
                            await showMovieParentalScopeDialog(
                              context,
                              playlistId: pid,
                              movieId: movie.id,
                              categoryId: movie.categoryId,
                            );
                          },
                        ),
                        DetailCompactAction(
                          label: l10n.actionExternal,
                          icon: Icons.open_in_new_rounded,
                          onPressed: () =>
                              unawaited(_openExternalPlayer()),
                        ),
                        DetailCompactAction(
                          label: l10n.actionTrailer,
                          icon: Icons.movie_filter_outlined,
                          onPressed: () => unawaited(_openTrailer()),
                        ),
                        DetailCompactAction(
                          label: inList
                              ? l10n.actionRemove
                              : l10n.actionMyList,
                          icon: inList
                              ? Icons.playlist_remove
                              : Icons.playlist_add,
                          onPressed: () =>
                              unawaited(_toggleMyList()),
                        ),
                        DetailCompactAction(
                          label: watching
                              ? l10n.actionWatchingOff
                              : l10n.actionWatching,
                          icon: watching
                              ? Icons.bookmark_remove_outlined
                              : Icons.bookmark_add_outlined,
                          onPressed: () =>
                              unawaited(_toggleWatching()),
                        ),
                        DetailCompactAction(
                          label: continueWatching
                              ? l10n.actionContinueWatchingOff
                              : l10n.actionContinueWatching,
                          icon: continueWatching
                              ? Icons.play_disabled_outlined
                              : Icons.play_circle_outline,
                          onPressed: () => unawaited(
                              _toggleContinueWatching(),
                            ),
                        ),
                        DetailCompactAction(
                          label: watched
                              ? l10n.actionUnwatch
                              : l10n.actionWatched,
                          icon: watched
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          onPressed: () =>
                              unawaited(_toggleWatched()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  const _MetaLabel({
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
              color: TeamPalette.textSecondary,
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
