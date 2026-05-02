import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device timezone — programme times follow the device clock.
const String kEpgDisplayModeLocal = 'local';

/// Server wall time from raw EPG strings (legacy “Original”).
const String kEpgDisplayModeOriginal = 'original';

/// Persists per-playlist EPG time display preference and server timezone offset.
///
/// Display mode: [kEpgDisplayModeLocal] (default), [kEpgDisplayModeOriginal], or
/// an IANA zone id (e.g. `Asia/Jerusalem`) from [kEpgTimezoneCatalog].
///
/// `serverUtcOffsetHours`: UTC offset of the Xtream server from `server_info.timezone`.
/// Used for catch-up URLs, not for EPG label formatting.
class PlaylistEpgTimezoneStore extends ChangeNotifier {
  PlaylistEpgTimezoneStore._();

  static final PlaylistEpgTimezoneStore instance = PlaylistEpgTimezoneStore._();

  static const _prefixMode = 'tvmatepro_epg_display_mode_';
  static const _prefixLocalLegacy = 'tvmatepro_epg_tz_local_';
  static const _prefixOffset = 'tvmatepro_epg_server_utc_offset_';
  bool _loaded = false;
  final Map<String, String> _modeMap = {};
  final Map<String, double> _offsetMap = {};

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefixMode)) {
        final playlistId = key.substring(_prefixMode.length);
        final v = prefs.getString(key);
        if (v != null && v.isNotEmpty) {
          _modeMap[playlistId] = v;
        }
      } else if (key.startsWith(_prefixLocalLegacy)) {
        final playlistId = key.substring(_prefixLocalLegacy.length);
        if (_modeMap.containsKey(playlistId)) continue;
        final legacy = prefs.getBool(key);
        if (legacy != null) {
          _modeMap[playlistId] =
              legacy ? kEpgDisplayModeLocal : kEpgDisplayModeOriginal;
        }
      } else if (key.startsWith(_prefixOffset)) {
        final playlistId = key.substring(_prefixOffset.length);
        _offsetMap[playlistId] = prefs.getDouble(key) ?? 0;
      }
    }
    _loaded = true;
  }

  /// Effective mode: defaults to [kEpgDisplayModeLocal].
  String epgDisplayMode(String playlistId) =>
      _modeMap[playlistId] ?? kEpgDisplayModeLocal;

  /// Legacy helper — true when showing device-local times.
  bool useLocalTime(String playlistId) {
    final m = epgDisplayMode(playlistId);
    return m == kEpgDisplayModeLocal || m.isEmpty;
  }

  /// UTC offset in hours for the server associated with this playlist.
  double serverUtcOffsetHours(String playlistId) =>
      _offsetMap[playlistId] ?? 0;

  Future<void> setEpgDisplayMode(String playlistId, String mode) async {
    _modeMap[playlistId] = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefixMode$playlistId', mode);
    await prefs.remove('$_prefixLocalLegacy$playlistId');
  }

  Future<void> setServerUtcOffset(
    String playlistId,
    double offsetHours,
  ) async {
    _offsetMap[playlistId] = offsetHours;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_prefixOffset$playlistId', offsetHours);
  }

  /// Serializes all per-playlist EPG modes + server offsets for backup JSON.
  Map<String, dynamic> exportForBackup() {
    final out = <String, dynamic>{};
    final allIds = <String>{..._modeMap.keys, ..._offsetMap.keys};
    for (final id in allIds) {
      final entry = <String, dynamic>{};
      final mode = _modeMap[id];
      if (mode != null && mode.isNotEmpty) entry['mode'] = mode;
      final offset = _offsetMap[id];
      if (offset != null && offset != 0) entry['serverUtcOffset'] = offset;
      if (entry.isNotEmpty) out[id] = entry;
    }
    return out;
  }

  /// Full replace from backup restore (after library playlists are applied).
  Future<void> replaceFromBackup(Map<String, dynamic>? encoded) async {
    await ensureLoaded();
    _modeMap.clear();
    _offsetMap.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in List<String>.from(prefs.getKeys())) {
      if (key.startsWith(_prefixMode) ||
          key.startsWith(_prefixLocalLegacy) ||
          key.startsWith(_prefixOffset)) {
        await prefs.remove(key);
      }
    }
    if (encoded != null) {
      for (final entry in encoded.entries) {
        final playlistId = entry.key;
        final v = entry.value;
        if (v is! Map<String, dynamic>) continue;
        final mode = v['mode']?.toString();
        if (mode != null && mode.isNotEmpty) {
          _modeMap[playlistId] = mode;
          await prefs.setString('$_prefixMode$playlistId', mode);
        }
        final offset = v['serverUtcOffset'];
        if (offset is num && offset != 0) {
          _offsetMap[playlistId] = offset.toDouble();
          await prefs.setDouble(
            '$_prefixOffset$playlistId',
            offset.toDouble(),
          );
        }
      }
    }
    notifyListeners();
  }

  Future<void> removePlaylist(String playlistId) async {
    _modeMap.remove(playlistId);
    _offsetMap.remove(playlistId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefixMode$playlistId');
    await prefs.remove('$_prefixLocalLegacy$playlistId');
    await prefs.remove('$_prefixOffset$playlistId');
  }
}

final playlistEpgTimezoneStore = PlaylistEpgTimezoneStore.instance;
