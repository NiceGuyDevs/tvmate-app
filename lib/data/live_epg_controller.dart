import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../xtream/xtream_api_client.dart';
import '../xtream/xtream_short_epg_parser.dart';
import 'epg_time_display.dart';
import 'library_controller.dart';

/// Current programme from Xtream short EPG for UI (hero + player).
class LiveNowEpgDisplay {
  const LiveNowEpgDisplay({
    required this.title,
    required this.description,
    required this.progress01,
    required this.isOnAir,
    this.timeRange,
    this.programStart,
    this.programEnd,
    this.programStartRaw,
    this.programEndRaw,
    this.programStartUnix,
    this.programEndUnix,
  });

  final String title;
  final String description;
  final double progress01;
  final bool isOnAir;
  final String? timeRange;

  /// Local wall-clock bounds for the current listing (when known).
  final DateTime? programStart;
  final DateTime? programEnd;

  /// From [XtreamEpgListing] for [formatEpgProgramTime] (per-playlist EPG display).
  final String? programStartRaw;
  final String? programEndRaw;
  final int? programStartUnix;
  final int? programEndUnix;
}

class _CacheEntry {
  _CacheEntry(this.display, this.listings, this.fetchedAt, this.validUntil);

  final LiveNowEpgDisplay display;
  final List<XtreamEpgListing> listings;
  final DateTime fetchedAt;
  final DateTime validUntil;
}

/// Fetches and caches `get_short_epg` / `get_simple_data_table` per stream for the active Xtream playlist.
class LiveEpgController extends ChangeNotifier {
  LiveEpgController._();

  static final LiveEpgController instance = LiveEpgController._();

  final Map<String, _CacheEntry> _cache = {};

  /// Longer EPG list for the live player full-screen guide overlay (per stream id).
  final Map<String, List<XtreamEpgListing>> _overlayListingsByStream = {};
  final Set<String> _overlayLoading = {};

  String? _focusedStreamId;
  LiveNowEpgDisplay? _display;
  List<XtreamEpgListing> _epgListings = const [];
  var _loading = false;
  int _requestGen = 0;

  String? get focusedStreamId => _focusedStreamId;

  LiveNowEpgDisplay? get display => _display;

  /// Upcoming / current slots for horizontal EPG rail (same order as Xtream short EPG).
  List<XtreamEpgListing> get epgListings =>
      UnmodifiableListView(_epgListings);

  bool get loading => _loading;

  /// programme line for [streamId] even if global focus moved (e.g. hero vs player).
  LiveNowEpgDisplay? lookupDisplay(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return null;
    if (_focusedStreamId == id) return _display;
    return _cache[id]?.display;
  }

  List<XtreamEpgListing> lookupListings(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return const [];
    if (_focusedStreamId == id) {
      return List<XtreamEpgListing>.from(_epgListings);
    }
    final c = _cache[id];
    if (c == null) return const [];
    return List<XtreamEpgListing>.from(c.listings);
  }

  bool isLoadingFor(String streamId) {
    final id = streamId.trim();
    return _loading && _focusedStreamId == id;
  }

  /// True while [loadOverlayListings] is fetching extended rows for [streamId].
  bool isOverlayLoadingFor(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return false;
    return _overlayLoading.contains(id);
  }

