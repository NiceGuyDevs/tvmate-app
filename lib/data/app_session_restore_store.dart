import 'package:shared_preferences/shared_preferences.dart';

import '../shell/shell_destination.dart';

/// Snapshot used to reopen the VOD player after a cold start (process killed).
class VodColdRestoreSnapshot {
  const VodColdRestoreSnapshot({
    required this.resumeContentId,
    required this.title,
    required this.streamUrl,
    this.contentDescription,
    this.subtitleSearchQuery,
    this.browseRestoreMovieId,
    this.browseRestoreSeriesId,
  });

  final String resumeContentId;
  final String title;
  final String streamUrl;
  final String? contentDescription;
  final String? subtitleSearchQuery;
  final String? browseRestoreMovieId;
  final String? browseRestoreSeriesId;
}

/// Persists last shell tab + Live TV browse position + whether live fullscreen
/// was open, so a **cold start** (process killed) can restore the same place.
///
/// Startup tab policy (cold start):
/// - **VOD resume** (movie/episode player was open): open **Movies** or **Series**
///   as needed.
/// - Otherwise: user’s **Top menu → Startup tab** ([TopMenuStore.startup]),
///   defaulting to **Live TV** if unset or not in the current menu.
/// - **Live TV fullscreen** restore is handled inside [LiveTvScreen] (tab stays
///   Live TV).
class AppSessionRestoreStore {
  AppSessionRestoreStore._();
  static final AppSessionRestoreStore instance = AppSessionRestoreStore._();

  static const _kDest = 'tvmatepro_session_shell_dest';
  static const _kLiveCat = 'tvmatepro_session_live_cat';
  static const _kLiveCh = 'tvmatepro_session_live_ch';
  static const _kLiveFs = 'tvmatepro_session_live_fullscreen';

  static const _kVodResume = 'tvmatepro_session_vod_resume_id';
  static const _kVodTitle = 'tvmatepro_session_vod_title';
  static const _kVodStream = 'tvmatepro_session_vod_stream';
  static const _kVodDesc = 'tvmatepro_session_vod_desc';
  static const _kVodSubq = 'tvmatepro_session_vod_subq';
  static const _kVodMovie = 'tvmatepro_session_vod_browse_movie';
  static const _kVodSeries = 'tvmatepro_session_vod_browse_series';
  static const _kVodShell = 'tvmatepro_session_vod_shell_dest';

  bool _loaded = false;
  String? _liveCategoryId;
  String? _liveChannelId;
  bool _liveWasFullscreen = false;

  String? _vodResumeContentId;
  String? _vodTitle;
  String? _vodStreamUrl;
  String? _vodDesc;
  String? _vodSubq;
  String? _vodBrowseMovieId;
  String? _vodBrowseSeriesId;
  String? _vodShellDestName;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _liveCategoryId = p.getString(_kLiveCat);
    _liveChannelId = p.getString(_kLiveCh);
    _liveWasFullscreen = p.getBool(_kLiveFs) ?? false;

