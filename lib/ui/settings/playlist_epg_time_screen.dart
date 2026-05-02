import 'package:flutter/material.dart';

import '../../data/epg_timezone_catalog.dart';
import '../../data/playlist_epg_timezone_store.dart';
import '../../data/stored_playlist.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';

/// Centered EPG time picker (Local pinned, then Original + world zones) — same shell as Manage groups.
class PlaylistEpgTimeScreen extends StatelessWidget {
  const PlaylistEpgTimeScreen({super.key, required this.playlist});

  final StoredPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: playlistEpgTimezoneStore,
      builder: (context, _) {
        final current = playlistEpgTimezoneStore.epgDisplayMode(playlist.id);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              playerSettingsRouteBackdrop(context),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
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
                                  l10n.playlistEpgTimeScreenTitle,
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
                          const SizedBox(height: 6),
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.72),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.playlistEpgTimeScreenHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TvFocusable(
                            focusScale: 1.0,
                            parallaxSlide: 0.0,
                            showFocusElevation: false,
                            focusedBorderWidth: 1.4,
                            onActivate: () async {
                              await playlistEpgTimezoneStore.setEpgDisplayMode(
                                playlist.id,
                                kEpgDisplayModeLocal,
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            child: _EpgModeRowTile(
                              label: l10n.playlistEpgTimeRowLocal,
                              icon: Icons.public_rounded,
                              selected: current == kEpgDisplayModeLocal ||
                                  current.isEmpty,
                              subtitle: l10n.playlistEpgTimeRowLocalSubtitle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: 1 + kEpgTimezoneCatalog.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, i) {
                                  if (i == 0) {
                                    final sel =
                                        current == kEpgDisplayModeOriginal;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: TvFocusable(
                                        focusScale: 1.0,
                                        parallaxSlide: 0.0,
                                        showFocusElevation: false,
                                        focusedBorderWidth: 1.4,
                                        onActivate: () async {
                                          await playlistEpgTimezoneStore
                                              .setEpgDisplayMode(
                                            playlist.id,
                                            kEpgDisplayModeOriginal,
                                          );
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        child: _EpgModeRowTile(
                                          label: l10n
                                              .playlistEpgTimeRowOriginal,
                                          icon: Icons.dns_rounded,
                                          selected: sel,
                                          subtitle: l10n
                                              .playlistEpgTimeRowOriginalSubtitle,
                                        ),
                                      ),
                                    );
                                  }
                                  final entry = kEpgTimezoneCatalog[i - 1];
                                  final sel = current == entry.ianaId;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: TvFocusable(
                                      focusScale: 1.0,
                                      parallaxSlide: 0.0,
                                      showFocusElevation: false,
                                      focusedBorderWidth: 1.4,
                                      onActivate: () async {
                                        await playlistEpgTimezoneStore
                                            .setEpgDisplayMode(
                                          playlist.id,
                                          entry.ianaId,
                                        );
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: _EpgModeRowTile(
                                        label: entry.label,
                                        icon: Icons.schedule_rounded,
                                        selected: sel,
                                        subtitle: entry.ianaId,
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

class _EpgModeRowTile extends StatelessWidget {
  const _EpgModeRowTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.teamPalette.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: context.teamPalette.surfaceElevated,
        border: Border.all(
          color: selected ? accent.withOpacity(0.55) : Colors.white.withOpacity(0.08),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? accent : Colors.white.withOpacity(0.78),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: accent.withOpacity(0.95),
            ),
        ],
      ),
    );
  }
}
