import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resolves a direct playback URL for YouTube [videoId] for in-app ExoPlayer.
/// Tries **Piped** first, then **Invidious** video API — stays in-app (no YouTube app).
Future<String?> resolveTrailerPlaybackUrl(String videoId) async {
  if (videoId.length != 11) return null;

  final piped = await _resolvePiped(videoId);
  if (piped != null && piped.isNotEmpty) return piped;

  final inv = await _resolveInvidious(videoId);
  if (inv != null && inv.isNotEmpty) return inv;

  return null;
}

/// @nodoc — kept for tests / direct piped debugging.
Future<String?> resolvePipedTrailerStreamUrl(String videoId) =>
    _resolvePiped(videoId);

Future<String?> _resolvePiped(String videoId) async {
  final client = http.Client();
  try {
    for (final host in _kPipedHosts) {
      try {
        final uri = Uri.parse('$host/streams/$videoId');
        final res = await client
            .get(uri, headers: _jsonHeaders)
            .timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) continue;

        final dynamic decoded = jsonDecode(res.body);
        if (decoded is! Map) continue;
        final m = Map<String, dynamic>.from(decoded);

        final hls = m['hls'] as String?;
        if (hls != null && hls.isNotEmpty) return hls;

        final dash = m['dash'] as String?;
        if (dash != null && dash.isNotEmpty) return dash;

        final url = _pickBestVideoStreamUrl(m['videoStreams']);
        if (url != null) return url;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Piped streams $host: $e\n$st');
        }
      }
    }
  } finally {
    client.close();
  }
  return null;
}

Future<String?> _resolveInvidious(String videoId) async {
  final client = http.Client();
  try {
    for (final host in _kInvidiousHosts) {
      try {
        final uri = Uri.parse('$host/api/v1/videos/$videoId');
        final res = await client
            .get(uri, headers: _jsonHeaders)
            .timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) continue;

        final dynamic decoded = jsonDecode(res.body);
        if (decoded is! Map) continue;
        final m = Map<String, dynamic>.from(decoded);

        final progressive = _pickInvidiousFormatStream(m['formatStreams']);
        if (progressive != null) return progressive;

        final adaptive = _pickInvidiousAdaptiveVideo(m['adaptiveFormats']);
        if (adaptive != null) return adaptive;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Invidious videos $host: $e\n$st');
        }
      }
    }
  } finally {
    client.close();
  }
  return null;
}

String? _pickInvidiousFormatStream(dynamic formatStreams) {
  if (formatStreams is! List || formatStreams.isEmpty) return null;
  final urls = <String>[];
  for (final e in formatStreams) {
    if (e is! Map) continue;
    final u = e['url'] as String?;
    if (u != null && u.isNotEmpty) urls.add(u);
  }
  if (urls.isEmpty) return null;
  return urls.last;
}

String? _pickInvidiousAdaptiveVideo(dynamic adaptiveFormats) {
  if (adaptiveFormats is! List || adaptiveFormats.isEmpty) return null;
  final candidates = <Map<String, dynamic>>[];
  for (final e in adaptiveFormats) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final type = (m['type'] as String?) ?? '';
    final url = m['url'] as String?;
    if (url == null || url.isEmpty) continue;
    if (!type.contains('video')) continue;
    if (type.contains('audio')) continue;
    candidates.add(m);
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final ba = int.tryParse('${a['bitrate']}') ?? 0;
    final bb = int.tryParse('${b['bitrate']}') ?? 0;
    return bb.compareTo(ba);
  });
  return candidates.first['url'] as String?;
}

const _kPipedHosts = <String>[
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.in.projectsegfau.lt',
  'https://pipedapi.syncpundit.com',
  'https://api.piped.projectsegfau.lt',
];

const _kInvidiousHosts = <String>[
  'https://vid.puffyan.us',
  'https://inv.nadeko.net',
  'https://inv.tux.pizza',
  'https://yewtu.be',
  'https://invidious.protokolla.fi',
];

Map<String, String> get _jsonHeaders => const {
      'Accept': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    };

String? _pickBestVideoStreamUrl(dynamic videoStreams) {
  if (videoStreams is! List || videoStreams.isEmpty) return null;

  var candidates = _videoStreamMapsPreferringVideo(videoStreams);
  if (candidates.isEmpty) {
    candidates = _videoStreamMapsAny(videoStreams);
  }
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final ba = (a['bitrate'] as num?)?.toInt() ?? 0;
    final bb = (b['bitrate'] as num?)?.toInt() ?? 0;
    return bb.compareTo(ba);
  });

  return candidates.first['url'] as String?;
}

List<Map<String, dynamic>> _videoStreamMapsPreferringVideo(
    List<dynamic> videoStreams) {
  final out = <Map<String, dynamic>>[];
  for (final e in videoStreams) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final url = m['url'] as String?;
    if (url == null || url.isEmpty) continue;
    final mime = (m['mimeType'] as String?) ?? '';
    if (mime.isNotEmpty && !mime.contains('video')) continue;
    out.add(m);
  }
  return out;
}

List<Map<String, dynamic>> _videoStreamMapsAny(List<dynamic> videoStreams) {
  final out = <Map<String, dynamic>>[];
  for (final e in videoStreams) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final url = m['url'] as String?;
    if (url != null && url.isNotEmpty) out.add(m);
  }
  return out;
}
