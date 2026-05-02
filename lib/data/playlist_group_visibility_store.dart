import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlaylistGroupSection { live, vod, series }

extension PlaylistGroupSectionStorage on PlaylistGroupSection {
  String get storageKey => switch (this) {
        PlaylistGroupSection.live => 'live',
        PlaylistGroupSection.vod => 'vod',
        PlaylistGroupSection.series => 'series',
      };
}

class PlaylistGroupVisibilityStore extends ChangeNotifier {
  static const _kPrefsKey = 'tvmatepro_group_visibility_v1';

  final Map<String, _PlaylistVisibilityRules> _rulesByPlaylist = {};
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
            _rulesByPlaylist[playlistId] =
                _PlaylistVisibilityRules.fromJson(value);
          }
        });
      }
    }
    _loaded = true;
    notifyListeners();
  }

  bool isCategoryVisible(
    String playlistId,
    PlaylistGroupSection section,
    String categoryId,
  ) {
    final rules = _rulesByPlaylist[playlistId];
    if (rules == null) return true;
    return !rules.hiddenFor(section).contains(categoryId);
  }

  /// Shown in browse UI; uses custom alias when set, otherwise [serverName].
  String categoryDisplayName(
    String playlistId,
    PlaylistGroupSection section,
    String categoryId,
    String serverName,
  ) {
    final rules = _rulesByPlaylist[playlistId];
    if (rules == null) return serverName;
    final a = rules.aliasFor(section, categoryId);
    if (a == null || a.trim().isEmpty) return serverName;
    return a.trim();
  }

  /// Custom label if any (trimmed), or null / empty when using server name.
  String? categoryAlias(
    String playlistId,
    PlaylistGroupSection section,
    String categoryId,
  ) {
    final rules = _rulesByPlaylist[playlistId];
    if (rules == null) return null;
    final a = rules.aliasFor(section, categoryId);
    if (a == null || a.trim().isEmpty) return null;
    return a.trim();
  }

  Future<void> setCategoryAlias({
    required String playlistId,
    required PlaylistGroupSection section,
    required String categoryId,
    required String? alias,
  }) async {
    await ensureLoaded();
    final rules = _rulesByPlaylist.putIfAbsent(
      playlistId,
      () => _PlaylistVisibilityRules(),
    );
    final t = alias?.trim() ?? '';
    if (t.isEmpty) {
      rules.removeAlias(section, categoryId);
    } else {
      rules.setAlias(section, categoryId, t);
    }
    await _persist();
    notifyListeners();
  }

  // ── Live TV: category pills before favorite groups (ordered left → right) ──

  /// Ordered playlist category ids pinned to appear **before** favorite pills.
  List<String> liveBeforeFavoritesOrderedIds(String playlistId) {
    final rules = _rulesByPlaylist[playlistId];
    if (rules == null) return const [];
    return List<String>.from(rules.liveBeforeFavoritesOrder);
  }

  bool isLiveCategoryBeforeFavorites(String playlistId, String categoryId) {
    return liveBeforeFavoritesOrderedIds(playlistId).contains(categoryId);
  }

  /// 1-based index among “before favorites” categories, or **0** if not pinned there.
  int liveBeforeFavoritesOneBasedPosition(String playlistId, String categoryId) {
    final list = liveBeforeFavoritesOrderedIds(playlistId);
    final i = list.indexOf(categoryId);
    if (i < 0) return 0;
    return i + 1;
  }

  Future<void> setLiveCategoryBeforeFavorites({
    required String playlistId,
    required String categoryId,
    required bool before,
  }) async {
    await ensureLoaded();
    final rules = _rulesByPlaylist.putIfAbsent(
      playlistId,
      () => _PlaylistVisibilityRules(),
    );
    final list = rules.liveBeforeFavoritesOrder;
    if (before) {
      if (!list.contains(categoryId)) {
        list.add(categoryId);
      }
    } else {
      list.remove(categoryId);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setLiveBeforeFavoritesOneBasedPosition({
    required String playlistId,
    required String categoryId,
    required int oneBasedPosition,
  }) async {
    await ensureLoaded();
    final rules = _rulesByPlaylist.putIfAbsent(
      playlistId,
      () => _PlaylistVisibilityRules(),
    );
    final list = rules.liveBeforeFavoritesOrder;
    if (!list.contains(categoryId)) return;
    list.remove(categoryId);
    final idx = (oneBasedPosition - 1).clamp(0, list.length);
    list.insert(idx, categoryId);
    await _persist();
    notifyListeners();
  }

  int countVisibleCategories(
    String playlistId,
    PlaylistGroupSection section,
    Iterable<String> categoryIds,
  ) {
    var count = 0;
    for (final id in categoryIds) {
      if (isCategoryVisible(playlistId, section, id)) {
        count++;
      }
    }
    return count;
  }

  Future<void> setCategoryVisible({
    required String playlistId,
    required PlaylistGroupSection section,
    required String categoryId,
    required bool visible,
  }) async {
    await ensureLoaded();
    final rules = _rulesByPlaylist.putIfAbsent(
      playlistId,
      () => _PlaylistVisibilityRules(),
    );
    final hidden = rules.hiddenFor(section);
    if (visible) {
      hidden.remove(categoryId);
    } else {
      hidden.add(categoryId);
      if (section == PlaylistGroupSection.live) {
        rules.liveBeforeFavoritesOrder.remove(categoryId);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setAllVisible({
    required String playlistId,
    required PlaylistGroupSection section,
    required Iterable<String> categoryIds,
    required bool visible,
  }) async {
    await ensureLoaded();
    final rules = _rulesByPlaylist.putIfAbsent(
      playlistId,
      () => _PlaylistVisibilityRules(),
    );
    final hidden = rules.hiddenFor(section);
    if (visible) {
      for (final id in categoryIds) {
        hidden.remove(id);
      }
    } else {
      hidden.addAll(categoryIds);
      if (section == PlaylistGroupSection.live) {
        for (final id in categoryIds) {
          rules.liveBeforeFavoritesOrder.remove(id);
        }
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removePlaylist(String playlistId) async {
    await ensureLoaded();
    final removed = _rulesByPlaylist.remove(playlistId);
    if (removed == null) return;
    await _persist();
    notifyListeners();
  }

  /// Serialized playlist id → hidden rules (same shape as prefs payload).
  Map<String, dynamic> exportForBackup() {
    final encoded = <String, dynamic>{};
    _rulesByPlaylist.forEach((playlistId, rules) {
      encoded[playlistId] = rules.toJson();
    });
    return encoded;
  }

  /// Full replace for backup restore (after library playlists match ids).
  Future<void> replaceFromBackup(Map<String, dynamic>? encoded) async {
    await ensureLoaded();
    _rulesByPlaylist.clear();
    if (encoded != null) {
      encoded.forEach((playlistId, value) {
        if (value is Map<String, dynamic>) {
          _rulesByPlaylist[playlistId] =
              _PlaylistVisibilityRules.fromJson(value);
        }
      });
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, dynamic>{};
    _rulesByPlaylist.forEach((playlistId, rules) {
      encoded[playlistId] = rules.toJson();
    });
    await prefs.setString(_kPrefsKey, jsonEncode(encoded));
  }
}

class _PlaylistVisibilityRules {
  _PlaylistVisibilityRules();

  final Map<PlaylistGroupSection, Set<String>> _hidden = {
    PlaylistGroupSection.live: <String>{},
    PlaylistGroupSection.vod: <String>{},
    PlaylistGroupSection.series: <String>{},
  };

  final Map<PlaylistGroupSection, Map<String, String>> _aliases = {
    PlaylistGroupSection.live: {},
    PlaylistGroupSection.vod: {},
    PlaylistGroupSection.series: {},
  };

  /// Live TV only: left-to-right order of playlist category ids **before** favorite pills.
  final List<String> liveBeforeFavoritesOrder = <String>[];

  Set<String> hiddenFor(PlaylistGroupSection section) => _hidden[section]!;

  String? aliasFor(PlaylistGroupSection section, String categoryId) =>
      _aliases[section]?[categoryId];

  void setAlias(PlaylistGroupSection section, String categoryId, String value) {
    _aliases[section]![categoryId] = value;
  }

  void removeAlias(PlaylistGroupSection section, String categoryId) {
    _aliases[section]?.remove(categoryId);
  }

  Map<String, dynamic> toJson() {
    final base = {
      for (final section in PlaylistGroupSection.values)
        section.storageKey: hiddenFor(section).toList(growable: false),
    };
    final aliasObj = <String, dynamic>{};
    for (final section in PlaylistGroupSection.values) {
      final m = _aliases[section]!;
      if (m.isEmpty) continue;
      aliasObj[section.storageKey] = Map<String, String>.from(m);
    }
    final outMap = {...base, if (aliasObj.isNotEmpty) 'aliases': aliasObj};
    if (liveBeforeFavoritesOrder.isNotEmpty) {
      return {
        ...outMap,
        'liveBeforeFavorites': List<String>.from(liveBeforeFavoritesOrder),
      };
    }
    return outMap;
  }

  factory _PlaylistVisibilityRules.fromJson(Map<String, dynamic> json) {
    final out = _PlaylistVisibilityRules();
    for (final section in PlaylistGroupSection.values) {
      final list = json[section.storageKey];
      if (list is List) {
        out.hiddenFor(section)
            .addAll(list.whereType<String>().where((e) => e.trim().isNotEmpty));
      }
    }
    final aliasRoot = json['aliases'];
    if (aliasRoot is Map<String, dynamic>) {
      for (final section in PlaylistGroupSection.values) {
        final raw = aliasRoot[section.storageKey];
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String &&
                v is String &&
                k.trim().isNotEmpty &&
                v.trim().isNotEmpty) {
              out.setAlias(section, k.trim(), v.trim());
            }
          });
        }
      }
    }
    final bf = json['liveBeforeFavorites'];
    if (bf is List) {
      for (final e in bf) {
        if (e is String && e.trim().isNotEmpty) {
          out.liveBeforeFavoritesOrder.add(e.trim());
        }
      }
    }
    return out;
  }
}

final PlaylistGroupVisibilityStore playlistGroupVisibilityStore =
    PlaylistGroupVisibilityStore();
