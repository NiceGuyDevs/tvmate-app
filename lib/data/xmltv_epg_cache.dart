import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../xtream/xtream_short_epg_parser.dart';
import '../xtream/xtream_url.dart';

/// SQLite-backed XMLTV EPG cache.
///
/// Downloads `xmltv.php`, parses `<programme>` elements, and **persists** them
/// to a local database. This means today's download becomes tomorrow's
/// historical data — exactly how TiviMate and other IPTV apps work.
class XmltvEpgCache {
  XmltvEpgCache._();
  static final XmltvEpgCache instance = XmltvEpgCache._();

  Database? _db;
  bool _fetching = false;
  Completer<void>? _fetchCompleter;
  String? _lastPlaylistSig;
  DateTime? _lastFetchAt;

  static const Duration _refetchInterval = Duration(minutes: 30);
  static const int _maxAgeDays = 12;

  Future<Database> _openDb() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'tvmatepro_xmltv_epg.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS programmes (
            channel TEXT NOT NULL,
            start_utc INTEGER NOT NULL,
            stop_utc INTEGER NOT NULL,
            start_raw TEXT NOT NULL,
            stop_raw TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            playlist_sig TEXT NOT NULL,
            PRIMARY KEY (channel, start_utc, playlist_sig)
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_ch_start '
          'ON programmes (channel, start_utc)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_playlist '
          'ON programmes (playlist_sig)',
        );
      },
    );
    return _db!;
  }

  /// Ensures XMLTV data is loaded for the given playlist.
  Future<void> ensureLoaded({
    required String serverUrl,
    required String username,
    required String password,
    required String playlistId,
  }) async {
    final sig = '$serverUrl|$username|$playlistId';
    _lastPlaylistSig = sig;

    if (_lastFetchAt != null &&
        DateTime.now().difference(_lastFetchAt!) < _refetchInterval) {
      debugPrint('[XMLTV] skip re-fetch — last fetch '
          '${DateTime.now().difference(_lastFetchAt!).inSeconds}s ago');
      return;
    }

    if (_fetching) {
      debugPrint('[XMLTV] already fetching, waiting…');
      await _fetchCompleter?.future;
      return;
    }

    _fetching = true;
    _fetchCompleter = Completer<void>();
    try {
      await _download(serverUrl, username, password, sig);
      _lastFetchAt = DateTime.now();
      await _pruneOld(sig);
    } catch (e, st) {
      debugPrint('[XMLTV] download error: $e\n$st');
    } finally {
      _fetching = false;
      _fetchCompleter?.complete();
      _fetchCompleter = null;
    }
  }

  /// Returns programmes for [channelIds] on [day] (device-local date).
  Future<List<XtreamEpgListing>> lookup({
    required List<String> channelIds,
    required DateTime day,
  }) async {
    final db = await _openDb();
    final sig = _lastPlaylistSig ?? '';
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final now = DateTime.now();
    final isStrictlyPast = day.isBefore(DateTime(now.year, now.month, now.day));

    final dayStartUtcMs = dayStart.toUtc().millisecondsSinceEpoch;
    final dayEndUtcMs = dayEnd.toUtc().millisecondsSinceEpoch;
    final nowUtcMs = now.toUtc().millisecondsSinceEpoch;

    debugPrint('[XMLTV lookup] channelIds=$channelIds day=$day '
        'dayStartUtc=$dayStartUtcMs dayEndUtc=$dayEndUtcMs');

    // Try each candidate channel ID
    for (final id in channelIds) {
      final rows = await db.query(
        'programmes',
        where: 'channel = ? AND start_utc >= ? AND start_utc < ? '
            'AND playlist_sig = ?',
        whereArgs: [id, dayStartUtcMs, dayEndUtcMs, sig],
        orderBy: 'start_utc ASC',
      );
      debugPrint('[XMLTV lookup] id="$id" → ${rows.length} DB rows');

      if (rows.isEmpty) continue;

      final listings = <XtreamEpgListing>[];
      for (final row in rows) {
        final startMs = row['start_utc'] as int;
        if (!isStrictlyPast && startMs > nowUtcMs) continue;
        listings.add(_rowToListing(row));
      }
      if (listings.isNotEmpty) {
        debugPrint('[XMLTV lookup] returning ${listings.length} for "$id"');
        return listings;
      }
    }

    // Fuzzy match: try numeric extraction
    debugPrint('[XMLTV lookup] exact match failed, trying fuzzy…');
    for (final id in channelIds) {
      final numPart = RegExp(r'\d+').firstMatch(id)?.group(0);
      if (numPart == null || numPart.length < 3) continue;

      final rows = await db.query(
        'programmes',
        where: 'channel LIKE ? AND start_utc >= ? AND start_utc < ? '
            'AND playlist_sig = ?',
        whereArgs: ['%$numPart%', dayStartUtcMs, dayEndUtcMs, sig],
        orderBy: 'start_utc ASC',
        limit: 200,
      );
      debugPrint('[XMLTV lookup] fuzzy "$numPart" → ${rows.length} DB rows');

      if (rows.isEmpty) continue;

      final listings = <XtreamEpgListing>[];
      for (final row in rows) {
        final startMs = row['start_utc'] as int;
        if (!isStrictlyPast && startMs > nowUtcMs) continue;
        listings.add(_rowToListing(row));
      }
      if (listings.isNotEmpty) return listings;
    }

    debugPrint('[XMLTV lookup] no match for $channelIds on $day');
    return const [];
  }

  /// How many programmes are stored for a playlist.
  Future<int> storedCount() async {
    final db = await _openDb();
    final sig = _lastPlaylistSig ?? '';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM programmes WHERE playlist_sig = ?',
      [sig],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Distinct channel count.
  Future<int> storedChannelCount() async {
    final db = await _openDb();
    final sig = _lastPlaylistSig ?? '';
    final result = await db.rawQuery(
      'SELECT COUNT(DISTINCT channel) as cnt FROM programmes '
      'WHERE playlist_sig = ?',
      [sig],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Date range of stored data.
  Future<(DateTime?, DateTime?)> storedDateRange() async {
    final db = await _openDb();
    final sig = _lastPlaylistSig ?? '';
    final result = await db.rawQuery(
      'SELECT MIN(start_utc) as mn, MAX(start_utc) as mx '
      'FROM programmes WHERE playlist_sig = ?',
      [sig],
    );
    if (result.isEmpty) return (null, null);
    final mn = result.first['mn'] as int?;
    final mx = result.first['mx'] as int?;
    return (
      mn != null ? DateTime.fromMillisecondsSinceEpoch(mn, isUtc: true) : null,
      mx != null ? DateTime.fromMillisecondsSinceEpoch(mx, isUtc: true) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Download & persist
  // ---------------------------------------------------------------------------

  Future<void> _download(
    String serverUrl,
    String user,
    String pass,
    String sig,
  ) async {
    final root = xtreamStreamRootUri(serverUrl);
    var pathPrefix = root.path;
    if (pathPrefix.endsWith('/')) {
      pathPrefix = pathPrefix.substring(0, pathPrefix.length - 1);
    }
    final xmltvPath =
        pathPrefix.isEmpty ? '/xmltv.php' : '$pathPrefix/xmltv.php';
    final uri = root.replace(
      path: xmltvPath,
      queryParameters: {'username': user, 'password': pass},
    );

    debugPrint('[XMLTV] fetching $uri');
    final stopwatch = Stopwatch()..start();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 180));

      debugPrint('[XMLTV] HTTP ${response.statusCode}');
      if (response.statusCode != 200) {
        await response.drain<void>();
        return;
      }

      final body = await response.transform(utf8.decoder).join();
      debugPrint('[XMLTV] downloaded ${body.length} chars');

      if (body.length < 100) {
        debugPrint('[XMLTV] body too short: '
            '${body.substring(0, body.length.clamp(0, 200))}');
        return;
      }

      // Parse on main thread (regex is fast, ~600ms for 12k programmes)
      final programmes = _parseXmltvBody(body);
      debugPrint('[XMLTV] parsed ${programmes.length} programmes');

      if (programmes.isEmpty) return;

      // Persist to DB
      final db = await _openDb();
      final batch = db.batch();
      for (final prog in programmes) {
        batch.rawInsert(
          'INSERT OR REPLACE INTO programmes '
          '(channel, start_utc, stop_utc, start_raw, stop_raw, '
          'title, description, playlist_sig) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            prog.channel,
            prog.startUtcMs,
            prog.stopUtcMs,
            prog.startRaw,
            prog.stopRaw,
            prog.title,
            prog.desc,
            sig,
          ],
        );
      }
      await batch.commit(noResult: true);

      stopwatch.stop();

      // Log stats
      final totalCount = await storedCount();
      final chCount = await storedChannelCount();
      final range = await storedDateRange();
      debugPrint('[XMLTV] DB now has $totalCount programmes for '
          '$chCount channels');
      debugPrint('[XMLTV] DB date range: ${range.$1} → ${range.$2}');
      debugPrint('[XMLTV] done in ${stopwatch.elapsedMilliseconds}ms');

      // Log sample channel IDs
      final sampleRows = await db.rawQuery(
        'SELECT DISTINCT channel FROM programmes '
        'WHERE playlist_sig = ? LIMIT 30',
        [sig],
      );
      final sampleIds =
          sampleRows.map((r) => r['channel'] as String).toList();
      debugPrint('[XMLTV] sample channel IDs: $sampleIds');
    } catch (e, st) {
      debugPrint('[XMLTV] error: $e\n$st');
    } finally {
      client.close(force: true);
    }
  }

  /// Remove programmes older than [_maxAgeDays].
  Future<void> _pruneOld(String sig) async {
    final db = await _openDb();
    final cutoff = DateTime.now()
        .subtract(Duration(days: _maxAgeDays))
        .toUtc()
        .millisecondsSinceEpoch;
    final deleted = await db.delete(
      'programmes',
      where: 'start_utc < ? AND playlist_sig = ?',
      whereArgs: [cutoff, sig],
    );
    if (deleted > 0) {
      debugPrint('[XMLTV] pruned $deleted old programmes');
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static List<_XmltvParsed> _parseXmltvBody(String body) {
    final out = <_XmltvParsed>[];
    final progRegex = RegExp(
      r'<programme\s+([^>]*)>(.*?)</programme>',
      dotAll: true,
    );
    for (final match in progRegex.allMatches(body)) {
      final attrs = match.group(1) ?? '';
      final inner = match.group(2) ?? '';
      final prog = _parseSingleProgramme(attrs, inner);
      if (prog != null) out.add(prog);
    }
    return out;
  }

  static _XmltvParsed? _parseSingleProgramme(String attrs, String inner) {
    final channel = _attrValue(attrs, 'channel');
    final startStr = _attrValue(attrs, 'start');
    final stopStr = _attrValue(attrs, 'stop');
    if (channel == null || startStr == null || stopStr == null) return null;

    final startUtc = _parseXmltvTime(startStr);
    final stopUtc = _parseXmltvTime(stopStr);
    if (startUtc == null || stopUtc == null) return null;

    final titleMatch =
        RegExp(r'<title[^>]*>(.*?)</title>', dotAll: true).firstMatch(inner);
    final descMatch =
        RegExp(r'<desc[^>]*>(.*?)</desc>', dotAll: true).firstMatch(inner);

    final title = _xmlDecode(titleMatch?.group(1)?.trim() ?? '');
    final desc = _xmlDecode(descMatch?.group(1)?.trim() ?? '');

    return _XmltvParsed(
      channel: channel.trim(),
      startUtcMs: startUtc.millisecondsSinceEpoch,
      stopUtcMs: stopUtc.millisecondsSinceEpoch,
      startRaw: _xmltvTimeToRawStr(startStr),
      stopRaw: _xmltvTimeToRawStr(stopStr),
      title: title.isEmpty ? 'Program' : title,
      desc: desc,
    );
  }

  /// Parses XMLTV datetime: "20260331201500 +0000" → UTC DateTime
  static DateTime? _parseXmltvTime(String? raw) {
    if (raw == null || raw.length < 14) return null;
    final digits = raw.substring(0, 14);
    final year = int.tryParse(digits.substring(0, 4));
    final month = int.tryParse(digits.substring(4, 6));
    final day = int.tryParse(digits.substring(6, 8));
    final hour = int.tryParse(digits.substring(8, 10));
    final minute = int.tryParse(digits.substring(10, 12));
    final second = int.tryParse(digits.substring(12, 14));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    int offsetMinutes = 0;
    final tzMatch = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(raw);
    if (tzMatch != null) {
      final sign = tzMatch.group(1) == '+' ? 1 : -1;
      final h = int.tryParse(tzMatch.group(2)!) ?? 0;
      final m = int.tryParse(tzMatch.group(3)!) ?? 0;
      offsetMinutes = sign * (h * 60 + m);
    }

    final asUtc = DateTime.utc(year, month, day, hour, minute, second);
    return asUtc.subtract(Duration(minutes: offsetMinutes));
  }

  /// "20260331201500 +0000" → "2026-03-31 20:15:00"
  static String _xmltvTimeToRawStr(String? raw) {
    if (raw == null || raw.length < 14) return '';
    final d = raw.substring(0, 14);
    return '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)} '
        '${d.substring(8, 10)}:${d.substring(10, 12)}:${d.substring(12, 14)}';
  }

  static String? _attrValue(String attrs, String name) {
    final regex = RegExp('$name="([^"]*)"');
    return regex.firstMatch(attrs)?.group(1);
  }

  static String _xmlDecode(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static XtreamEpgListing _rowToListing(Map<String, Object?> row) {
    final startMs = row['start_utc'] as int;
    final stopMs = row['stop_utc'] as int;
    final startUtc = DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
    final stopUtc = DateTime.fromMillisecondsSinceEpoch(stopMs, isUtc: true);

    return XtreamEpgListing(
      title: row['title'] as String? ?? 'Program',
      description: row['description'] as String? ?? '',
      start: startUtc.toLocal(),
      end: stopUtc.toLocal(),
      startUnix: startMs ~/ 1000,
      endUnix: stopMs ~/ 1000,
      startRaw: row['start_raw'] as String? ?? '',
      endRaw: row['stop_raw'] as String? ?? '',
    );
  }
}

/// Lightweight parsed programme for batch DB insertion.
class _XmltvParsed {
  _XmltvParsed({
    required this.channel,
    required this.startUtcMs,
    required this.stopUtcMs,
    required this.startRaw,
    required this.stopRaw,
    required this.title,
    required this.desc,
  });

  final String channel;
  final int startUtcMs;
  final int stopUtcMs;
  final String startRaw;
  final String stopRaw;
  final String title;
  final String desc;
}

final xmltvEpgCache = XmltvEpgCache.instance;
