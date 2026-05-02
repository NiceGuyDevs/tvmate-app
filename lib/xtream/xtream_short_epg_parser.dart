import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One row from Xtream `get_short_epg` / `get_simple_data_table` (field names vary by panel).
class XtreamEpgListing {
  XtreamEpgListing({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    this.startUnix,
    this.endUnix,
    this.startRaw,
    this.endRaw,
    this.nowPlayingHint = false,
  });

  final String title;
  final String description;
  final DateTime? start;
  final DateTime? end;

  /// Raw Unix timestamps (seconds) — used for building catch-up URLs.
  final int? startUnix;
  final int? endUnix;

  /// Raw start/end strings exactly as the server sent them (e.g.
  /// "2026-03-30 14:00:00"). These are in the server's timezone and can be
  /// used directly in `timeshift.php` start parameter without conversion.
  final String? startRaw;
  final String? endRaw;

  /// Server `now_playing` flag (1/true) when start/end are missing or unreliable.
  final bool nowPlayingHint;
}

DateTime? _tsFromUnixSeconds(int sec) {
  final ms = sec >= 1000000000000 ? sec : sec * 1000;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
}

DateTime? _ts(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    final n = v.toInt();
    return _tsFromUnixSeconds(n);
  }
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final asInt = int.tryParse(s);
  if (asInt != null) {
    return _tsFromUnixSeconds(asInt);
  }
  // Xtream servers send date strings in their own timezone (often UTC).
  // Dart's DateTime.tryParse treats strings WITHOUT a timezone marker as
  // device-local, which causes incorrect conversion when the device is in
  // a different timezone. Force UTC interpretation by appending 'Z'.
  var normalized = s;
  if (normalized.contains(' ') && !normalized.contains('T')) {
    normalized = normalized.replaceFirst(' ', 'T');
  }
  if (!normalized.endsWith('Z') &&
      !normalized.contains('+') &&
      !RegExp(r'-\d{2}:\d{2}$').hasMatch(normalized)) {
    normalized = '${normalized}Z';
  }
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    return parsed.toLocal();
  }
  return null;
}

/// Returns the UTC epoch seconds for the value.
/// Numeric values are treated as epoch seconds (or ms).
/// String values are treated as UTC (matching [_ts] behavior).
int? _tsUnix(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    final n = v.toInt();
    return n >= 1000000000000 ? n ~/ 1000 : n;
  }
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final asInt = int.tryParse(s);
  if (asInt != null) {
    return asInt >= 1000000000000 ? asInt ~/ 1000 : asInt;
  }
  var normalized = s;
  if (normalized.contains(' ') && !normalized.contains('T')) {
    normalized = normalized.replaceFirst(' ', 'T');
  }
  if (!normalized.endsWith('Z') &&
      !normalized.contains('+') &&
      !RegExp(r'-\d{2}:\d{2}$').hasMatch(normalized)) {
    normalized = '${normalized}Z';
  }
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    return parsed.millisecondsSinceEpoch ~/ 1000;
  }
  return null;
}

/// Returns the raw timestamp string if it's a date-time string (not a pure number).
/// Returns null if the value is a number or null.
String? _rawTimeString(dynamic v) {
  if (v == null) return null;
  if (v is num) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  if (int.tryParse(s) != null) return null;
  return s;
}

String _decodeMaybeBase64(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final looksB64 =
      t.length >= 12 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(t);
  if (looksB64) {
    try {
      final dec = utf8.decode(base64Decode(t));
      if (dec.trim().isNotEmpty) return dec.trim();
    } catch (_) {}
  }
  return t;
}

String _localizedOrPlain(dynamic v) {
  if (v == null) return '';
  if (v is String) return _decodeMaybeBase64(v);
  if (v is Map) {
    for (final value in v.values) {
      if (value == null) continue;
      final s = value.toString().trim();
      if (s.isNotEmpty) return _decodeMaybeBase64(s);
    }
  }
  return '';
}

String _text(dynamic v) {
  if (v == null) return '';
  return v.toString().trim();
}

bool _truthyNowPlaying(dynamic v) {
  if (v == true) return true;
  if (v == 1 || v == '1') return true;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == 'yes';
}

