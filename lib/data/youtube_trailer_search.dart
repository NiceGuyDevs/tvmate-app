import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One video row from [searchTrailerVideos].
class YoutubeTrailerVideo {
  const YoutubeTrailerVideo({
    required this.videoId,
    required this.title,
    this.author,
    this.lengthSeconds,
  });

  final String videoId;
  final String title;
  final String? author;
  final int? lengthSeconds;

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
}

const _kHttpTimeout = Duration(seconds: 28);

/// Browser-like headers so YouTube returns full HTML with `ytInitialData`.
Map<String, String> _htmlHeaders() => {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    };

Map<String, String> _apiHeaders() => {
      'Accept': 'application/json, text/plain, */*',
      'User-Agent': _htmlHeaders()['User-Agent']!,
    };

/// Invidious / Piped fallbacks (often blocked on TVs / ISPs).
const _kInvidiousHosts = <String>[
  'https://vid.puffyan.us',
  'https://inv.nadeko.net',
  'https://inv.tux.pizza',
  'https://yewtu.be',
];

const _kPipedHosts = <String>[
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.in.projectsegfau.lt',
];

/// Searches YouTube: **primary** = parse official search page (`ytInitialData`).
/// Fallbacks = Piped / Invidious. No API key required.
Future<List<YoutubeTrailerVideo>> searchTrailerVideos(String query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];

  final encoded = Uri.encodeQueryComponent(q);
  final client = http.Client();
  try {
    final fromYt = await _searchYoutubeInitialData(client, encoded);
    if (fromYt.isNotEmpty) return fromYt;

    final piped = await _searchPipedAll(client, encoded);
    if (piped.isNotEmpty) return piped;

    final inv = await _searchInvidiousAll(client, encoded);
    if (inv.isNotEmpty) return inv;
  } finally {
    client.close();
  }
  return const [];
}

/// Loads youtube.com/results and extracts all [videoRenderer] entries from JSON.
Future<List<YoutubeTrailerVideo>> _searchYoutubeInitialData(
  http.Client client,
  String encodedQuery,
) async {
  final urls = <Uri>[
    Uri.parse(
      'https://www.youtube.com/results?search_query=$encodedQuery&hl=en&gl=US',
    ),
    Uri.parse(
      'https://m.youtube.com/results?search_query=$encodedQuery&hl=en',
    ),
  ];

  for (final uri in urls) {
    try {
      final res = await client
          .get(uri, headers: _htmlHeaders())
          .timeout(_kHttpTimeout);
      if (res.statusCode != 200) continue;
      final html = res.body;
      final jsonStr = _extractYtInitialDataJson(html);
      if (jsonStr == null) {
        if (kDebugMode) {
          debugPrint('ytInitialData not found (${uri.host})');
        }
        continue;
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(jsonStr);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ytInitialData JSON decode: $e');
        }
        continue;
      }
      final renderers = <Map<String, dynamic>>[];
      _collectVideoRenderers(decoded, renderers);
      final seen = <String>{};
      final out = <YoutubeTrailerVideo>[];
      for (final vr in renderers) {
        final v = _fromVideoRenderer(vr);
        if (v == null) continue;
        if (seen.contains(v.videoId)) continue;
        seen.add(v.videoId);
        out.add(v);
        if (out.length >= 40) break;
      }
      if (out.isNotEmpty) return out;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('YouTube HTML search: $e\n$st');
      }
    }
  }
  return const [];
}

/// Finds `var ytInitialData = {...}` and returns the JSON object text.
String? _extractYtInitialDataJson(String html) {
  const markers = <String>[
    'var ytInitialData = ',
    'ytInitialData = ',
  ];
  for (final m in markers) {
    final i = html.indexOf(m);
    if (i < 0) continue;
    final brace = html.indexOf('{', i + m.length);
    if (brace < 0) continue;
    final extracted = _extractBalancedObject(html, brace);
    if (extracted != null) return extracted;
  }
  return null;
}

/// Starting at [openBraceIndex] (`{`), returns balanced `{...}` respecting strings.
String? _extractBalancedObject(String s, int openBraceIndex) {
  var depth = 0;
  var inString = false;
  var escape = false;
  for (var i = openBraceIndex; i < s.length; i++) {
    final ch = s[i];
    if (escape) {
      escape = false;
      continue;
    }
    if (inString) {
      if (ch == r'\') {
        escape = true;
        continue;
      }
      if (ch == '"') inString = false;
      continue;
    }
    if (ch == '"') {
      inString = true;
      continue;
    }
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return s.substring(openBraceIndex, i + 1);
      }
    }
  }
  return null;
}

void _collectVideoRenderers(dynamic node, List<Map<String, dynamic>> out) {
  if (node is Map) {
    final vr = node['videoRenderer'];
    if (vr is Map<String, dynamic>) {
      out.add(vr);
    } else if (vr is Map) {
      out.add(Map<String, dynamic>.from(vr));
    }
    for (final v in node.values) {
      _collectVideoRenderers(v, out);
    }
  } else if (node is List) {
    for (final e in node) {
      _collectVideoRenderers(e, out);
    }
  }
}

YoutubeTrailerVideo? _fromVideoRenderer(Map<String, dynamic> vr) {
  final id = vr['videoId'] as String?;
  if (id == null || !_looksLikeYoutubeId(id)) return null;

  final title = _textFromRunsMap(vr['title']) ?? 'Video';
  final author = _textFromRunsMap(vr['ownerText']) ??
      _textFromRunsMap(vr['longBylineText']) ??
      _textFromRunsMap(vr['shortBylineText']);
  final len = _lengthSecondsFromRenderer(vr);

  return YoutubeTrailerVideo(
    videoId: id,
    title: title,
    author: author,
    lengthSeconds: len,
  );
}

