import 'package:shared_preferences/shared_preferences.dart';

/// On-device: external subtitle timing (ms) per [resumeContentId] for VOD.
/// Positive = show subtitles later; negative = earlier vs file times.
class VodSubtitleDelayStore {
  static const _prefix = 'tvmatepro_vod_sub_delay_ms_';

  static const int minMs = -10000;
  static const int maxMs = 10000;

  static Future<int> getOffsetMs(String contentId) async {
    final p = await SharedPreferences.getInstance();
    final v = p.getInt('$_prefix$contentId') ?? 0;
    return v.clamp(minMs, maxMs);
  }

  static Future<void> setOffsetMs(String contentId, int ms) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_prefix$contentId', ms.clamp(minMs, maxMs));
  }
}
