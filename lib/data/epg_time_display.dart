import 'package:timezone/timezone.dart' as tz;

import '../xtream/xtream_short_epg_parser.dart' show XtreamEpgListing, formatEpgTimeRange;
import 'playlist_epg_timezone_store.dart';

/// Server/original: HH:MM from raw strings when possible.
String? formatEpgTimeRangeOriginal(XtreamEpgListing e) {
  final a = _extractHourMinute(e.startRaw);
  final b = _extractHourMinute(e.endRaw);
  if (a != null && b != null) return '$a – $b';
  return formatEpgTimeRange(e);
}

/// Convert instant to a named zone for display.
String? formatEpgTimeRangeInZone(XtreamEpgListing e, String ianaId) {
  tz.Location loc;
  try {
    loc = tz.getLocation(ianaId);
  } catch (_) {
    return formatEpgTimeRange(e);
  }
  final su = e.startUnix;
  final eu = e.endUnix;
  if (su != null && su > 0 && eu != null && eu > 0) {
    final utcS = DateTime.fromMillisecondsSinceEpoch(su * 1000, isUtc: true);
    final utcE = DateTime.fromMillisecondsSinceEpoch(eu * 1000, isUtc: true);
    final zs = tz.TZDateTime.from(utcS, loc);
    final ze = tz.TZDateTime.from(utcE, loc);
    return '${_fmtHm(zs)} – ${_fmtHm(ze)}';
  }
  final s = e.start;
  final en = e.end;
  if (s != null && en != null) {
    final utcS = s.toUtc();
    final utcE = en.toUtc();
    final zs = tz.TZDateTime.from(utcS, loc);
    final ze = tz.TZDateTime.from(utcE, loc);
    return '${_fmtHm(zs)} – ${_fmtHm(ze)}';
  }
  return formatEpgTimeRange(e);
}

String _fmtHm(tz.TZDateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String? _extractHourMinute(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.trim();
  final spaceIdx = s.indexOf(' ');
  final tIdx = s.indexOf('T');
  final sep = spaceIdx >= 0 ? spaceIdx : tIdx;
  if (sep < 0 || sep + 6 > s.length) return null;
  final timePart = s.substring(sep + 1);
  final parts = timePart.split(':');
  if (parts.length < 2) return null;
  final h = parts[0].padLeft(2, '0');
  final m = parts[1].padLeft(2, '0');
  return '$h:$m';
}

/// Programme start/end for UI (recording list) for one playlist EPG mode.
String formatEpgProgramTime(
  DateTime? localDt,
  String? rawStr,
  int? unixSec,
  String playlistId,
) {
  final mode = playlistEpgTimezoneStore.epgDisplayMode(playlistId);
  if (mode == kEpgDisplayModeLocal || mode.isEmpty) {
    if (localDt == null) return '--:--';
    return _fmtDtHm(localDt);
  }
  if (mode == kEpgDisplayModeOriginal) {
    if (rawStr != null && rawStr.isNotEmpty) {
      final t = _extractHourMinute(rawStr);
      if (t != null) return t;
    }
    if (localDt == null) return '--:--';
    return _fmtDtHm(localDt);
  }
  tz.Location loc;
  try {
    loc = tz.getLocation(mode);
  } catch (_) {
    if (localDt == null) return '--:--';
    return _fmtDtHm(localDt);
  }
  if (unixSec != null && unixSec > 0) {
    final utc = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000, isUtc: true);
    final z = tz.TZDateTime.from(utc, loc);
    return _fmtHm(z);
  }
  if (localDt == null) return '--:--';
  final z = tz.TZDateTime.from(localDt.toUtc(), loc);
  return _fmtHm(z);
}

String _fmtDtHm(DateTime d) {
  return '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

/// Legacy Android / fallback: device-local HH:mm for programme bounds.
String playerTvFormatClockLocal(DateTime? d) {
  if (d == null) return '—';
  return _fmtDtHm(d);
}

/// Start and end clock labels for fullscreen live timeline strip / chrome.
/// Uses [formatEpgProgramTime] when [playlistId] is set; otherwise local HH:mm.
(String, String) formatEpgProgramStartEndLabels(
  XtreamEpgListing listing,
  String? playlistId,
) {
  final s = listing.start;
  final en = listing.end;
  final su = listing.startUnix;
  final eu = listing.endUnix;
  if (playlistId == null || playlistId.isEmpty) {
    return (playerTvFormatClockLocal(s), playerTvFormatClockLocal(en));
  }
  return (
    formatEpgProgramTime(s, listing.startRaw, su, playlistId),
    formatEpgProgramTime(en, listing.endRaw, eu, playlistId),
  );
}

/// Progress through the current listing window (0…1) for live timeline bars.
double liveListingProgress01(XtreamEpgListing listing) {
  final s = listing.start;
  final en = listing.end;
  if (s == null || en == null) return 0;
  final now = DateTime.now();
  if (now.isBefore(s)) return 0;
  if (!now.isBefore(en)) return 1;
  final total = en.difference(s).inMilliseconds;
  if (total <= 0) return 0;
  return (now.difference(s).inMilliseconds / total).clamp(0.0, 1.0);
}

/// Range string for overlays / hero (uses active playlist EPG mode).
String? formatEpgTimeRangeForPlaylist(
  XtreamEpgListing e,
  String? playlistId,
) {
  if (playlistId == null || playlistId.isEmpty) {
    return formatEpgTimeRange(e);
  }
  final mode = playlistEpgTimezoneStore.epgDisplayMode(playlistId);
  if (mode == kEpgDisplayModeLocal || mode.isEmpty) {
    return formatEpgTimeRange(e);
  }
  if (mode == kEpgDisplayModeOriginal) {
    return formatEpgTimeRangeOriginal(e);
  }
  return formatEpgTimeRangeInZone(e, mode);
}
