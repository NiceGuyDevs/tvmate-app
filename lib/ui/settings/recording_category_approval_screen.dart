import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../data/recording_approval_store.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';
import 'recording_channel_approval_screen.dart';

/// Step B: shows all live categories for a playlist; each can be toggled
/// on/off for the Recording feature. Tapping an approved category opens
/// the channel-level approval screen (Step C).
class RecordingCategoryApprovalScreen extends StatelessWidget {
  const RecordingCategoryApprovalScreen({
    super.key,
    required this.playlist,
  });

  final StoredPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable:
          Listenable.merge([xtreamCatalogRepository, recordingApprovalStore]),
      builder: (context, _) {
        final categories = xtreamCatalogRepository.liveCategories;
        final approved = recordingApprovalStore.approvedCategoryIds(playlist.id);
        final filterCatchup =
            recordingApprovalStore.filterCatchupOnly(playlist.id);
        final tvFrame = recordingApprovalStore.tvFrameEpg(playlist.id);

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
                              l10n.catchupBreadcrumbCategories,
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
                        '${playlist.name} · ${approved.length} / ${categories.length} approved',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                              onActivate: categories.isEmpty
                                  ? null
                                  : () => recordingApprovalStore
                                          .setAllCategoriesApproved(
                                        playlistId: playlist.id,
                                        categoryIds:
                                            categories.map((c) => c.id),
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
                              onActivate: categories.isEmpty
                                  ? null
                                  : () => recordingApprovalStore
                                          .setAllCategoriesApproved(
                                        playlistId: playlist.id,
                                        categoryIds:
                                            categories.map((c) => c.id),
                                        approved: false,
                                      ),
                              child: _QuickActionTile(
                                label: l10n.catchupClearAll,
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
                              onActivate: () =>
                                  recordingApprovalStore.setFilterCatchupOnly(
                                playlistId: playlist.id,
                                value: !filterCatchup,
                              ),
                              child: _QuickActionTile(
                                label: filterCatchup
                                    ? l10n.catchupFilterQuickOn
                                    : l10n.catchupFilterQuickOff,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TvFocusable(
                        focusScale: 1.0,
                        parallaxSlide: 0.0,
                        showFocusElevation: false,
                        focusedBorderWidth: 1.4,
                        onActivate: () => recordingApprovalStore.setTvFrameEpg(
                          playlistId: playlist.id,
                          value: !tvFrame,
                        ),
                        child: _QuickActionTile(
                          label: tvFrame
                              ? 'TV frame on EPG: ON'
                              : 'TV frame on EPG: OFF',
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Category list
                      Expanded(
                        child: categories.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.catchupNoLiveCategoriesSync,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: ListView.separated(
                                  itemCount: categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, i) {
                                    final cat = categories[i];
                                    final isApproved =
                                        approved.contains(cat.id);
                                    return TvFocusable(
                                      focusScale: 1.0,
                                      parallaxSlide: 0.0,
                                      showFocusElevation: false,
                                      focusedBorderWidth: 1.4,
                                      focusPadding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      onActivate: () {
                                        if (isApproved) {
                                          pushSettingsRoute<void>(
                                            context,
                                            (_) =>
                                                RecordingChannelApprovalScreen(
                                              playlist: playlist,
                                              categoryId: cat.id,
                                              categoryName: cat.name,
                                            ),
                                          );
                                        } else {
                                          recordingApprovalStore
                                              .setCategoryApproved(
                                            playlistId: playlist.id,
                                            categoryId: cat.id,
                                            approved: true,
                                          );
                                        }
                                      },
                                      child: _CategoryToggleRow(
                                        name: cat.name,
                                        enabled: isApproved,
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

class _CategoryToggleRow extends StatelessWidget {
  const _CategoryToggleRow({required this.name, required this.enabled});

  final String name;
  final bool enabled;

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
          if (enabled)
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Colors.white.withOpacity(0.45),
            ),
          const SizedBox(width: 4),
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
