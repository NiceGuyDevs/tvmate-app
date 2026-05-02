import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ui/live_tv/mock_live_tv_data.dart';
import '../ui/movies/mock_movies_data.dart';
import '../ui/series/mock_series_data.dart';
import '../xtream/xtream_api_client.dart';
import '../xtream/xtream_exceptions.dart';
import '../xtream/xtream_mapper.dart' as mapper
    show
        mapXtreamLiveCategories,
        mapXtreamVodCategories,
        mapXtreamSeriesCategories,
        mergeXtreamSeriesDetail,
        computeLiveChannelsInIsolate,
        computeVodStreamsInIsolate,
        computeSeriesListInIsolate;
import '../xtream/xtream_user_info.dart';
import '../xtream/xtream_stream_urls.dart';
import 'library_controller.dart';
import 'playlist_epg_timezone_store.dart';
import 'stored_playlist.dart';
import 'xtream_catalog_cache_db.dart';
import 'xtream_catalog_snapshot_codec.dart';

/// Loading / error state for Xtream-backed browse surfaces.
enum XtreamCatalogPhase { idle, loading, ready, error }

enum XtreamBrowseErrorKind {
  none,
  network,
  auth,
  badUrl,
  empty,
  unsupported,
}

final XtreamCatalogRepository xtreamCatalogRepository =
    XtreamCatalogRepository();

class XtreamCatalogRepository extends ChangeNotifier {
  XtreamCatalogRepository();

  XtreamCatalogPhase phase = XtreamCatalogPhase.idle;
  XtreamBrowseErrorKind errorKind = XtreamBrowseErrorKind.none;
  String? errorMessage;
  String? _lastSignature;
  var _busy = false;
  int _catalogSyncGeneration = 0;
  String? _refreshingSignature;
  String? _lastNetworkRefreshSig;
  int _lastNetworkRefreshAtMs = 0;

  static const int _minBackgroundRefreshGapMs = 120000;

  List<MockLiveCategory> liveCategories = [];
  List<MockLiveChannel> liveChannelsAll = [];

  List<MockMovieCategory> vodCategories = [];
  List<MockMovie> vodMoviesAll = [];

  List<MockSeriesCategory> seriesCategories = [];
  List<MockSeries> seriesAll = [];

  void _clearData() {
    liveCategories = [];
    liveChannelsAll = [];
    vodCategories = [];
    vodMoviesAll = [];
    seriesCategories = [];
    seriesAll = [];
  }

  String _signatureFor(LibraryController lib) {
    final p = lib.activePlaylist;
    return '${lib.useDemoData}_${p?.id}_${p?.serverUrl}_${p?.username}';
  }

  bool _applySnapshot(XtreamCatalogSnapshot s) {
    liveCategories = s.liveCategories;
    liveChannelsAll = s.liveChannelsAll;
    vodCategories = s.vodCategories;
    vodMoviesAll = s.vodMoviesAll;
    seriesCategories = s.seriesCategories;
    seriesAll = s.seriesAll;
    return liveCategories.isNotEmpty ||
        vodCategories.isNotEmpty ||
        seriesCategories.isNotEmpty;
  }

  XtreamCatalogSnapshot _snapshotFromCurrentLists() {
    return XtreamCatalogSnapshot(
      liveCategories: List<MockLiveCategory>.from(liveCategories),
      liveChannelsAll: List<MockLiveChannel>.from(liveChannelsAll),
      vodCategories: List<MockMovieCategory>.from(vodCategories),
      vodMoviesAll: List<MockMovie>.from(vodMoviesAll),
      seriesCategories: List<MockSeriesCategory>.from(seriesCategories),
      seriesAll: List<MockSeries>.from(seriesAll),
    );
  }

