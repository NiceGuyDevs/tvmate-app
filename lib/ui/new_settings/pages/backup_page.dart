/// Backup & restore — 1:1 port of `renderBackupPage()` in
/// settings.html (line 7816).
///
/// Layout:
///   [sub-page head]   title=Backup & restore
///     actions=[Import backup] (primary)
///
///   .split-3 (2-col on wide, 1 on narrow):
///     card ▪ Personal backup  → Export personal   (primary)
///     card ▪ Share with family → Export shareable (default)
///
///   section.group "BACKUPS ON THIS DEVICE"
///     card wrapping .file-row stack:
///       36×36 file icon · name + "{size} · {date} · {kind}"
///       actions: [share] [Restore] [trash (danger)]
library;

import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../data/backup/tvmatepro_backup_paths.dart';
import '../../../data/backup/tvmatepro_backup_service.dart';
import '../../settings/backup_import_screen.dart';
import '../../settings/player_settings_overlay_scope.dart';
import '../ns_local_backup_controller.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_confirm_dialog.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_message_bar.dart';
import '../widgets/ns_sub_page_head.dart';

class NsBackupPage extends StatefulWidget {
  const NsBackupPage({
    super.key,
    required this.state,
    required this.onBack,
  });

  final NewSettingsState state;
  final VoidCallback onBack;

  @override
  State<NsBackupPage> createState() => _NsBackupPageState();
}

class _NsBackupPageState extends State<NsBackupPage> {
  /// Which list the section tab is showing — `local` or `cloud`.
  /// Exporting flips to local, uploading flips to cloud, and the
  /// user can also tap the tabs directly to browse between them.
  _BackupTab _tab = _BackupTab.local;

  final NsLocalBackupListController _local = NsLocalBackupListController();

  NewSettingsState get state => widget.state;
  VoidCallback get onBack => widget.onBack;

  @override
  void initState() {
    super.initState();
    _local.addListener(_onLocalChanged);
    unawaited(_loadLocalList());
  }

  @override
  void dispose() {
    _local.removeListener(_onLocalChanged);
    super.dispose();
  }

  void _onLocalChanged() {
    if (!mounted) return;
    _syncSummaryToState();
    setState(() {});
  }

  void _syncSummaryToState() {
    final rows = _local.rows;
    if (rows.isEmpty) {
      state.setLocalDiskBackupSummary(0, null);
    } else {
      state.setLocalDiskBackupSummary(rows.length, rows.first.date);
    }
  }

