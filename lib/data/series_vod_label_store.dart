import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'movie_vod_label_store.dart';

/// Same [MovieVodLabel] semantics as movies, keyed by **series id** (browse posters + auto from episode playback).
class SeriesVodLabelStore extends ChangeNotifier {
  SeriesVodLabelStore._();

  static final SeriesVodLabelStore instance = SeriesVodLabelStore._();

  static const _kMapKey = 'series_vod_labels_v1';

  final Map<String, MovieVodLabel> _labels = {};
  var _loaded = false;

  MovieVodLabel labelFor(String seriesId) =>
      _labels[seriesId] ?? MovieVodLabel.none;

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
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLabel(String seriesId, MovieVodLabel label) async {
    await ensureLoaded();
    if (label == MovieVodLabel.none) {
      _labels.remove(seriesId);
    } else {
      _labels[seriesId] = label;
    }
    final p = await SharedPreferences.getInstance();
    await _persist(p);
    notifyListeners();
  }

  Future<void> toggleWatching(String seriesId) async {
    final cur = labelFor(seriesId);
    await setLabel(
      seriesId,
      cur == MovieVodLabel.watching ? MovieVodLabel.none : MovieVodLabel.watching,
    );
  }

  Future<void> toggleContinueWatching(String seriesId) async {
    final cur = labelFor(seriesId);
    await setLabel(
      seriesId,
      cur == MovieVodLabel.continueWatching
          ? MovieVodLabel.none
          : MovieVodLabel.continueWatching,
    );
  }

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

  Map<String, int> exportForBackup() {
    return {for (final e in _labels.entries) e.key: e.value.index};
  }

  Future<void> _persist(SharedPreferences p) async {
    final encoded = jsonEncode(
      {for (final e in _labels.entries) e.key: e.value.index},
    );
    await p.setString(_kMapKey, encoded);
  }
}
