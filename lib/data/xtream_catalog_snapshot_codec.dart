import 'dart:convert';

import 'package:flutter/material.dart';

import '../ui/live_tv/mock_live_tv_data.dart';
import '../ui/movies/mock_movies_data.dart';
import '../ui/series/mock_series_data.dart';

/// Bump when JSON shape changes (DB rows with old [payloadVersion] are ignored).
const int kXtreamCatalogPayloadVersion = 2;

int _colorToArgb(Color c) {
  final a = (c.a * 255.0).round().clamp(0, 255);
  final r = (c.r * 255.0).round().clamp(0, 255);
  final g = (c.g * 255.0).round().clamp(0, 255);
  final b = (c.b * 255.0).round().clamp(0, 255);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

Color _colorFromArgb(int v) => Color(v);

Map<String, dynamic> _catLive(MockLiveCategory c) => {'id': c.id, 'name': c.name};

MockLiveCategory _catLiveFrom(Map<String, dynamic> m) => MockLiveCategory(
      id: m['id'] as String,
      name: m['name'] as String,
    );

Map<String, dynamic> _chLive(MockLiveChannel c) => {
      'id': c.id,
      'categoryId': c.categoryId,
      'name': c.name,
      'programTitle': c.programTitle,
      'description': c.description,
      'progress': c.progress,
      'logoArgb': _colorToArgb(c.logoColor),
      'streamUrl': c.streamUrl,
      'iconUrl': c.iconUrl,
      'epgChannelId': c.epgChannelId,
      'tvArchive': c.tvArchive,
      'tvArchiveDuration': c.tvArchiveDuration,
    };

MockLiveChannel _chLiveFrom(Map<String, dynamic> m) => MockLiveChannel(
      id: m['id'] as String,
      categoryId: m['categoryId'] as String,
      name: m['name'] as String,
      programTitle: m['programTitle'] as String? ?? '',
      description: m['description'] as String? ?? '',
      progress: (m['progress'] as num?)?.toDouble() ?? 0,
      logoColor: _colorFromArgb((m['logoArgb'] as num).toInt()),
      streamUrl: m['streamUrl'] as String?,
      iconUrl: m['iconUrl'] as String?,
      epgChannelId: m['epgChannelId'] as String?,
      tvArchive: (m['tvArchive'] as num?)?.toInt(),
      tvArchiveDuration: (m['tvArchiveDuration'] as num?)?.toInt(),
    );

Map<String, dynamic> _catMovie(MockMovieCategory c) =>
    {'id': c.id, 'name': c.name};

MockMovieCategory _catMovieFrom(Map<String, dynamic> m) => MockMovieCategory(
      id: m['id'] as String,
      name: m['name'] as String,
    );

Map<String, dynamic> _movie(MockMovie c) => {
      'id': c.id,
      'categoryId': c.categoryId,
      'title': c.title,
      'year': c.year,
      'genre': c.genre,
      'description': c.description,
      'duration': c.duration,
      'posterA': _colorToArgb(c.posterPrimary),
      'posterB': _colorToArgb(c.posterSecondary),
      'backdropA': _colorToArgb(c.backdropPrimary),
      'backdropB': _colorToArgb(c.backdropSecondary),
      'streamUrl': c.streamUrl,
      'coverUrl': c.coverUrl,
      'backdropUrl': c.backdropUrl,
      'cast': c.cast,
      'director': c.director,
      'rating': c.rating,
    };

MockMovie _movieFrom(Map<String, dynamic> m) => MockMovie(
      id: m['id'] as String,
      categoryId: m['categoryId'] as String,
      title: m['title'] as String,
      year: (m['year'] as num?)?.toInt() ?? 0,
      genre: m['genre'] as String? ?? '',
      description: m['description'] as String? ?? '',
      duration: m['duration'] as String? ?? '',
      posterPrimary: _colorFromArgb((m['posterA'] as num).toInt()),
      posterSecondary: _colorFromArgb((m['posterB'] as num).toInt()),
      backdropPrimary: _colorFromArgb((m['backdropA'] as num).toInt()),
      backdropSecondary: _colorFromArgb((m['backdropB'] as num).toInt()),
      streamUrl: m['streamUrl'] as String?,
      coverUrl: m['coverUrl'] as String?,
      backdropUrl: m['backdropUrl'] as String?,
      cast: m['cast'] as String?,
      director: m['director'] as String?,
      rating: m['rating'] as String?,
    );

Map<String, dynamic> _catSeries(MockSeriesCategory c) =>
    {'id': c.id, 'name': c.name};

MockSeriesCategory _catSeriesFrom(Map<String, dynamic> m) =>
    MockSeriesCategory(
      id: m['id'] as String,
      name: m['name'] as String,
    );

Map<String, dynamic> _episode(MockEpisode e) => {
      'id': e.id,
      'seriesId': e.seriesId,
      'season': e.season,
      'episode': e.episode,
      'title': e.title,
      'description': e.description,
      'streamUrl': e.streamUrl,
      'stillUrl': e.stillUrl,
    };

MockEpisode _episodeFrom(Map<String, dynamic> m) => MockEpisode(
      id: m['id'] as String,
      seriesId: m['seriesId'] as String,
      season: (m['season'] as num).toInt(),
      episode: (m['episode'] as num).toInt(),
      title: m['title'] as String,
      description: m['description'] as String? ?? '',
      streamUrl: m['streamUrl'] as String?,
      stillUrl: m['stillUrl'] as String?,
    );

Map<String, dynamic> _season(MockSeason s) => {
      'number': s.number,
      'episodes': s.episodes.map(_episode).toList(),
    };

MockSeason _seasonFrom(Map<String, dynamic> m) => MockSeason(
      number: (m['number'] as num).toInt(),
      episodes: (m['episodes'] as List<dynamic>)
          .map((e) => _episodeFrom(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _series(MockSeries s) => {
      'id': s.id,
      'categoryId': s.categoryId,
      'title': s.title,
      'year': s.year,
      'genre': s.genre,
      'description': s.description,
      'posterA': _colorToArgb(s.posterPrimary),
      'posterB': _colorToArgb(s.posterSecondary),
      'backdropA': _colorToArgb(s.backdropPrimary),
      'backdropB': _colorToArgb(s.backdropSecondary),
      'seasons': s.seasons.map(_season).toList(),
      'coverUrl': s.coverUrl,
      'backdropUrl': s.backdropUrl,
      'cast': s.cast,
      'director': s.director,
      'rating': s.rating,
    };

MockSeries _seriesFrom(Map<String, dynamic> m) => MockSeries(
      id: m['id'] as String,
      categoryId: m['categoryId'] as String,
      title: m['title'] as String,
      year: (m['year'] as num?)?.toInt() ?? 0,
      genre: m['genre'] as String? ?? '',
      description: m['description'] as String? ?? '',
      posterPrimary: _colorFromArgb((m['posterA'] as num).toInt()),
      posterSecondary: _colorFromArgb((m['posterB'] as num).toInt()),
      backdropPrimary: _colorFromArgb((m['backdropA'] as num).toInt()),
      backdropSecondary: _colorFromArgb((m['backdropB'] as num).toInt()),
      seasons: (m['seasons'] as List<dynamic>)
          .map((e) => _seasonFrom(e as Map<String, dynamic>))
          .toList(),
      coverUrl: m['coverUrl'] as String?,
      backdropUrl: m['backdropUrl'] as String?,
      cast: m['cast'] as String?,
      director: m['director'] as String?,
      rating: m['rating'] as String?,
    );

/// Full Xtream browse snapshot (live + VOD + series lists).
class XtreamCatalogSnapshot {
  const XtreamCatalogSnapshot({
    required this.liveCategories,
    required this.liveChannelsAll,
    required this.vodCategories,
    required this.vodMoviesAll,
    required this.seriesCategories,
    required this.seriesAll,
  });

  final List<MockLiveCategory> liveCategories;
  final List<MockLiveChannel> liveChannelsAll;
  final List<MockMovieCategory> vodCategories;
  final List<MockMovie> vodMoviesAll;
  final List<MockSeriesCategory> seriesCategories;
  final List<MockSeries> seriesAll;

  Map<String, dynamic> toJson() => {
        'v': kXtreamCatalogPayloadVersion,
        'liveCategories': liveCategories.map(_catLive).toList(),
        'liveChannelsAll': liveChannelsAll.map(_chLive).toList(),
        'vodCategories': vodCategories.map(_catMovie).toList(),
        'vodMoviesAll': vodMoviesAll.map(_movie).toList(),
        'seriesCategories': seriesCategories.map(_catSeries).toList(),
        'seriesAll': seriesAll.map(_series).toList(),
      };

  static XtreamCatalogSnapshot? fromJson(Map<String, dynamic> m) {
    final ver = m['v'];
    if (ver is! num || ver.toInt() < 1 || ver.toInt() > kXtreamCatalogPayloadVersion) {
      return null;
    }
    try {
      return XtreamCatalogSnapshot(
        liveCategories: (m['liveCategories'] as List<dynamic>)
            .map((e) => _catLiveFrom(e as Map<String, dynamic>))
            .toList(),
        liveChannelsAll: (m['liveChannelsAll'] as List<dynamic>)
            .map((e) => _chLiveFrom(e as Map<String, dynamic>))
            .toList(),
        vodCategories: (m['vodCategories'] as List<dynamic>)
            .map((e) => _catMovieFrom(e as Map<String, dynamic>))
            .toList(),
        vodMoviesAll: (m['vodMoviesAll'] as List<dynamic>)
            .map((e) => _movieFrom(e as Map<String, dynamic>))
            .toList(),
        seriesCategories: (m['seriesCategories'] as List<dynamic>)
            .map((e) => _catSeriesFrom(e as Map<String, dynamic>))
            .toList(),
        seriesAll: (m['seriesAll'] as List<dynamic>)
            .map((e) => _seriesFrom(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  String encodeToString() => jsonEncode(toJson());

  static XtreamCatalogSnapshot? decodeFromString(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(m);
    } catch (_) {
      return null;
    }
  }
}

/// Live-only slice (cross-playlist favorites / partial cache).
class XtreamLiveCatalogPersistV1 {
  const XtreamLiveCatalogPersistV1({
    required this.liveCategories,
    required this.liveChannelsAll,
  });

  final List<MockLiveCategory> liveCategories;
  final List<MockLiveChannel> liveChannelsAll;

  Map<String, dynamic> toJson() => {
        'v': kXtreamCatalogPayloadVersion,
        'partialLive': true,
        'liveCategories': liveCategories.map(_catLive).toList(),
        'liveChannelsAll': liveChannelsAll.map(_chLive).toList(),
      };

  static XtreamLiveCatalogPersistV1? fromJson(Map<String, dynamic> m) {
    final ver = m['v'];
    if (ver is! num || ver.toInt() < 1 || ver.toInt() > kXtreamCatalogPayloadVersion) {
      return null;
    }
    try {
      return XtreamLiveCatalogPersistV1(
        liveCategories: (m['liveCategories'] as List<dynamic>)
            .map((e) => _catLiveFrom(e as Map<String, dynamic>))
            .toList(),
        liveChannelsAll: (m['liveChannelsAll'] as List<dynamic>)
            .map((e) => _chLiveFrom(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  String encodeToString() => jsonEncode(toJson());

  static XtreamLiveCatalogPersistV1? decodeFromString(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(m);
    } catch (_) {
      return null;
    }
  }
}

/// Top-level for [compute] / isolates.
XtreamCatalogSnapshot? decodeXtreamCatalogSnapshotString(String raw) {
  return XtreamCatalogSnapshot.decodeFromString(raw);
}

XtreamLiveCatalogPersistV1? decodeXtreamLiveCatalogPersistString(String raw) {
  return XtreamLiveCatalogPersistV1.decodeFromString(raw);
}

/// Top-level encode functions for [compute] isolates.
String encodeXtreamCatalogSnapshotToString(XtreamCatalogSnapshot snapshot) {
  return snapshot.encodeToString();
}

String encodeXtreamLiveCatalogPersistToString(
    XtreamLiveCatalogPersistV1 persist) {
  return persist.encodeToString();
}
