import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/library_controller.dart';
import '../../data/playlist_channel_override_store.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import '../live_tv/mock_live_tv_data.dart';
import 'player_settings_overlay_scope.dart';
import 'shield_tv_text_field.dart';

/// Entry: **Manage channels** on a playlist card → categories → channels with overrides.
class ManageLiveChannelsScreen extends StatefulWidget {
  const ManageLiveChannelsScreen({super.key, required this.playlist});

  final StoredPlaylist playlist;

  @override
  State<ManageLiveChannelsScreen> createState() =>
      _ManageLiveChannelsScreenState();
}

class _ManageLiveChannelsScreenState extends State<ManageLiveChannelsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(playlistChannelOverrideStore.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isActive = libraryController.activePlaylistId == widget.playlist.id;

    return ListenableBuilder(
      listenable: Listenable.merge([
        xtreamCatalogRepository,
        playlistGroupVisibilityStore,
        playlistChannelOverrideStore,
      ]),
      builder: (context, _) {
        final cats = xtreamCatalogRepository.liveCategories;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              playerSettingsRouteBackdrop(context),
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
                          Expanded(
                            child: Text(
                              l10n.manageLiveChannelsTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.manageLiveChannelsSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.58),
                        ),
                      ),
                      if (!isActive) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.manageLiveChannelsNeedActive,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Expanded(
                        child: cats.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.manageLiveChannelsNoCategories,
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.separated(
                                itemCount: cats.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, i) {
                                  final c = cats[i];
                                  final label =
                                      playlistGroupVisibilityStore
                                          .categoryDisplayName(
                                    widget.playlist.id,
                                    PlaylistGroupSection.live,
                                    c.id,
                                    c.name,
                                  );
                                  return TvFocusable(
                                    onActivate: !isActive
                                        ? null
                                        : () {
                                            pushSettingsRoute<void>(
                                              context,
                                              (_) =>
                                                  ManageLiveChannelsCategoryScreen(
                                                playlist: widget.playlist,
                                                categoryId: c.id,
                                                categoryName: label,
                                              ),
                                            );
                                          },
                                    focusPadding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 5,
                                    ),
                                    child: Opacity(
                                      opacity: isActive ? 1 : 0.55,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.06),
                                              Colors.white.withOpacity(0.025),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.folder_open_rounded,
                                              size: 18,
                                              color: Colors.white
                                                  .withOpacity(0.88),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                label,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.labelLarge
                                                    ?.copyWith(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 20,
                                              color: Colors.white
                                                  .withOpacity(0.45),
                                            ),
                                          ],
                                        ),
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
      },
    );
  }
}

class ManageLiveChannelsCategoryScreen extends StatefulWidget {
  const ManageLiveChannelsCategoryScreen({
    super.key,
    required this.playlist,
    required this.categoryId,
    required this.categoryName,
  });

  final StoredPlaylist playlist;
  final String categoryId;
  final String categoryName;

  @override
  State<ManageLiveChannelsCategoryScreen> createState() =>
      _ManageLiveChannelsCategoryScreenState();
}

