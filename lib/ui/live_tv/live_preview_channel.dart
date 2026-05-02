import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../player/player_service.dart';

/// Hero live preview with audio; separate from fullscreen [PlayerService].
class LivePreviewChannel {
  LivePreviewChannel._();

  static const _method = MethodChannel('com.tvmate.app/live_preview');

  /// Stop preview AV while fullscreen player is on top (avoids double audio).
  static Future<void> pauseForFullscreen() =>
      _method.invokeMethod<void>('pauseForFullscreen');

  /// Restore preview playback when fullscreen route is popped.
  static Future<void> resumeAfterFullscreen() =>
      _method.invokeMethod<void>('resumeAfterFullscreen');

  static Future<int> ensureTexture() async {
    final id = await _method.invokeMethod<int>('ensureTexture');
    if (id == null) {
      throw PlatformException(code: 'texture', message: 'No preview texture id');
    }
    return id;
  }

  static Future<void> load(String url) => _method.invokeMethod<void>('load', {
        'url': url,
      });

  /// Start playback after [load] (preview may have been paused for fullscreen).
  static Future<void> play() => _method.invokeMethod<void>('play');

  /// User mute (persisted in Dart); video keeps playing. Ignored while fullscreen handoff is active.
  static Future<void> setUserMuted(bool muted) =>
      _method.invokeMethod<void>('setUserMuted', {'muted': muted});

  /// Release texture and ExoPlayer; call when [LiveTvScreen] is disposed.
  static Future<void> dispose() => _method.invokeMethod<void>('dispose');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
