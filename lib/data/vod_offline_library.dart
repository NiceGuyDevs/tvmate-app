import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One saved VOD file on Android (app-private storage + index).
final class VodOfflineItem {
  const VodOfflineItem({
    required this.id,
    required this.title,
    required this.filePath,
    required this.sizeBytes,
    required this.savedAt,
    this.posterUrl,
  });

  final String id;
  final String title;
  final String filePath;
  final int sizeBytes;
  final DateTime savedAt;
  final String? posterUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'savedAt': savedAt.toIso8601String(),
        'posterUrl': posterUrl,
      };

  factory VodOfflineItem.fromJson(Map<String, dynamic> j) {
    return VodOfflineItem(
      id: j['id'] as String,
      title: j['title'] as String,
      filePath: j['filePath'] as String,
      sizeBytes: (j['sizeBytes'] as num).toInt(),
      savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      posterUrl: j['posterUrl'] as String?,
    );
  }
}

/// Fixed app-private folder + JSON index (Android offline downloads).
final class VodOfflineLibrary extends ChangeNotifier {
  VodOfflineLibrary._();
  static final VodOfflineLibrary instance = VodOfflineLibrary._();

  List<VodOfflineItem> _items = [];
  bool _loaded = false;

  List<VodOfflineItem> get items => List.unmodifiable(_items);

  Future<Directory> rootDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'TVMatePro', 'vod_offline'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await rootDirectory();
    return File(p.join(dir.path, 'index.json'));
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final f = await _indexFile();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final list = raw['items'] as List<dynamic>? ?? [];
        _items = list
            .map((e) => VodOfflineItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
        _items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      }
    } catch (e, st) {
      debugPrint('VodOfflineLibrary load: $e\n$st');
      _items = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> reload() async {
    _loaded = false;
    _items = [];
    await ensureLoaded();
  }

  Future<void> _persist() async {
    final f = await _indexFile();
    await f.writeAsString(
      jsonEncode({
        'version': 1,
        'items': _items.map((e) => e.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  Future<void> addEntry({
    required String title,
    required String filePath,
    required int sizeBytes,
    String? posterUrl,
  }) async {
    await ensureLoaded();
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    _items.insert(
      0,
      VodOfflineItem(
        id: id,
        title: title,
        filePath: filePath,
        sizeBytes: sizeBytes,
        savedAt: DateTime.now(),
        posterUrl: posterUrl,
      ),
    );
    await _persist();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final item = _items[idx];
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    _items.removeAt(idx);
    await _persist();
  }

  /// Removes index rows whose files are gone.
  Future<void> pruneMissingFiles() async {
    await ensureLoaded();
    final before = _items.length;
    _items = _items.where((e) => File(e.filePath).existsSync()).toList();
    if (_items.length != before) {
      await _persist();
    }
  }
}
