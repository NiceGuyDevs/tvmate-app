import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tvmatepro_backup_constants.dart';

const _channel = MethodChannel('com.tvmate.app/backup_storage');

/// Directory used for **writing** new backups. Prefers `Download/TVMatePro`.
Future<Directory> resolveTvMateBackupDirectory() async {
  // Desktop: use Documents/TVMatePro/backups
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'TVMatePro', 'backups'));
      if (dir.existsSync() || _tryCreate(dir)) return dir;
    } catch (e) {
      debugPrint('BackupPaths: path_provider failed: $e');
    }
    return Directory.systemTemp;
  }

  try {
    final path = await _channel.invokeMethod<String>('getPublicBackupDir');
    if (path != null && path.isNotEmpty) {
      final dir = Directory(path);
      if (dir.existsSync() || _tryCreate(dir)) return dir;
    }
  } catch (e) {
    debugPrint('BackupPaths: platform channel failed: $e');
  }

  if (Platform.isAndroid) {
    for (final path in const [
      '/storage/emulated/0/Download/TVMatePro',
      '/sdcard/Download/TVMatePro',
    ]) {
      try {
        final dir = Directory(path);
        if (dir.existsSync() || _tryCreate(dir)) return dir;
      } catch (_) {}
    }
    for (final path in const [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ]) {
      final dir = Directory(path);
      if (dir.existsSync()) return dir;
    }
  }
  return Directory.systemTemp;
}

/// Scans the entire public Download tree **recursively** for
/// `tvmate-backup-*.json` files. This finds backups no matter which subfolder
/// they landed in (TVMatePro/, Downloader/, root Download/, etc.).
Future<List<File>> discoverAllBackupFiles() async {
  await ensureBackupStoragePermission();
  final roots = <Directory>[];

  // Desktop: scan the backup directory from path_provider
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'TVMatePro', 'backups'));
      if (dir.existsSync()) roots.add(dir);
    } catch (_) {}
  } else {
    try {
      final path = await _channel.invokeMethod<String>('getPublicBackupDir');
      if (path != null && path.isNotEmpty) {
        final backupDir = Directory(path);
        final parent = backupDir.parent;
        if (parent.existsSync()) roots.add(parent);
      }
    } catch (_) {}

    if (roots.isEmpty && Platform.isAndroid) {
      for (final path in const [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
      ]) {
        final d = Directory(path);
        if (d.existsSync()) {
          roots.add(d);
          break;
        }
      }
    }
  }

  final found = <String, File>{};
  for (final root in roots) {
    try {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is File && isTvMateBackupFileName(entity.path)) {
          found[entity.path] = entity;
        }
      }
    } catch (e) {
      debugPrint('discoverAllBackupFiles walk error: $e');
    }
  }

  final list = found.values.toList();
  list.sort((a, b) {
    try {
      return b.statSync().modified.compareTo(a.statSync().modified);
    } catch (_) {
      return 0;
    }
  });
  return list;
}

bool _tryCreate(Directory dir) {
  try {
    dir.createSync(recursive: true);
    return dir.existsSync();
  } catch (_) {
    return false;
  }
}

Future<bool> ensureBackupStoragePermission() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return true;
  try {
    final granted =
        await _channel.invokeMethod<bool>('ensureStoragePermission');
    return granted ?? false;
  } catch (e) {
    debugPrint('BackupPaths: permission request failed: $e');
    return false;
  }
}

String tvMateBackupFileNameNow() {
  final n = DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final mo = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  final h = n.hour.toString().padLeft(2, '0');
  final mi = n.minute.toString().padLeft(2, '0');
  final s = n.second.toString().padLeft(2, '0');
  final ms = n.millisecond.toString().padLeft(3, '0');
  return '$kTvMateBackupFilePrefix$y$mo$d-${h}${mi}${s}-$ms.json';
}

bool isTvMateBackupFileName(String name) {
  final base = p.basename(name);
  return base.startsWith(kTvMateBackupFilePrefix) && base.endsWith('.json');
}

/// Lists backup files in a single directory (non-recursive). Newest first.
List<FileSystemEntity> listTvMateBackupFiles(Directory dir) {
  try {
    if (!dir.existsSync()) return [];
    final out = <FileSystemEntity>[
      for (final e in dir.listSync())
        if (e is File && isTvMateBackupFileName(e.path)) e,
    ];
    out.sort((a, b) {
      try {
        return b.statSync().modified.compareTo(a.statSync().modified);
      } catch (_) {
        return 0;
      }
    });
    return out;
  } catch (e, st) {
    debugPrint('listTvMateBackupFiles: $e\n$st');
    return [];
  }
}
