import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../ui/live_tv/mock_live_tv_data.dart';
import 'library_disk_store.dart';
import 'stored_playlist.dart';
import 'xtream_catalog_snapshot_codec.dart';

/// SQLite file version ([openDatabase] / [onUpgrade]).
const int kAppLocalDbVersion = 5;

/// Stored in each [xtream_catalog_cache] row; bump when cached catalog JSON shape changes.
const int kXtreamCatalogCacheRowSchemaVersion = 1;

/// Persistent local-first cache for Xtream browse payloads (SQLite, transactional).
final XtreamCatalogCacheDb xtreamCatalogCacheDb = XtreamCatalogCacheDb._();

class XtreamCatalogCacheDb {
  XtreamCatalogCacheDb._();

  Database? _db;

  bool get isOpen => _db != null;

  Future<void> initialize() async {
    if (_db != null) return;
    try {
      final dir = await getDatabasesPath();
      final path = p.join(dir, 'tvmatepro_xtream_catalog.db');
      _db = await openDatabase(
        path,
        version: kAppLocalDbVersion,
        onCreate: (db, version) async {
          await _createXtreamCatalogTable(db);
          await _createAppLibraryTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            await db.execute('DROP TABLE IF EXISTS library_state');
          }
          if (oldVersion < 4) {
            await _createAppLibraryTable(db);
          }
          if (oldVersion < 5) {
            // Large TEXT blobs exceed Android CursorWindow (~2MB) and cannot be read back.
            // Catalog JSON is stored in files next to the DB (see [_fullCatalogFile]).
            await db.execute(
              'UPDATE xtream_catalog_cache SET full_catalog_json = NULL',
            );
            await db.execute(
              'UPDATE xtream_catalog_cache SET live_catalog_json = NULL',
            );
          }
        },
      );
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb: init failed $e\n$st');
      _db = null;
    }
  }

  static Future<void> _createXtreamCatalogTable(Database db) async {
    await db.execute('''
CREATE TABLE xtream_catalog_cache (
  playlist_id TEXT NOT NULL PRIMARY KEY,
  fingerprint TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  full_catalog_json TEXT,
  live_catalog_json TEXT
)
''');
  }

  /// Single-row library mirror (same JSON shape as [LibraryDiskStore]) — survives
  /// Android TV kills better than SharedPreferences / some app support paths.
  static Future<void> _createAppLibraryTable(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_library (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  payload_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
''');
  }

  Future<Map<String, dynamic>?> readLibraryPayload() async {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        'app_library',
        columns: ['payload_json'],
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final raw = rows.first['payload_json'] as String?;
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final m = Map<String, dynamic>.from(decoded);
      if (m['v'] != kLibraryDiskFormatVersion) return null;
      return m;
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb.readLibraryPayload: $e\n$st');
      return null;
    }
  }

  Future<void> saveLibraryPayload(Map<String, dynamic> payload) async {
    final db = _db;
    if (db == null) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'app_library',
        {
          'id': 1,
          'payload_json': jsonEncode(payload),
          'updated_at_ms': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb.saveLibraryPayload: $e\n$st');
    }
  }

  /// SHA-256 of credentials (server + user + password). Invalidates cache on credential change.
  static String credentialsFingerprint(StoredPlaylist playlist) {
    final raw =
        '${playlist.serverUrl?.trim() ?? ''}\u001f${playlist.username?.trim() ?? ''}\u001f${playlist.password ?? ''}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static String _safeCatalogFileSegment(String playlistId) {
    return playlistId.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  static Future<String> _fullCatalogFile(String playlistId) async {
    final dir = await getDatabasesPath();
    final seg = _safeCatalogFileSegment(playlistId);
    return p.join(dir, 'tvmatepro_cat_full_$seg.json');
  }

  static Future<String> _liveCatalogFile(String playlistId) async {
    final dir = await getDatabasesPath();
    final seg = _safeCatalogFileSegment(playlistId);
    return p.join(dir, 'tvmatepro_cat_live_$seg.json');
  }

  Future<void> _deleteCatalogDiskFiles(String playlistId) async {
    try {
      for (final path in await Future.wait([
        _fullCatalogFile(playlistId),
        _liveCatalogFile(playlistId),
      ])) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb._deleteCatalogDiskFiles: $e\n$st');
    }
  }

  Future<XtreamCatalogSnapshot?> readFullCatalog({
    required String playlistId,
    required String fingerprint,
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        'xtream_catalog_cache',
        columns: ['schema_version', 'fingerprint'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      if ((row['fingerprint'] as String?) != fingerprint) return null;
      final sv = (row['schema_version'] as num?)?.toInt();
      if (sv != kXtreamCatalogCacheRowSchemaVersion) return null;
      final path = await _fullCatalogFile(playlistId);
      final f = File(path);
      if (!await f.exists()) return null;
      final json = await f.readAsString();
      if (json.isEmpty) return null;
      return await compute(decodeXtreamCatalogSnapshotString, json);
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb.readFullCatalog failed: $e\n$st');
      return null;
    }
  }

  /// Live categories + channels for [playlistId] (from full snapshot file or live-only file).
  Future<XtreamLiveCatalogPersistV1?> readLiveCatalog({
    required String playlistId,
    required String fingerprint,
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        'xtream_catalog_cache',
        columns: ['schema_version', 'fingerprint'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      if ((row['fingerprint'] as String?) != fingerprint) return null;
      final sv = (row['schema_version'] as num?)?.toInt();
      if (sv != kXtreamCatalogCacheRowSchemaVersion) return null;

      final fullPath = await _fullCatalogFile(playlistId);
      final fullFile = File(fullPath);
      if (await fullFile.exists()) {
        final full = await fullFile.readAsString();
        if (full.isNotEmpty) {
          try {
            final snap = await compute(decodeXtreamCatalogSnapshotString, full);
            if (snap == null) return null;
            return XtreamLiveCatalogPersistV1(
              liveCategories: snap.liveCategories,
              liveChannelsAll: snap.liveChannelsAll,
            );
          } catch (e, st) {
            debugPrint(
                'XtreamCatalogCacheDb.readLiveCatalog full decode failed: $e\n$st');
          }
        }
      }

      final livePath = await _liveCatalogFile(playlistId);
      final liveFile = File(livePath);
      if (!await liveFile.exists()) return null;
      final live = await liveFile.readAsString();
      if (live.isEmpty) return null;
      return await compute(decodeXtreamLiveCatalogPersistString, live);
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb.readLiveCatalog failed: $e\n$st');
      return null;
    }
  }

  Future<void> saveFullCatalog({
    required String playlistId,
    required String fingerprint,
    required XtreamCatalogSnapshot snapshot,
  }) async {
    final db = _db;
    if (db == null) return;
    final livePersist = XtreamLiveCatalogPersistV1(
      liveCategories: snapshot.liveCategories,
      liveChannelsAll: snapshot.liveChannelsAll,
    );
    final results = await Future.wait([
      compute(encodeXtreamCatalogSnapshotToString, snapshot),
      compute(encodeXtreamLiveCatalogPersistToString, livePersist),
    ]);
    final fullStr = results[0];
    final liveStr = results[1];
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      await File(await _fullCatalogFile(playlistId)).writeAsString(fullStr);
      await File(await _liveCatalogFile(playlistId)).writeAsString(liveStr);
    } catch (e, st) {
      debugPrint('XtreamCatalogCacheDb.saveFullCatalog file write: $e\n$st');
      return;
    }
    await db.transaction((txn) async {
      await txn.insert(
        'xtream_catalog_cache',
        {
          'playlist_id': playlistId,
          'fingerprint': fingerprint,
          'schema_version': kXtreamCatalogCacheRowSchemaVersion,
          'updated_at_ms': now,
          'full_catalog_json': null,
          'live_catalog_json': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> saveLiveCatalogOnly({
    required String playlistId,
    required String fingerprint,
    required List<MockLiveCategory> liveCategories,
    required List<MockLiveChannel> liveChannelsAll,
  }) async {
    final db = _db;
    if (db == null) return;
    final liveStr = XtreamLiveCatalogPersistV1(
      liveCategories: liveCategories,
      liveChannelsAll: liveChannelsAll,
    ).encodeToString();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'xtream_catalog_cache',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert(
          'xtream_catalog_cache',
          {
            'playlist_id': playlistId,
            'fingerprint': fingerprint,
            'schema_version': kXtreamCatalogCacheRowSchemaVersion,
            'updated_at_ms': now,
            'full_catalog_json': null,
            'live_catalog_json': liveStr,
          },
        );
      } else {
        await txn.update(
          'xtream_catalog_cache',
          {
            'fingerprint': fingerprint,
            'schema_version': kXtreamCatalogCacheRowSchemaVersion,
            'updated_at_ms': now,
            'live_catalog_json': liveStr,
          },
          where: 'playlist_id = ?',
          whereArgs: [playlistId],
        );
      }
    });
  }

  Future<void> deleteForPlaylist(String playlistId) async {
    final db = _db;
    if (db == null) return;
    await _deleteCatalogDiskFiles(playlistId);
    await db.delete(
      'xtream_catalog_cache',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
  }
}
