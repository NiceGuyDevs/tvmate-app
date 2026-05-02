import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-defined Live TV grouping: title, display order, channel ids.
class MySpaceSection {
  const MySpaceSection({
    required this.id,
    required this.title,
    required this.sortOrder,
    required this.channelIds,
  });

  final String id;
  final String title;
  /// Lower numbers appear first (strip + vertical stack).
  final int sortOrder;
  final List<String> channelIds;

  MySpaceSection copyWith({
    String? id,
    String? title,
    int? sortOrder,
    List<String>? channelIds,
  }) {
    return MySpaceSection(
      id: id ?? this.id,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      channelIds: channelIds ?? this.channelIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sortOrder': sortOrder,
        'channelIds': channelIds,
      };

  static MySpaceSection fromJson(Map<String, dynamic> m) {
    return MySpaceSection(
      id: m['id'] as String,
      title: m['title'] as String,
      sortOrder: (m['sortOrder'] as num).toInt(),
      channelIds: List<String>.from(m['channelIds'] as List<dynamic>? ?? const []),
    );
  }
}

/// Persisted My space sections (separate from Live TV categories).
class MySpaceStore extends ChangeNotifier {
  MySpaceStore._();

  static final MySpaceStore instance = MySpaceStore._();

  static const _kPrefsKey = 'tvmatepro_my_space_sections_v1';

  final List<MySpaceSection> _sections = [];
  var _loaded = false;

  List<MySpaceSection> get sectionsUnordered =>
      List.unmodifiable(_sections);

  /// Sorted by [MySpaceSection.sortOrder], then title.
  List<MySpaceSection> get sectionsSorted {
    final copy = List<MySpaceSection>.from(_sections);
    copy.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return copy;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefsKey);
    _sections.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final list = map['sections'] as List<dynamic>? ?? const [];
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            _sections.add(MySpaceSection.fromJson(e));
          }
        }
      } catch (_) {
        // ignore corrupt payload
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'sections': [for (final s in _sections) s.toJson()],
    });
    await p.setString(_kPrefsKey, payload);
  }

  Future<void> addSection({
    required String title,
    required int sortOrder,
    List<String> channelIds = const [],
  }) async {
    await ensureLoaded();
    final id = 'ms_${DateTime.now().microsecondsSinceEpoch}';
    _sections.add(
      MySpaceSection(
        id: id,
        title: title.trim().isEmpty ? 'Untitled' : title.trim(),
        sortOrder: sortOrder,
        channelIds: List<String>.from(channelIds),
      ),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updateSection(MySpaceSection updated) async {
    await ensureLoaded();
    final i = _sections.indexWhere((s) => s.id == updated.id);
    if (i < 0) return;
    _sections[i] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> removeSection(String id) async {
    await ensureLoaded();
    _sections.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> setChannelIds(String sectionId, List<String> ids) async {
    await ensureLoaded();
    final i = _sections.indexWhere((s) => s.id == sectionId);
    if (i < 0) return;
    _sections[i] = _sections[i].copyWith(channelIds: List<String>.from(ids));
    await _persist();
    notifyListeners();
  }

  /// Full replace for backup restore.
  Future<void> replaceFromBackup(Iterable<Map<String, dynamic>> sectionMaps) async {
    await ensureLoaded();
    _sections.clear();
    for (final e in sectionMaps) {
      try {
        _sections.add(MySpaceSection.fromJson(e));
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }
}
