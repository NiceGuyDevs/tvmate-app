import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../data/backup/tvmatepro_backup_paths.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';

/// Multi-select and delete `tvmate-backup-*.json` files in Downloads.
class BackupManageScreen extends StatefulWidget {
  const BackupManageScreen({super.key});

  @override
  State<BackupManageScreen> createState() => _BackupManageScreenState();
}

class _BackupManageScreenState extends State<BackupManageScreen> {
  List<File> _files = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final listed = await discoverAllBackupFiles();
    if (!mounted) return;
    setState(() {
      _files = listed;
      _selected.removeWhere((path) => !listed.any((f) => f.path == path));
    });
  }

  void _toggle(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final shell = ctx.teamPalette;
        final dlg = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: shell.surface,
          title: Text(dlg.backupManageDeleteConfirmTitle),
          content: Text(
            dlg.backupManageDeleteConfirmBody(_selected.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dlg.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dlg.dialogDelete),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    for (final path in List<String>.from(_selected)) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _selected.clear());
    await _load();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(l10n.backupManageToastRemoved),
        ),
      );
  }

  String _friendlyName(String fileName) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final shell = context.teamPalette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          playerSettingsRouteBackdrop(context),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      TvFocusable(
                        focusPadding: const EdgeInsets.all(3),
                        onActivate: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.14)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.backupManageTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_files.isNotEmpty) ...[
                        TvFocusable(
                          focusPadding: const EdgeInsets.all(3),
                          onActivate: () {
                            setState(() {
                              if (_selected.length == _files.length) {
                                _selected.clear();
                              } else {
                                _selected
                                  ..clear()
                                  ..addAll(_files.map((f) => f.path));
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.14)),
                            ),
                            child: Text(
                              _selected.length == _files.length
                                  ? l10n.backupManageClearAll
                                  : l10n.backupManageSelectAll,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TvFocusable(
                          canRequestFocus: _selected.isNotEmpty,
                          focusPadding: const EdgeInsets.all(3),
                          onActivate: _deleteSelected,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _selected.isEmpty
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.redAccent.withOpacity(0.18),
                              border: Border.all(
                                color: _selected.isEmpty
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.redAccent.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              _selected.isEmpty
                                  ? l10n.backupManageDelete
                                  : l10n.backupManageDeleteCount(
                                      _selected.length,
                                    ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _selected.isEmpty
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.92),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_files.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.backupManageEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _files.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, i) {
                          final f = _files[i];
                          final path = f.path;
                          final name = p.basename(path);
                          final friendly = _friendlyName(name);
                          final sel = _selected.contains(path);
                          return TvFocusable(
                            autofocus: i == 0,
                            onActivate: () => _toggle(path),
                            focusPadding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel
                                      ? shell.accent.withOpacity(0.65)
                                      : Colors.white.withOpacity(0.1),
                                  width: sel ? 1.5 : 1,
                                ),
                                color: sel
                                    ? shell.accent.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.04),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    sel
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 18,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friendly,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontSize: 9,
                                            color:
                                                Colors.white.withOpacity(0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