List<Map<String, dynamic>> _listingMaps(dynamic json) {
  if (json is List) {
    return json
        .map((dynamic e) {
          if (e is! Map) return null;
          return Map<String, dynamic>.from(e);
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }
  if (json is Map) {
    for (final key in const [
      'epg_listings',
      'listings',
      'epg',
      'data',
      'programs',
    ]) {
      final listings = json[key];
      if (listings is List) {
        return listings
            .map((dynamic e) {
              if (e is! Map) return null;
              return Map<String, dynamic>.from(e);
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
  }
  return const [];
}

/// Parses Xtream short/simple EPG JSON into listings.
List<XtreamEpgListing> parseXtreamShortEpgListings(dynamic json) {
  final out = <XtreamEpgListing>[];
  final maps = _listingMaps(json);
  if (maps.isNotEmpty) {
    final sample = maps.first;
    debugPrint('[EPG Parse] first raw item keys: ${sample.keys.toList()}');
    debugPrint('[EPG Parse] first raw item: $sample');
  }
  for (final m in maps) {
    var titleRaw = _localizedOrPlain(
      m['title'] ?? m['name'] ?? m['program_title'] ?? m['programme_title'],
    );
    if (titleRaw.isEmpty) {
      titleRaw = _text(m['t_title']);
    }
    var desc = _localizedOrPlain(
      m['description'] ??
          m['descr'] ??
          m['plot'] ??
          m['overview'] ??
          m['long_description'] ??
          m['text'] ??
          m['sub_description'],
    );
    if (desc.isEmpty) {
      desc = _text(m['t_description']);
    }
    // Xtream APIs often provide BOTH a date-string field (server-local tz)
    // and a separate Unix timestamp field (UTC epoch). We must use the right
    // field for each purpose:
    //  - startRaw / endRaw  → the server-local date string (for timeshift URLs)
    //  - startUnix / endUnix → the UTC epoch (for date filtering & local display)
    //  - start / end         → local DateTime converted from the UTC epoch
    //
    // String-type fields (server-local time):
    final startStrField = m['start'] ?? m['start_time'] ?? m['time_start'] ??
        m['startDate'] ?? m['start_date'];
    final endStrField = m['end'] ?? m['stop'] ?? m['end_time'] ??
        m['time_stop'] ?? m['endDate'] ?? m['end_date'];
    // Numeric / epoch fields (UTC):
    final startEpochField = m['start_timestamp'] ?? m['startTimestamp'];
    final endEpochField = m['stop_timestamp'] ?? m['end_timestamp'] ??
        m['stopTimestamp'] ?? m['endTimestamp'];

    // Prefer the epoch field for Unix timestamps and DateTime objects
    // because it's unambiguous (always UTC). Fall back to the string field.
    final startUnixSource = startEpochField ?? startStrField;
    final endUnixSource = endEpochField ?? endStrField;
    final startUnix = _tsUnix(startUnixSource);
    final endUnix = _tsUnix(endUnixSource);

    // For the local DateTime used in filtering/display, prefer the epoch.
    // _tsFromUnixSeconds does UTC→local correctly.
    DateTime? start;
    DateTime? end;
    if (startUnix != null) {
      start = _tsFromUnixSeconds(startUnix);
    } else {
      start = _ts(startStrField);
    }
    if (endUnix != null) {
      end = _tsFromUnixSeconds(endUnix);
    } else {
      end = _ts(endStrField);
    }

    // The raw string for timeshift URLs must be the server-local string.
    final startRaw = _rawTimeString(startStrField) ??
        _rawTimeString(startEpochField);
    final endRaw = _rawTimeString(endStrField) ??
        _rawTimeString(endEpochField);
    final nowPlayingHint = _truthyNowPlaying(m['now_playing']);
    if (titleRaw.isEmpty &&
        desc.isEmpty &&
        start == null &&
        !nowPlayingHint) {
      continue;
    }
    out.add(
      XtreamEpgListing(
        title: titleRaw.isEmpty ? 'Program' : titleRaw,
        description: desc,
        start: start,
        end: end,
        startUnix: startUnix,
        endUnix: endUnix,
        startRaw: startRaw,
        endRaw: endRaw,
        nowPlayingHint: nowPlayingHint,
      ),
    );
  }
  return out;
}

/// Picks the listing that is on-air now; otherwise the next starting soon.
XtreamEpgListing? pickCurrentOrNextXtreamListing(List<XtreamEpgListing> items) {
  if (items.isEmpty) return null;
  final now = DateTime.now();

  XtreamEpgListing? hinted;
  for (final e in items) {
    if (e.nowPlayingHint) {
      if (listingIsOnAirNow(e)) return e;
      hinted ??= e;
    }
  }
  if (hinted != null) return hinted;

  XtreamEpgListing? current;
  for (final e in items) {
    final s = e.start;
    final en = e.end;
    if (s != null && en != null) {
      if (!now.isBefore(s) && now.isBefore(en)) {
        current = e;
        break;
      }
    }
  }
  if (current != null) return current;

  XtreamEpgListing? next;
  DateTime? nextStart;
  for (final e in items) {
    final s = e.start;
    if (s == null || !s.isAfter(now)) continue;
    if (nextStart == null || s.isBefore(nextStart)) {
      nextStart = s;
      next = e;
    }
  }
  return next;
}

double progress01ForListing(XtreamEpgListing e) {
  if (e.nowPlayingHint && (e.start == null || e.end == null)) {
    return 0.35;
  }
  final s = e.start;
  final en = e.end;
  if (s == null || en == null) return 0;
  final total = en.difference(s).inMilliseconds;
  if (total <= 0) return 0;
  final now = DateTime.now();
  final t = now.difference(s).inMilliseconds;
  return (t / total).clamp(0.0, 1.0);
}

bool listingIsOnAirNow(XtreamEpgListing e) {
  if (e.nowPlayingHint) {
    final s = e.start;
    final en = e.end;
    if (s != null && en != null) {
      final now = DateTime.now();
      return !now.isBefore(s) && now.isBefore(en);
    }
    return true;
  }
  final s = e.start;
  final en = e.end;
  if (s == null || en == null) return false;
  final now = DateTime.now();
  return !now.isBefore(s) && now.isBefore(en);
}

/// Full EPG overlay: only the on-air programme and programmes that have not ended yet
/// (no scrolling through past slots).
List<XtreamEpgListing> filterEpgListingsFromNow(List<XtreamEpgListing> items) {
  final now = DateTime.now();
  return items.where((e) {
    if (listingIsOnAirNow(e)) return true;
    final en = e.end;
    if (en != null && en.isBefore(now)) return false;
    return true;
  }).toList();
}

String? formatEpgTimeRange(XtreamEpgListing e) {
  final s = e.start;
  final en = e.end;
  if (s == null || en == null) return null;
  String fmt(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  return '${fmt(s)} – ${fmt(en)}';
}
