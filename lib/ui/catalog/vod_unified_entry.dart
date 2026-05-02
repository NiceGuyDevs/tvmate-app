import '../movies/mock_movies_data.dart';
import '../series/mock_series_data.dart';

/// One tile in a merged Movies + Series VOD search rail.
class VodUnifiedEntry {
  const VodUnifiedEntry.movie(this.movie) : series = null;
  const VodUnifiedEntry.series(this.series) : movie = null;

  final MockMovie? movie;
  final MockSeries? series;

  bool get isMovie => movie != null;
}
