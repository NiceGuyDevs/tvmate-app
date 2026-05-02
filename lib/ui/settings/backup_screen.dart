import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../data/backup/tvmatepro_backup_paths.dart';
import '../../data/backup/tvmatepro_backup_service.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'backup_import_screen.dart';
import 'backup_manage_screen.dart';
import 'player_settings_overlay_scope.dart';

/// Settings -> **Backup**: export / import / share / delete backup files.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _lastExportPath;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String text) {
    if (!mounted) return;
    _toastTimer?.cancel();
    setState(() => _lastExportPath = null);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text(text),
    ));
  }

  Future<void> _export(TvMateBackupKind kind) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final granted = await ensureBackupStoragePermission();
      if (!granted) {
        _showToast(l10n.backupToastStorageRequired);
        return;
      }
      final path = await TvMateBackupService.instance.exportToDownloads(kind);
      if (!mounted) return;
      final name = path.split(Platform.pathSeparator).last;
      setState(() => _lastExportPath = path);
      _showToast(l10n.backupToastSavedDownloads(name));
      _toastTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _lastExportPath = null);
      });
    } catch (e) {
      if (!mounted) return;
      _showToast(AppLocalizations.of(context)!.backupToastExportFailed('$e'));
    }
  }

  Future<void> _shareFile(String path) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: l10n.backupShareSubject,
        text: l10n.backupShareBody,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(AppLocalizations.of(context)!.backupToastShareFailed('$e'));
    }
  }

  Future<void> _shareLatest() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final files = await discoverAllBackupFiles();
      if (files.isEmpty) {
        _showToast(l10n.backupToastNoBackupsToShare);
        return;
      }
      await _shareFile(files.first.path);
    } catch (e) {
      if (!mounted) return;
      _showToast(AppLocalizations.of(context)!.backupToastShareFailed('$e'));
    }
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
                        border:
                            Border.all(color: Colors.white.withOpacity(0.14)),
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
                  Text(
                    l10n.settingsBackup,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Banner
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: shell.accent.withOpacity(0.09),
                  border: Border.all(
                    color: shell.accent.withOpacity(0.25),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Text(
                    l10n.backupInfoBanner,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.35,
                      color: Colors.white.withOpacity(0.78),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Action grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 3.0,
                  children: [
                    _BackupActionTile(
                      autofocus: true,
                      icon: Icons.lock_person_rounded,
                      title: l10n.backupExportPersonal,
                      subtitle: l10n.backupExportPersonalSub,
                      onActivate: () => _export(TvMateBackupKind.personal),
                    ),
                    _BackupActionTile(
                      icon: Icons.ios_share_rounded,
                      title: l10n.backupExportShare,
                      subtitle: l10n.backupExportShareSub,
                      onActivate: () => _export(TvMateBackupKind.share),
                    ),
                    if (_lastExportPath != null)
                      _BackupActionTile(
                        icon: Icons.send_rounded,
                        title: l10n.backupShareLastExport,
                        subtitle: l10n.backupShareLastExportSub,
                        onActivate: () => _shareFile(_lastExportPath!),
                      )
                    else
                      _BackupActionTile(
                        icon: Icons.share_rounded,
                        title: l10n.backupShareLatest,
                        subtitle: l10n.backupShareLatestSub,
                        onActivate: _shareLatest,
                      ),
                    _BackupActionTile(
                      icon: Icons.file_download_rounded,
                      title: l10n.backupImportNavigate,
                      subtitle: l10n.backupImportNavigateSub,
                      onActivate: () {
                        pushSettingsRoute<void>(
                          context,
                          (_) => const BackupImportScreen(),
                        );
                      },
                    ),
                    _BackupActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: l10n.backupDeleteNavigate,
                      subtitle: l10n.backupDeleteNavigateSub,
                      onActivate: () {
                        pushSettingsRoute<void>(
                          context,
                          (_) => const BackupManageScreen(),
                        );
                      },
                    ),
                  ],
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

class _BackupActionTile extends StatelessWidget {
  const _BackupActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onActivate,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onActivate;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      autofocus: autofocus,
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withOpacity(0.85)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9.5,
                      color: Colors.white.withOpacity(0.62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
