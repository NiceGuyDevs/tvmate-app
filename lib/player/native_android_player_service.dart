import 'dart:async';

import 'package:flutter/services.dart';

import 'player_events.dart';
import 'player_service.dart';
import 'player_track.dart';

/// Android: [MethodChannel] `com.tvmate.app/player`, [EventChannel] `com.tvmate.app/player_events`.
class NativeAndroidPlayerService implements PlayerService {
  static const _method = MethodChannel('com.tvmate.app/player');
  static const _events = EventChannel('com.tvmate.app/player_events');

  Stream<PlayerNativeEvent>? _eventStream;

  @override
  Future<int> ensureTexture() async {
    final id = await _method.invokeMethod<int>('ensureTexture');
    if (id == null) {
      throw PlatformException(code: 'texture', message: 'No texture id');
    }
    return id;
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
  }) async {
    await _method.invokeMethod<void>('load', {
      'url': url,
      'isLive': isLive,
      'audioDelayMs': audioDelayMs,
      'subtitleDelayMs': subtitleDelayMs,
      'playbackSpeed': playbackSpeed,
      if (liveFastSwitch) 'liveFastSwitch': true,
      if (subtitlePath != null && subtitlePath.isNotEmpty)
        'subtitlePath': subtitlePath,
    });
  }

  @override
  Future<void> setExternalSubtitle(String? path, {int? subtitleDelayMs}) =>
      _method.invokeMethod<void>('setExternalSubtitle', {
        'path': path,
        if (subtitleDelayMs != null) 'subtitleDelayMs': subtitleDelayMs,
      });

  @override
  Future<void> play() => _method.invokeMethod<void>('play');

  @override
  Future<void> pause() => _method.invokeMethod<void>('pause');

  @override
  Future<void> seekTo(Duration position) =>
      _method.invokeMethod<void>('seekTo', {
        'positionMs': position.inMilliseconds,
      });

  @override
  Future<void> setVolume(double volume) =>
      _method.invokeMethod<void>('setVolume', {'volume': volume});

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _method.invokeMethod<void>('setPlaybackSpeed', {'speed': speed});

  @override
  Future<void> setAudioDelayMs(int audioDelayMs) =>
      _method.invokeMethod<void>('setAudioDelayMs', {
        'audioDelayMs': audioDelayMs,
      });

  @override
  Future<void> setSubtitleDelayMs(int subtitleDelayMs) =>
      _method.invokeMethod<void>('setSubtitleDelayMs', {
        'subtitleDelayMs': subtitleDelayMs,
      });

  @override
  Future<void> setSubtitleOverlayOffset({
    required double dx,
    required double dy,
  }) async {}

  @override
  int? get playbackPositionMsSync => null;

  @override
  Future<void> releaseTexture() =>
      _method.invokeMethod<void>('releaseTexture');

  @override
  Future<TracksSnapshot> getTracksSnapshot() async {
    final raw = await _method.invokeMethod<dynamic>('getTracksSnapshot');
    if (raw == null) return TracksSnapshot.empty;
    return TracksSnapshot.fromPayload(raw);
  }

  @override
  Future<void> setLiveVideoMaxHeight(int maxHeightPx) =>
      _method.invokeMethod<void>('setLiveVideoMaxHeight', {
        'maxHeight': maxHeightPx.clamp(0, 1 << 20),
      });

  @override
  Stream<PlayerNativeEvent> get events {
    _eventStream ??= _events.receiveBroadcastStream().map(
          (e) => PlayerNativeEvent.fromPayload(e),
        );
    return _eventStream!;
  }

  @override
  void dispose() {
    _eventStream = null;
  }
}