  /// Extended programme rows for the full guide overlay (may be empty until loaded).
  List<XtreamEpgListing> overlayListingsFor(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) return const [];
    return List<XtreamEpgListing>.from(_overlayListingsByStream[id] ?? const []);
  }

  /// Fetches a longer EPG window for the overlay (short → simple → all-EPG fallback).
  Future<void> loadOverlayListings(
    String streamId, {
    String? epgChannelId,
  }) async {
    final id = streamId.trim();
    if (id.isEmpty) return;

    if (libraryController.useDemoData) {
      _overlayListingsByStream[id] = const [];
      notifyListeners();
      return;
    }

    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) {
      _overlayListingsByStream[id] = const [];
      notifyListeners();
      return;
    }

    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) {
      _overlayListingsByStream[id] = const [];
      notifyListeners();
      return;
    }

    if (_overlayLoading.contains(id)) return;

    _overlayLoading.add(id);
    // Drop stale rows so the overlay shows loading until this full fetch completes.
    _overlayListingsByStream.remove(id);
    notifyListeners();

    final candidates = _epgIdCandidates(id, epgChannelId);
    var best = <XtreamEpgListing>[];

    try {
      final client = XtreamApiClient(
        baseUrl: server,
        username: u,
        password: pw,
      );

      /// Pull as many programmes as the panel allows — pick the largest non-empty result.
      Future<List<XtreamEpgListing>> loadBestForStreamId(String tryId) async {
        var longest = <XtreamEpgListing>[];
        void takeIfBetter(List<XtreamEpgListing> parsed) {
          if (parsed.length > longest.length) longest = parsed;
        }

        try {
          final rawAll = await client.getAllEpg(streamId: tryId);
          takeIfBetter(parseXtreamShortEpgListings(rawAll));
        } catch (e, st) {
          debugPrint('LiveEpgController overlay getAllEpg id=$tryId: $e\n$st');
        }
        try {
          final rawT = await client.getSimpleDataTable(
            streamId: tryId,
            limit: 800,
          );
          takeIfBetter(parseXtreamShortEpgListings(rawT));
        } catch (e, st) {
          debugPrint(
            'LiveEpgController overlay getSimpleDataTable id=$tryId: $e\n$st',
          );
        }
        try {
          final rawS = await client.getShortEpg(
            streamId: tryId,
            limit: 200,
          );
          takeIfBetter(parseXtreamShortEpgListings(rawS));
        } catch (e, st) {
          debugPrint(
            'LiveEpgController overlay getShortEpg id=$tryId: $e\n$st',
          );
        }
        return longest;
      }

      for (final tryId in candidates) {
        try {
          final listings = await loadBestForStreamId(tryId);
          if (listings.length > best.length) {
            best = listings;
          }
        } catch (e, st) {
          debugPrint('LiveEpgController overlay id=$tryId: $e\n$st');
        }
      }

      best.sort((a, b) {
        final as = a.start;
        final bs = b.start;
        if (as == null && bs == null) return 0;
        if (as == null) return 1;
        if (bs == null) return -1;
        return as.compareTo(bs);
      });

      _overlayListingsByStream[id] = filterEpgListingsFromNow(best);
    } catch (e, st) {
      debugPrint('LiveEpgController overlay: $e\n$st');
      _overlayListingsByStream[id] = const [];
    } finally {
      _overlayLoading.remove(id);
      notifyListeners();
    }
  }

  static List<String> _epgIdCandidates(String streamId, String? epgChannelId) {
    final sid = streamId.trim();
    final ec = epgChannelId?.trim();
    final out = <String>[];
    final seen = <String>{};
    void add(String x) {
      final t = x.trim();
      if (t.isEmpty || !seen.add(t)) return;
      out.add(t);
    }

    if (ec != null && ec.isNotEmpty) add(ec);
    add(sid);
    return out;
  }

  static Future<List<XtreamEpgListing>> _loadListingsForId(
    XtreamApiClient client,
    String id,
  ) async {
    dynamic raw = await client.getShortEpg(streamId: id, limit: 24);
    var listings = parseXtreamShortEpgListings(raw);
    if (listings.isEmpty) {
      raw = await client.getSimpleDataTable(streamId: id, limit: 32);
      listings = parseXtreamShortEpgListings(raw);
    }
    return listings;
  }

  /// Silently populate the cache for [streamId] without changing focus or
  /// triggering loading state. Safe to call in bulk for pre-warming grids.
  Future<void> prefetchForStream(
    String streamId, {
    String? epgChannelId,
  }) async {
    final id = streamId.trim();
    if (id.isEmpty || libraryController.useDemoData) return;

    final cached = _cache[id];
    if (cached != null && DateTime.now().isBefore(cached.validUntil)) return;

    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) return;
    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) return;

    final candidates = _epgIdCandidates(id, epgChannelId);
    try {
      final client = XtreamApiClient(baseUrl: server, username: u, password: pw);
      XtreamEpgListing? picked;
      var winningListings = <XtreamEpgListing>[];
      for (final tryId in candidates) {
        try {
          final listings = await _loadListingsForId(client, tryId);
          if (listings.isEmpty) continue;
          winningListings = listings;
          picked = pickCurrentOrNextXtreamListing(listings) ?? listings.first;
          break;
        } catch (_) {}
      }
      if (picked != null) {
        final onAir = listingIsOnAirNow(picked);
        final display = LiveNowEpgDisplay(
          title: picked.title,
          description: picked.description.isEmpty
              ? (onAir ? 'Now playing' : 'Up next')
              : picked.description,
          progress01: onAir ? progress01ForListing(picked) : 0,
          isOnAir: onAir,
          timeRange: formatEpgTimeRangeForPlaylist(
            picked, libraryController.activePlaylistId),
          programStart: picked.start,
          programEnd: picked.end,
          programStartRaw: picked.startRaw,
          programEndRaw: picked.endRaw,
          programStartUnix: picked.startUnix,
          programEndUnix: picked.endUnix,
        );
        var validUntil = DateTime.now().add(const Duration(minutes: 2));
        final end = picked.end;
        if (end != null && end.isAfter(DateTime.now()) && end.isBefore(validUntil)) {
          validUntil = end.add(const Duration(seconds: 15));
        }
        final trimmed = winningListings.length > 16
            ? winningListings.sublist(0, 16)
            : List<XtreamEpgListing>.from(winningListings);
        _cache[id] = _CacheEntry(display, trimmed, DateTime.now(), validUntil);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('LiveEpgController prefetch id=$id: $e\n$st');
    }
  }

  /// Request EPG for [streamId]. When the panel maps EPG by XMLTV id, pass [epgChannelId].
  /// Demo mode clears API overlay. Ignored if [streamId] is empty.
  Future<void> refreshForStream(
    String streamId, {
    String? epgChannelId,
  }) async {
    final id = streamId.trim();
    if (id.isEmpty) return;

    final gen = ++_requestGen;
    _focusedStreamId = id;
    _epgListings = const [];

    if (libraryController.useDemoData) {
      _loading = false;
      _display = null;
      notifyListeners();
      return;
    }

    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) {
      _loading = false;
      _display = null;
      notifyListeners();
      return;
    }

    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) {
      _display = null;
      notifyListeners();
      return;
    }

    final cached = _cache[id];
    if (cached != null && DateTime.now().isBefore(cached.validUntil)) {
      if (gen != _requestGen || _focusedStreamId != id) return;
      _display = cached.display;
      _epgListings = List<XtreamEpgListing>.from(cached.listings);
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    final candidates = _epgIdCandidates(id, epgChannelId);
    LiveNowEpgDisplay? built;
    XtreamEpgListing? picked;
    var winningListings = <XtreamEpgListing>[];

    try {
      final client = XtreamApiClient(
        baseUrl: server,
        username: u,
        password: pw,
      );

      Object? lastError;
      for (final tryId in candidates) {
        try {
          final listings = await _loadListingsForId(client, tryId);
          if (listings.isEmpty) continue;
          winningListings = listings;
          picked = pickCurrentOrNextXtreamListing(listings) ?? listings.first;
          break;
        } catch (e, st) {
          lastError = e;
          debugPrint('LiveEpgController id=$tryId: $e\n$st');
        }
      }

      if (picked != null) {
        final onAir = listingIsOnAirNow(picked);
        built = LiveNowEpgDisplay(
          title: picked.title,
          description: picked.description.isEmpty
              ? (onAir ? 'Now playing' : 'Up next')
              : picked.description,
          progress01: onAir ? progress01ForListing(picked) : 0,
          isOnAir: onAir,
          timeRange: formatEpgTimeRangeForPlaylist(
            picked,
            libraryController.activePlaylistId,
          ),
          programStart: picked.start,
          programEnd: picked.end,
          programStartRaw: picked.startRaw,
          programEndRaw: picked.endRaw,
          programStartUnix: picked.startUnix,
          programEndUnix: picked.endUnix,
        );
      } else if (lastError != null) {
        debugPrint('LiveEpgController: no EPG for stream $id (candidates=$candidates)');
      }

      final trimmedListings = winningListings.length > 16
          ? winningListings.sublist(0, 16)
          : List<XtreamEpgListing>.from(winningListings);

      if (built != null) {
        var validUntil = DateTime.now().add(const Duration(minutes: 2));
        final end = picked?.end;
        if (end != null &&
            end.isAfter(DateTime.now()) &&
            end.isBefore(validUntil)) {
          validUntil = end.add(const Duration(seconds: 15));
        }
        _cache[id] = _CacheEntry(
          built,
          trimmedListings,
          DateTime.now(),
          validUntil,
        );
      }

      if (gen != _requestGen || _focusedStreamId != id) return;
      _display = built;
      _epgListings = built != null ? trimmedListings : const [];
    } catch (e, st) {
      debugPrint('LiveEpgController: $e\n$st');
      if (gen != _requestGen || _focusedStreamId != id) return;
      _display = null;
      _epgListings = const [];
    } finally {
      if (gen == _requestGen && _focusedStreamId == id) {
        _loading = false;
        notifyListeners();
      }
    }
  }
}