    _vodResumeContentId = p.getString(_kVodResume);
    _vodTitle = p.getString(_kVodTitle);
    _vodStreamUrl = p.getString(_kVodStream);
    _vodDesc = p.getString(_kVodDesc);
    _vodSubq = p.getString(_kVodSubq);
    _vodBrowseMovieId = p.getString(_kVodMovie);
    _vodBrowseSeriesId = p.getString(_kVodSeries);
    _vodShellDestName = p.getString(_kVodShell);
    _loaded = true;
  }

  bool get hasLiveRestore =>
      _liveCategoryId != null &&
      _liveCategoryId!.isNotEmpty &&
      _liveChannelId != null &&
      _liveChannelId!.isNotEmpty;

  String? get liveCategoryId => _liveCategoryId;
  String? get liveChannelId => _liveChannelId;
  bool get liveWasFullscreen => _liveWasFullscreen;

  /// Called when a VOD [PlayerScreen] with [resumeContentId] is shown.
  Future<void> recordVodPlaybackSnapshot({
    required String resumeContentId,
    required String title,
    required String streamUrl,
    String? contentDescription,
    String? subtitleSearchQuery,
    String? browseMovieId,
    String? browseSeriesId,
  }) async {
    await ensureLoaded();
    final p = await SharedPreferences.getInstance();
    final shellName = (browseSeriesId != null && browseSeriesId.isNotEmpty)
        ? ShellDestination.series.name
        : ShellDestination.movies.name;

    await p.setString(_kVodResume, resumeContentId);
    await p.setString(_kVodTitle, title);
    await p.setString(_kVodStream, streamUrl);
    if (contentDescription != null && contentDescription.isNotEmpty) {
      await p.setString(_kVodDesc, contentDescription);
    } else {
      await p.remove(_kVodDesc);
    }
    if (subtitleSearchQuery != null && subtitleSearchQuery.isNotEmpty) {
      await p.setString(_kVodSubq, subtitleSearchQuery);
    } else {
      await p.remove(_kVodSubq);
    }
    if (browseMovieId != null && browseMovieId.isNotEmpty) {
      await p.setString(_kVodMovie, browseMovieId);
    } else {
      await p.remove(_kVodMovie);
    }
    if (browseSeriesId != null && browseSeriesId.isNotEmpty) {
      await p.setString(_kVodSeries, browseSeriesId);
    } else {
      await p.remove(_kVodSeries);
    }
    await p.setString(_kVodShell, shellName);

    _vodResumeContentId = resumeContentId;
    _vodTitle = title;
    _vodStreamUrl = streamUrl;
    _vodDesc = contentDescription;
    _vodSubq = subtitleSearchQuery;
    _vodBrowseMovieId = browseMovieId;
    _vodBrowseSeriesId = browseSeriesId;
    _vodShellDestName = shellName;
  }

  /// Called when VOD [PlayerScreen] is disposed normally (user exited player).
  Future<void> clearVodPlaybackSnapshot() async {
    await ensureLoaded();
    final p = await SharedPreferences.getInstance();
    await _removeVodKeys(p);
  }

  Future<void> _removeVodKeys(SharedPreferences p) async {
    await p.remove(_kVodResume);
    await p.remove(_kVodTitle);
    await p.remove(_kVodStream);
    await p.remove(_kVodDesc);
    await p.remove(_kVodSubq);
    await p.remove(_kVodMovie);
    await p.remove(_kVodSeries);
    await p.remove(_kVodShell);
    _vodResumeContentId = null;
    _vodTitle = null;
    _vodStreamUrl = null;
    _vodDesc = null;
    _vodSubq = null;
    _vodBrowseMovieId = null;
    _vodBrowseSeriesId = null;
    _vodShellDestName = null;
  }

  /// First launch after kill: returns snapshot once, clears prefs, pins next
  /// cold start to Live TV unless a new VOD session is saved.
  /// [predicate] must return true for this resume id (e.g. `movie_` vs `episode_`).
  Future<VodColdRestoreSnapshot?> consumeVodColdRestoreIf(
    bool Function(String resumeContentId) predicate,
  ) async {
    await ensureLoaded();
    final id = _vodResumeContentId;
    if (id == null || id.isEmpty || !predicate(id)) return null;
    final title = _vodTitle;
    final url = _vodStreamUrl;
    if (title == null ||
        title.isEmpty ||
        url == null ||
        url.isEmpty) {
      await clearVodPlaybackSnapshot();
      return null;
    }

    final snap = VodColdRestoreSnapshot(
      resumeContentId: id,
      title: title,
      streamUrl: url,
      contentDescription: _vodDesc,
      subtitleSearchQuery: _vodSubq,
      browseRestoreMovieId: _vodBrowseMovieId,
      browseRestoreSeriesId: _vodBrowseSeriesId,
    );

    final p = await SharedPreferences.getInstance();
    await _removeVodKeys(p);
    await p.setString(_kDest, ShellDestination.liveTv.name);

    return snap;
  }

  /// [userStartup] is the persisted “Startup tab” (see [TopMenuStore.startup]).
  ShellDestination initialShellDestination(
    List<ShellDestination> menuIncludingSettings,
    ShellDestination userStartup,
  ) {
    final id = _vodResumeContentId;
    final name = _vodShellDestName;
    if (id != null &&
        id.isNotEmpty &&
        name != null &&
        name.isNotEmpty) {
      final movieOk =
          name == ShellDestination.movies.name && id.startsWith('movie_');
      final seriesOk =
          name == ShellDestination.series.name && id.startsWith('episode_');
      if (movieOk || seriesOk) {
        for (final d in ShellDestination.values) {
          if (d.name == name && menuIncludingSettings.contains(d)) {
            if (d == ShellDestination.movies || d == ShellDestination.series) {
              return d;
            }
          }
        }
      }
    }
    if (menuIncludingSettings.contains(userStartup)) {
      return userStartup;
    }
    if (menuIncludingSettings.contains(ShellDestination.liveTv)) {
      return ShellDestination.liveTv;
    }
    return menuIncludingSettings.isNotEmpty
        ? menuIncludingSettings.first
        : ShellDestination.liveTv;
  }

  /// Writes current session. Updates Live TV keys when [shellDestination] is
  /// Live TV (grid browse) or when [liveFullscreen] (live player on top).
  Future<void> persistSession({
    required ShellDestination shellDestination,
    String? liveCategoryId,
    String? liveChannelId,
    required bool liveFullscreen,
    required bool vodFullscreen,
  }) async {
    await ensureLoaded();
    final p = await SharedPreferences.getInstance();

    if (liveFullscreen) {
      await _removeVodKeys(p);
      await p.setString(_kDest, ShellDestination.liveTv.name);
      if (liveCategoryId != null &&
          liveCategoryId.isNotEmpty &&
          liveChannelId != null &&
          liveChannelId.isNotEmpty) {
        await p.setString(_kLiveCat, liveCategoryId);
        await p.setString(_kLiveCh, liveChannelId);
        _liveCategoryId = liveCategoryId;
        _liveChannelId = liveChannelId;
      }
      await p.setBool(_kLiveFs, true);
      _liveWasFullscreen = true;
      return;
    }

    await p.setBool(_kLiveFs, false);
    _liveWasFullscreen = false;

    if (vodFullscreen) {
      final vs = _vodShellDestName;
      if (vs != null && vs.isNotEmpty) {
        await p.setString(_kDest, vs);
      }
      return;
    }

    await p.setString(_kDest, ShellDestination.liveTv.name);

    if (shellDestination == ShellDestination.liveTv &&
        liveCategoryId != null &&
        liveCategoryId.isNotEmpty &&
        liveChannelId != null &&
        liveChannelId.isNotEmpty) {
      await p.setString(_kLiveCat, liveCategoryId);
      await p.setString(_kLiveCh, liveChannelId);
      _liveCategoryId = liveCategoryId;
      _liveChannelId = liveChannelId;
    }
  }

  /// Clears the “reopen in fullscreen” flag after auto-opening the player.
  Future<void> consumeLiveFullscreenRestore() async {
    await ensureLoaded();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLiveFs, false);
    _liveWasFullscreen = false;
  }
}
