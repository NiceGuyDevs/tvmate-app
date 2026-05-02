import 'package:flutter/foundation.dart';

import 'xtream_url.dart';

/// Builds standard Xtream-style stream URLs (live / movie / series).
@immutable
class XtreamStreamLinkBuilder {
  XtreamStreamLinkBuilder({
    required String serverUrl,
    required this.username,
    required this.password,
  }) : rootUri = xtreamStreamRootUri(serverUrl);

  final Uri rootUri;
  final String username;
  final String password;

  String get _root {
    var p = rootUri.path;
    if (p.endsWith('/')) p = p.substring(0, p.length - 1);
    return '${rootUri.origin}$p';
  }

  String _segment(String s) => Uri.encodeComponent(s);

  /// Typical live URL: `{root}/live/{user}/{pass}/{streamId}.ts`
  String liveUrl({
    required String streamId,
    String extension = 'ts',
  }) {
    final u = _segment(username);
    final p = _segment(password);
    final ext = extension.replaceAll('.', '');
    return '$_root/live/$u/$p/$streamId.$ext';
  }

  /// VOD URL: `{root}/movie/{user}/{pass}/{streamId}.{ext}`
  String movieUrl({
    required String streamId,
    required String containerExtension,
  }) {
    var ext = containerExtension.trim().replaceAll('.', '');
    if (ext.isEmpty) ext = 'mp4';
    final u = _segment(username);
    final p = _segment(password);
    return '$_root/movie/$u/$p/$streamId.$ext';
  }

  /// Series episode URL: `{root}/series/{user}/{pass}/{episodeId}.{ext}`
  String seriesEpisodeUrl({
    required String episodeId,
    required String containerExtension,
  }) {
    var ext = containerExtension.trim().replaceAll('.', '');
    if (ext.isEmpty) ext = 'mp4';
    final u = _segment(username);
    final p = _segment(password);
    return '$_root/series/$u/$p/$episodeId.$ext';
  }

  /// Builds the standard Xtream catch-up URL using `timeshift.php`.
  ///
  /// The `start` parameter MUST be in the server's local timezone.
  /// [durationMin] — program duration in minutes (computed by caller from
  /// reliable DateTime objects, not from potentially broken Unix timestamps).
  String catchupUrlWithDuration({
    required String streamId,
    String? startRaw,
    required int startUnix,
    required int durationMin,
    double serverUtcOffsetHours = 0,
  }) {
    final String dateFmt;
    if (startRaw != null && startRaw.isNotEmpty) {
      dateFmt = _rawToTimeshiftStart(startRaw);
    } else {
      final serverOffsetMs = (serverUtcOffsetHours * 3600 * 1000).round();
      final serverLocal = DateTime.fromMillisecondsSinceEpoch(
        startUnix * 1000 + serverOffsetMs,
        isUtc: true,
      );
      dateFmt =
          '${serverLocal.year}-'
          '${serverLocal.month.toString().padLeft(2, '0')}-'
          '${serverLocal.day.toString().padLeft(2, '0')}:'
          '${serverLocal.hour.toString().padLeft(2, '0')}-'
          '${serverLocal.minute.toString().padLeft(2, '0')}';
    }

    return '${rootUri.origin}/streaming/timeshift.php'
        '?username=${_segment(username)}'
        '&password=${_segment(password)}'
        '&stream=$streamId'
        '&start=$dateFmt'
        '&duration=$durationMin';
  }

  /// Converts a raw EPG date-time string to the `start` parameter format
  /// required by `timeshift.php`: `YYYY-MM-DD:HH-MM`.
  ///
  /// Handles various input formats:
  ///   "2026-03-30 14:00:00" → "2026-03-30:14-00"
  ///   "2026-03-30T14:00:00" → "2026-03-30:14-00"
  ///   "2026-03-30T14:00:00.000Z" → "2026-03-30:14-00"
  static String _rawToTimeshiftStart(String raw) {
    var s = raw.trim();
    s = s.replaceAll('T', ' ');
    // Drop fractional seconds and Z suffix
    final dotIdx = s.indexOf('.');
    if (dotIdx > 0) s = s.substring(0, dotIdx);
    if (s.endsWith('Z') || s.endsWith('z')) s = s.substring(0, s.length - 1);

    // Now expecting "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD HH:MM"
    final parts = s.split(' ');
    if (parts.length < 2) return s; // fallback
    final datePart = parts[0]; // "YYYY-MM-DD"
    final timeParts = parts[1].split(':');
    final hour = timeParts.isNotEmpty ? timeParts[0].padLeft(2, '0') : '00';
    final minute = timeParts.length > 1 ? timeParts[1].padLeft(2, '0') : '00';
    return '$datePart:$hour-$minute';
  }
}
