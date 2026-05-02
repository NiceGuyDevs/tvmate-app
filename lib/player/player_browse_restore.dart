/// Returned when the fullscreen player closes so browse UIs can refocus the
/// last-played item (live channel may change via UP/DOWN in-player).
class PlayerBrowseRestore {
  const PlayerBrowseRestore({
    this.liveChannelId,
    this.movieId,
    this.seriesId,
    this.reopenLiveChannel = false,
  });

  /// Last focused live lineup channel when exiting (includes in-player switches).
  final String? liveChannelId;

  /// Movie id when playing VOD from movie details / browse context.
  final String? movieId;

  /// Series id when playing an episode (for series browse restore).
  final String? seriesId;

  /// True when the live player was killed because the app went to background.
  /// The browse screen should immediately re-open the same channel fresh.
  final bool reopenLiveChannel;
}
