import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../player/playback_resume_store.dart';

/// Single manual + automatic label per movie (VOD): watching, continue watching, watched.
enum MovieVodLabel { none, watching, continueWatching, watched }

class MovieVodLabelStore extends ChangeNotifier {
  MovieVodLabelStore._();

  static final MovieVodLabelStore instance = MovieVodLabelStore._();

  static const _kMapKey = 'movie_vod_labels_v1';
  static const _kLegacyWatched = 'movie_watched_ids';

  final Map<String, MovieVodLabel> _labels = {};
  var _loaded = false;

  MovieVodLabel labelFor(String movieId) =>
      _labels[movieId] ?? MovieVodLabel.none;

  List<String> movieIdsWithLabel(MovieVodLabel label) {
    final out = <String>[
      for (final e in _labels.entries)
        if (e.value == label) e.key,
    ];
    out.sort();
    return out;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kMapKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          final idx = e.value is num
              ? (e.value as num).toInt()
              : int.tryParse('${e.value}') ?? -1;
          if (idx < 0 || idx >= MovieVodLabel.values.length) continue;
          final lab = MovieVodLabel.values[idx];
          if (lab != MovieVodLabel.none) {
            _labels[e.key] = lab;
          }
        }
      } catch (_) {}
    } else {
      final legacy = p.getStringList(_kLegacyWatched) ?? const [];
      for (final id in legacy) {
        _labels[id] = MovieVodLabel.watched;
      }
      await _persist(p);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLabel(String movieId, MovieVodLabel label) async {
    await ensureLoaded();
    if (label == MovieVodLabel.none) {
      _labels.remove(movieId);
    } else {
      _labels[movieId] = label;
    }
    final p = await SharedPreferences.getInstance();
    await _persist(p);
    notifyListeners();
  }

  Future<void> toggleWatching(String movieId) async {
    final cur = labelFor(movieId);
    await setLabel(
      movieId,
      cur == MovieVodLabel.watching ? MovieVodLabel.none : MovieVodLabel.watching,
    );
  }

  Future<void> toggleContinueWatching(String movieId) async {
    final cur = labelFor(movieId);
    final next = cur == MovieVodLabel.continueWatching
        ? MovieVodLabel.none
        : MovieVodLabel.continueWatching;
    await setLabel(movieId, next);
    if (cur == MovieVodLabel.continueWatching && next == MovieVodLabel.none) {
      await PlaybackResumeStore.clear('movie_$movieId');
    }
  }

  /// Import from backup JSON: `{ "movieId": 0..3 }`.
  Future<void> replaceFromBackupMap(Map<String, dynamic> map) async {
    await ensureLoaded();
    _labels.clear();
    for (final e in map.entries) {
      final idx = e.value is num
          ? (e.value as num).toInt()
          : int.tryParse('${e.value}') ?? -1;
      if (idx < 1 || idx >= MovieVodLabel.values.length) continue;
      final lab = MovieVodLabel.values[idx];
      if (lab != MovieVodLabel.none) {
        _labels[e.key] = lab;
      }
    }
    final p = await SharedPreferences.getInstance();
    await _persist(p);
    notifyListeners();
  }

  /// Legacy restore: replaces the **watched** set only; other labels unchanged.
  Future<void> replaceWatchedOnlyFromLegacyBackup(List<String> movieIds) async {
    await ensureLoaded();
    _labels.removeWhere((_, v) => v == MovieVodLabel.watched);
    for (final id in movieIds) {
      _labels[id] = MovieVodLabel.watched;
    }
    final p = await SharedPreferences.getInstance();
    await _persist(p);
    notifyListeners();
  }

  Map<String, int> exportForBackup() {
    return {for (final e in _labels.entries) e.key: e.value.index};
  }

  Future<void> _persist(SharedPreferences p) async {
    final encoded = jsonEncode(
      {for (final e in _labels.entries) e.key: e.value.index},
    );
    await p.setString(_kMapKey, encoded);
    final watched = movieIdsWithLabel(MovieVodLabel.watched);
    await p.setStringList(_kLegacyWatched, watched);
  }
}