class _ManageLiveChannelsCategoryScreenState
    extends State<ManageLiveChannelsCategoryScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(playlistChannelOverrideStore.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        xtreamCatalogRepository,
        playlistChannelOverrideStore,
      ]),
      builder: (context, _) {
        // Same order as the playlist/catalog (liveChannelsAll), not A–Z.
        final raw = xtreamCatalogRepository
            .liveChannelsForCategory(widget.categoryId);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              playerSettingsRouteBackdrop(context),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                              Expanded(
                                child: Text(
                                  widget.categoryName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: raw.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n.manageLiveChannelsCategoryEmpty,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: raw.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 6),
                                    itemBuilder: (context, i) {
                                      return _LiveChannelOverrideCard(
                                        playlistId: widget.playlist.id,
                                        channel: raw[i],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
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

class _LiveChannelOverrideCard extends StatelessWidget {
  const _LiveChannelOverrideCard({
    required this.playlistId,
    required this.channel,
  });

  final String playlistId;
  final MockLiveChannel channel;

  Future<void> _dialogName(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cur = playlistChannelOverrideStore.displayNameOverride(
          playlistId,
          channel.id,
        ) ??
        '';
    final controller = TextEditingController(text: cur);
    final nameFocus = FocusNode(debugLabel: 'chName');
    final saveFocus = FocusNode(debugLabel: 'chNameSave');
    final cancelFocus = FocusNode(debugLabel: 'chNameCancel');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: ctx.teamPalette.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.channelOverrideDisplayNameDialogTitle,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.playlistGroupOriginalLabel(channel.name),
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.65),
                        ),
                  ),
                  const SizedBox(height: 10),
                  ShieldTvTextField(
                    dense: true,
                    label: l10n.channelOverrideDisplayNameDialogTitle,
                    hint: l10n.channelOverrideDisplayNameHint,
                    controller: controller,
                    focusNode: nameFocus,
                    nextFieldFocus: saveFocus,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TvFocusable(
                          focusNode: cancelFocus,
                          onActivate: () => Navigator.of(ctx).pop(),
                          child: _MiniDialogButton(
                            label: l10n.dialogCancel,
                            primary: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TvFocusable(
                          focusNode: saveFocus,
                          onActivate: () async {
                            await playlistChannelOverrideStore.setDisplayName(
                              playlistId: playlistId,
                              channelId: channel.id,
                              displayName: controller.text,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: _MiniDialogButton(
                            label: l10n.dialogSave,
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

    controller.dispose();
    nameFocus.dispose();
    saveFocus.dispose();
    cancelFocus.dispose();
  }

  Future<void> _dialogLogo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cur = playlistChannelOverrideStore.logoUrlOverride(
          playlistId,
          channel.id,
        ) ??
        '';
    final controller = TextEditingController(text: cur);
    final urlFocus = FocusNode(debugLabel: 'chLogo');
    final saveFocus = FocusNode(debugLabel: 'chLogoSave');
    final cancelFocus = FocusNode(debugLabel: 'chLogoCancel');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: ctx.teamPalette.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.channelOverrideLogoDialogTitle,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.channelOverrideLogoDialogHint,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.65),
                        ),
                  ),
                  const SizedBox(height: 10),
                  ShieldTvTextField(
                    dense: true,
                    label: l10n.channelOverrideLogoAction,
                    hint: l10n.channelOverrideLogoDialogHint,
                    controller: controller,
                    focusNode: urlFocus,
                    nextFieldFocus: saveFocus,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TvFocusable(
                          focusNode: cancelFocus,
                          onActivate: () => Navigator.of(ctx).pop(),
                          child: _MiniDialogButton(
                            label: l10n.dialogCancel,
                            primary: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TvFocusable(
                          focusNode: saveFocus,
                          onActivate: () async {
                            await playlistChannelOverrideStore.setLogoUrl(
                              playlistId: playlistId,
                              channelId: channel.id,
                              logoUrl: controller.text,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: _MiniDialogButton(
                            label: l10n.dialogSave,
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

    controller.dispose();
    urlFocus.dispose();
    saveFocus.dispose();
    cancelFocus.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final pid = playlistId;
    final serverName = channel.name;
    final display = playlistChannelOverrideStore.displayName(
      pid,
      channel.id,
      serverName,
    );
    final hasAlias = display != serverName;
    final hidden = playlistChannelOverrideStore.isHidden(pid, channel.id);
    final hasLogo =
        playlistChannelOverrideStore.logoUrlOverride(pid, channel.id) != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          if (hasAlias) ...[
            const SizedBox(height: 2),
            Text(
              l10n.playlistGroupOriginalLabel(serverName),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                color: Colors.white.withOpacity(0.55),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (hidden)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.orange.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.45),
                    ),
                  ),
                  child: Text(
                    l10n.channelOverrideHiddenFromLive,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade200,
                    ),
                  ),
                ),
              if (hasLogo)
                Icon(
                  Icons.image_rounded,
                  size: 14,
                  color: context.teamPalette.accent.withOpacity(0.9),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TvFocusable(
                  onActivate: () => unawaited(_dialogName(context)),
                  child: _ActionChip(
                    label: l10n.channelOverrideNameAction,
                    icon: Icons.badge_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TvFocusable(
                  onActivate: () => unawaited(_dialogLogo(context)),
                  child: _ActionChip(
                    label: l10n.channelOverrideLogoAction,
                    icon: Icons.image_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TvFocusable(
                  onActivate: () async {
                    await playlistChannelOverrideStore.setHidden(
                      playlistId: pid,
                      channelId: channel.id,
                      hidden: !hidden,
                    );
                  },
                  child: _ActionChip(
                    label: hidden
                        ? l10n.channelOverrideVisibleInLive
                        : l10n.channelOverrideHiddenFromLive,
                    icon: hidden ? Icons.visibility_rounded : Icons.visibility_off_outlined,
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

class _MiniDialogButton extends StatelessWidget {
  const _MiniDialogButton({required this.label, required this.primary});

  final String label;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: primary
            ? context.teamPalette.accent.withOpacity(0.2)
            : Colors.white.withOpacity(0.06),
        border: Border.all(
          color: primary
              ? context.teamPalette.accent.withOpacity(0.55)
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.88)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
