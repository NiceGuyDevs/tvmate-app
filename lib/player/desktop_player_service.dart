import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'player_events.dart';
import 'player_service.dart';
import 'player_track.dart';
import 'vod_subtitle_delay_store.dart';

/// Desktop (Windows/macOS) implementation of [PlayerService] using media_kit (mpv).
class DesktopPlayerService implements PlayerService {
  late final mk.Player _player;
  late final mkv.VideoController _videoController;
  final _events = StreamController<PlayerNativeEvent>.broadcast();

  bool _disposed = false;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  StreamSubscription<mk.PlaylistMode>? _completedSub;
  StreamSubscription<List<String>>? _subtitleSub;

  int? _lastVideoWidth;
  int? _lastVideoHeight;

  /// Last-known playback metrics — [PlayerScreen] used to treat every `progress`
  /// as a full snapshot; media_kit fires **separate** streams (position / buffer /
  /// duration), so partial events cleared duration and made VOD chrome vanish.
  int _progressPositionMs = 0;
  int _progressBufferedMs = 0;
  int _progressDurationMs = -1;

  DesktopPlayerService() {
    _player = mk.Player();
    _videoController = mkv.VideoController(_player);
    _subscribeToEvents();
  }

  mkv.VideoController get videoController => _videoController;

  void _subscribeToEvents() {
    _playingSub = _player.stream.playing.listen((playing) {
      _events.add(PlayerNativeEvent(
        type: 'state',
        playbackState: playing ? 'ready' : 'ready',
        isPlaying: playing,
      ));
    });

    _positionSub = _player.stream.position.listen((pos) {
      _progressPositionMs = pos.inMilliseconds;
      _emitProgressSnapshot();
    });

    _bufferSub = _player.stream.buffer.listen((buf) {
      _progressBufferedMs = buf.inMilliseconds;
      _emitProgressSnapshot();
    });

    _durationSub = _player.stream.duration.listen((dur) {
      _progressDurationMs = dur.inMilliseconds;
      _emitProgressSnapshot();
    });

    _widthSub = _player.stream.width.listen((w) {
      _lastVideoWidth = w;
      if (w != null && _lastVideoHeight != null) {
        _events.add(PlayerNativeEvent(
          type: 'videoSize',
          videoWidth: w,
          videoHeight: _lastVideoHeight,
        ));
      }
    });

    _heightSub = _player.stream.height.listen((h) {
      _lastVideoHeight = h;
      if (h != null && _lastVideoWidth != null) {
        _events.add(PlayerNativeEvent(
          type: 'videoSize',
          videoWidth: _lastVideoWidth,
          videoHeight: h,
        ));
      }
    });

    _player.stream.buffering.listen((buffering) {
      _events.add(PlayerNativeEvent(
        type: 'state',
        playbackState: buffering ? 'buffering' : 'ready',
        isPlaying: _player.state.playing,
      ));
    });

    _player.stream.error.listen((error) {
      _events.add(PlayerNativeEvent(
        type: 'error',
        message: error,
      ));
    });

    _player.stream.completed.listen((completed) {
      if (completed) {
        _events.add(const PlayerNativeEvent(
          type: 'state',
          playbackState: 'ended',
          isPlaying: false,
        ));
      }
    });

    // Same contract as Android ExoPlayer `cues` / TextOutput — drives
    // [_buildVodSubtitleOverlay] so desktop uses Flutter styling + position.
    _subtitleSub = _player.stream.subtitle.listen((lines) {
      if (_disposed) return;
      final cueLines = lines
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      _events.add(PlayerNativeEvent(
        type: 'cues',
        cueLines: cueLines,
      ));
    });
  }

  /// Hide libmpv OSD so subtitles are not double-drawn; decoding continues for [stream.subtitle].
  Future<void> _ensureSubtitleOsdHidden() async {
    final platform = _player.platform;
    if (platform is! mk.NativePlayer) return;
    try {
      await platform.setProperty('sub-visibility', 'no');
    } catch (_) {}
  }

  void _emitProgressSnapshot() {
    if (_disposed) return;
    _events.add(PlayerNativeEvent(
      type: 'progress',
      positionMs: _progressPositionMs,
      bufferedMs: _progressBufferedMs,
      durationMs: _progressDurationMs,
    ));
  }

