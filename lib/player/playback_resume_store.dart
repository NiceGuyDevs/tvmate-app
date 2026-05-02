import 'package:shared_preferences/shared_preferences.dart';

/// Persists last playback position (ms) for VOD (movies / episodes).
class PlaybackResumeStore {
  static const _prefix = 'tvmatepro_resume_ms_';

  static Future<int?> getResumePositionMs(String contentId) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('$_prefix$contentId');
  }

  static Future<void> setResumePositionMs(String contentId, int ms) async {
    if (ms < 0) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_prefix$contentId', ms);
  }

  static Future<void> clear(String contentId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_prefix$contentId');
  }

  /// Clears resume keys for episodes (ids without `episode_` prefix — same as [resumeContentId] after prefix).
  static Future<void> clearEpisodeResumes(Iterable<String> episodeIds) async {
    for (final id in episodeIds) {
      await clear('episode_$id');
    }
  }

  /// All stored positions: keys are full content ids (`movie_x`, `episode_y`, …).
  static Future<Map<String, int>> exportForBackup() async {
    final p = await SharedPreferences.getInstance();
    final out = <String, int>{};
    for (final k in p.getKeys()) {
      if (!k.startsWith(_prefix)) continue;
      final id = k.substring(_prefix.length);
      final v = p.getInt(k);
      if (v != null) out[id] = v;
    }
    return out;
  }

  /// Merges saved positions from backup (does not remove keys missing from [map]).
  static Future<void> applyFromBackup(Map<String, dynamic>? map) async {
    if (map == null) return;
    for (final e in map.entries) {
      final v = e.value;
      if (v is num) {
        await setResumePositionMs(e.key, v.toInt());
      }
    }
  }
}
