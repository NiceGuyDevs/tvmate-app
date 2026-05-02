import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/live_tv/mock_live_tv_data.dart';
import '../ui/movies/mock_movies_data.dart';
import '../ui/series/mock_series_data.dart';
import 'xtream_stream_urls.dart';

Color xtreamPairColorA(String seed) {
  final h = seed.hashCode & 0xFFFFFF;
  return Color(0xFF000000 | h);
}

Color xtreamPairColorB(String seed) {
  final h = (seed.hashCode * 17) & 0xFFFFFF;
  return Color(0xFF000000 | h);
}

String? _cleanUrl(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  return s;
}

String? _xtreamText(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

Map<String, dynamic>? _asStringKeyedMap(dynamic v) {
  if (v is! Map) return null;
  return Map<String, dynamic>.from(v);
}

/// Plot / synopsis: top-level keys first, then nested `info` object (common on Xtream VOD).
String _vodPlotFromEntry(Map<String, dynamic> e) {
  String pickMap(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final t = _xtreamText(m[k]);
      if (t != null) return t;
    }
    return '';
  }

  var plot = pickMap(e, [
    'plot',
    'description',
    'overview',
    'synopsis',
    'plot_outline',
    'storyline',
  ]);
  if (plot.isNotEmpty) return plot;

  final info = _asStringKeyedMap(e['info']);
  if (info != null) {
    plot = pickMap(info, [
      'plot',
      'description',
      'overview',
      'synopsis',
      'storyline',
      'movie_plot',
    ]);
    if (plot.isNotEmpty) return plot;
  }

  final rawInfo = e['info'];
  if (rawInfo is String) {
    final s = rawInfo.trim();
    if (s.isNotEmpty && !s.startsWith('{')) return s;
  }
  return '';
}

String? _vodCastFromEntry(Map<String, dynamic> e) {
  final top = _xtreamText(e['cast'] ?? e['actors'] ?? e['stars']);
  if (top != null) return top;
  final info = _asStringKeyedMap(e['info']);
  if (info == null) return null;
  return _xtreamText(
    info['cast'] ?? info['actors'] ?? info['stars'] ?? info['cast_members'],
  );
}

String? _vodDirectorFromEntry(Map<String, dynamic> e) {
  final top = _xtreamText(e['director'] ?? e['directors']);
  if (top != null) return top;
  final info = _asStringKeyedMap(e['info']);
  if (info == null) return null;
  return _xtreamText(
    info['director'] ?? info['directors'] ?? info['director_name'],
  );
}

String? _vodRatingFromEntry(Map<String, dynamic> e) {
  final top = _xtreamText(
    e['rating'] ??
        e['rating_5based'] ??
        e['imdb_rating'] ??
        e['rating_imdb'],
  );
  if (top != null) return top;
  final info = _asStringKeyedMap(e['info']);
  if (info == null) return null;
  return _xtreamText(
    info['rating'] ??
        info['rating_5based'] ??
        info['imdb_rating'] ??
        info['rating_imdb'],
  );
}

int _parseYear(dynamic v) {
  if (v == null) return 0;
  final s = v.toString();
  if (s.length >= 4) {
    final y = int.tryParse(s.substring(0, 4));
    if (y != null) return y;
  }
  return int.tryParse(s) ?? 0;
}

String _formatDurationSeconds(dynamic raw) {
  if (raw == null) return '';
  final sec = int.tryParse(raw.toString());
  if (sec == null || sec <= 0) return '';
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m';
}