  @override
  Future<int> ensureTexture() async {
    // media_kit uses its own Video widget rather than Flutter Texture IDs.
    // Return -1 as a sentinel; PlayerScreen uses the Video widget directly.
    return -1;
  }

  int _sessionSubtitleDelayMs = 0;

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
    _progressPositionMs = 0;
    _progressBufferedMs = 0;
    _progressDurationMs = -1;
    _sessionSubtitleDelayMs = subtitleDelayMs.clamp(
      VodSubtitleDelayStore.minMs,
      VodSubtitleDelayStore.maxMs,
    );
    await _player.open(mk.Media(url));
    if (playbackSpeed != 1.0) {
      await _player.setRate(playbackSpeed);
    }
    if (subtitlePath != null && subtitlePath.isNotEmpty) {
      await _setSubtitleTrack(subtitlePath);
    }
    await setSubtitleDelayMs(_sessionSubtitleDelayMs);
    await _ensureSubtitleOsdHidden();
  }

  Future<void> _setSubtitleTrack(String path) async {
    if (File(path).existsSync()) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.uri(path));
    }
  }

  @override
  Future<void> setExternalSubtitle(String? path, {int? subtitleDelayMs}) async {
    if (subtitleDelayMs != null) {
      _sessionSubtitleDelayMs = subtitleDelayMs.clamp(
        VodSubtitleDelayStore.minMs,
        VodSubtitleDelayStore.maxMs,
      );
    }
    if (path == null || path.isEmpty) {
      await _player.setSubtitleTrack(mk.SubtitleTrack.no());
    } else {
      await _setSubtitleTrack(path);
      await setSubtitleDelayMs(_sessionSubtitleDelayMs);
    }
    await _ensureSubtitleOsdHidden();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume * 100.0);

  @override
  Future<void> setPlaybackSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> setAudioDelayMs(int audioDelayMs) async {
    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      await platform.setProperty(
          'audio-delay', (audioDelayMs / 1000.0).toString());
    }
  }

  @override
  Future<void> setSubtitleDelayMs(int subtitleDelayMs) async {
    final d = subtitleDelayMs.clamp(
      VodSubtitleDelayStore.minMs,
      VodSubtitleDelayStore.maxMs,
    );
    _sessionSubtitleDelayMs = d;
    final platform = _player.platform;
    if (platform is mk.NativePlayer) {
      // mpv: sub-delay in seconds; positive = show subtitles later.
      await platform.setProperty('sub-delay', (d / 1000.0).toString());
    }
  }

  @override
  Future<void> setSubtitleOverlayOffset({
    required double dx,
    required double dy,
  }) async {
    // Position/size are applied only in Flutter ([PlayerScreen] overlay), not mpv.
  }

  @override
  int? get playbackPositionMsSync {
    if (_disposed) return null;
    try {
      return _player.state.position.inMilliseconds;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> releaseTexture() async {
    await _player.stop();
  }

  @override
  Future<TracksSnapshot> getTracksSnapshot() async {
    final tracks = _player.state.tracks;
    final audioTracks = <PlayerMediaTrack>[];
    for (final t in tracks.audio) {
      if (t.id == 'auto' || t.id == 'no') continue;
      audioTracks.add(PlayerMediaTrack(
        id: t.id,
        label: t.title,
        language: t.language,
      ));
    }
    final subtitleTracks = <PlayerMediaTrack>[];
    for (final t in tracks.subtitle) {
      if (t.id == 'auto' || t.id == 'no') continue;
      subtitleTracks.add(PlayerMediaTrack(
        id: t.id,
        label: t.title,
        language: t.language,
      ));
    }
    return TracksSnapshot(
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
    );
  }

  @override
  Future<void> setLiveVideoMaxHeight(int maxHeightPx) async {
    // Not directly supported by mpv in the same way as ExoPlayer track selection.
    // Could be implemented via mpv's --vf=lavfi=[scale] or ytdl-format but
    // skipping for v1.
  }

  @override
  Stream<PlayerNativeEvent> get events => _events.stream;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _playingSub?.cancel();
    _positionSub?.cancel();
    _bufferSub?.cancel();
    _durationSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _completedSub?.cancel();
    _subtitleSub?.cancel();
    _player.dispose();
    _events.close();
  }
}
