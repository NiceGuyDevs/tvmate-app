import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart façade for the native [NativePlayerPool] (Kotlin).
///
/// Each **slot** (0-3) is an independent ExoPlayer instance with its own
/// Flutter [Texture].  Used for:
///  • **Multiview** – up to 4 channels playing at once.
///  • **Zero-delay channel switching** – two slots leapfrog so the next
///    channel is pre-buffered before the switch happens.
class PlayerPool {
  PlayerPool._();

  static const _ch = MethodChannel('com.tvmate.app/player_pool');
  static const int maxSlots = 4;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Create the ExoPlayer + Flutter texture for [slot]. Returns the texture id.
  /// Set [bg] to true for background (non-focused) slots — creates a smaller
  /// surface and uses reduced buffers to save decoder/memory resources.
  static Future<int> ensureTexture(int slot, {bool bg = false}) async {
    final id = await _ch.invokeMethod<int>(
        'ensureTexture', {'slot': slot, 'bg': bg});
    if (id == null) {
      throw PlatformException(
          code: 'texture', message: 'Pool slot $slot: no texture id');
    }
    return id;
  }

  /// Load a stream URL on [slot]. Starts buffering immediately.
  static Future<void> load(int slot, String url) =>
      _ch.invokeMethod<void>('load', {'slot': slot, 'url': url});

  /// Ensure playback is running on [slot].
  static Future<void> play(int slot) =>
      _ch.invokeMethod<void>('play', {'slot': slot});

  /// Pause playback on [slot].
  static Future<void> pause(int slot) =>
      _ch.invokeMethod<void>('pause', {'slot': slot});

  /// Stop playback on [slot] (releases network but keeps player alive).
  static Future<void> stop(int slot) =>
      _ch.invokeMethod<void>('stop', {'slot': slot});

  /// Set volume for [slot].  0.0 = mute, 1.0 = full.
  static Future<void> setVolume(int slot, double volume) =>
      _ch.invokeMethod<void>('setVolume', {'slot': slot, 'volume': volume});

  /// Limit the maximum video resolution decoded on [slot].
  /// Pass 0,0 (or omit) to remove the cap and allow full quality.
  static Future<void> setMaxVideoSize(int slot,
      {int maxWidth = 0, int maxHeight = 0}) {
    final w = maxWidth <= 0 ? 2147483647 : maxWidth;
    final h = maxHeight <= 0 ? 2147483647 : maxHeight;
    return _ch.invokeMethod<void>(
        'setMaxVideoSize', {'slot': slot, 'maxWidth': w, 'maxHeight': h});
  }

  /// Release one slot's player + texture.
  static Future<void> releaseSlot(int slot) =>
      _ch.invokeMethod<void>('releaseSlot', {'slot': slot});

  /// Release every slot.
  static Future<void> releaseAll() =>
      _ch.invokeMethod<void>('releaseAll', <String, dynamic>{});

  /// Cap max video **height** on a foreground leapfrog slot (0 = full ladder).
  static Future<void> setUserQualityMaxHeight(int slot, int maxHeightPx) =>
      _ch.invokeMethod<void>('setUserQualityMaxHeight', {
        'slot': slot,
        'maxHeight': maxHeightPx.clamp(0, 1 << 20),
      });

  static Future<({int width, int height})> getPlaybackMetrics(int slot) async {
    final raw = await _ch.invokeMethod<dynamic>('getPlaybackMetrics', {
      'slot': slot,
    });
    if (raw is! Map) return (width: -1, height: -1);
    final m = Map<Object?, Object?>.from(raw);
    int iv(Object? k) {
      final v = m[k];
      if (v is int) return v;
      if (v is double) return v.toInt();
      return -1;
    }

    return (width: iv('videoWidth'), height: iv('videoHeight'));
  }

  static Future<List<int>> getVideoVariantHeights(int slot) async {
    final raw = await _ch.invokeMethod<dynamic>('getVideoVariantHeights', {
      'slot': slot,
    });
    if (raw is! List) return const [];
    final out = <int>[];
    for (final e in raw) {
      if (e is int) {
        if (e > 0) out.add(e);
      } else if (e is double) {
        final v = e.toInt();
        if (v > 0) out.add(v);
      }
    }
    return out;
  }
}
