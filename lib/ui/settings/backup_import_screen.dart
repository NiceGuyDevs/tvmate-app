import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../data/backup/tvmatepro_backup_paths.dart';
import '../../data/backup/tvmatepro_backup_service.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import '../new_settings/widgets/ns_message_bar.dart';
import 'player_settings_overlay_scope.dart';

/// Lists ALL backup files found anywhere under Download/ and lets the user
/// pick one to restore.
class BackupImportScreen extends StatefulWidget {
  const BackupImportScreen({super.key});

  @override
  State<BackupImportScreen> createState() => _BackupImportScreenState();
}

class _BackupImportScreenState extends State<BackupImportScreen> {
  List<File> _files = [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    try {
      final files = await discoverAllBackupFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _importFile(File file) async {
    if (_importing) return;
    setState(() => _importing = true);
    final nav = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final raw = await file.readAsString();
      await TvMateBackupService.instance.applyFromJsonString(raw);
      if (!mounted) return;
      showNsMessage(
        context,
        title: l10n.nsMessageBackupAppliedTitle,
        message: l10n.backupImportRestoredToast,
        variant: NsMessageVariant.success,
        duration: const Duration(seconds: 4),
      );
      nav.pop();
    } on TvMateBackupException catch (e) {
      if (!mounted) return;
      showNsMessage(
        context,
        title: l10n.nsMessageErrorTitle,
        message: e.message,
        variant: NsMessageVariant.error,
        duration: const Duration(seconds: 5),
      );
      setState(() => _importing = false);
    } catch (e) {
      if (!mounted) return;
      showNsMessage(
        context,
        title: l10n.nsMessageErrorTitle,
        message: l10n.backupImportFailedToast('$e'),
        variant: NsMessageVariant.error,
        duration: const Duration(seconds: 5),
      );
      setState(() => _importing = false);
    }
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

  String _fileMeta(File f) {
    final parts = <String>[];
    try {
      final bytes = f.lengthSync();
      if (bytes < 1024) {
        parts.add('$bytes B');
      } else if (bytes < 1024 * 1024) {
        parts.add('${(bytes / 1024).toStringAsFixed(1)} KB');
      } else {
        parts.add('${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB');
      }
    } catch (_) {}
    final dir = p.basename(f.parent.path);
    if (dir.isNotEmpty) parts.add(dir);
    return parts.join(' · ');
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
                          l10n.backupImportTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (!_loading)
                        TvFocusable(
                          focusPadding: const EdgeInsets.all(3),
                          onActivate: _scan,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.14)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded,
                                    size: 13,
                                    color: Colors.white.withOpacity(0.8)),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.backupImportRefresh,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.backupImportScanSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_importing)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                            const SizedBox(height: 10),
                            Text(l10n.backupImportRestoring),
                          ],
                        ),
                      ),
                    )
                  else if (_loading)
                    const Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_files.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.backupImportEmpty,
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
                          final name = p.basename(f.path);
                          final friendly = _friendlyName(name);
                          final meta = _fileMeta(f);
                          return TvFocusable(
                            autofocus: i == 0,
                            onActivate: () => _importFile(f),
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
                                    color: Colors.white.withOpacity(0.1)),
                                color: Colors.white.withOpacity(0.04),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 17,
                                    color: shell.accent.withOpacity(0.8),
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
                                  if (meta.isNotEmpty)
                                    Text(
                                      meta,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 9.5,
                                        color: Colors.white.withOpacity(0.5),
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
