import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/epg_timezone_catalog.dart';
import '../../data/playlist_epg_timezone_store.dart';
import '../../data/playlist_live_catalog_cache.dart';
import '../../data/playlist_type.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_cache_db.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';
import 'manage_live_channels_screen.dart';
import 'playlist_epg_time_screen.dart';
import 'playlist_group_manager_screen.dart';
import 'shield_tv_text_field.dart';

class MyPlaylistsScreen extends StatefulWidget {
  const MyPlaylistsScreen({super.key});

  @override
  State<MyPlaylistsScreen> createState() => _MyPlaylistsScreenState();
}

String _playlistEpgChipLabel(AppLocalizations l10n, String playlistId) {
  final mode = playlistEpgTimezoneStore.epgDisplayMode(playlistId);
  if (mode == kEpgDisplayModeLocal || mode.isEmpty) {
    return l10n.playlistEpgLocal;
  }
  if (mode == kEpgDisplayModeOriginal) {
    return l10n.playlistEpgOriginal;
  }
  return l10n.playlistEpgZoneChip(chipShortForIana(mode));
}

class _MyPlaylistsScreenState extends State<MyPlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    playlistEpgTimezoneStore.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _editPlaylist(StoredPlaylist p) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.teamPalette.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          child: _EditPlaylistForm(playlist: p),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(StoredPlaylist p) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return Dialog(
          backgroundColor: ctx.teamPalette.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.dialogDeletePlaylistTitle,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.dialogDeletePlaylistBody(p.name),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TvFocusable(
                          onActivate: () => Navigator.of(ctx).pop(),
                          child: _DialogButton(label: l10n.dialogCancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TvFocusable(
                          onActivate: () async {
                            await libraryController.deletePlaylist(p.id);
                            playlistLiveCatalogCache.evict(p.id);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: _DialogButton(
                            label: l10n.dialogDelete,
                            primary: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([libraryController, playlistEpgTimezoneStore]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context)!;
        final items = libraryController.playlists;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (!PlayerSettingsOverlayScope.isActiveContext(context))
                const SizedBox.expand(
                  child: TeamShellBackdrop(),
                ),
              SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TvFocusable(
                        focusPadding: const EdgeInsets.all(4),
                        onActivate: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.myPlaylistsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.myPlaylistsSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              l10n.myPlaylistsEmpty,
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final count = w >= 1100 ? 3 : (w >= 700 ? 2 : 1);
                              final ratio = count == 3
                                  ? 2.75
                                  : count == 2
                                      ? 2.45
                                      : 2.2;
                              return GridView.builder(
                                itemCount: items.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: count,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: ratio,
                                ),
                                itemBuilder: (context, i) {
                                  final p = items[i];
                                  final active = p.id ==
                                      libraryController.activePlaylistId;
                                  final epgChip = _playlistEpgChipLabel(
                                    l10n,
                                    p.id,
                                  );
                                  return _PlaylistGridTile(
                                    l10n: l10n,
                                    playlist: p,
                                    isActive: active,
                                    epgChipLabel: epgChip,
                                    onActivate: () async {
                                      await libraryController.setActivePlaylist(
                                        p.id,
                                      );
                                      await xtreamCatalogRepository
                                          .syncFromLibrary(
                                        libraryController,
                                      );
                                    },
                                    onRename: () => _editPlaylist(p),
                                    onDelete: () => _confirmDelete(p),
                                    onOpenEpgTime: () async {
                                      await pushSettingsRoute<void>(
                                        context,
                                        (_) => PlaylistEpgTimeScreen(
                                          playlist: p,
                                        ),
                                      );
                                    },
                                    onManageGroups: () async {
                                      if (libraryController.activePlaylistId !=
                                          p.id) {
                                        await libraryController
                                            .setActivePlaylist(p.id);
                                      }
                                      await xtreamCatalogRepository
                                          .syncFromLibrary(
                                        libraryController,
                                      );
                                      if (!mounted) return;
                                      pushSettingsRoute<void>(
                                        context,
                                        (_) => PlaylistGroupManagerScreen(
                                          playlist: p,
                                        ),
                                      );
                                    },
                                    onManageChannels: () async {
                                      if (libraryController.activePlaylistId !=
                                          p.id) {
                                        await libraryController
                                            .setActivePlaylist(p.id);
                                      }
                                      await xtreamCatalogRepository
                                          .syncFromLibrary(
                                        libraryController,
                                      );
                                      if (!mounted) return;
                                      pushSettingsRoute<void>(
                                        context,
                                        (_) => ManageLiveChannelsScreen(
                                          playlist: p,
                                        ),
                                      );
                                    },
                                  );
                                },
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
      },
    );
  }
}

/// Edit playlist name + Xtream (server / user / pass) or M3U URL — same chip as before.
class _EditPlaylistForm extends StatefulWidget {
  const _EditPlaylistForm({required this.playlist});

  final StoredPlaylist playlist;

  @override
  State<_EditPlaylistForm> createState() => _EditPlaylistFormState();
}

class _EditPlaylistFormState extends State<_EditPlaylistForm> {
  bool get _credentialsHidden =>
      widget.playlist.isXtream &&
      (widget.playlist.serverUrl == null || widget.playlist.serverUrl!.isEmpty) &&
      (widget.playlist.username == null || widget.playlist.username!.isEmpty);

  late final TextEditingController _name;
  late final TextEditingController _server;
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late final TextEditingController _m3u;

  late final FocusNode _serverFocus;
  late final FocusNode _userFocus;
  late final FocusNode _passFocus;
  late final FocusNode _nameFocus;
  late final FocusNode _m3uFocus;
  late final FocusNode _cancelFocus;
  late final FocusNode _saveFocus;

  @override
  void initState() {
    super.initState();
    final p = widget.playlist;
    _name = TextEditingController(text: p.name);
    _server = TextEditingController(text: p.serverUrl ?? '');
    _user = TextEditingController(text: p.username ?? '');
    _pass = TextEditingController(text: p.password ?? '');
    _m3u = TextEditingController(text: p.m3uUrl ?? '');
    _serverFocus = FocusNode(debugLabel: 'edit_pl_srv');
    _userFocus = FocusNode(debugLabel: 'edit_pl_usr');
    _passFocus = FocusNode(debugLabel: 'edit_pl_pwd');
    _nameFocus = FocusNode(debugLabel: 'edit_pl_nm');
    _m3uFocus = FocusNode(debugLabel: 'edit_pl_m3u');
    _cancelFocus = FocusNode(debugLabel: 'edit_pl_cancel');
    _saveFocus = FocusNode(debugLabel: 'edit_pl_save');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (p.isXtream) {
        _serverFocus.requestFocus();
      } else {
        _nameFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _server.dispose();
    _user.dispose();
    _pass.dispose();
    _m3u.dispose();
    _serverFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _nameFocus.dispose();
    _m3uFocus.dispose();
    _cancelFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final p = widget.playlist;
    final name = _name.text.trim();
    if (name.isEmpty) {
      _toast(l10n.dialogPlaylistEditInvalid);
      return;
    }
    if (p.isXtream) {
      if (_server.text.trim().isEmpty || _user.text.trim().isEmpty) {
        _toast(l10n.dialogPlaylistEditInvalid);
        return;
      }
      await libraryController.updatePlaylistDetails(
        id: p.id,
        name: name,
        serverUrl: _server.text,
        username: _user.text,
        password: _pass.text,
      );
    } else {
      if (_m3u.text.trim().isEmpty) {
        _toast(l10n.dialogPlaylistEditInvalid);
        return;
      }
      await libraryController.updatePlaylistDetails(
        id: p.id,
        name: name,
        m3uUrl: _m3u.text,
      );
    }
    await xtreamCatalogCacheDb.deleteForPlaylist(p.id);
    playlistLiveCatalogCache.evict(p.id);
    if (libraryController.activePlaylistId == p.id && p.isXtream) {
      await xtreamCatalogRepository.syncFromLibrary(libraryController);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final xt = widget.playlist.isXtream;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.dialogEditPlaylist,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (xt) ...[
                    if (_credentialsHidden) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16, color: Colors.amber),
                            SizedBox(width: 8),
                            Text(
                              'Credentials managed by admin',
                              style: TextStyle(color: Colors.amber, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      ShieldTvTextField(
                        dense: true,
                        label: l10n.dialogPlaylistServerUrl,
                        controller: _server,
                        focusNode: _serverFocus,
                        nextFieldFocus: _userFocus,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 8),
                      ShieldTvTextField(
                        dense: true,
                        label: l10n.dialogPlaylistUsername,
                        controller: _user,
                        focusNode: _userFocus,
                        previousFieldFocus: _serverFocus,
                        nextFieldFocus: _passFocus,
                      ),
                      const SizedBox(height: 8),
                      ShieldTvTextField(
                        dense: true,
                        label: l10n.dialogPlaylistPassword,
                        controller: _pass,
                        focusNode: _passFocus,
                        previousFieldFocus: _userFocus,
                        nextFieldFocus: _nameFocus,
                        obscure: true,
                      ),
                      const SizedBox(height: 8),
                    ],
                    ShieldTvTextField(
                      dense: true,
                      label: l10n.dialogPlaylistNameHint,
                      controller: _name,
                      focusNode: _nameFocus,
                      previousFieldFocus: _credentialsHidden ? null : _passFocus,
                      nextFieldFocus: _cancelFocus,
                    ),
                  ] else ...[
                    ShieldTvTextField(
                      dense: true,
                      label: l10n.dialogPlaylistNameHint,
                      controller: _name,
                      focusNode: _nameFocus,
                      nextFieldFocus: _m3uFocus,
                    ),
                    const SizedBox(height: 8),
                    ShieldTvTextField(
                      dense: true,
                      label: l10n.dialogPlaylistM3uUrl,
                      controller: _m3u,
                      focusNode: _m3uFocus,
                      previousFieldFocus: _nameFocus,
                      nextFieldFocus: _cancelFocus,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: TvFocusable(
                      focusNode: _cancelFocus,
                      onActivate: () => Navigator.of(context).pop(),
                      child: _DialogButton(label: l10n.dialogCancel),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(2),
                    child: TvFocusable(
                      focusNode: _saveFocus,
                      onActivate: () => unawaited(_submit()),
                      child: _DialogButton(
                        label: l10n.dialogSave,
                        primary: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  _DialogButton({required this.label, this.primary = false});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: primary
            ? context.teamPalette.accent.withOpacity(0.2)
            : Colors.white.withOpacity(0.06),
        border: Border.all(
          color: primary
              ? context.teamPalette.accent.withOpacity(0.65)
              : Colors.white.withOpacity(0.14),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: primary ? context.teamPalette.accent : Colors.white,
            ),
      ),
    );
  }
}

/// Compact tile for 2–3 playlists per row on TV.
class _PlaylistGridTile extends StatelessWidget {
  const _PlaylistGridTile({
    required this.l10n,
    required this.playlist,
    required this.isActive,
    required this.epgChipLabel,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
    required this.onOpenEpgTime,
    required this.onManageGroups,
    required this.onManageChannels,
  });

  final AppLocalizations l10n;
  final StoredPlaylist playlist;
  final bool isActive;
  final String epgChipLabel;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onOpenEpgTime;
  final VoidCallback onManageGroups;
  final VoidCallback onManageChannels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = playlist.type == PlaylistType.xtream
        ? l10n.playlistTypeXtream
        : l10n.playlistTypeM3u;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        border: Border.all(
          color: isActive
              ? context.teamPalette.accent.withOpacity(0.55)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(
                  playlist.type == PlaylistType.xtream
                      ? Icons.dns_rounded
                      : Icons.link_rounded,
                  size: 14,
                  color: Colors.white.withOpacity(0.88),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.myPlaylistTileStats(
                        typeLabel,
                        playlist.liveCount,
                        playlist.moviesCount,
                        playlist.seriesCount,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 9.5,
                        color: Colors.white.withOpacity(0.68),
                        height: 1.2,
                      ),
                    ),
                    if (playlist.isXtream)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: _PlaylistSubscriptionStatusLine(
                          l10n: l10n,
                          playlist: playlist,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TvFocusable(
                  onActivate: onManageGroups,
                  focusPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: _GridChip(
                    label: l10n.playlistChipGroups,
                    icon: Icons.folder_open_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TvFocusable(
                  onActivate: onOpenEpgTime,
                  focusPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: _GridChip(
                    label: epgChipLabel,
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TvFocusable(
            onActivate: onManageChannels,
            focusPadding:
                const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: _GridChip(
              label: l10n.playlistChipManageChannels,
              icon: Icons.settings_remote_rounded,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: isActive ? 0.45 : 1,
                  child: TvFocusable(
                    onActivate: isActive ? null : onActivate,
                    focusPadding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                    child: _GridChip(
                      label: isActive
                          ? l10n.playlistChipOn
                          : l10n.playlistChipUse,
                      icon: Icons.power_settings_new_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TvFocusable(
                  onActivate: onRename,
                  focusPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: _GridChip(
                    label: l10n.playlistChipRename,
                    icon: Icons.edit_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TvFocusable(
                  onActivate: onDelete,
                  focusPadding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: _GridChip(
                    label: l10n.playlistChipDelete,
                    icon: Icons.delete_outline_rounded,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Xtream: `Active` (green) / `Expire on …` (red). Unknown expiry: green "Active" only.
class _PlaylistSubscriptionStatusLine extends StatelessWidget {
  const _PlaylistSubscriptionStatusLine({
    required this.l10n,
    required this.playlist,
  });

  final AppLocalizations l10n;
  final StoredPlaylist playlist;

  static const Color _kGreen = Color(0xFF66BB6A);
  static const Color _kRed = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 0.2,
      fontWeight: FontWeight.w800,
      fontSize: 9,
      height: 1.2,
    );
    final expSec = playlist.subscriptionExpiresAtSec;
    if (expSec == null) {
      return Text(
        l10n.playlistSubscriptionActive,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: base?.copyWith(color: _kGreen),
      );
    }
    final expDt =
        DateTime.fromMillisecondsSinceEpoch(expSec * 1000, isUtc: true)
            .toLocal();
    final now = DateTime.now();
    final expired = !expDt.isAfter(now);
    final locale = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMMd(locale).format(expDt);
    final sepStyle = base?.copyWith(
      color: Colors.white.withOpacity(0.45),
      fontWeight: FontWeight.w700,
    );
    final headStyle = base?.copyWith(
      color: expired ? _kRed : _kGreen,
    );
    final tailStyle = base?.copyWith(color: _kRed);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: expired
                ? l10n.playlistSubscriptionExpired
                : l10n.playlistSubscriptionActive,
            style: headStyle,
          ),
          TextSpan(text: ' / ', style: sepStyle),
          TextSpan(
            text: l10n.playlistExpireOn(dateStr),
            style: tailStyle,
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _GridChip extends StatelessWidget {
  _GridChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