  Future<void> _loadLocalList() async {
    await _local.refresh();
    if (!mounted) return;
    _syncSummaryToState();
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([state, _local]),
      builder: (context, _) {
        final localFiles = _local.rows;
        final cloudFiles = state.cloudBackupFiles;
        final files =
            _tab == _BackupTab.local ? localFiles : cloudFiles;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Backup & restore',
              subtitle:
                  'Export your settings & playlists, share a copy, '
                  'or import from a file.',
              onBack: onBack,
              actions: [
                NsButton(
                  label: 'Import backup',
                  icon: Icons.file_upload_rounded,
                  variant: NsButtonVariant.primary,
                  onPressed: () => _openImport(context),
                ),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // HTML uses `.split-3` at `grid-template-columns: 1fr
                // 1fr`. Keep the two cards side-by-side on every
                // real TV pane — only stack on genuinely tiny widths.
                final stacked = constraints.maxWidth < 520;
                final personal = _ExportCard(
                  title: 'Personal backup',
                  description:
                      "Includes parental rules and the PIN hash. "
                      "Don't share this file.",
                  primaryLabel: 'Export personal',
                  primaryIcon: Icons.file_download_rounded,
                  secondaryLabel: 'Upload personal',
                  secondaryIcon: Icons.cloud_upload_rounded,
                  onExport: () => _export(context, NsBackupKind.personal),
                  onUpload: () =>
                      _uploadCloud(context, NsBackupKind.personal),
                );
                final share = _ExportCard(
                  title: 'Share with family',
                  description:
                      'Strips PIN and rules. Safe to send to another '
                      'device.',
                  primaryLabel: 'Export shareable',
                  primaryIcon: Icons.ios_share_rounded,
                  primaryVariant: NsButtonVariant.defaultVariant,
                  secondaryLabel: 'Upload shareable',
                  secondaryIcon: Icons.cloud_upload_rounded,
                  onExport: () => _export(context, NsBackupKind.share),
                  onUpload: () =>
                      _uploadCloud(context, NsBackupKind.share),
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      personal,
                      const SizedBox(height: 10),
                      share,
                    ],
                  );
                }
                // IntrinsicHeight forces the Row (and its Expanded
                // children) to measure their real content height
                // instead of inheriting the ListView's unbounded
                // cross-axis — otherwise `stretch` silently eats the
                // viewport and everything below the Row disappears.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: personal),
                      const SizedBox(width: 10),
                      Expanded(child: share),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Section header: "BACKUPS" label · tab switcher
            // (Local | Cloud) · sign-in status on the right.
            _BackupsHeader(
              tab: _tab,
              localCount: localFiles.length,
              cloudCount: cloudFiles.length,
              signedIn: state.cloudSignedIn,
              account: state.cloudAccount,
              onPickTab: (t) => setState(() => _tab = t),
              onSignInToggle: () =>
                  state.setCloudSignedIn(!state.cloudSignedIn),
            ),
            const SizedBox(height: 5),
            if (_tab == _BackupTab.local && _local.loading && localFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (files.isEmpty)
              _tab == _BackupTab.local
                  ? const _EmptyState()
                  : const _CloudEmptyState()
            else
              _FilesCard(
                files: files,
                onShare: _tab == _BackupTab.local
                    ? (f) => _shareDiskBackup(context, f)
                    : null,
                onRestore: (f) => _confirmRestore(context, f),
                onDelete: _tab == _BackupTab.local
                    ? (f) => _confirmDeleteLocal(context, f)
                    : (f) => state.deleteCloudBackup(f.name),
                cloudIcon: _tab == _BackupTab.cloud,
              ),
          ],
        );
      },
    );
  }

  void _uploadCloud(BuildContext context, NsBackupKind kind) {
    // Preview-only: no server upload (mirrors pre-port mock list).
    final f = state.uploadToCloud(kind);
    setState(() => _tab = _BackupTab.cloud);
    _toast(
      context,
      kind == NsBackupKind.personal
          ? 'Personal uploaded · ${f.name}'
          : 'Shareable uploaded · ${f.name}',
    );
  }

  Future<void> _export(BuildContext context, NsBackupKind kind) async {
    final l10n = AppLocalizations.of(context);
    final tvKind = kind == NsBackupKind.personal
        ? TvMateBackupKind.personal
        : TvMateBackupKind.share;
    try {
      final granted = await ensureBackupStoragePermission();
      if (!granted) {
        if (!context.mounted) return;
        _toast(context, l10n.backupToastStorageRequired);
        return;
      }
      final outPath = await TvMateBackupService.instance.exportToDownloads(
        tvKind,
      );
      if (!context.mounted) return;
      final name = p.basename(outPath);
      setState(() => _tab = _BackupTab.local);
      showNsMessage(
        context,
        message: l10n.backupToastSavedDownloads(name),
        variant: NsMessageVariant.success,
        duration: const Duration(seconds: 4),
      );
      await _local.refresh();
    } catch (e) {
      if (!context.mounted) return;
      showNsMessage(
        context,
        title: l10n.nsMessageErrorTitle,
        message: l10n.backupToastExportFailed('$e'),
        variant: NsMessageVariant.error,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _openImport(BuildContext context) async {
    await pushSettingsRoute<void>(
      context,
      (_) => const BackupImportScreen(),
    );
    if (context.mounted) await _local.refresh();
  }

  Future<void> _shareDiskBackup(
    BuildContext context,
    NsBackupFile f,
  ) async {
    final path = f.diskPath;
    if (path == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await Share.shareXFiles(
        [XFile(path)],
        subject: l10n.backupShareSubject,
        text: l10n.backupShareBody,
      );
    } catch (e) {
      if (context.mounted) {
        showNsMessage(
          context,
          title: l10n.nsMessageErrorTitle,
          message: l10n.backupToastShareFailed('$e'),
          variant: NsMessageVariant.error,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<void> _confirmDeleteLocal(
    BuildContext context,
    NsBackupFile f,
  ) async {
    final path = f.diskPath;
    if (path == null) return;
    final r = await showNsConfirmDialog(
      context,
      title: 'Delete "${f.name}"?',
      message: 'This removes the file from your device. You cannot undo it.',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (r != NsConfirmResult.confirmed || !context.mounted) return;
    try {
      await File(path).delete();
    } catch (_) {}
    if (!context.mounted) return;
    await _local.refresh();
  }

  Future<void> _confirmRestore(
    BuildContext context,
    NsBackupFile f,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (f.diskPath == null) {
      if (!context.mounted) return;
      _toast(
        context,
        'Restore from cloud is not available yet',
      );
      return;
    }
    final r = await showNsConfirmDialog(
      context,
      title: 'Restore "${f.name}"?',
      message:
          'Your current settings will be overwritten with the '
          'contents of this backup.',
      confirmLabel: 'Restore',
      isDanger: false,
    );
    if (r != NsConfirmResult.confirmed || !context.mounted) return;
    try {
      final raw = await File(f.diskPath!).readAsString();
      await TvMateBackupService.instance.applyFromJsonString(raw);
      if (!context.mounted) return;
      showNsMessage(
        context,
        title: l10n.nsMessageBackupAppliedTitle,
        message: l10n.backupImportRestoredToast,
        variant: NsMessageVariant.success,
        duration: const Duration(seconds: 4),
      );
      await _local.refresh();
    } on TvMateBackupException catch (e) {
      if (context.mounted) {
        showNsMessage(
          context,
          title: l10n.nsMessageErrorTitle,
          message: e.message,
          variant: NsMessageVariant.error,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showNsMessage(
          context,
          title: l10n.nsMessageErrorTitle,
          message: l10n.backupImportFailedToast('$e'),
          variant: NsMessageVariant.error,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  void _toast(BuildContext context, String msg) {
    showNsMessage(
      context,
      message: msg,
      variant: NsMessageVariant.neutral,
      duration: const Duration(seconds: 2),
    );
  }
}

/// Which file list the user is currently looking at.
enum _BackupTab { local, cloud }

// ═══════════════════════════════════════════════════════════════════════
//  Backups section header — [BACKUPS label] [Local|Cloud tabs]
//  [● Signed in pill]. Single component that replaces both the HTML's
//  `.group-label` and the separate cloud section header.
// ═══════════════════════════════════════════════════════════════════════

class _BackupsHeader extends StatelessWidget {
  const _BackupsHeader({
    required this.tab,
    required this.localCount,
    required this.cloudCount,
    required this.signedIn,
    required this.account,
    required this.onPickTab,
    required this.onSignInToggle,
  });

  final _BackupTab tab;
  final int localCount;
  final int cloudCount;
  final bool signedIn;
  final String? account;
  final void Function(_BackupTab) onPickTab;
  final VoidCallback onSignInToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'BACKUPS',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 8),
          // Tab switcher.
          _TabPill(
            label: 'Local',
            count: localCount,
            selected: tab == _BackupTab.local,
            onPressed: () => onPickTab(_BackupTab.local),
          ),
          const SizedBox(width: 4),
          _TabPill(
            label: 'Cloud',
            count: cloudCount,
            selected: tab == _BackupTab.cloud,
            onPressed: () => onPickTab(_BackupTab.cloud),
          ),
          const Spacer(),
          _SignInPill(
            signedIn: signedIn,
            account: account,
            onPressed: onSignInToggle,
          ),
        ],
      ),
    );
  }
}

/// A small pill the user taps to switch between Local / Cloud.
class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: '$label backups',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? NsColors.accentSoft
              : (focused ? NsColors.surface2 : NsColors.bg2),
          border: Border.all(
            color: selected
                ? NsColors.accentLine
                : (focused ? NsColors.line2 : NsColors.line),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? NsColors.accent : NsColors.text2,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x33000000)
                      : NsColors.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? NsColors.accent : NsColors.text4,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                    height: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Export card — "Personal backup" / "Share with family" panel.
//  Matches HTML `.card` with title, description, and a single button.
// ═══════════════════════════════════════════════════════════════════════

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.secondaryLabel,
    required this.secondaryIcon,
    required this.onExport,
    required this.onUpload,
    this.primaryVariant = NsButtonVariant.primary,
  });

  final String title;
  final String description;
  final String primaryLabel;
  final IconData primaryIcon;
  final String secondaryLabel;
  final IconData secondaryIcon;
  final NsButtonVariant primaryVariant;
  final VoidCallback onExport;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(10),
        boxShadow: NsShadow.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: NsColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.06,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(
              color: NsColors.text3,
              fontSize: 9.5,
              height: 1.3,
              decoration: TextDecoration.none,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Two buttons side-by-side: local Export + cloud Upload.
          // Wrap handles very narrow panes by letting the second
          // button drop to a new line instead of clipping.
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              NsButton(
                label: primaryLabel,
                icon: primaryIcon,
                variant: primaryVariant,
                onPressed: onExport,
              ),
              NsButton(
                label: secondaryLabel,
                icon: secondaryIcon,
                variant: NsButtonVariant.defaultVariant,
                onPressed: onUpload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Files card — stacked `.file-row`s separated by dividers.
// ═══════════════════════════════════════════════════════════════════════

class _FilesCard extends StatelessWidget {
  const _FilesCard({
    required this.files,
    required this.onShare,
    required this.onRestore,
    required this.onDelete,
    this.cloudIcon = false,
  });

  final List<NsBackupFile> files;

  /// When null, the Share button is hidden. Used by the Cloud section
  /// (sharing already-hosted files means handing out account access).
  final void Function(NsBackupFile)? onShare;
  final void Function(NsBackupFile) onRestore;
  final void Function(NsBackupFile) onDelete;

  /// Swap the default file glyph for a cloud one — so at a glance the
  /// user can tell a row belongs to the cloud list vs the local list.
  final bool cloudIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
        boxShadow: NsShadow.s1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < files.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: NsColors.line,
              ),
            _FileRow(
              file: files[i],
              onShare: onShare == null
                  ? null
                  : () => onShare!(files[i]),
              onRestore: () => onRestore(files[i]),
              onDelete: () => onDelete(files[i]),
              cloudIcon: cloudIcon,
            ),
          ],
        ],
      ),
    );
  }
}

// `.file-row` — grid 36 / 1fr / auto · 12/16 padding. TV compact: 30
// icon, 10/12 padding.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.onShare,
    required this.onRestore,
    required this.onDelete,
    this.cloudIcon = false,
  });

  final NsBackupFile file;

  /// Optional — cloud rows don't render a share button.
  final VoidCallback? onShare;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final bool cloudIcon;

  @override
  Widget build(BuildContext context) {
    final kindLabel =
        file.kind == NsBackupKind.personal ? 'personal' : 'share';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.bg2,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              cloudIcon
                  ? Icons.cloud_rounded
                  : Icons.insert_drive_file_rounded,
              size: 11,
              color: NsColors.accent,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    color: NsColors.text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${file.size} · ${file.date} · $kindLabel',
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 9.5,
                    height: 1.25,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          _IconBtn(
            icon: Icons.refresh_rounded,
            tooltip: 'Restore',
            onPressed: onRestore,
          ),
          if (onShare != null) ...[
            const SizedBox(width: 3),
            _IconBtn(
              icon: Icons.ios_share_rounded,
              tooltip: 'Share',
              onPressed: onShare!,
            ),
          ],
          const SizedBox(width: 3),
          _IconBtn(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete',
            danger: true,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: NsFocusable(
        onActivate: onPressed,
        semanticLabel: tooltip,
        builder: (context, focused) {
          final fg = danger ? NsColors.danger : NsColors.text2;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: NsEase.ease,
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focused
                  ? (danger
                      ? NsColors.dangerSoft
                      : NsColors.surface2)
                  : NsColors.surface,
              border: Border.all(
                color: focused
                    ? (danger ? NsColors.danger : NsColors.line2)
                    : NsColors.line,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 11, color: fg),
          );
        },
      ),
    );
  }
}