  Future<void> _backgroundRefreshCatalog(
    LibraryController lib,
    String sig,
  ) async {
    if (_refreshingSignature == sig) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastNetworkRefreshSig == sig &&
        now - _lastNetworkRefreshAtMs < _minBackgroundRefreshGapMs) {
      return;
    }
    _refreshingSignature = sig;
    try {
      if (!lib.isReady) return;
      if (_signatureFor(lib) != sig) return;
      final p = lib.activePlaylist;
      if (p == null || !p.isXtream) return;
      final server = p.serverUrl?.trim() ?? '';
      final u = p.username?.trim() ?? '';
      final pw = p.password ?? '';
      if (server.isEmpty || u.isEmpty || pw.isEmpty) return;
      final fp = XtreamCatalogCacheDb.credentialsFingerprint(p);
      await _performNetworkSync(
        lib,
        sig,
        p,
        fp,
        isBackground: true,
      );
    } finally {
      if (_refreshingSignature == sig) {
        _refreshingSignature = null;
      }
    }
  }

  /// [myGen] — discard stale results when a newer sync started (playlist switch).
  Future<bool> _performNetworkSync(
    LibraryController lib,
    String sigAtStart,
    StoredPlaylist p,
    String fingerprint, {
    required bool isBackground,
    int? myGen,
    XtreamApiClient? existingClient,
    List<Map<String, dynamic>>? prefetchedLiveStreams,
    List<Map<String, dynamic>>? prefetchedVodStreams,
    List<Map<String, dynamic>>? prefetchedSeriesList,
  }) async {
    if (_signatureFor(lib) != sigAtStart) return false;

    void bumpGenerationCheck() {
      if (myGen != null && myGen != _catalogSyncGeneration) {
        throw _StaleCatalogSyncException();
      }
    }

    try {
      final client = existingClient ??
          XtreamApiClient(
            baseUrl: p.serverUrl!.trim(),
            username: p.username!.trim(),
            password: p.password!,
          );
      if (existingClient == null) {
        final ui = await client.verifyAuthAndGetUserInfo();
        final exp = xtreamParseExpDateUnix(ui);
        await libraryController.updatePlaylistSubscriptionExpiry(p.id, exp);
      } else {
        try {
          final ui = await client.verifyAuthAndGetUserInfo();
          final exp = xtreamParseExpDateUnix(ui);
          await libraryController.updatePlaylistSubscriptionExpiry(p.id, exp);
        } catch (_) {}
      }
      bumpGenerationCheck();

      try {
        final serverInfo = await client.getServerInfo();
        final tzString = serverInfo['timezone']?.toString() ?? '';
        if (tzString.isNotEmpty) {
          final offset = _parseTimezoneOffset(tzString, serverInfo);
          if (offset != null) {
            await playlistEpgTimezoneStore.setServerUtcOffset(p.id, offset);
          }
        }
      } catch (_) {
        // Non-fatal — timezone fetch failure shouldn't block catalog sync
      }

      final links = XtreamStreamLinkBuilder(
        serverUrl: p.serverUrl!.trim(),
        username: p.username!.trim(),
        password: p.password!,
      );

      final liveCatRaw = await client.getLiveCategories();
      bumpGenerationCheck();
      final vodCatRaw = await client.getVodCategories();
      bumpGenerationCheck();
      final serCatRaw = await client.getSeriesCategories();
      bumpGenerationCheck();

      late final List<Map<String, dynamic>> liveStrRaw;
      late final List<Map<String, dynamic>> vodStrRaw;
      late final List<Map<String, dynamic>> serListRaw;

      if (prefetchedLiveStreams != null &&
          prefetchedVodStreams != null &&
          prefetchedSeriesList != null) {
        liveStrRaw = prefetchedLiveStreams;
        vodStrRaw = prefetchedVodStreams;
        serListRaw = prefetchedSeriesList;
      } else {
        liveStrRaw = await client.getLiveStreams();
        bumpGenerationCheck();
        vodStrRaw = await client.getVodStreams();
        bumpGenerationCheck();
        serListRaw = await client.getSeriesList();
        bumpGenerationCheck();
      }

      if (_signatureFor(lib) != sigAtStart) return false;
      if (myGen != null && myGen != _catalogSyncGeneration) return false;

      liveCategories = mapper.mapXtreamLiveCategories(liveCatRaw);
      vodCategories = mapper.mapXtreamVodCategories(vodCatRaw);
      seriesCategories = mapper.mapXtreamSeriesCategories(serCatRaw);

      final serverUrl = p.serverUrl!.trim();
      final user = p.username!.trim();
      final pass = p.password!;

      // Stagger updates: map each content type in an isolate, assign, yield
      // to the event loop so the framework can paint between heavy rebuilds.
      liveChannelsAll = await mapper.computeLiveChannelsInIsolate(
        liveStrRaw,
        serverUrl: serverUrl,
        username: user,
        password: pass,
      );
      bumpGenerationCheck();
      notifyListeners();
      await Future<void>.delayed(Duration.zero);

      vodMoviesAll = await mapper.computeVodStreamsInIsolate(
        vodStrRaw,
        serverUrl: serverUrl,
        username: user,
        password: pass,
      );
      bumpGenerationCheck();
      notifyListeners();
      await Future<void>.delayed(Duration.zero);

      seriesAll = await mapper.computeSeriesListInIsolate(serListRaw);
      bumpGenerationCheck();

      final hasSomething = liveCategories.isNotEmpty ||
          vodCategories.isNotEmpty ||
          seriesCategories.isNotEmpty;
      if (!hasSomething) {
        if (!isBackground) {
          phase = XtreamCatalogPhase.error;
          errorKind = XtreamBrowseErrorKind.empty;
          errorMessage = 'The server returned no categories.';
          _clearData();
          notifyListeners();
        }
        return false;
      }

      phase = XtreamCatalogPhase.ready;
      errorKind = XtreamBrowseErrorKind.none;
      errorMessage = null;

      await xtreamCatalogCacheDb.saveFullCatalog(
        playlistId: p.id,
        fingerprint: fingerprint,
        snapshot: _snapshotFromCurrentLists(),
      );

      _lastNetworkRefreshSig = sigAtStart;
      _lastNetworkRefreshAtMs = DateTime.now().millisecondsSinceEpoch;

      notifyListeners();
      return true;
    } on _StaleCatalogSyncException {
      return false;
    } catch (e, st) {
      debugPrint('XtreamCatalogRepository: $e\n$st');
      if (!isBackground) {
        phase = XtreamCatalogPhase.error;
        if (e is XtreamAuthException) {
          errorKind = XtreamBrowseErrorKind.auth;
          errorMessage = e.message;
        } else if (e is XtreamBadUrlException) {
          errorKind = XtreamBrowseErrorKind.badUrl;
          errorMessage = e.message;
        } else if (e is XtreamNetworkException) {
          errorKind = XtreamBrowseErrorKind.network;
          errorMessage = e.message;
        } else if (e is XtreamParseException) {
          errorKind = XtreamBrowseErrorKind.network;
          errorMessage = e.message;
        } else {
          errorKind = XtreamBrowseErrorKind.network;
          errorMessage = 'Unexpected error: $e';
        }
        _clearData();
        notifyListeners();
      }
      return false;
    }
  }

  /// Call when [LibraryController] or active playlist changes.
  Future<void> syncFromLibrary(LibraryController lib) async {
    if (!lib.isReady) return;
    final sig = _signatureFor(lib);

    if (lib.useDemoData) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.idle;
      errorKind = XtreamBrowseErrorKind.none;
      errorMessage = null;
      _clearData();
      notifyListeners();
      return;
    }

    final p = lib.activePlaylist;
    if (p == null || !p.isXtream) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.error;
      errorKind = XtreamBrowseErrorKind.unsupported;
      errorMessage =
          'M3U playlists are not supported in this build. Use demo mode or an Xtream Codes playlist.';
      _clearData();
      notifyListeners();
      return;
    }

    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.error;
      errorKind = XtreamBrowseErrorKind.badUrl;
      errorMessage =
          'This playlist is missing server URL, username, or password.';
      _clearData();
      notifyListeners();
      return;
    }

    if (_lastSignature == sig && phase == XtreamCatalogPhase.ready) {
      unawaited(_backgroundRefreshCatalog(lib, sig));
      return;
    }

    final fp = XtreamCatalogCacheDb.credentialsFingerprint(p);
    final cached = await xtreamCatalogCacheDb.readFullCatalog(
      playlistId: p.id,
      fingerprint: fp,
    );
    if (cached != null && _applySnapshot(cached)) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.ready;
      errorKind = XtreamBrowseErrorKind.none;
      errorMessage = null;
      notifyListeners();
      unawaited(_backgroundRefreshCatalog(lib, sig));
      return;
    }

    final myGen = ++_catalogSyncGeneration;
    _busy = true;
    _lastSignature = sig;
    phase = XtreamCatalogPhase.loading;
    errorKind = XtreamBrowseErrorKind.none;
    errorMessage = null;
    notifyListeners();

    try {
      await _performNetworkSync(
        lib,
        sig,
        p,
        fp,
        isBackground: false,
        myGen: myGen,
      );
    } finally {
      if (myGen == _catalogSyncGeneration) {
        _busy = false;
      }
      notifyListeners();
    }
  }

  /// After adding a playlist, reuses stream payloads from the add flow so we
  /// only fetch categories (avoids duplicating heavy `get_*_streams` calls).
  Future<void> syncFromLibraryWithPrefetchedStreams(
    LibraryController lib, {
    required XtreamApiClient client,
    required List<Map<String, dynamic>> liveStreamsRaw,
    required List<Map<String, dynamic>> vodStreamsRaw,
    required List<Map<String, dynamic>> seriesListRaw,
  }) async {
    if (!lib.isReady) return;
    final sig = _signatureFor(lib);

    if (lib.useDemoData) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.idle;
      errorKind = XtreamBrowseErrorKind.none;
      errorMessage = null;
      _clearData();
      notifyListeners();
      return;
    }

    final p = lib.activePlaylist;
    if (p == null || !p.isXtream) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.error;
      errorKind = XtreamBrowseErrorKind.unsupported;
      errorMessage =
          'M3U playlists are not supported in this build. Use demo mode or an Xtream Codes playlist.';
      _clearData();
      notifyListeners();
      return;
    }

    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) {
      _lastSignature = sig;
      phase = XtreamCatalogPhase.error;
      errorKind = XtreamBrowseErrorKind.badUrl;
      errorMessage =
          'This playlist is missing server URL, username, or password.';
      _clearData();
      notifyListeners();
      return;
    }

    final myGen = ++_catalogSyncGeneration;
    _busy = true;
    _lastSignature = sig;
    phase = XtreamCatalogPhase.loading;
    errorKind = XtreamBrowseErrorKind.none;
    errorMessage = null;
    notifyListeners();

    final fp = XtreamCatalogCacheDb.credentialsFingerprint(p);
    try {
      await _performNetworkSync(
        lib,
        sig,
        p,
        fp,
        isBackground: false,
        myGen: myGen,
        existingClient: client,
        prefetchedLiveStreams: liveStreamsRaw,
        prefetchedVodStreams: vodStreamsRaw,
        prefetchedSeriesList: seriesListRaw,
      );
    } finally {
      if (myGen == _catalogSyncGeneration) {
        _busy = false;
      }
      notifyListeners();
    }
  }

  List<MockLiveChannel> liveChannelsForCategory(String categoryId) {
    return liveChannelsAll
        .where((c) => c.categoryId == categoryId)
        .toList(growable: false);
  }

  List<MockMovie> vodMoviesForCategory(String categoryId) {
    return vodMoviesAll
        .where((m) => m.categoryId == categoryId)
        .toList(growable: false);
  }

  List<MockSeries> seriesForCategory(String categoryId) {
    return seriesAll
        .where((s) => s.categoryId == categoryId)
        .toList(growable: false);
  }

  /// Loads seasons/episodes for [skeleton] (browse rows use empty seasons).
  Future<MockSeries> fetchSeriesDetail(
    LibraryController lib,
    MockSeries skeleton,
  ) async {
    if (lib.useDemoData) return skeleton;
    final p = lib.activePlaylist;
    if (p == null || !p.isXtream) return skeleton;
    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) return skeleton;

    final client = XtreamApiClient(
      baseUrl: server,
      username: u,
      password: pw,
    );
    final links = XtreamStreamLinkBuilder(
      serverUrl: server,
      username: u,
      password: pw,
    );
    final json = await client.getSeriesInfo(skeleton.id);
    return mapper.mergeXtreamSeriesDetail(skeleton, json, links);
  }
}

