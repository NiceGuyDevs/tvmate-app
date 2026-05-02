import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/youtube_trailer_search.dart';
import '../catalog/catalog_status_widgets.dart';
import '../focus/tv_focusable.dart';
import '../widgets/tv_catalog_image.dart';
/// In-app trailer **search** (D-pad list). Playback opens the **YouTube app**
/// (or browser) via the watch URL so trailers play reliably on TV.
class InAppYoutubeTrailerScreen extends StatefulWidget {
  const InAppYoutubeTrailerScreen({
    super.key,
    required this.searchQuery,
    this.title = 'Trailer',
  });

  final String searchQuery;
  final String title;

  /// Opens trailer search for [searchQuery] (e.g. `"My Movie trailer"`).
  static Future<void> open(
    BuildContext context, {
    required String searchQuery,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => InAppYoutubeTrailerScreen(
          searchQuery: searchQuery,
          title: 'Trailer',
        ),
      ),
    );
  }

  @override
  State<InAppYoutubeTrailerScreen> createState() =>
      _InAppYoutubeTrailerScreenState();
}

class _InAppYoutubeTrailerScreenState extends State<InAppYoutubeTrailerScreen> {
  late Future<List<YoutubeTrailerVideo>> _future;

  @override
  void initState() {
    super.initState();
    _future = searchTrailerVideos(widget.searchQuery);
  }

  Future<void> _retry() async {
    setState(() {
      _future = searchTrailerVideos(widget.searchQuery);
    });
  }

  Future<void> _openInBrowser() async {
    final q = Uri.encodeComponent(widget.searchQuery);
    final uri = Uri.parse('https://www.youtube.com/results?search_query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPlayer(YoutubeTrailerVideo v) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=${v.videoId}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
                child: Row(
                  children: [
                    TvFocusable(
                      onActivate: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Back',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'D-pad: move between videos · OK: play · Back: leave',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<YoutubeTrailerVideo>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CatalogLoadingBody(
                        message: 'Searching trailers…',
                      );
                    }
                    if (snapshot.hasError) {
                      return _SearchErrorBody(
                        onRetry: _retry,
                        onOpenBrowser: _openInBrowser,
                      );
                    }
                    final list = snapshot.data ?? const <YoutubeTrailerVideo>[];
                    if (list.isEmpty) {
                      return _SearchErrorBody(
                        onRetry: _retry,
                        onOpenBrowser: _openInBrowser,
                        empty: true,
                      );
                    }
                    return _TrailerResultsList(
                      videos: list,
                      onActivateVideo: (v) => unawaited(_openPlayer(v)),
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

/// When search completes, moves D-pad focus to the **first** result so the user
/// can move down the list without landing on the header Back button first.
class _TrailerResultsList extends StatefulWidget {
  const _TrailerResultsList({
    required this.videos,
    required this.onActivateVideo,
  });

  final List<YoutubeTrailerVideo> videos;
  final void Function(YoutubeTrailerVideo v) onActivateVideo;

  @override
  State<_TrailerResultsList> createState() => _TrailerResultsListState();
}

class _TrailerResultsListState extends State<_TrailerResultsList> {
  late final FocusNode _firstFocus =
      FocusNode(debugLabel: 'trailerFirstResult');

  @override
  void initState() {
    super.initState();
    scheduleSteadyChannelTileFocus(() => mounted, _firstFocus);
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        final v = widget.videos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TvFocusable(
            focusNode: index == 0 ? _firstFocus : null,
            onActivate: () => widget.onActivateVideo(v),
            child: _TrailerResultCard(video: v),
          ),
        );
      },
    );
  }
}

class _TrailerResultCard extends StatelessWidget {
  const _TrailerResultCard({required this.video});

  final YoutubeTrailerVideo video;

  String _durationLabel() {
    final s = video.lengthSeconds;
    if (s == null || s <= 0) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final r = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
    }
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dur = _durationLabel();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            height: 68,
            child: TvCatalogImage(
              url: video.thumbnailUrl,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (video.author != null && video.author!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      video.author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (dur.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dur,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchErrorBody extends StatelessWidget {
  const _SearchErrorBody({
    required this.onRetry,
    required this.onOpenBrowser,
    this.empty = false,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenBrowser;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              empty ? Icons.search_off_rounded : Icons.cloud_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              empty
                  ? 'No trailer results'
                  : 'Could not reach trailer search',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              empty
                  ? 'Try again or open YouTube in the browser.'
                  : 'Check your connection. You can retry or open YouTube.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            TvFocusable(
              autofocus: true,
              onActivate: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Retry',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TvFocusable(
              onActivate: onOpenBrowser,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Open in browser',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