// (The _BackupsHeader above fully replaces the old `_CloudSectionHeader`.)

/// `● Signed in as {email}` (success) / `Sign in` (muted). Clickable
/// so the user can toggle the mock auth state.
class _SignInPill extends StatelessWidget {
  const _SignInPill({
    required this.signedIn,
    required this.account,
    required this.onPressed,
  });
  final bool signedIn;
  final String? account;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: signedIn ? 'Sign out' : 'Sign in',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: signedIn
              ? NsColors.successSoft
              : (focused ? NsColors.surface2 : NsColors.bg2),
          border: Border.all(
            color: signedIn
                ? const Color(0x594ADE80)
                : (focused ? NsColors.line2 : NsColors.line),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: signedIn ? NsColors.success : NsColors.text4,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              signedIn
                  ? 'Signed in as ${account ?? 'account'}'
                  : 'Sign in',
              style: TextStyle(
                color: signedIn ? NsColors.success : NsColors.text3,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Empty state — "No backups yet".
// ═══════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.insert_drive_file_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No backups yet',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use "Export personal" or "Export shareable" to create one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cloud-specific empty state — same chrome as `_EmptyState`, just a
/// cloud glyph + copy that points at Upload instead of Export.
class _CloudEmptyState extends StatelessWidget {
  const _CloudEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.cloud_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No cloud backups yet',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use "Upload personal" or "Upload shareable" to push a '
            'copy to the cloud.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
