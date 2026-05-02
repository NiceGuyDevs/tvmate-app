import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'library_disk_store.dart';

/// Tiny DB **only** for playlist JSON — opens even if the main catalog DB fails.
final LibraryStoreDb libraryStoreDb = LibraryStoreDb._();

class LibraryStoreDb {
  LibraryStoreDb._();

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) return;
    try {
      final path = p.join(await getDatabasesPath(), 'tvmatepro_library.db');
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE library_snapshot (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  payload_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
''');
        },
      );
      await _db!.execute('PRAGMA synchronous = FULL');
    } catch (e, st) {
      debugPrint('LibraryStoreDb.init failed: $e\n$st');
      _db = null;
    }
  }

  Future<Map<String, dynamic>?> readPayload() async {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        'library_snapshot',
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
      debugPrint('LibraryStoreDb.readPayload: $e\n$st');
      return null;
    }
  }

  Future<void> savePayload(Map<String, dynamic> payload) async {
    final db = _db;
    if (db == null) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.transaction((txn) async {
        await txn.insert(
          'library_snapshot',
          {
            'id': 1,
            'payload_json': jsonEncode(payload),
            'updated_at_ms': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (e, st) {
      debugPrint('LibraryStoreDb.savePayload: $e\n$st');
    }
  }
}
