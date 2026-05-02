import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../data/recording_approval_store.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';

/// Step C: shows all live channels in a category; each can be toggled on/off
/// for the Recording feature. When the "Recording filter" is active, channels
/// without catch-up / archive (`tv_archive`) are dimmed.
class RecordingChannelApprovalScreen extends StatelessWidget {
  const RecordingChannelApprovalScreen({
    super.key,
    required this.playlist,
    required this.categoryId,
    required this.categoryName,
  });

  final StoredPlaylist playlist;
  final String categoryId;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable:
          Listenable.merge([xtreamCatalogRepository, recordingApprovalStore]),
      builder: (context, _) {
        final allChannels = xtreamCatalogRepository
            .liveChannelsForCategory(categoryId);
        final filterCatchup =
            recordingApprovalStore.filterCatchupOnly(playlist.id);
        final approvedIds =
            recordingApprovalStore.approvedChannelIds(playlist.id, categoryId);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              playerSettingsRouteBackdrop(context),
              SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
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
                              l10n.catchupBreadcrumbWithCategory(categoryName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${approvedIds.length} / ${allChannels.length} channels approved',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick actions
                      Row(
                        children: [
                          Expanded(
                            child: TvFocusable(
                              focusScale: 1.0,
                              parallaxSlide: 0.0,
                              showFocusElevation: false,
                              focusedBorderWidth: 1.4,
                              autofocus: true,
                              onActivate: allChannels.isEmpty
                                  ? null
                                  : () => recordingApprovalStore
                                          .setAllChannelsApproved(
                                        playlistId: playlist.id,
                                        categoryId: categoryId,
                                        channelIds:
                                            allChannels.map((c) => c.id),
                                        approved: true,
                                      ),
                              child: _QuickActionTile(
                                label: l10n.catchupSelectAll,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TvFocusable(
                              focusScale: 1.0,
                              parallaxSlide: 0.0,
                              showFocusElevation: false,
                              focusedBorderWidth: 1.4,
                              onActivate: allChannels.isEmpty
                                  ? null
                                  : () => recordingApprovalStore
                                          .setAllChannelsApproved(
                                        playlistId: playlist.id,
                                        categoryId: categoryId,
                                        channelIds:
                                            allChannels.map((c) => c.id),
                                        approved: false,
                                      ),
                              child: _QuickActionTile(
                                label: l10n.catchupClearAll,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Channel list
                      Expanded(
                        child: allChannels.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.catchupNoChannelsInCategory,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: ListView.separated(
                                  itemCount: allChannels.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, i) {
                                    final ch = allChannels[i];
                                    final isApproved =
                                        approvedIds.contains(ch.id);
                                    final dimmed =
                                        filterCatchup && !ch.hasCatchup;
                                    return Opacity(
                                      opacity: dimmed ? 0.35 : 1.0,
                                      child: TvFocusable(
                                        focusScale: 1.0,
                                        parallaxSlide: 0.0,
                                        showFocusElevation: false,
                                        focusedBorderWidth: 1.4,
                                        focusPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        onActivate: () => recordingApprovalStore
                                            .setChannelApproved(
                                          playlistId: playlist.id,
                                          categoryId: categoryId,
                                          channelId: ch.id,
                                          approved: !isApproved,
                                        ),
                                        child: _ChannelToggleRow(
                                          name: ch.name,
                                          enabled: isApproved,
                                          hasPanelEpg: ch.hasPanelEpg,
                                          hasCatchup: ch.hasCatchup,
                                        ),
                                      ),
                                    );
                                  },
                                ),
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ChannelToggleRow extends StatelessWidget {
  const _ChannelToggleRow({
    required this.name,
    required this.enabled,
    required this.hasPanelEpg,
    required this.hasCatchup,
  });

  final String name;
  final bool enabled;
  final bool hasPanelEpg;
  final bool hasCatchup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.teamPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 5, 8, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: palette.surfaceElevated,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          if (hasPanelEpg || hasCatchup)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasPanelEpg)
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  if (hasCatchup) ...[
                    if (hasPanelEpg) const SizedBox(width: 4),
                    Icon(
                      Icons.history_rounded,
                      size: 14,
                      color: palette.accent.withOpacity(0.75),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 24,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: enabled
                  ? palette.accent.withOpacity(0.42)
                  : Colors.white.withOpacity(0.14),
              border: Border.all(
                color: enabled
                    ? palette.accent.withOpacity(0.65)
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: Align(
              alignment:
                  enabled ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
