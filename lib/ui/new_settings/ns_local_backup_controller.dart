import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/backup/tvmatepro_backup_paths.dart';
import 'new_settings_data.dart';

/// Drives the **local** backup list on [NsBackupPage] from real disk files.
class NsLocalBackupListController extends ChangeNotifier {
  List<NsBackupFile> _rows = [];
  bool _loading = false;

  List<NsBackupFile> get rows => List.unmodifiable(_rows);

  bool get loading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final files = await discoverAllBackupFiles();
      final out = <NsBackupFile>[];
      for (final f in files) {
        final row = await nsBackupFileFromDisk(f);
        if (row != null) out.add(row);
      }
      _rows = out;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

Future<NsBackupFile?> nsBackupFileFromDisk(File f) async {
  try {
    final name = p.basename(f.path);
    final friendly = _friendlyBackupTitle(name);
    final kind = await _readBackupKind(f);
    final size = _formatSize(f);
    final date = _formatModified(f);
    return NsBackupFile(
      name: friendly,
      size: size,
      date: date,
      kind: kind,
      diskPath: f.path,
    );
  } catch (e, st) {
    debugPrint('nsBackupFileFromDisk: $e\n$st');
    return null;
  }
}

Future<NsBackupKind> _readBackupKind(File f) async {
  try {
    final raw = await f.readAsString();
    final o = jsonDecode(raw);
    if (o is Map<String, dynamic>) {
      final k = o['kind'] as String?;
      if (k == 'share') return NsBackupKind.share;
    }
  } catch (_) {}
  return NsBackupKind.personal;
}

String _formatSize(File f) {
  try {
    final bytes = f.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } catch (_) {
    return '—';
  }
}

String _formatModified(File f) {
  try {
    final d = f.statSync().modified;
    final y = d.year.toString().padLeft(4, '0');
    final mo = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '$y-$mo-$day  $h:$mi';
  } catch (_) {
    return '';
  }
}

String _friendlyBackupTitle(String fileName) {
  var s = fileName;
  if (s.startsWith('tvmate-backup-')) s = s.substring(14);
  if (s.endsWith('.json')) s = s.substring(0, s.length - 5);
  final parts = s.split('-');
  if (parts.length >= 2) {
    final datePart = parts[0];
    final timePart = parts[1];
    if (datePart.length == 8 && timePart.length >= 4) {
      final y = datePart.substring(0, 4);
      final mo = datePart.substring(4, 6);
      final d = datePart.substring(6, 8);
      final h = timePart.substring(0, 2);
      final mi = timePart.substring(2, 4);
      return '$y-$mo-$d  $h:$mi';
    }
  }
  return fileName;
}
