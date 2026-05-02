import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal OpenSubtitles.com REST client (search + download).
/// See https://www.opensubtitles.com/en/consumers — register for an API key.
class OpenSubtitlesClient {
  OpenSubtitlesClient({
    http.Client? httpClient,
    this.userAgent = 'TVMatePro/1.0',
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String userAgent;

  static const _base = 'https://api.opensubtitles.com/api/v1';

  Map<String, String> _headers(String apiKey) => {
        'Api-Key': apiKey,
        'User-Agent': userAgent,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// Search subtitles; results grouped by language, [preferredLanguage] first.
  Future<List<OpenSubtitlesLanguageGroup>> searchSubtitles({
    required String apiKey,
    required String query,
    String preferredLanguage = 'en',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final uri = Uri.parse('$_base/subtitles').replace(
      queryParameters: {'query': q},
    );
    final res = await _http.get(uri, headers: _headers(apiKey));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw OpenSubtitlesException('Invalid API key or access denied.');
    }
    if (res.statusCode != 200) {
      throw OpenSubtitlesException(
        'Search failed (${res.statusCode}).',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OpenSubtitlesException('Bad search response.');
    }
    final data = decoded['data'];
    if (data is! List) return [];

    final byLang = <String, List<OpenSubtitlesFileEntry>>{};
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final attrs = item['attributes'];
      if (attrs is! Map<String, dynamic>) continue;
      final lang = (attrs['language'] as String? ?? 'und').toLowerCase();
      final files = attrs['files'];
      if (files is! List) continue;
      final release = attrs['release'] as String? ??
          attrs['feature_details']?.toString() ??
          '';
      for (final f in files) {
        if (f is! Map<String, dynamic>) continue;
        final id = f['file_id'];
        final fileId = id == null ? '' : id.toString();
        if (fileId.isEmpty) continue;
        final name = f['file_name'] as String? ?? 'subtitle.srt';
        byLang.putIfAbsent(lang, () => []).add(
              OpenSubtitlesFileEntry(
                fileId: fileId,
                fileName: name,
                release: release,
              ),
            );
      }
    }

    final pref = preferredLanguage.trim().toLowerCase();
    final keys = byLang.keys.toList()
      ..sort((a, b) {
        if (a == pref) return -1;
        if (b == pref) return 1;
        return a.compareTo(b);
      });

    return [
      for (final k in keys)
        OpenSubtitlesLanguageGroup(
          languageCode: k,
          files: byLang[k]!,
        ),
    ];
  }

  /// Union of one or more [searchSubtitles] result lists: same language key merges
  /// [files] (deduplicated by [fileId], last write wins for metadata).
  /// [preferredLanguage] is sorted first, then the rest A–Z.
  static List<OpenSubtitlesLanguageGroup> mergeAndSortLanguageGroups(
    List<List<OpenSubtitlesLanguageGroup>> parts, {
    required String preferredLanguage,
  }) {
    final byLang = <String, Map<String, OpenSubtitlesFileEntry>>{};
    for (final part in parts) {
      for (final g in part) {
        final lang = g.languageCode.toLowerCase();
        final m = byLang.putIfAbsent(lang, () => {});
        for (final f in g.files) {
          m[f.fileId] = f;
        }
      }
    }
    final pref = preferredLanguage.trim().toLowerCase();
    final keys = byLang.keys.toList()
      ..sort((a, b) {
        if (a == pref) return -1;
        if (b == pref) return 1;
        return a.compareTo(b);
      });
    return [
      for (final k in keys)
        OpenSubtitlesLanguageGroup(
          languageCode: k,
          files: (byLang[k]!.values.toList()
            ..sort(
              (a, b) => a.fileName
                  .toLowerCase()
                  .compareTo(b.fileName.toLowerCase()),
            )),
        ),
    ];
  }

  /// Distinct title-like labels from a search response, for under-field autocomplete.
  /// Uses the same endpoint as [searchSubtitles] with a short query.
  Future<List<String>> fetchSearchQueryHints({
    required String apiKey,
    required String query,
    int limit = 8,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final uri = Uri.parse('$_base/subtitles').replace(
      queryParameters: {'query': q},
    );
    final res = await _http.get(uri, headers: _headers(apiKey));
    if (res.statusCode == 401 || res.statusCode == 403) {
      return [];
    }
    if (res.statusCode != 200) {
      return [];
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      return [];
    }
    final data = decoded['data'];
    if (data is! List) {
      return [];
    }
    final seen = <String>{};
    final out = <String>[];
    for (final item in data) {
      if (out.length >= limit) break;
      if (item is! Map<String, dynamic>) continue;
      final attrs = item['attributes'];
      if (attrs is! Map<String, dynamic>) continue;
      String? label;
      final feat = attrs['feature_details'];
      if (feat is Map<String, dynamic>) {
        final t = feat['title'] ?? feat['movie_name'] ?? feat['name'];
        if (t is String) {
          label = t.trim();
        } else if (t != null) {
          final s = t.toString().trim();
          if (s.isNotEmpty) label = s;
        }
      } else if (feat is String) {
        final s = feat.trim();
        if (s.isNotEmpty) label = s;
      }
      label ??= (attrs['release'] as String?)?.trim();
      if (label == null || label.isEmpty) continue;
      final keyL = label.toLowerCase();
      if (seen.contains(keyL)) continue;
      seen.add(keyL);
      out.add(label);
    }
    return out;
  }

  Future<List<int>> downloadBytes({
    required String apiKey,
    required String fileId,
  }) async {
    final uri = Uri.parse('$_base/download');
    final res = await _http.post(
      uri,
      headers: _headers(apiKey),
      body: jsonEncode({'file_id': fileId}),
    );
    if (res.statusCode != 200) {
      throw OpenSubtitlesException(
        'Download request failed (${res.statusCode}).',
      );
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OpenSubtitlesException('Bad download response.');
    }
    final link = decoded['link'] as String?;
    if (link == null || link.isEmpty) {
      throw const OpenSubtitlesException('No download link in response.');
    }
    final bin = await _http.get(
      Uri.parse(link),
      headers: {'User-Agent': userAgent},
    );
    if (bin.statusCode != 200) {
      throw OpenSubtitlesException(
        'File fetch failed (${bin.statusCode}).',
      );
    }
    return bin.bodyBytes;
  }
}

class OpenSubtitlesLanguageGroup {
  const OpenSubtitlesLanguageGroup({
    required this.languageCode,
    required this.files,
  });

  final String languageCode;
  final List<OpenSubtitlesFileEntry> files;
}

class OpenSubtitlesFileEntry {
  const OpenSubtitlesFileEntry({
    required this.fileId,
    required this.fileName,
    this.release,
  });

  final String fileId;
  final String fileName;
  final String? release;
}

class OpenSubtitlesException implements Exception {
  const OpenSubtitlesException(this.message);
  final String message;
  @override
  String toString() => message;
}
