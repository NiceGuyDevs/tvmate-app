import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

enum MediaPosterCardStyle {
  posterOnly,
  /// Poster + title overlay (no year / meta line).
  posterAndName,
  /// Poster + title + year (and duration / meta where applicable).
  posterAndTitle,
  titleOnly,
}

extension MediaPosterCardStyleLabel on MediaPosterCardStyle {
  String get label => switch (this) {
        MediaPosterCardStyle.posterAndTitle => 'Poster + Title',
        MediaPosterCardStyle.posterOnly => 'Poster only',
        MediaPosterCardStyle.posterAndName => 'Name + Poster',
        MediaPosterCardStyle.titleOnly => 'Title only',
      };
}

class MediaCardStyleStore extends ChangeNotifier {
  static const _kMovieKey = 'tvmatepro_movie_card_style_v1';
  static const _kSeriesKey = 'tvmatepro_series_card_style_v1';

  var _loaded = false;
  /// Fresh install: **Poster only** for both rails.
  MediaPosterCardStyle _movieStyle = MediaPosterCardStyle.posterOnly;
  MediaPosterCardStyle _seriesStyle = MediaPosterCardStyle.posterOnly;

  bool get isLoaded => _loaded;
  MediaPosterCardStyle get movieStyle => _movieStyle;
  MediaPosterCardStyle get seriesStyle => _seriesStyle;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final movieRaw = prefs.getString(_kMovieKey);
    final seriesRaw = prefs.getString(_kSeriesKey);
    _movieStyle = movieRaw == null ? MediaPosterCardStyle.posterOnly : parseStorage(movieRaw);
    _seriesStyle =
        seriesRaw == null ? MediaPosterCardStyle.posterOnly : parseStorage(seriesRaw);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMovieStyle(MediaPosterCardStyle next) async {
    if (_movieStyle == next) return;
    _movieStyle = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMovieKey, _toStorage(next));
    notifyListeners();
  }

  Future<void> setSeriesStyle(MediaPosterCardStyle next) async {
    if (_seriesStyle == next) return;
    _seriesStyle = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSeriesKey, _toStorage(next));
    notifyListeners();
  }

  static String _toStorage(MediaPosterCardStyle style) {
    switch (style) {
      case MediaPosterCardStyle.posterOnly:
        return 'poster_only';
      case MediaPosterCardStyle.posterAndName:
        return 'poster_name';
      case MediaPosterCardStyle.titleOnly:
        return 'title_only';
      case MediaPosterCardStyle.posterAndTitle:
        return 'poster_title';
    }
  }

  static String storageString(MediaPosterCardStyle style) => _toStorage(style);

  static MediaPosterCardStyle parseStorage(String? raw) {
    switch (raw) {
      case 'poster_only':
        return MediaPosterCardStyle.posterOnly;
      case 'poster_name':
        return MediaPosterCardStyle.posterAndName;
      case 'title_only':
        return MediaPosterCardStyle.titleOnly;
      case 'poster_title':
        return MediaPosterCardStyle.posterAndTitle;
      default:
        return MediaPosterCardStyle.posterOnly;
    }
  }
}

final MediaCardStyleStore mediaCardStyleStore = MediaCardStyleStore();
