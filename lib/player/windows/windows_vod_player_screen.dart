import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../live_lineup_item.dart';
import '../player_screen.dart';

/// **Windows desktop only** — entry surface for movies / series / catch-up VOD.
///
/// Routed from [openTvMatePlayer] when `!isLive && !kIsWeb &&
/// defaultTargetPlatform == TargetPlatform.windows`. Every other platform
/// uses [PlayerScreen] directly with the same arguments.
///
/// Delegates to [PlayerScreen] with `isLive: false` and **the same parameters**
/// as the generic VOD route, so behavior matches Android/TV VOD. Android code
/// paths are unchanged; this file is Windows-only wiring.
class WindowsVodPlayerScreen extends StatelessWidget {
  const WindowsVodPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.contentDescription,
    this.liveLineup,
    this.initialLiveIndex = 0,
    this.resumeContentId,
    this.browseMovieId,
    this.browseSeriesId,
    this.liveChannelId,
    this.liveEpgXmltvId,
    this.liveViewCategoryId,
    this.subtitleSearchQuery,
    this.vodPosterUrl,
  });

  final String title;
  final String streamUrl;
  final String? contentDescription;
  final List<LiveLineupItem>? liveLineup;
  final int initialLiveIndex;
  final String? resumeContentId;
  final String? browseMovieId;
  final String? browseSeriesId;
  final String? liveChannelId;
  final String? liveEpgXmltvId;
  final String? liveViewCategoryId;
  final String? subtitleSearchQuery;
  final String? vodPosterUrl;

  /// Navigation should already restrict to Windows; useful for tests.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Widget build(BuildContext context) {
    return PlayerScreen(
      title: title,
      streamUrl: streamUrl,
      isLive: false,
      contentDescription: contentDescription,
      liveLineup: liveLineup,
      initialLiveIndex: initialLiveIndex,
      resumeContentId: resumeContentId,
      browseMovieId: browseMovieId,
      browseSeriesId: browseSeriesId,
      liveChannelId: liveChannelId,
      liveEpgXmltvId: liveEpgXmltvId,
      liveViewCategoryId: liveViewCategoryId,
      subtitleSearchQuery: subtitleSearchQuery,
      vodPosterUrl: vodPosterUrl,
    );
  }
}
