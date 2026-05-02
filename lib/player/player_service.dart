import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'desktop_player_service.dart';
import 'native_android_player_service.dart';
import 'player_events.dart';
import 'player_track.dart';

/// Abstraction over native playback (Android ExoPlayer / Media3 via platform channels).
/// The app does not use `package:video_player` for primary playback.
abstract class PlayerService {
  /// Flutter [Texture] id for video output, or throws if unsupported / failed.
  Future<int> ensureTexture();

  Future<void> load({
    required String url,
    required bool isLive,
    int audioDelayMs = 0,
    int subtitleDelayMs = 0,
    double playbackSpeed = 1.0,
    String? subtitlePath,
    /// Live only: smaller ExoPlayer buffers on weak devices — faster channel change (single player).
    bool liveFastSwitch = false,
  });

  /// VOD: attach external SRT (absolute path) or clear when [path] is null.
  /// When [subtitleDelayMs] is set, Android applies it before building the sidecar (one native update).
  Future<void> setExternalSubtitle(String? path, {int? subtitleDelayMs});

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  /// Set player volume (0.0 = mute, 1.0 = full). Used by multiview to
  /// swap audio between the focused and unfocused tile decoders.
  Future<void> setVolume(double volume);

  /// VOD: playback speed (session-only; native resets when texture is released).
  Future<void> setPlaybackSpeed(double speed);

  /// VOD: A/V sync in ms (positive = audio late; negative = audio early).
  Future<void> setAudioDelayMs(int audioDelayMs);

  /// VOD: external subtitle time offset in ms (positive = subtitles later).
  Future<void> setSubtitleDelayMs(int subtitleDelayMs);

  /// VOD: Flutter subtitle overlay offset (logical px from bottom-center anchor).
  /// Desktop (mpv): maps to `sub-margin-x` / `sub-margin-y`. No-op where unsupported.
  Future<void> setSubtitleOverlayOffset({
    required double dx,
    required double dy,
  });

  /// Best-effort current playback position (ms). Desktop reads media_kit directly
  /// for accurate resume saves; return null to use UI-tracked [_positionMs].
  int? get playbackPositionMsSync;

  /// Release GPU texture; native player may stay alive for the next [load].
  Future<void> releaseTexture();

  /// Track lists for future audio/subtitle UX; empty when unsupported or not ready.
  Future<TracksSnapshot> getTracksSnapshot();

  /// Live TV: cap max decoded video height (e.g. 720). Use 0 for full ladder.
  Future<void> setLiveVideoMaxHeight(int maxHeightPx);

  Stream<PlayerNativeEvent> get events;

  void dispose();
}

PlayerService createPlayerService() {
  if (kIsWeb) return UnavailablePlayerService();
  if (defaultTargetPlatform == TargetPlatform.android) {
    return NativeAndroidPlayerService();
  }
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return DesktopPlayerService();
  }
  return UnavailablePlayerService();
}

bool get isNativePlayerSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
     defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.macOS);

/// No-op implementation for non-Android platforms (analyzer / tests).
class UnavailablePlayerService implements PlayerService {
  final _controller = StreamController<PlayerNativeEvent>.broadcast();

  @override
  Future<int> ensureTexture() async {
    throw PlatformException(
      code: 'unsupported',
      message: 'Native player is only available on Android.',
    );
  }

  @override
  Future<void> load({
    required String url,
    required bool isLive,
    int audioDelayMs = 0,
    int subtitleDelayMs = 0,
    double playbackSpeed = 1.0,
    String? subtitlePath,
    bool liveFastSwitch = false,
  }) async {}

  @override
  Future<void> setExternalSubtitle(String? path, {int? subtitleDelayMs}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setAudioDelayMs(int audioDelayMs) async {}

  @override
  Future<void> setSubtitleDelayMs(int subtitleDelayMs) async {}

  @override
  Future<void> setSubtitleOverlayOffset({
    required double dx,
    required double dy,
  }) async {}

  @override
  int? get playbackPositionMsSync => null;

  @override
  Future<void> releaseTexture() async {}

  @override
  Future<TracksSnapshot> getTracksSnapshot() async => TracksSnapshot.empty;

  @override
  Future<void> setLiveVideoMaxHeight(int maxHeightPx) async {}

  @override
  Stream<PlayerNativeEvent> get events => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}
