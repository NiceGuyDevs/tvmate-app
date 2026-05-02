import 'package:shared_preferences/shared_preferences.dart';

/// On-device: remembers the last *manual* OpenSubtitles [query] per VOD
/// [resumeContentId] so the next open can merge automatic + that search.
class VodSubtitleSearchMemoryStore {
  static const _prefix = 'tvmatepro_vod_sub_manual_query_';

  static Future<String?> getManualQuery(String contentId) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('$_prefix$contentId')?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static Future<void> setManualQuery(String contentId, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('$_prefix$contentId', q);
  }

  static Future<void> clear(String contentId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_prefix$contentId');
  }
}
