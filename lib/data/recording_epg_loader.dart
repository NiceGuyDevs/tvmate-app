import 'package:flutter/foundation.dart';

import '../xtream/xtream_api_client.dart';
import '../xtream/xtream_short_epg_parser.dart';
import 'library_controller.dart';
import 'xmltv_epg_cache.dart';

class _DayCache {
  _DayCache(this.listings, this.fetchedAt);

  final List<XtreamEpgListing> listings;
  final DateTime fetchedAt;

  bool get isStale => DateTime.now().difference(fetchedAt).inMinutes > 10;
}

/// Fetches, filters, and caches EPG listings for the Recording screen.
class RecordingEpgLoader extends ChangeNotifier {
  RecordingEpgLoader._();

  static final RecordingEpgLoader instance = RecordingEpgLoader._();

  final Map<String, _DayCache> _cache = {};
  final Set<String> _inflight = {};

  bool isLoading(String streamId, DateTime day) =>
      _inflight.contains(_key(streamId, day));

  List<XtreamEpgListing> lookup(String streamId, DateTime day) {
    final c = _cache[_key(streamId, day)];
    if (c == null) return const [];
    return c.listings;
  }

  Future<List<XtreamEpgListing>> fetchDay({
    required String streamId,
    required DateTime day,
    String? epgChannelId,
  }) async {
    final key = _key(streamId, day);

    final cached = _cache[key];
    if (cached != null && !cached.isStale) return cached.listings;
    if (_inflight.contains(key)) return cached?.listings ?? const [];

    _inflight.add(key);
    notifyListeners();

    try {
      final p = libraryController.activePlaylist;
      if (p == null || !p.isXtream) {
        _inflight.remove(key);
        notifyListeners();
        return const [];
      }
      final server = p.serverUrl?.trim() ?? '';
      final u = p.username?.trim() ?? '';
      final pw = p.password ?? '';
      if (server.isEmpty || u.isEmpty || pw.isEmpty) {
        _inflight.remove(key);
        notifyListeners();
        return const [];
      }

      final candidates = _epgIdCandidates(streamId, epgChannelId);
      debugPrint('[EPG] fetchDay streamId=$streamId epgChannelId=$epgChannelId '
          'candidates=$candidates day=$day');
      final now = DateTime.now();
      final isToday = day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;

      List<XtreamEpgListing> allListings = const [];

      final client = XtreamApiClient(
        baseUrl: server, username: u, password: pw,
      );

      // Strategy 1: get_simple_data_table with NO params (returns ALL EPG)
      for (final tryId in candidates) {
        try {
          debugPrint('[EPG] trying getAllEpg for id=$tryId');
          final raw = await client.getAllEpg(streamId: tryId);
          final parsed = parseXtreamShortEpgListings(raw);
          debugPrint('[EPG] getAllEpg id=$tryId → ${parsed.length} total listings');
          if (parsed.length > 5) {
            // Log date range of what we got
            DateTime? earliest;
            DateTime? latest;
            for (final e in parsed) {
              if (e.start != null) {
                if (earliest == null || e.start!.isBefore(earliest)) {
                  earliest = e.start;
                }
                if (latest == null || e.start!.isAfter(latest)) {
                  latest = e.start;
                }
              }
            }
            debugPrint('[EPG] getAllEpg date range: $earliest → $latest');
          }
          if (parsed.isNotEmpty) {
            allListings = parsed;
            break;
          }
        } catch (e) {
          debugPrint('[EPG] getAllEpg id=$tryId error: $e');
        }
      }

      // Strategy 2: get_short_epg (near-now window)
      if (allListings.isEmpty || (isToday && allListings.length < 3)) {
        for (final tryId in candidates) {
          try {
            debugPrint('[EPG] trying getFullDayEpg for id=$tryId');
            final raw = await client.getFullDayEpg(
              streamId: tryId, forDay: day,
            );
            final parsed = parseXtreamShortEpgListings(raw);
            debugPrint('[EPG] getFullDayEpg id=$tryId → ${parsed.length} listings');
            if (parsed.isNotEmpty) {
              allListings = _mergeUnique(allListings, parsed);
              break;
            }
          } catch (e) {
            debugPrint('[EPG] getFullDayEpg id=$tryId error: $e');
          }
        }
      }

      // Strategy 3: XMLTV DB (accumulated historical data)
      if (allListings.isEmpty || (!isToday && allListings.length < 3)) {
        try {
          await xmltvEpgCache.ensureLoaded(
            serverUrl: server,
            username: u,
            password: pw,
            playlistId: p.id,
          );
          final xmltvResults = await xmltvEpgCache.lookup(
            channelIds: candidates,
            day: day,
          );
          debugPrint('[EPG] XMLTV DB → ${xmltvResults.length} listings');
          if (xmltvResults.length > allListings.length) {
            allListings = _mergeUnique(allListings, xmltvResults);
          }
        } catch (e) {
          debugPrint('[EPG] XMLTV error: $e');
        }
      }

      debugPrint('[EPG] total before filter: ${allListings.length}');

      final filtered = _filterForDay(allListings, day);
      _cache[key] = _DayCache(filtered, DateTime.now());
      return filtered;
    } catch (e, st) {
      debugPrint('RecordingEpgLoader: $e\n$st');
      return const [];
    } finally {
      _inflight.remove(key);
      notifyListeners();
    }
  }

  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  static String _key(String streamId, DateTime day) {
    final d =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return '$streamId|$d';
  }

