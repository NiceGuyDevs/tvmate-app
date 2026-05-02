import 'package:flutter/foundation.dart';

import 'movie_vod_label_store.dart';

/// Watched marks — backed by [MovieVodLabelStore] (`watched` label).
class MovieWatchedStore extends ChangeNotifier {
  MovieWatchedStore._();

  static final MovieWatchedStore instance = MovieWatchedStore._();

  void _onVodChanged() => notifyListeners();

  List<String> get movieIds =>
      MovieVodLabelStore.instance.movieIdsWithLabel(MovieVodLabel.watched);

  bool contains(String movieId) =>
      MovieVodLabelStore.instance.labelFor(movieId) == MovieVodLabel.watched;

  Future<void> ensureLoaded() async {
    await MovieVodLabelStore.instance.ensureLoaded();
    MovieVodLabelStore.instance.removeListener(_onVodChanged);
    MovieVodLabelStore.instance.addListener(_onVodChanged);
  }

  Future<void> toggle(String id) async {
    await ensureLoaded();
    final cur = MovieVodLabelStore.instance.labelFor(id);
    if (cur == MovieVodLabel.watched) {
      await MovieVodLabelStore.instance.setLabel(id, MovieVodLabel.none);
    } else {
      await MovieVodLabelStore.instance.setLabel(id, MovieVodLabel.watched);
    }
  }

  /// Full replace for backup restore (legacy **watched** list only).
  Future<void> replaceFromBackup(List<String> movieIds) async {
    await MovieVodLabelStore.instance.replaceWatchedOnlyFromLegacyBackup(movieIds);
  }
}
