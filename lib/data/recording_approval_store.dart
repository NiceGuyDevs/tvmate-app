import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which playlists / categories / channels are approved for the
/// Recording (catch-up / EPG) feature.
///
/// Structure per playlist:
/// ```json
/// {
///   "approvedCategories": ["catId1", "catId2"],
///   "approvedChannels": { "catId1": ["chId1", "chId2"], ... },
///   "filterCatchupOnly": false,
///   "tvFrameEpg": false  // Recording EPG: channel logo inside TV frame asset
/// }
/// ```
class RecordingApprovalStore extends ChangeNotifier {
  static const _kPrefsKey = 'tvmatepro_recording_approval_v1';

  final Map<String, _PlaylistApproval> _byPlaylist = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((playlistId, value) {
          if (value is Map<String, dynamic>) {
            _byPlaylist[playlistId] = _PlaylistApproval.fromJson(value);
          }
        });
      }
    }
    _loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Playlist level
  // ---------------------------------------------------------------------------

  bool isPlaylistApproved(String playlistId) =>
      _byPlaylist.containsKey(playlistId) &&
      _byPlaylist[playlistId]!.approvedCategories.isNotEmpty;

  List<String> get approvedPlaylistIds =>
      _byPlaylist.keys.where((id) => isPlaylistApproved(id)).toList();

  // ---------------------------------------------------------------------------
  // Category level
  // ---------------------------------------------------------------------------

  Set<String> approvedCategoryIds(String playlistId) =>
      _byPlaylist[playlistId]?.approvedCategories ?? const {};

  Future<void> setCategoryApproved({
    required String playlistId,
    required String categoryId,
    required bool approved,
  }) async {
    await ensureLoaded();
    final a = _byPlaylist.putIfAbsent(playlistId, _PlaylistApproval.new);
    if (approved) {
      a.approvedCategories.add(categoryId);
    } else {
      a.approvedCategories.remove(categoryId);
      a.approvedChannels.remove(categoryId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setAllCategoriesApproved({
    required String playlistId,
    required Iterable<String> categoryIds,
    required bool approved,
  }) async {
    await ensureLoaded();
    final a = _byPlaylist.putIfAbsent(playlistId, _PlaylistApproval.new);
    if (approved) {
      a.approvedCategories.addAll(categoryIds);
    } else {
      for (final id in categoryIds) {
        a.approvedCategories.remove(id);
        a.approvedChannels.remove(id);
      }
    }
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Channel level
  // ---------------------------------------------------------------------------

  Set<String> approvedChannelIds(String playlistId, String categoryId) =>
      _byPlaylist[playlistId]?.approvedChannels[categoryId] ?? const {};

  Future<void> setChannelApproved({
    required String playlistId,
    required String categoryId,
    required String channelId,
    required bool approved,
  }) async {
    await ensureLoaded();
    final a = _byPlaylist.putIfAbsent(playlistId, _PlaylistApproval.new);
    final channels =
        a.approvedChannels.putIfAbsent(categoryId, () => <String>{});
    if (approved) {
      channels.add(channelId);
    } else {
      channels.remove(channelId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setAllChannelsApproved({
    required String playlistId,
    required String categoryId,
    required Iterable<String> channelIds,
    required bool approved,
  }) async {
    await ensureLoaded();
    final a = _byPlaylist.putIfAbsent(playlistId, _PlaylistApproval.new);
    final channels =
        a.approvedChannels.putIfAbsent(categoryId, () => <String>{});
    if (approved) {
      channels.addAll(channelIds);
    } else {
      for (final id in channelIds) {
        channels.remove(id);
      }
    }
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Recording filter (hide non–catch-up channels; key name kept for prefs)
  // ---------------------------------------------------------------------------

  bool filterCatchupOnly(String playlistId) =>
      _byPlaylist[playlistId]?.filterCatchupOnly ?? false;

  Future<void> setFilterCatchupOnly({
    required String playlistId,
    required bool value,
  }) async {
    await ensureLoaded();
    final a = _byPlaylist.putIfAbsent(playlistId, _PlaylistApproval.new);
    a.filterCatchupOnly = value;
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Recording EPG: TV frame around channel logo (Recording screen only)
  // ---------------------------------------------------------------------------

  bool tvFrameEpg(String playlistId) =>
      _byPlaylist[playlistId]?.tvFrameEpg ?? false;

  Future<void> setTvFrameEpg({
    required String playlistId,
    required bool value,
  }) async {
    await ensureLoaded();
    final a = _byPlaylist.putIfAbsent(playlistId, _PlaylistApproval.new);
    a.tvFrameEpg = value;
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  Map<String, dynamic> exportForBackup() {
    final out = <String, dynamic>{};
    _byPlaylist.forEach((id, a) {
      out[id] = a.toJson();
    });
    return out;
  }

  Future<void> replaceFromBackup(Map<String, dynamic>? encoded) async {
    await ensureLoaded();
    _byPlaylist.clear();
    if (encoded != null) {
      encoded.forEach((id, value) {
        if (value is Map<String, dynamic>) {
          _byPlaylist[id] = _PlaylistApproval.fromJson(value);
        }
      });
    }
    await _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    _byPlaylist.forEach((id, a) {
      out[id] = a.toJson();
    });
    await prefs.setString(_kPrefsKey, jsonEncode(out));
  }
}

// ---------------------------------------------------------------------------
// Internal model
// ---------------------------------------------------------------------------

class _PlaylistApproval {
  _PlaylistApproval();

  final Set<String> approvedCategories = {};
  final Map<String, Set<String>> approvedChannels = {};
  bool filterCatchupOnly = false;
  bool tvFrameEpg = false;

  Map<String, dynamic> toJson() => {
        'approvedCategories': approvedCategories.toList(growable: false),
        'approvedChannels': {
          for (final entry in approvedChannels.entries)
            entry.key: entry.value.toList(growable: false),
        },
        'filterCatchupOnly': filterCatchupOnly,
        'tvFrameEpg': tvFrameEpg,
      };

  factory _PlaylistApproval.fromJson(Map<String, dynamic> json) {
    final a = _PlaylistApproval();
    final cats = json['approvedCategories'];
    if (cats is List) {
      a.approvedCategories
          .addAll(cats.whereType<String>().where((e) => e.trim().isNotEmpty));
    }
    final chans = json['approvedChannels'];
    if (chans is Map<String, dynamic>) {
      chans.forEach((catId, list) {
        if (list is List) {
          a.approvedChannels[catId] = list
              .whereType<String>()
              .where((e) => e.trim().isNotEmpty)
              .toSet();
        }
      });
    }
    a.filterCatchupOnly = json['filterCatchupOnly'] == true;
    a.tvFrameEpg = json['tvFrameEpg'] == true;
    return a;
  }
}

final RecordingApprovalStore recordingApprovalStore = RecordingApprovalStore();
