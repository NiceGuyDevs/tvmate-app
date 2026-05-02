import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted "My List" for movies, series, and live TV channels (separate lists).
class MyListStore extends ChangeNotifier {
  MyListStore._();

  static final MyListStore instance = MyListStore._();

  static const _kMoviesKey = 'my_list_movie_ids';
  static const _kSeriesKey = 'my_list_series_ids';
  static const _kLiveChannelsKey = 'my_list_live_channel_ids';

  final List<String> _movieIds = [];
  final List<String> _seriesIds = [];
  final List<String> _liveChannelIds = [];
  var _loaded = false;

  List<String> get movieIds => List.unmodifiable(_movieIds);
  List<String> get seriesIds => List.unmodifiable(_seriesIds);
  List<String> get liveChannelIds => List.unmodifiable(_liveChannelIds);

  bool containsMovie(String id) => _movieIds.contains(id);
  bool containsSeries(String id) => _seriesIds.contains(id);
  bool containsLiveChannel(String id) => _liveChannelIds.contains(id);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _movieIds
      ..clear()
      ..addAll(p.getStringList(_kMoviesKey) ?? const []);
    _seriesIds
      ..clear()
      ..addAll(p.getStringList(_kSeriesKey) ?? const []);
    _liveChannelIds
      ..clear()
      ..addAll(p.getStringList(_kLiveChannelsKey) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleMovie(String id) async {
    await ensureLoaded();
    if (_movieIds.contains(id)) {
      _movieIds.remove(id);
    } else {
      _movieIds.add(id);
    }
    await _saveMovies();
    notifyListeners();
  }

  Future<void> toggleSeries(String id) async {
    await ensureLoaded();
    if (_seriesIds.contains(id)) {
      _seriesIds.remove(id);
    } else {
      _seriesIds.add(id);
    }
    await _saveSeries();
    notifyListeners();
  }

  Future<void> _saveMovies() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kMoviesKey, List<String>.from(_movieIds));
  }

  Future<void> _saveSeries() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kSeriesKey, List<String>.from(_seriesIds));
  }

  Future<void> toggleLiveChannel(String id) async {
    await ensureLoaded();
    if (_liveChannelIds.contains(id)) {
      _liveChannelIds.remove(id);
    } else {
      _liveChannelIds.add(id);
    }
    await _saveLiveChannels();
    notifyListeners();
  }

  /// Replaces the live favorites list (order preserved).
  Future<void> setLiveChannelFavorites(List<String> orderedIds) async {
    await ensureLoaded();
    _liveChannelIds
      ..clear()
      ..addAll(orderedIds);
    await _saveLiveChannels();
    notifyListeners();
  }

  Future<void> _saveLiveChannels() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kLiveChannelsKey, List<String>.from(_liveChannelIds));
  }

  /// Full replace for backup restore.
  Future<void> replaceFromBackup({
    required List<String> movieIds,
    required List<String> seriesIds,
    required List<String> liveChannelIds,
  }) async {
    await ensureLoaded();
    _movieIds
      ..clear()
      ..addAll(movieIds);
    _seriesIds
      ..clear()
      ..addAll(seriesIds);
    _liveChannelIds
      ..clear()
      ..addAll(liveChannelIds);
    await _saveMovies();
    await _saveSeries();
    await _saveLiveChannels();
    notifyListeners();
  }
}