String? _textFromRunsMap(dynamic n) {
  if (n == null) return null;
  if (n is Map && n['simpleText'] is String) {
    return n['simpleText'] as String;
  }
  if (n is Map && n['runs'] is List) {
    final sb = StringBuffer();
    for (final r in n['runs'] as List) {
      if (r is Map && r['text'] is String) sb.write(r['text']);
    }
    final t = sb.toString().trim();
    return t.isEmpty ? null : t;
  }
  return null;
}

int? _lengthSecondsFromRenderer(Map<String, dynamic> vr) {
  final lt = vr['lengthText'];
  if (lt is! Map) return null;
  final st = lt['simpleText'] as String?;
  if (st == null) return null;
  return _parseDurationLabel(st);
}

/// Parses "1:23:45", "23:45", "45" (seconds-only rare) to seconds.
int? _parseDurationLabel(String raw) {
  final t = raw.replaceAll(RegExp(r'[^\d:]'), '');
  final parts = t.split(':').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final nums = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null) return null;
    nums.add(n);
  }
  if (nums.length == 1) return nums[0];
  if (nums.length == 2) return nums[0] * 60 + nums[1];
  if (nums.length == 3) {
    return nums[0] * 3600 + nums[1] * 60 + nums[2];
  }
  return null;
}

bool _looksLikeYoutubeId(String id) {
  if (id.length != 11) return false;
  return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id);
}

// --- Fallbacks: Piped / Invidious ---

Future<List<YoutubeTrailerVideo>> _searchPipedAll(
  http.Client client,
  String encodedQuery,
) async {
  for (final host in _kPipedHosts) {
    try {
      final uri = Uri.parse('$host/search?q=$encodedQuery&filter=videos');
      final res =
          await client.get(uri, headers: _apiHeaders()).timeout(_kHttpTimeout);
      if (res.statusCode != 200) continue;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) continue;
      final items = decoded['items'] ?? decoded['results'];
      if (items is! List) continue;
      final out = _parsePipedItems(items);
      if (out.isNotEmpty) return out;
    } catch (_) {}
  }
  return const [];
}

List<YoutubeTrailerVideo> _parsePipedItems(List<dynamic> items) {
  final out = <YoutubeTrailerVideo>[];
  for (final e in items) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final url = m['url'] as String?;
    final id = _videoIdFromYoutubeUrl(url);
    if (id == null || !_looksLikeYoutubeId(id)) continue;
    final title = m['title'] as String? ?? 'Video';
    final author = m['uploaderName'] as String? ?? m['uploader'] as String?;
    int? dur;
    final d = m['duration'];
    if (d is int) {
      dur = d;
    } else if (d is num) {
      dur = d.toInt();
    }
    out.add(
      YoutubeTrailerVideo(
        videoId: id,
        title: title,
        author: author,
        lengthSeconds: dur,
      ),
    );
  }
  return out;
}

Future<List<YoutubeTrailerVideo>> _searchInvidiousAll(
  http.Client client,
  String encodedQuery,
) async {
  for (final host in _kInvidiousHosts) {
    for (final path in [
      '$host/api/v1/search?q=$encodedQuery&type=video',
      '$host/api/v1/search?q=$encodedQuery',
    ]) {
      try {
        final res = await client
            .get(Uri.parse(path), headers: _apiHeaders())
            .timeout(_kHttpTimeout);
        if (res.statusCode != 200) continue;
        final decoded = jsonDecode(res.body);
        final list = _invidiousListFromDecoded(decoded);
        if (list == null) continue;
        final out = _parseInvidiousList(list);
        if (out.isNotEmpty) return out;
      } catch (_) {}
    }
  }
  return const [];
}

List<dynamic>? _invidiousListFromDecoded(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map) {
    final m = Map<String, dynamic>.from(decoded);
    final s = m['search'] ?? m['results'] ?? m['items'];
    if (s is List) return s;
  }
  return null;
}

List<YoutubeTrailerVideo> _parseInvidiousList(List<dynamic> list) {
  final out = <YoutubeTrailerVideo>[];
  for (final e in list) {
    if (e is! Map) continue;
    final m = Map<String, dynamic>.from(e);
    final t = m['type'];
    if (t != null && t != 'video') continue;
    final id = (m['videoId'] ?? m['id']) as String?;
    if (id == null || !_looksLikeYoutubeId(id)) continue;
    final title = m['title'] as String? ?? 'Video';
    final author = m['author'] as String?;
    final len = (m['lengthSeconds'] as num?)?.toInt();
    out.add(
      YoutubeTrailerVideo(
        videoId: id,
        title: title,
        author: author,
        lengthSeconds: len,
      ),
    );
  }
  return out;
}

String? _videoIdFromYoutubeUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  var s = url.trim();
  if (!s.startsWith('http')) {
    if (s.startsWith('/')) {
      s = 'https://www.youtube.com$s';
    } else {
      return null;
    }
  }
  final u = Uri.tryParse(s);
  if (u == null) return null;
  final v = u.queryParameters['v'];
  if (v != null && v.isNotEmpty) return v;
  if (u.host.contains('youtu.be') && u.pathSegments.isNotEmpty) {
    return u.pathSegments.first;
  }
  return null;
}