  static List<XtreamEpgListing> _mergeUnique(
    List<XtreamEpgListing> a,
    List<XtreamEpgListing> b,
  ) {
    final seen = <String>{};
    final out = <XtreamEpgListing>[];
    void take(XtreamEpgListing e) {
      final u = e.startUnix ?? 0;
      final k = '$u|${e.title}';
      if (seen.add(k)) out.add(e);
    }

    for (final e in a) {
      take(e);
    }
    for (final e in b) {
      take(e);
    }
    return out;
  }

  static List<String> _epgIdCandidates(String streamId, String? epgChannelId) {
    final out = <String>[];
    final seen = <String>{};
    void add(String x) {
      final t = x.trim();
      if (t.isEmpty || !seen.add(t)) return;
      out.add(t);
    }

    final ec = epgChannelId?.trim();
    if (ec != null && ec.isNotEmpty) add(ec);
    add(streamId.trim());
    return out;
  }

  /// True when [raw] begins with `YYYY-MM-DD` matching [day] (panel wall date).
  static bool _calendarDayPrefixMatches(String? raw, DateTime day) {
    if (raw == null || raw.length < 10) return false;
    final head = raw.substring(0, 10);
    if (head[4] != '-' || head[7] != '-') return false;
    final want =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return head == want;
  }

  /// Shows past programs for the requested day.
  /// For catch-up, only programs that have already started are useful.
  static List<XtreamEpgListing> _filterForDay(
    List<XtreamEpgListing> all,
    DateTime day,
  ) {
    if (all.isEmpty) return const [];

    final now = DateTime.now();
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final todayStart = DateTime(now.year, now.month, now.day);
    final isStrictlyPastDay = day.isBefore(todayStart);

    var filtered = all.where((e) {
      final s = e.start;
      final byRaw = _calendarDayPrefixMatches(e.startRaw, day);
      var inParsedDay = false;
      if (s != null && !s.isBefore(dayStart) && s.isBefore(dayEnd)) {
        inParsedDay = true;
      }
      if (!byRaw && !inParsedDay) return false;
      if (isStrictlyPastDay) return true;
      return s != null && s.isBefore(now);
    }).toList();

    // Only for *today*: short EPG may not align with midnight boundaries
    // (timezone / panel window). Do not reuse this for other days — the API
    // blob is usually "near now", so that fallback would repeat the same list
    // for yesterday and earlier.
    final sameDayAsNow = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    if (filtered.isEmpty && sameDayAsNow) {
      filtered = all.where((e) {
        final s = e.start;
        return s != null && s.isBefore(now);
      }).toList();
    }

    filtered.sort((a, b) {
      final sa = a.start;
      final sb = b.start;
      if (sa == null && sb == null) return 0;
      if (sa == null) return -1;
      if (sb == null) return 1;
      return sa.compareTo(sb);
    });

    return filtered;
  }

  /// Pre-loads the XMLTV cache in the background so past-day lookups are fast.
  Future<void> preloadXmltv() async {
    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) return;
    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) return;
    try {
      await xmltvEpgCache.ensureLoaded(
        serverUrl: server,
        username: u,
        password: pw,
        playlistId: p.id,
      );
    } catch (e) {
      debugPrint('RecordingEpgLoader preloadXmltv: $e');
    }
  }
}
