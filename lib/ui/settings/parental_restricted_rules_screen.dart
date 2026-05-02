import 'package:flutter/material.dart';

import '../../data/library_controller.dart';
import '../../data/live_favorite_groups_store.dart';
import '../../data/parental_control_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shell/team_shell_backdrop.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'parental_panel_shell.dart';
import 'parental_rule_labels.dart';
import 'player_settings_overlay_scope.dart';

/// Lists lock rules (same data used for lock & hide) with remove actions.
class ParentalRestrictedRulesScreen extends StatelessWidget {
  const ParentalRestrictedRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = context.teamPalette.accent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: TeamShellBackdrop()),
          SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                parentalControlStore,
                libraryController,
                xtreamCatalogRepository,
                LiveFavoriteGroupsStore.instance,
              ]),
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Row(
                        children: [
                          TvFocusable(
                            onActivate: () => Navigator.of(context).pop(),
                            focusScale: 1.0,
                            parallaxSlide: 0,
                            showFocusElevation: false,
                            focusPadding: const EdgeInsets.all(4),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.parentalRulesTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          _sectionTitle(
                            theme,
                            l10n.parentalRulesSectionLive,
                            parentalControlStore.lockAllLive
                                ? l10n.parentalRulesLockAllOn
                                : l10n.parentalRulesLockAllOff,
                          ),
                          ..._liveRows(context, l10n, accent),
                          const SizedBox(height: 20),
                          _sectionTitle(
                            theme,
                            l10n.parentalRulesSectionMovies,
                            parentalControlStore.lockAllMovies
                                ? l10n.parentalRulesLockAllOn
                                : l10n.parentalRulesLockAllOff,
                          ),
                          ..._movieRows(context, l10n, accent),
                          const SizedBox(height: 20),
                          _sectionTitle(
                            theme,
                            l10n.parentalRulesSectionSeries,
                            parentalControlStore.lockAllSeries
                                ? l10n.parentalRulesLockAllOn
                                : l10n.parentalRulesLockAllOff,
                          ),
                          ..._seriesRows(context, l10n, accent),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title, String lockAllLine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lockAllLine,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _liveRows(
    BuildContext context,
    AppLocalizations l10n,
    Color accent,
  ) {
    final out = <Widget>[];
    final favs = parentalControlStore.lockedFavoriteGroupIdsSorted;
    for (final id in favs) {
      out.add(
        _ruleTile(
          context,
          accent,
          formatFavoriteGroupRuleLabel(l10n, id),
          () => parentalControlStore.removeLockedFavoriteGroup(id),
        ),
      );
    }
    for (final e in parentalControlStore.lockedLiveCategoriesByPlaylist.entries) {
      final pid = e.key;
      for (final id in e.value) {
        out.add(
          _ruleTile(
            context,
            accent,
            formatLiveCategoryRuleLabel(l10n, pid, id),
            () => parentalControlStore.removeLockedLiveCategory(
              pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
              id,
            ),
          ),
        );
      }
    }
    for (final e in parentalControlStore.lockedLiveChannelsByPlaylist.entries) {
      final pid = e.key;
      for (final id in e.value) {
        out.add(
          _ruleTile(
            context,
            accent,
            formatLiveChannelRuleLabel(l10n, pid, id),
            () => parentalControlStore.removeLockedLiveChannel(
              pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
              id,
            ),
          ),
        );
      }
    }
    if (out.isEmpty &&
        !parentalControlStore.lockAllLive) {
      out.add(
        Text(
          l10n.parentalRulesEmpty,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _movieRows(
    BuildContext context,
    AppLocalizations l10n,
    Color accent,
  ) {
    final out = <Widget>[];
    for (final e in parentalControlStore.lockedVodCategoriesByPlaylist.entries) {
      final pid = e.key;
      for (final id in e.value) {
        out.add(
          _ruleTile(
            context,
            accent,
            formatVodCategoryRuleLabel(l10n, pid, id),
            () => parentalControlStore.removeLockedVodCategory(
              pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
              id,
            ),
          ),
        );
      }
    }
    for (final e in parentalControlStore.lockedMovieIdsByPlaylist.entries) {
      final pid = e.key;
      for (final id in e.value) {
        out.add(
          _ruleTile(
            context,
            accent,
            formatMovieRuleLabel(l10n, pid, id),
            () => parentalControlStore.removeLockedMovie(
              pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
              id,
            ),
          ),
        );
      }
    }
    if (out.isEmpty && !parentalControlStore.lockAllMovies) {
      out.add(
        Text(
          l10n.parentalRulesEmpty,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _seriesRows(
    BuildContext context,
    AppLocalizations l10n,
    Color accent,
  ) {
    final out = <Widget>[];
    for (final e in parentalControlStore.lockedSeriesCategoriesByPlaylist.entries) {
      final pid = e.key;
      for (final id in e.value) {
        out.add(
          _ruleTile(
            context,
            accent,
            formatSeriesCategoryRuleLabel(l10n, pid, id),
            () => parentalControlStore.removeLockedSeriesCategory(
              pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
              id,
            ),
          ),
        );
      }
    }
    for (final e in parentalControlStore.lockedSeriesIdsByPlaylist.entries) {
      final pid = e.key;
      for (final id in e.value) {
        out.add(
          _ruleTile(
            context,
            accent,
            formatSeriesRuleLabel(l10n, pid, id),
            () => parentalControlStore.removeLockedSeries(
              pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
              id,
            ),
          ),
        );
      }
    }
    if (out.isEmpty && !parentalControlStore.lockAllSeries) {
      out.add(
        Text(
          l10n.parentalRulesEmpty,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    return out;
  }

  Widget _ruleTile(
    BuildContext context,
    Color accent,
    String label,
    Future<void> Function() onRemove,
  ) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ParentalPanelCard(
        compact: true,
        maxWidth: 900,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.25,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            TvFocusable(
              focusScale: 1.0,
              parallaxSlide: 0,
              showFocusElevation: false,
              onActivate: () async {
                await onRemove();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.parentalUnlocked)),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                child: Text(
                  l10n.parentalRulesRemoveRule,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [ParentalRestrictedRulesScreen] from Settings (shell or player overlay).
void openParentalRestrictedRulesScreen(BuildContext context) {
  pushSettingsRoute<void>(
    context,
    (_) => const ParentalRestrictedRulesScreen(),
  );
}
