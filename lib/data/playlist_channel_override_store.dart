import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/live_tv/mock_live_tv_data.dart';

/// Per-playlist live channel overrides: custom display name, hide from Live TV, custom logo URL.
final PlaylistChannelOverrideStore playlistChannelOverrideStore =
    PlaylistChannelOverrideStore();

class _ChannelOverride {
  _ChannelOverride({
    this.displayName,
    this.hidden = false,
    this.logoUrl,
  });

  final String? displayName;
  final bool hidden;
  final String? logoUrl;

  Map<String, dynamic> toJson() => {
        if (displayName != null && displayName!.trim().isNotEmpty)
          'name': displayName!.trim(),
        if (hidden) 'hidden': true,
        if (logoUrl != null && logoUrl!.trim().isNotEmpty)
          'logo': logoUrl!.trim(),
      };

  static _ChannelOverride? fromJson(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) return null;
    final name = m['name']?.toString();
    final hidden = m['hidden'] == true;
    final logo = m['logo']?.toString();
    if ((name == null || name.isEmpty) && !hidden && (logo == null || logo.isEmpty)) {
      return null;
    }
    return _ChannelOverride(
      displayName: name != null && name.isNotEmpty ? name : null,
      hidden: hidden,
      logoUrl: logo != null && logo.isNotEmpty ? logo : null,
    );
  }
}

class PlaylistChannelOverrideStore extends ChangeNotifier {
  PlaylistChannelOverrideStore();

  static const _prefsKey = 'tvmatepro_channel_overrides_v1';

  final Map<String, Map<String, _ChannelOverride>> _byPlaylist = {};
  var _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((playlistId, value) {
            if (value is! Map<String, dynamic>) return;
            final inner = <String, _ChannelOverride>{};
            value.forEach((channelId, v) {
              if (v is Map<String, dynamic>) {
                final o = _ChannelOverride.fromJson(v);
                if (o != null) inner[channelId] = o;
              }
            });
            if (inner.isNotEmpty) _byPlaylist[playlistId] = inner;
          });
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  _ChannelOverride? _override(String playlistId, String channelId) =>
      _byPlaylist[playlistId]?[channelId];

  bool isHidden(String playlistId, String channelId) =>
      _override(playlistId, channelId)?.hidden == true;

  /// Custom display name if set, else [serverName].
  String displayName(
    String playlistId,
    String channelId,
    String serverName,
  ) {
    final n = _override(playlistId, channelId)?.displayName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return serverName;
  }

  String? displayNameOverride(String playlistId, String channelId) {
    final n = _override(playlistId, channelId)?.displayName;
    if (n == null || n.trim().isEmpty) return null;
    return n.trim();
  }

  String? logoUrlOverride(String playlistId, String channelId) {
    final u = _override(playlistId, channelId)?.logoUrl;
    if (u == null || u.trim().isEmpty) return null;
    return u.trim();
  }

  /// Applies user overrides to [ch] for this [playlistId] (name + icon URL).
  MockLiveChannel apply(String playlistId, MockLiveChannel ch) {
    final o = _override(playlistId, ch.id);
    if (o == null) return ch;
    var name = ch.name;
    var icon = ch.iconUrl;
    if (o.displayName != null && o.displayName!.trim().isNotEmpty) {
      name = o.displayName!.trim();
    }
    if (o.logoUrl != null && o.logoUrl!.trim().isNotEmpty) {
      icon = o.logoUrl!.trim();
    }
    if (name == ch.name && icon == ch.iconUrl) return ch;
    return ch.copyWith(name: name, iconUrl: icon);
  }

  Future<void> setDisplayName({
    required String playlistId,
    required String channelId,
    required String? displayName,
  }) async {
    await ensureLoaded();
    final map = _byPlaylist.putIfAbsent(playlistId, () => {});
    final prev = map[channelId];
    final t = displayName?.trim() ?? '';
    final next = _ChannelOverride(
      displayName: t.isEmpty ? null : t,
      hidden: prev?.hidden ?? false,
      logoUrl: prev?.logoUrl,
    );
    if (_isEmptyOverride(next)) {
      map.remove(channelId);
    } else {
      map[channelId] = next;
    }
    _prunePlaylist(playlistId);
    await _persist();
    notifyListeners();
  }

  Future<void> setHidden({
    required String playlistId,
    required String channelId,
    required bool hidden,
  }) async {
    await ensureLoaded();
    final map = _byPlaylist.putIfAbsent(playlistId, () => {});
    final prev = map[channelId];
    final next = _ChannelOverride(
      displayName: prev?.displayName,
      hidden: hidden,
      logoUrl: prev?.logoUrl,
    );
    if (_isEmptyOverride(next)) {
      map.remove(channelId);
    } else {
      map[channelId] = next;
    }
    _prunePlaylist(playlistId);
    await _persist();
    notifyListeners();
  }

  Future<void> setLogoUrl({
    required String playlistId,
    required String channelId,
    required String? logoUrl,
  }) async {
    await ensureLoaded();
    final map = _byPlaylist.putIfAbsent(playlistId, () => {});
    final prev = map[channelId];
    final t = logoUrl?.trim() ?? '';
    final next = _ChannelOverride(
      displayName: prev?.displayName,
      hidden: prev?.hidden ?? false,
      logoUrl: t.isEmpty ? null : t,
    );
    if (_isEmptyOverride(next)) {
      map.remove(channelId);
    } else {
      map[channelId] = next;
    }
    _prunePlaylist(playlistId);
    await _persist();
    notifyListeners();
  }

  bool _isEmptyOverride(_ChannelOverride o) {
    final hasName = o.displayName != null && o.displayName!.trim().isNotEmpty;
    final hasLogo = o.logoUrl != null && o.logoUrl!.trim().isNotEmpty;
    return !o.hidden && !hasName && !hasLogo;
  }

  void _prunePlaylist(String playlistId) {
    final m = _byPlaylist[playlistId];
    if (m == null || m.isEmpty) return;
    if (m.values.every(_isEmptyOverride)) {
      _byPlaylist.remove(playlistId);
    }
  }

  /// Serializes all per-playlist channel overrides for backup JSON.
  Map<String, dynamic> exportForBackup() {
    final out = <String, dynamic>{};
    _byPlaylist.forEach((pid, channels) {
      final inner = <String, dynamic>{};
      channels.forEach((cid, o) {
        final j = o.toJson();
        if (j.isNotEmpty) inner[cid] = j;
      });
      if (inner.isNotEmpty) out[pid] = inner;
    });
    return out;
  }

  /// Full replace from backup restore (after library playlists are applied).
  Future<void> replaceFromBackup(Map<String, dynamic>? encoded) async {
    await ensureLoaded();
    _byPlaylist.clear();
    if (encoded != null) {
      encoded.forEach((playlistId, value) {
        if (value is! Map<String, dynamic>) return;
        final inner = <String, _ChannelOverride>{};
        value.forEach((channelId, v) {
          if (v is Map<String, dynamic>) {
            final o = _ChannelOverride.fromJson(v);
            if (o != null) inner[channelId] = o;
          }
        });
        if (inner.isNotEmpty) _byPlaylist[playlistId] = inner;
      });
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final out = <String, dynamic>{};
    _byPlaylist.forEach((pid, channels) {
      final inner = <String, dynamic>{};
      channels.forEach((cid, o) {
        final j = o.toJson();
        if (j.isNotEmpty) inner[cid] = j;
      });
      if (inner.isNotEmpty) out[pid] = inner;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(out));
  }
}
