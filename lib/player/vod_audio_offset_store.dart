import 'package:shared_preferences/shared_preferences.dart';

/// Persists VOD A/V sync offset (ms) per [resumeContentId] (same key family as resume).
class VodAudioOffsetStore {
  static const _prefix = 'tvmatepro_vod_audio_ms_';

  static const int minMs = -2000;
  static const int maxMs = 2000;

  static Future<int> getOffsetMs(String contentId) async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt('$_prefix$contentId') ?? 0;
    return v.clamp(minMs, maxMs);
  }

  static Future<void> setOffsetMs(String contentId, int ms) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_prefix$contentId', ms.clamp(minMs, maxMs));
  }

  static Future<void> clear(String contentId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_prefix$contentId');
  }

  /// Keys are content ids (`movie_x`, `episode_y`, …); values are ms in [-2000, 2000].
  static Future<Map<String, int>> exportForBackup() async {
    final p = await SharedPreferences.getInstance();
    final out = <String, int>{};
    for (final k in p.getKeys()) {
      if (!k.startsWith(_prefix)) continue;
      final id = k.substring(_prefix.length);
      final v = p.getInt(k);
      if (v != null) out[id] = v.clamp(minMs, maxMs);
    }
    return out;
  }

  static Future<void> applyFromBackup(Map<String, dynamic>? map) async {
    if (map == null) return;
    for (final e in map.entries) {
      final v = e.value;
      if (v is num) {
        await setOffsetMs(e.key, v.toInt());
      }
    }
  }
}
