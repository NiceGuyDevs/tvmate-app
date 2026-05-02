import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/recording_approval_store.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';
import 'recording_category_approval_screen.dart';

/// Step A: lists all Xtream playlists so the user can pick which one to
/// configure for the Recording / catch-up feature.
class RecordingEditScreen extends StatelessWidget {
  const RecordingEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([libraryController, recordingApprovalStore]),
      builder: (context, _) {
        final playlists = libraryController.playlists
            .where((p) => p.isXtream)
            .toList(growable: false);

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
                      Text(
                        l10n.settingsRecordingEdit,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.catchupSelectPlaylistHelp,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (playlists.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.catchupNoXtreamPlaylists,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: GridView.builder(
                        itemCount: playlists.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.35,
                        ),
                        itemBuilder: (context, i) {
                          final pl = playlists[i];
                          final approved =
                              recordingApprovalStore.isPlaylistApproved(pl.id);
                          final catCount = recordingApprovalStore
                              .approvedCategoryIds(pl.id)
                              .length;
                          return TvFocusable(
                            autofocus: i == 0,
                            focusPadding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 5,
                            ),
                            onActivate: () {
                              pushSettingsRoute<void>(
                                context,
                                (_) => RecordingCategoryApprovalScreen(
                                  playlist: pl,
                                ),
                              );
                            },
                            child: _PlaylistTile(
                              name: pl.name,
                              subtitle: approved
                                  ? '$catCount categor${catCount == 1 ? 'y' : 'ies'} approved'
                                  : 'Not configured',
                              approved: approved,
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

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.name,
    required this.subtitle,
    required this.approved,
  });

  final String name;
  final String subtitle;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.teamPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.025),
          ],
        ),
        border: Border.all(
          color: approved
              ? palette.accent.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: approved ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(
              Icons.fiber_smart_record_rounded,
              size: 15,
              color: Colors.white.withOpacity(0.92),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 12.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.72),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Colors.white.withOpacity(0.45),
          ),
        ],
      ),
    );
  }
}
