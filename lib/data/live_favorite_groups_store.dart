import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_favorite_channel_ref.dart';

/// One user-named favorite list for Live TV (pill title + ordered channels).
@immutable
class LiveFavoriteGroup {
  const LiveFavoriteGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.channelRefs,
    this.color,
  });

  final String id;
  final String name;
  /// Lower numbers appear first among favorite pills.
  final int sortOrder;
  /// Optional accent color for the new settings UI (hex, e.g. `#4DD0E1`). Ignored
  /// by the legacy settings editor.
  final String? color;
  /// Playback / grid order: first added = first in list.
  ///
  /// [LiveFavoriteChannelRef.playlistId] empty = legacy (resolve vs active catalog).
  final List<LiveFavoriteChannelRef> channelRefs;

  LiveFavoriteGroup copyWith({
    String? id,
    String? name,
    int? sortOrder,
    String? color,
    List<LiveFavoriteChannelRef>? channelRefs,
  }) {
    return LiveFavoriteGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      color: color ?? this.color,
      channelRefs: channelRefs ?? this.channelRefs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
        'channelRefs': [for (final r in channelRefs) r.toJson()],
        if (color != null) 'color': color,
      };

  static LiveFavoriteGroup fromJson(Map<String, dynamic> m) {
    if (m.containsKey('channelRefs')) {
      final refsRaw = m['channelRefs'] as List<dynamic>? ?? const [];
      return LiveFavoriteGroup(
        id: m['id'] as String,
        name: m['name'] as String,
        sortOrder: (m['sortOrder'] as num).toInt(),
        color: m['color'] as String?,
        channelRefs: [
          for (final e in refsRaw)
            if (e is Map<String, dynamic>)
              LiveFavoriteChannelRef.fromJson(e),
        ],
      );
    }
    final legacyIds = List<String>.from(
      m['channelIds'] as List<dynamic>? ?? const [],
    );
    return LiveFavoriteGroup(
      id: m['id'] as String,
      name: m['name'] as String,
      sortOrder: (m['sortOrder'] as num).toInt(),
      color: m['color'] as String?,
      channelRefs: [
        for (final id in legacyIds) LiveFavoriteChannelRef(playlistId: '', channelId: id),
      ],
    );
  }
}

/// Persisted favorite groups (replaces single flat [MyListStore] live list for Live TV UI).
class LiveFavoriteGroupsStore extends ChangeNotifier {
  LiveFavoriteGroupsStore._();

  static final LiveFavoriteGroupsStore instance = LiveFavoriteGroupsStore._();

  static const _kPrefsKey = 'tvmatepro_live_favorite_groups_v1';
  static const _kLegacyLiveListKey = 'my_list_live_channel_ids';

  final List<LiveFavoriteGroup> _groups = [];
  var _loaded = false;

  bool get isLoaded => _loaded;

  List<LiveFavoriteGroup> get groupsUnordered => List.unmodifiable(_groups);

  /// Sorted by [LiveFavoriteGroup.sortOrder], then name.
  List<LiveFavoriteGroup> get groupsSorted {
    final copy = List<LiveFavoriteGroup>.from(_groups);
    copy.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  LiveFavoriteGroup? groupById(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefsKey);
    _groups.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final list = map['groups'] as List<dynamic>? ?? const [];
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            _groups.add(LiveFavoriteGroup.fromJson(e));
          }
        }
      } catch (_) {}
    }
    if (_groups.isEmpty) {
      final legacy = p.getStringList(_kLegacyLiveListKey);
      if (legacy != null && legacy.isNotEmpty) {
        _groups.add(
          LiveFavoriteGroup(
            id: _newId(),
            name: 'My favorites',
            sortOrder: 0,
            color: null,
            channelRefs: [
              for (final id in legacy)
                LiveFavoriteChannelRef(playlistId: '', channelId: id),
            ],
          ),
        );
        await _persist();
        await p.setStringList(_kLegacyLiveListKey, []);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'groups': [for (final g in _groups) g.toJson()],
    });
    await prefs.setString(_kPrefsKey, payload);
  }

  String _newId() => 'lf_${DateTime.now().microsecondsSinceEpoch}';

  /// Next suggested sort order (max + 1).
  int suggestedSortOrder() {
    if (_groups.isEmpty) return 0;
    var m = _groups.first.sortOrder;
    for (final g in _groups) {
      if (g.sortOrder > m) m = g.sortOrder;
    }
    return m + 1;
  }

  Future<LiveFavoriteGroup> addGroup({
    required String name,
    required int sortOrder,
    List<LiveFavoriteChannelRef> channelRefs = const [],
    String? color,
  }) async {
    await ensureLoaded();
    final g = LiveFavoriteGroup(
      id: _newId(),
      name: name.trim().isEmpty ? 'Favorite' : name.trim(),
      sortOrder: sortOrder,
      color: color,
      channelRefs: List<LiveFavoriteChannelRef>.from(channelRefs),
    );
    _groups.add(g);
    await _persist();
    notifyListeners();
    return g;
  }

  Future<void> updateGroup(LiveFavoriteGroup updated) async {
    await ensureLoaded();
    final i = _groups.indexWhere((g) => g.id == updated.id);
    if (i < 0) return;
    _groups[i] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> removeGroup(String id) async {
    await ensureLoaded();
    _groups.removeWhere((g) => g.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> setChannelRefs(
    String groupId,
    List<LiveFavoriteChannelRef> orderedRefs,
  ) async {
    await ensureLoaded();
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i < 0) return;
    _groups[i] = _groups[i].copyWith(
      channelRefs: List<LiveFavoriteChannelRef>.from(orderedRefs),
    );
    await _persist();
    notifyListeners();
  }

  /// Full replace for backup restore.
  Future<void> replaceFromBackup(Iterable<Map<String, dynamic>> groupMaps) async {
    await ensureLoaded();
    _groups.clear();
    for (final e in groupMaps) {
      try {
        _groups.add(LiveFavoriteGroup.fromJson(e));
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }
}