List<MockLiveCategory> mapXtreamLiveCategories(List<Map<String, dynamic>> raw) {
  final out = <MockLiveCategory>[];
  for (final e in raw) {
    final id = e['category_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final name = e['category_name']?.toString() ?? 'Category';
    out.add(MockLiveCategory(id: id, name: name));
  }
  return out;
}

List<MockLiveChannel> mapXtreamLiveChannels(
  List<Map<String, dynamic>> raw,
  XtreamStreamLinkBuilder links,
) {
  final out = <MockLiveChannel>[];
  for (final e in raw) {
    final id = e['stream_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final cat = e['category_id']?.toString() ?? '';
    final name = e['name']?.toString() ?? 'Channel';
    final icon = e['stream_icon']?.toString();
    final rawEpgCh = e['epg_channel_id']?.toString().trim();
    final epgCh =
        (rawEpgCh != null && rawEpgCh.isNotEmpty) ? rawEpgCh : null;
    final tvArchFlag = int.tryParse(e['tv_archive']?.toString() ?? '');
    final tvArchDur = int.tryParse(e['tv_archive_duration']?.toString() ?? '');
    final hasCatchup = tvArchFlag == 1 || (tvArchDur != null && tvArchDur > 0);
    final prog = hasCatchup ? 0.5 : 0.2;
    out.add(
      MockLiveChannel(
        id: id,
        categoryId: cat,
        name: name,
        programTitle: 'Live',
        description: name,
        progress: prog,
        logoColor: xtreamPairColorA(id),
        streamUrl: links.liveUrl(streamId: id),
        iconUrl: icon?.isEmpty == true ? null : icon,
        epgChannelId: epgCh,
        tvArchive: tvArchFlag,
        tvArchiveDuration: tvArchDur,
      ),
    );
  }
  return out;
}

List<MockMovieCategory> mapXtreamVodCategories(List<Map<String, dynamic>> raw) {
  final out = <MockMovieCategory>[];
  for (final e in raw) {
    final id = e['category_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final name = e['category_name']?.toString() ?? 'Movies';
    out.add(MockMovieCategory(id: id, name: name));
  }
  return out;
}

List<MockMovie> mapXtreamVodStreams(
  List<Map<String, dynamic>> raw,
  XtreamStreamLinkBuilder links,
) {
  final out = <MockMovie>[];
  for (final e in raw) {
    final id = e['stream_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final cat = e['category_id']?.toString() ?? '';
    final title = e['name']?.toString() ?? 'Movie';
    final plot = _vodPlotFromEntry(e);
    final genre = e['genre']?.toString() ?? '';
    final year = _parseYear(e['releasedate'] ?? e['releaseDate']);
    final dur = _formatDurationSeconds(e['duration']);
    final ext = e['container_extension']?.toString() ?? 'mp4';
    final c1 = xtreamPairColorA(id);
    final c2 = xtreamPairColorB(id);
    final icon = _cleanUrl(e['stream_icon']?.toString());
    final movieImage = _cleanUrl(e['movie_image']?.toString());
    final cover = movieImage ?? icon;
    final backdrop = _cleanUrl(e['backdrop_path']?.toString()) ??
        _cleanUrl(e['backdrop']?.toString()) ??
        cover;
    final cast = _vodCastFromEntry(e);
    final director = _vodDirectorFromEntry(e);
    final rating = _vodRatingFromEntry(e);
    out.add(
      MockMovie(
        id: id,
        categoryId: cat,
        title: title,
        year: year,
        genre: genre.isEmpty ? 'VOD' : genre,
        description: plot.isEmpty ? title : plot,
        duration: dur.isEmpty ? '—' : dur,
        posterPrimary: c1,
        posterSecondary: c2,
        backdropPrimary: c1,
        backdropSecondary: c2,
        streamUrl: links.movieUrl(streamId: id, containerExtension: ext),
        coverUrl: cover,
        backdropUrl: backdrop,
        cast: cast,
        director: director,
        rating: rating,
      ),
    );
  }
  return out;
}

List<MockSeriesCategory> mapXtreamSeriesCategories(List<Map<String, dynamic>> raw) {
  final out = <MockSeriesCategory>[];
  for (final e in raw) {
    final id = e['category_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final name = e['category_name']?.toString() ?? 'Series';
    out.add(MockSeriesCategory(id: id, name: name));
  }
  return out;
}

List<MockSeries> mapXtreamSeriesList(
  List<Map<String, dynamic>> raw,
) {
  final out = <MockSeries>[];
  for (final e in raw) {
    final id = e['series_id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final cat = e['category_id']?.toString() ?? '';
    final title = e['name']?.toString() ?? 'Series';
    final plot = e['plot']?.toString() ?? e['info']?.toString() ?? '';
    final genre = e['genre']?.toString() ?? '';
    final year = _parseYear(e['releaseDate'] ?? e['releasedate']);
    final c1 = xtreamPairColorA(id);
    final c2 = xtreamPairColorB(id);
    final cover = _cleanUrl(e['cover']?.toString());
    final backdrop = _cleanUrl(e['backdrop_path']?.toString()) ??
        _cleanUrl(e['backdrop']?.toString()) ??
        cover;
    final castRaw = e['cast']?.toString() ?? '';
    final directorRaw = e['director']?.toString() ?? '';
    final ratingRaw = e['rating']?.toString() ?? e['rating_5based']?.toString() ?? '';
    out.add(
      MockSeries(
        id: id,
        categoryId: cat,
        title: title,
        year: year,
        genre: genre.isEmpty ? 'Series' : genre,
        description: plot.isEmpty ? title : plot,
        posterPrimary: c1,
        posterSecondary: c2,
        backdropPrimary: c1,
        backdropSecondary: c2,
        seasons: const [],
        coverUrl: cover,
        backdropUrl: backdrop,
        cast: castRaw.isNotEmpty ? castRaw : null,
        director: directorRaw.isNotEmpty ? directorRaw : null,
        rating: ratingRaw.isNotEmpty && ratingRaw != '0' ? ratingRaw : null,
      ),
    );
  }
  return out;
}

// ── compute()-compatible wrapper functions ──────────────────────────────
// These are top-level so they can be passed to `compute()` from the
// repository layer. Each accepts a serializable parameter bundle.

class _LiveChannelParams {
  final List<Map<String, dynamic>> raw;
  final String serverUrl;
  final String username;
  final String password;
  _LiveChannelParams(this.raw, this.serverUrl, this.username, this.password);
}

List<MockLiveChannel> _computeLiveChannels(_LiveChannelParams p) {
  final links = XtreamStreamLinkBuilder(
    serverUrl: p.serverUrl,
    username: p.username,
    password: p.password,
  );
  return mapXtreamLiveChannels(p.raw, links);
}

Future<List<MockLiveChannel>> computeLiveChannelsInIsolate(
  List<Map<String, dynamic>> raw, {
  required String serverUrl,
  required String username,
  required String password,
}) {
  return compute(
    _computeLiveChannels,
    _LiveChannelParams(raw, serverUrl, username, password),
  );
}

class _VodStreamsParams {
  final List<Map<String, dynamic>> raw;
  final String serverUrl;
  final String username;
  final String password;
  _VodStreamsParams(this.raw, this.serverUrl, this.username, this.password);
}

List<MockMovie> _computeVodStreams(_VodStreamsParams p) {
  final links = XtreamStreamLinkBuilder(
    serverUrl: p.serverUrl,
    username: p.username,
    password: p.password,
  );
  return mapXtreamVodStreams(p.raw, links);
}

Future<List<MockMovie>> computeVodStreamsInIsolate(
  List<Map<String, dynamic>> raw, {
  required String serverUrl,
  required String username,
  required String password,
}) {
  return compute(
    _computeVodStreams,
    _VodStreamsParams(raw, serverUrl, username, password),
  );
}

List<MockSeries> _computeSeriesList(List<Map<String, dynamic>> raw) {
  return mapXtreamSeriesList(raw);
}

Future<List<MockSeries>> computeSeriesListInIsolate(
  List<Map<String, dynamic>> raw,
) {
  return compute(_computeSeriesList, raw);
}

List<MockSeason> parseXtreamSeriesEpisodes(
  dynamic episodesNode,
  String seriesId,
  XtreamStreamLinkBuilder links,
) {
  if (episodesNode is! Map) return const [];
  final bySeason = <int, List<MockEpisode>>{};
  for (final seasonEntry in episodesNode.entries) {
    final sn = int.tryParse(seasonEntry.key.toString()) ?? 0;
    final list = seasonEntry.value;
    if (list is! List) continue;
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final epId = m['id']?.toString() ?? '';
      if (epId.isEmpty) continue;
      final title = m['title']?.toString() ?? 'Episode';
      final plot = m['info']?.toString() ?? m['plot']?.toString() ?? '';
      final epNum = int.tryParse(m['episode_num']?.toString() ?? '') ?? 0;
      final ext = m['container_extension']?.toString() ?? 'mp4';
      final still = _cleanUrl(
        m['cover']?.toString() ?? m['movie_image']?.toString(),
      );
      final ep = MockEpisode(
        id: epId,
        seriesId: seriesId,
        season: sn,
        episode: epNum,
        title: title,
        description: plot.isEmpty ? title : plot,
        streamUrl: links.seriesEpisodeUrl(
          episodeId: epId,
          containerExtension: ext,
        ),
        stillUrl: still,
      );
      bySeason.putIfAbsent(sn, () => []).add(ep);
    }
  }
  final seasonNums = bySeason.keys.toList()..sort();
  return seasonNums
      .map((n) => MockSeason(number: n, episodes: bySeason[n]!))
      .toList(growable: false);
}

/// Fills seasons from `get_series_info` JSON; merges metadata from `info` map when present.
MockSeries mergeXtreamSeriesDetail(
  MockSeries skeleton,
  Map<String, dynamic> api,
  XtreamStreamLinkBuilder links,
) {
  Map<String, dynamic> meta = {};
  final info = api['info'];
  if (info is Map) {
    meta = Map<String, dynamic>.from(info);
  }
  final title = meta['name']?.toString() ?? skeleton.title;
  final plot = meta['plot']?.toString() ?? meta['description']?.toString();
  final genre = meta['genre']?.toString() ?? skeleton.genre;
  final year = _parseYear(meta['releaseDate'] ?? meta['releasedate'] ?? skeleton.year);
  final desc = (plot != null && plot.isNotEmpty) ? plot : skeleton.description;
  final seasons = parseXtreamSeriesEpisodes(api['episodes'], skeleton.id, links);
  final cov =
      _cleanUrl(meta['cover']?.toString()) ?? skeleton.coverUrl;
  final back = _cleanUrl(meta['backdrop_path']?.toString()) ??
      _cleanUrl(meta['backdrop']?.toString()) ??
      skeleton.backdropUrl ??
      cov;
  final castRaw = meta['cast']?.toString() ?? '';
  final directorRaw = meta['director']?.toString() ?? '';
  final ratingRaw = meta['rating']?.toString() ?? meta['rating_5based']?.toString() ?? '';
  return MockSeries(
    id: skeleton.id,
    categoryId: skeleton.categoryId,
    title: title,
    year: year == 0 ? skeleton.year : year,
    genre: genre.isEmpty ? skeleton.genre : genre,
    description: desc,
    posterPrimary: skeleton.posterPrimary,
    posterSecondary: skeleton.posterSecondary,
    backdropPrimary: skeleton.backdropPrimary,
    backdropSecondary: skeleton.backdropSecondary,
    seasons: seasons.isEmpty ? skeleton.seasons : seasons,
    coverUrl: cov,
    backdropUrl: back,
    cast: castRaw.isNotEmpty ? castRaw : skeleton.cast,
    director: directorRaw.isNotEmpty ? directorRaw : skeleton.director,
    rating: ratingRaw.isNotEmpty && ratingRaw != '0' ? ratingRaw : skeleton.rating,
  );
}