class _StaleCatalogSyncException implements Exception {}

/// Refreshes the server timezone offset for the active playlist.
/// Can be called independently of a full catalog sync.
Future<void> refreshServerTimezone() async {
  final p = libraryController.activePlaylist;
  if (p == null || !p.isXtream) return;
  final server = p.serverUrl?.trim() ?? '';
  final u = p.username?.trim() ?? '';
  final pw = p.password ?? '';
  if (server.isEmpty || u.isEmpty || pw.isEmpty) return;

  try {
    final client = XtreamApiClient(baseUrl: server, username: u, password: pw);
    final serverInfo = await client.getServerInfo();
    final tzString = serverInfo['timezone']?.toString() ?? '';
    if (tzString.isNotEmpty) {
      final offset = _parseTimezoneOffset(tzString, serverInfo);
      if (offset != null) {
        debugPrint('[TZ Refresh] playlist=${p.id} offset=$offset');
        await playlistEpgTimezoneStore.setServerUtcOffset(p.id, offset);
      }
    }
  } catch (e) {
    debugPrint('[TZ Refresh] error: $e');
  }
}

/// Computes the server's UTC offset in hours from `server_info`.
///
/// Strategy: compare `timestamp_now` (Unix UTC) with the parsed `time_now`
/// string (server local time). The difference is the UTC offset.
/// Falls back to well-known timezone names if the numeric approach fails.
double? _parseTimezoneOffset(
  String tzName,
  Map<String, dynamic> serverInfo,
) {
  // Try numeric approach: compare timestamp_now (UTC epoch) with time_now
  // (server-local date-time string).
  //
  // time_now e.g. "2026-03-31 10:46:07" — this is in the SERVER's timezone.
  // timestamp_now e.g. 1774971967 — this is UTC epoch seconds.
  //
  // Parse time_now as UTC (ignoring device timezone) then compare with the
  // actual UTC epoch to derive the server's offset.
  final tsNow = serverInfo['timestamp_now'];
  final timeNow = serverInfo['time_now']?.toString();
  if (tsNow != null && timeNow != null && timeNow.isNotEmpty) {
    final utcEpoch = tsNow is num
        ? tsNow.toInt()
        : int.tryParse(tsNow.toString());
    if (utcEpoch != null && utcEpoch > 0) {
      // Parse the local-time string AS IF it were UTC to get its "face value"
      var raw = timeNow.trim();
      if (raw.contains(' ') && !raw.contains('T')) {
        raw = raw.replaceFirst(' ', 'T');
      }
      if (!raw.endsWith('Z') && !raw.contains('+')) {
        raw = '${raw}Z'; // force UTC interpretation
      }
      final serverLocalAsUtc = DateTime.tryParse(raw);
      if (serverLocalAsUtc != null) {
        final actualUtc = DateTime.fromMillisecondsSinceEpoch(
          utcEpoch * 1000,
          isUtc: true,
        );
        final diffSeconds =
            serverLocalAsUtc.difference(actualUtc).inSeconds;
        final offsetHours = diffSeconds / 3600;
        if (offsetHours >= -14 && offsetHours <= 14) {
          debugPrint('[TZ] time_now=$timeNow tsNow=$utcEpoch '
              'diff=${diffSeconds}s → offset=$offsetHours');
          return (offsetHours * 2).round() / 2;
        }
      }
    }
  }

  // Fallback: common timezone name lookup (standard offsets — DST not handled)
  final tz = tzName.toLowerCase();
  const knownOffsets = <String, double>{
    'asia/jerusalem': 2,
    'asia/tel_aviv': 2,
    'europe/london': 0,
    'europe/berlin': 1,
    'europe/paris': 1,
    'europe/amsterdam': 1,
    'europe/rome': 1,
    'europe/madrid': 1,
    'europe/athens': 2,
    'europe/bucharest': 2,
    'europe/istanbul': 3,
    'europe/moscow': 3,
    'america/new_york': -5,
    'america/chicago': -6,
    'america/denver': -7,
    'america/los_angeles': -8,
    'utc': 0,
    'gmt': 0,
  };
  return knownOffsets[tz];
}
