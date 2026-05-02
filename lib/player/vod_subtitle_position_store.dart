import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists VOD subtitle **position** (logical px, same space as [SubtitleAppearanceStore])
/// per [resumeContentId], so each title remembers its own placement.
class VodSubtitlePositionStore {
  static const _prefixDx = 'tvmatepro_vod_subpos_dx_';
  static const _prefixDy = 'tvmatepro_vod_subpos_dy_';

  /// Returns null if this movie has no saved override (use global appearance).
  static Future<Offset?> getIfSet(String contentId) async {
    final p = await SharedPreferences.getInstance();
    final kx = '$_prefixDx$contentId';
    if (!p.containsKey(kx)) return null;
    final dx = p.getDouble(kx) ?? 0;
    final dy = p.getDouble('$_prefixDy$contentId') ?? 0;
    return Offset(dx, dy);
  }

  static Future<void> setOffset(String contentId, Offset o) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('$_prefixDx$contentId', o.dx);
    await p.setDouble('$_prefixDy$contentId', o.dy);
  }

  static Future<void> clear(String contentId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('$_prefixDx$contentId');
    await p.remove('$_prefixDy$contentId');
  }
}
