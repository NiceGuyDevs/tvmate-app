# Live TV Player — Background Kill & Fresh Reopen

**Date:** April 10, 2026

---

## What It Does

When the user is watching **Live TV** and minimizes or closes the app:

1. The live stream is **killed immediately** — no background playback, zero resources running.
2. When the app is reopened, it **remembers the exact channel** and opens it **fresh** from scratch.
3. This behavior **only applies to Live TV**. VOD (movies, series) is completely untouched.

---

## How It Works — The Flow

1. User is watching Live TV channel X → minimizes/closes the app.
2. `AppLifecycleState.paused` fires in `PlayerScreen`.
3. The current channel ID is synced to `LiveTvSessionSnapshot` (in case the user switched channels inside the player).
4. `_killLiveStreamForBackground()` runs — stops ExoPlayer, releases texture, stops leapfrog pool and multiview. Stream is completely dead.
5. Meanwhile, `MainShellScreen` also persists `liveWasFullscreen = true` with the correct channel ID to SharedPreferences (existing behavior).
6. User reopens the app → `AppLifecycleState.resumed` fires.
7. The player detects it was background-killed → pops itself with `reopenLiveChannel: true` in the route result.
8. `LiveTvScreen` receives the signal → finds the channel by ID → opens the player fresh on that channel.
9. If the app was fully killed (cold start), the existing `_applyColdStartLiveRestoreIfNeeded` handles it using the persisted `liveWasFullscreen` flag — same end result.

---

## Files Changed

### 1. `lib/player/player_browse_restore.dart`

Added `reopenLiveChannel` flag to signal background-kill reopen:

```dart
class PlayerBrowseRestore {
  const PlayerBrowseRestore({
    this.liveChannelId,
    this.movieId,
    this.seriesId,
    this.reopenLiveChannel = false,  // <-- NEW
  });

  final String? liveChannelId;
  final String? movieId;
  final String? seriesId;

  /// True when the live player was killed because the app went to background.
  /// The browse screen should immediately re-open the same channel fresh.
  final bool reopenLiveChannel;  // <-- NEW
}
```

---

### 2. `lib/player/player_screen.dart`

**New import:**

```dart
import '../shell/live_tv_session_snapshot.dart';
```

**New fields (in `_PlayerScreenState`):**

```dart
var _liveBackgroundKilled = false;
var _exitDueToBackgroundKill = false;
```

**Updated `didChangeAppLifecycleState`:**

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  if (!Platform.isAndroid) return;
  switch (state) {
    case AppLifecycleState.paused:
      if (widget.isLive && !_released) {
        _updateLiveSessionSnapshotFromPlayer();
        _liveBackgroundKilled = true;
        unawaited(_killLiveStreamForBackground());
      }
      _hadPausedLifecycle = true;
      unawaited(DeviceMemoryChannel.setKeepScreenOn(false));
      break;
    case AppLifecycleState.resumed:
      if (widget.isLive && _liveBackgroundKilled && mounted && !_released) {
        _liveBackgroundKilled = false;
        _exitDueToBackgroundKill = true;
        unawaited(_exit());
        return;
      }
      if (mounted && !_released) {
        unawaited(DeviceMemoryChannel.setKeepScreenOn(true));
        if (_hadPausedLifecycle) {
          _hadPausedLifecycle = false;
          unawaited(_rebootstrapAfterResume());
        }
      }
      break;
    case AppLifecycleState.inactive:
    case AppLifecycleState.hidden:
      unawaited(DeviceMemoryChannel.setKeepScreenOn(false));
      break;
    case AppLifecycleState.detached:
      break;
  }
}
```

**New method — kills the stream without popping the route:**

```dart
Future<void> _killLiveStreamForBackground() async {
  if (_released) return;
  if (_inMultiview) {
    try { await _mvReleasePool(); } catch (_) {}
    _mvTiles.clear();
  }
  try { await _lfStop(); } catch (_) {}
  try { await _service.pause(); } catch (_) {}
  try { await _service.releaseTexture(); } catch (_) {}
  if (mounted) setState(() => _textureId = null);
}
```

**New method — syncs current in-player channel to the session snapshot:**

```dart
void _updateLiveSessionSnapshotFromPlayer() {
  if (!widget.isLive) return;
  final chId = _currentLiveChannelId;
  if (chId == null || chId.isEmpty) return;
  final catId = widget.liveViewCategoryId;
  if (catId == null || catId.isEmpty) return;
  LiveTvSessionSnapshot.update(categoryId: catId, channelId: chId);
}
```

**Updated `_switchLiveToIndex` — keeps snapshot in sync on channel switch:**

```dart
_liveIndex = idx;
final item = lineup[_liveIndex];
_activeStreamUrl = item.streamUrl;
setState(() {
  _displayTitle = item.title;
  _liveEpgWindowCenter = -1;
});
_updateLiveSessionSnapshotFromPlayer();  // <-- NEW LINE
```

**Updated `_exit()` — passes the background-kill flag in the pop result:**

```dart
Navigator.of(context).pop(
  PlayerBrowseRestore(
    liveChannelId: widget.isLive ? _effectiveEpgChannelId : null,
    movieId: widget.isLive ? null : widget.browseMovieId,
    seriesId: widget.isLive ? null : widget.browseSeriesId,
    reopenLiveChannel: _exitDueToBackgroundKill,  // <-- NEW
  ),
);
```

---

### 3. `lib/ui/live_tv/live_tv_screen.dart`

**Updated `onPlayerClosed` callback in `_openLivePlayer`:**

```dart
onPlayerClosed: (restore) {
  if (!mounted) return;
  final id = restore?.liveChannelId;
  if (id == null) return;
  if (restore!.reopenLiveChannel) {       // <-- NEW
    _reopenLiveChannelAfterBackground(id); // <-- NEW
    return;                                // <-- NEW
  }                                        // <-- NEW
  _restoreLiveGridFocusByChannelId(id);
},
```

**New method — re-opens the player fresh after background return:**

```dart
void _reopenLiveChannelAfterBackground(String channelId) {
  if (!mounted) return;
  final channels = _channelsForCurrentView();
  MockLiveChannel? ch;
  for (final c in channels) {
    if (c.id == channelId) {
      ch = c;
      break;
    }
  }
  ch ??= channels.isNotEmpty ? channels.first : null;
  if (ch != null) {
    unawaited(_openLivePlayer(ch));
  }
}
```

---

## Key Points

- **VOD is untouched.** Movies and series still pause on background and resume on foreground exactly as before.
- **Works on all Android devices** — Nvidia Shield, Fire TV, Chromecast, Mi Box, any Android TV. It uses the standard Flutter app lifecycle, nothing device-specific.
- **Channel switch tracking** — If the user switches from channel A to B inside the player and then minimizes, channel B is saved (not A).
- **Cold start covered** — If the OS kills the app completely, the existing `_applyColdStartLiveRestoreIfNeeded` in `LiveTvScreen` handles the restore using the persisted SharedPreferences data.
