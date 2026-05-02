/// Tracks whether a **live** fullscreen [PlayerScreen] route is on the stack
/// (supports multiple simultaneous opens defensively).
///
/// Also tracks **VOD** [PlayerScreen] with a [PlayerScreen.resumeContentId] (movies /
/// series resume keys), used when persisting shell tab on app pause.
class PlayerSessionRestoreMarker {
  PlayerSessionRestoreMarker._();

  static int _liveOpen = 0;
  static int _vodOpen = 0;

  static bool get livePlayerOpen => _liveOpen > 0;

  /// VOD player that participates in cold-start restore (has [resumeContentId]).
  static bool get vodPlayerOpen => _vodOpen > 0;

  static void markLiveOpened() {
    _liveOpen++;
  }

  static void markLiveClosed() {
    if (_liveOpen > 0) _liveOpen--;
  }

  static void markVodOpened() {
    _vodOpen++;
  }

  static void markVodClosed() {
    if (_vodOpen > 0) _vodOpen--;
  }
}
