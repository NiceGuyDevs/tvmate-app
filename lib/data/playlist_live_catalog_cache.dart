import 'package:flutter/foundation.dart';

import '../ui/live_tv/mock_live_tv_data.dart';
import '../xtream/xtream_api_client.dart';
import '../xtream/xtream_exceptions.dart';
import '../xtream/xtream_mapper.dart' as mapper;
import '../xtream/xtream_stream_urls.dart';
import 'library_controller.dart';
import 'stored_playlist.dart';
import 'xtream_catalog_cache_db.dart';
import 'xtream_catalog_repository.dart';

/// In-memory live categories + channels for **non-active** Xtream playlists
/// (used for cross-playlist Live TV favorites). The active playlist still uses
/// [XtreamCatalogRepository].
final PlaylistLiveCatalogCache playlistLiveCatalogCache =
    PlaylistLiveCatalogCache._();

class _LiveSnapshot {
  _LiveSnapshot({
    required this.categories,
    required this.channelsAll,
  }) {
    for (final c in channelsAll) {
      byId[c.id] = c;
    }
  }

  final List<MockLiveCategory> categories;
  final List<MockLiveChannel> channelsAll;
  final Map<String, MockLiveChannel> byId = {};
}

/// Loads and caches `get_live_categories` + `get_live_streams` per playlist id.
class PlaylistLiveCatalogCache extends ChangeNotifier {
  PlaylistLiveCatalogCache._();

  final Map<String, _LiveSnapshot?> _snapshots = {};
  final Map<String, String?> _errors = {};
  final Map<String, Future<void>> _inFlight = {};

  String? errorFor(String playlistId) => _errors[playlistId];

  List<MockLiveCategory> categoriesFor(String playlistId) {
    return _snapshots[playlistId]?.categories ?? const [];
  }

  List<MockLiveChannel> channelsForCategory(String playlistId, String categoryId) {
    final all = _snapshots[playlistId]?.channelsAll;
    if (all == null) return const [];
    return all.where((c) => c.categoryId == categoryId).toList(growable: false);
  }

  MockLiveChannel? channelById(String playlistId, String channelId) {
    return _snapshots[playlistId]?.byId[channelId];
  }

  bool isReady(String playlistId) => _snapshots[playlistId] != null;

  void evict(String playlistId) {
    _snapshots.remove(playlistId);
    _errors.remove(playlistId);
    notifyListeners();
  }

  StoredPlaylist? _playlist(String playlistId) {
    for (final p in libraryController.playlists) {
      if (p.id == playlistId) return p;
    }
    return null;
  }

  /// Fetches live catalog for [playlistId] if missing. Safe to call repeatedly.
  Future<void> ensurePlaylistLoaded(String playlistId) async {
    if (playlistId.isEmpty) return;
    if (_snapshots[playlistId] != null) return;
    final existing = _inFlight[playlistId];
    if (existing != null) {
      await existing;
      return;
    }
    final fut = _loadInternal(playlistId);
    _inFlight[playlistId] = fut;
    try {
      await fut;
    } finally {
      _inFlight.remove(playlistId);
    }
  }

  Future<void> _loadInternal(String playlistId) async {
    if (playlistId == libraryController.activePlaylistId &&
        xtreamCatalogRepository.phase == XtreamCatalogPhase.ready &&
        xtreamCatalogRepository.liveChannelsAll.isNotEmpty) {
      _snapshots[playlistId] = _LiveSnapshot(
        categories: List<MockLiveCategory>.from(
          xtreamCatalogRepository.liveCategories,
        ),
        channelsAll: List<MockLiveChannel>.from(
          xtreamCatalogRepository.liveChannelsAll,
        ),
      );
      _errors[playlistId] = null;
      notifyListeners();
      return;
    }

    final p = _playlist(playlistId);
    if (p == null || !p.isXtream) {
      _errors[playlistId] = 'Playlist not found or not Xtream.';
      _snapshots[playlistId] = null;
      notifyListeners();
      return;
    }
    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) {
      _errors[playlistId] = 'Missing server URL, username, or password.';
      _snapshots[playlistId] = null;
      notifyListeners();
      return;
    }

    final fp = XtreamCatalogCacheDb.credentialsFingerprint(p);
    final diskLive = await xtreamCatalogCacheDb.readLiveCatalog(
      playlistId: playlistId,
      fingerprint: fp,
    );
    if (diskLive != null && diskLive.liveChannelsAll.isNotEmpty) {
      _snapshots[playlistId] = _LiveSnapshot(
        categories: diskLive.liveCategories,
        channelsAll: diskLive.liveChannelsAll,
      );
      _errors[playlistId] = null;
      notifyListeners();
      return;
    }

    try {
      final client = XtreamApiClient(
        baseUrl: server,
        username: u,
        password: pw,
      );
      await client.verifyAuth();
      final links = XtreamStreamLinkBuilder(
        serverUrl: server,
        username: u,
        password: pw,
      );
      final liveCatRaw = await client.getLiveCategories();
      final liveStrRaw = await client.getLiveStreams();
      final categories = mapper.mapXtreamLiveCategories(liveCatRaw);
      final channelsAll = mapper.mapXtreamLiveChannels(liveStrRaw, links);
      _snapshots[playlistId] = _LiveSnapshot(
        categories: categories,
        channelsAll: channelsAll,
      );
      _errors[playlistId] = null;
      if (playlistId != libraryController.activePlaylistId) {
        await xtreamCatalogCacheDb.saveLiveCatalogOnly(
          playlistId: playlistId,
          fingerprint: fp,
          liveCategories: categories,
          liveChannelsAll: channelsAll,
        );
      }
    } catch (e, st) {
      debugPrint('PlaylistLiveCatalogCache: $e\n$st');
      _snapshots[playlistId] = null;
      _errors[playlistId] = e is XtreamAuthException
          ? e.message
          : e is XtreamBadUrlException
              ? e.message
              : e is XtreamNetworkException
                  ? e.message
                  : e is XtreamParseException
                      ? e.message
                      : 'Could not load playlist.';
    }
    notifyListeners();
  }
}
