import '../live_tv/mock_live_tv_data.dart';
import '../movies/mock_movies_data.dart';
import '../series/mock_series_data.dart';

/// True when [raw] is plausible for [Image.network] (avoids Xtream sentinels / relative paths).
bool catalogArtUrlLooksLoadable(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return false;
  final l = s.toLowerCase();
  if (l == 'null' || l == '0' || l == '-' || l == 'n/a') return false;
  return l.startsWith('http://') || l.startsWith('https://');
}

/// Bundled [Image.asset] path (demo / offline art).
bool catalogArtIsBundledAsset(String? raw) {
  final s = raw?.trim() ?? '';
  return s.startsWith('assets/');
}

/// TMDb backdrop: request a wider art path when possible.
String catalogBackdropHiResUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return t;
  if (catalogArtIsBundledAsset(t)) return t;
  if (!t.contains('image.tmdb.org/t/p/')) return t;
  return t.replaceFirstMapped(
    RegExp(r'/t/p/[^/]+/'),
    (_) => '/t/p/w1280/',
  );
}

/// TMDb poster / still: medium-wide for hero edges.
String catalogPosterHiResUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return t;
  if (catalogArtIsBundledAsset(t)) return t;
  if (!t.contains('image.tmdb.org/t/p/')) return t;
  return t.replaceFirstMapped(
    RegExp(r'/t/p/[^/]+/'),
    (_) => '/t/p/w780/',
  );
}

String moviePosterUrl(MockMovie m) {
  final u = m.coverUrl?.trim();
  if (u == null || u.isEmpty) return '';
  if (catalogArtIsBundledAsset(u)) return u;
  if (catalogArtUrlLooksLoadable(u)) return u;
  return '';
}

String movieBackdropUrl(MockMovie m) {
  final u = m.backdropUrl?.trim();
  if (u != null && u.isNotEmpty) {
    if (catalogArtIsBundledAsset(u)) return u;
    if (catalogArtUrlLooksLoadable(u)) return u;
  }
  final c = m.coverUrl?.trim();
  if (c == null || c.isEmpty) return '';
  if (catalogArtIsBundledAsset(c)) return c;
  if (catalogArtUrlLooksLoadable(c)) return c;
  return '';
}

String seriesPosterUrl(MockSeries s) {
  final u = s.coverUrl?.trim();
  if (u == null || u.isEmpty) return '';
  if (catalogArtIsBundledAsset(u)) return u;
  if (catalogArtUrlLooksLoadable(u)) return u;
  return '';
}

String seriesBackdropUrl(MockSeries s) {
  final u = s.backdropUrl?.trim();
  if (u != null && u.isNotEmpty) {
    if (catalogArtIsBundledAsset(u)) return u;
    if (catalogArtUrlLooksLoadable(u)) return u;
  }
  final c = s.coverUrl?.trim();
  if (c == null || c.isEmpty) return '';
  if (catalogArtIsBundledAsset(c)) return c;
  if (catalogArtUrlLooksLoadable(c)) return c;
  return '';
}

String liveChannelArtUrl(MockLiveChannel c) {
  final u = c.iconUrl?.trim();
  if (u == null || u.isEmpty) return '';
  if (catalogArtIsBundledAsset(u)) return u;
  if (catalogArtUrlLooksLoadable(u)) return u;
  return '';
}

String episodeStillUrl(MockSeries s, MockEpisode e) {
  final u = e.stillUrl?.trim();
  if (catalogArtUrlLooksLoadable(u)) return u!.trim();
  return '';
}
