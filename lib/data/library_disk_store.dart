import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Same directory as [getDatabasesPath] — reliable on Android TV (matches catalog DB).
const int kLibraryDiskFormatVersion = 1;

class LibraryDiskStore {
  LibraryDiskStore._();

  static File? _file;

  static Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final dir = await getDatabasesPath();
    final d = Directory(dir);
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    _file = File(p.join(dir, 'tvmatepro_library_state.json'));
    return _file!;
  }

  static Future<Map<String, dynamic>?> load() async {
    try {
      final f = await _ensureFile();
      if (!f.existsSync()) return null;
      final raw = f.readAsStringSync();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      if (m['v'] != kLibraryDiskFormatVersion) return null;
      return m;
    } catch (e, st) {
      debugPrint('LibraryDiskStore.load failed: $e\n$st');
      return null;
    }
  }

  static Future<void> save({
    required List<Map<String, dynamic>> playlists,
    required String? activePlaylistId,
    required bool demoMode,
    required bool demoFixApplied,
  }) async {
    final f = await _ensureFile();
    final payload = <String, dynamic>{
      'v': kLibraryDiskFormatVersion,
      'playlists': playlists,
      'activePlaylistId': activePlaylistId,
      'demoMode': demoMode,
      'demoFixApplied': demoFixApplied,
    };
    final str = jsonEncode(payload);
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(str);
    if (f.existsSync()) {
      f.deleteSync();
    }
    try {
      tmp.renameSync(f.path);
    } catch (_) {
      tmp.copySync(f.path);
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }
}
