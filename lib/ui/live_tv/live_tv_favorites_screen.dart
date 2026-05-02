import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/live_favorite_groups_store.dart';
import '../../data/live_tv_card_style_store.dart';
import '../../data/live_tv_name_horizontal_bias_store.dart';
import '../../data/live_tv_name_vertical_bias_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/team_palette_theme.dart';
import '../catalog/catalog_status_widgets.dart';
import '../focus/tv_focusable.dart';
import '../settings/player_settings_overlay_scope.dart';
import 'live_favorite_group_editor_screen.dart';

/// **Favorite setup** (Settings): named favorite groups, order, ordered channels.
class LiveTvFavoritesScreen extends StatefulWidget {
  const LiveTvFavoritesScreen({super.key});

  @override
  State<LiveTvFavoritesScreen> createState() => _LiveTvFavoritesScreenState();
}

class _LiveTvFavoritesScreenState extends State<LiveTvFavoritesScreen> {
  @override
  void initState() {
    super.initState();
    LiveFavoriteGroupsStore.instance.addListener(_onStore);
    libraryController.addListener(_onLib);
    xtreamCatalogRepository.addListener(_onCat);
    liveTvCardStyleStore.addListener(_onCat);
    liveTvNameVerticalBiasStore.addListener(_onCat);
    liveTvNameHorizontalBiasStore.addListener(_onCat);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LiveFavoriteGroupsStore.instance.ensureLoaded();
      await xtreamCatalogRepository.syncFromLibrary(libraryController);
      if (mounted) setState(() {});
    });
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _onLib() {
    if (mounted) setState(() {});
  }

  void _onCat() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LiveFavoriteGroupsStore.instance.removeListener(_onStore);
    libraryController.removeListener(_onLib);
    xtreamCatalogRepository.removeListener(_onCat);
    liveTvCardStyleStore.removeListener(_onCat);
    liveTvNameVerticalBiasStore.removeListener(_onCat);
    liveTvNameHorizontalBiasStore.removeListener(_onCat);
    super.dispose();
  }

  Future<void> _openEditor({LiveFavoriteGroup? existing}) async {
    await pushSettingsRoute<void>(
      context,
      (context) => LiveFavoriteGroupEditorScreen(existing: existing),
      fullscreenDialog: true,
    );
    if (mounted) setState(() {});
  }

  bool get _isPushedRoute => ModalRoute.of(context)?.canPop ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!libraryController.useDemoData) {
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.loading) {
        return CatalogLoadingBody(message: l10n.catalogLoading);
      }
      if (xtreamCatalogRepository.phase == XtreamCatalogPhase.error) {
        return CatalogErrorBody(
          message: l10n.catalogErrorPlaylist,
          subtitle: xtreamCatalogRepository.errorMessage,
        );
      }
    }

    final content = _buildContent(context, l10n);

    if (_isPushedRoute) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            playerSettingsRouteBackdrop(context),
            SafeArea(child: content),
          ],
        ),
      );
    }
    return content;
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    final groups = LiveFavoriteGroupsStore.instance.groupsSorted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isPushedRoute) ...[
                TvFocusable(
                  focusPadding: const EdgeInsets.all(4),
                  onActivate: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.14)),
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
              ],
              Text(
                l10n.settingsFavoriteSetup,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: p.surfaceElevated,
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: p.railCardRestShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: p.accent.withOpacity(0.9),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.favSetupInfoBanner,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.86),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              itemCount: groups.length + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _NewFavoriteTile(
                    l10n: l10n,
                    autofocus: true,
                    onActivate: () => unawaited(_openEditor()),
                  );
                }
                final g = groups[index - 1];
                return _FavoriteGroupTile(
                  l10n: l10n,
                  name: g.name,
                  channelCount: g.channelRefs.length,
                  sortOrder: g.sortOrder,
                  onActivate: () => unawaited(_openEditor(existing: g)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewFavoriteTile extends StatelessWidget {
  const _NewFavoriteTile({
    required this.l10n,
    required this.onActivate,
    this.autofocus = false,
  });

  final AppLocalizations l10n;
  final VoidCallback onActivate;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.teamPalette;
    return TvFocusable(
      autofocus: autofocus,
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: p.accent.withOpacity(0.08),
          border: Border.all(color: p.accent.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.accent.withOpacity(0.18),
                border: Border.all(color: p.accent.withOpacity(0.3)),
              ),
              child: Icon(Icons.add_rounded, size: 15, color: p.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.favNewFavorite,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 12.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.favCreateGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
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

class _FavoriteGroupTile extends StatelessWidget {
  const _FavoriteGroupTile({
    required this.l10n,
    required this.name,
    required this.channelCount,
    required this.sortOrder,
    required this.onActivate,
  });

  final AppLocalizations l10n;
  final String name;
  final int channelCount;
  final int sortOrder;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TvFocusable(
      onActivate: onActivate,
      focusPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.06),
              Colors.white.withOpacity(0.025),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
              child: Icon(Icons.star_rounded,
                  size: 15, color: Colors.white.withOpacity(0.92)),
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
                    l10n.favGroupSubtitle(channelCount, sortOrder),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.62),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: Colors.white.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }
}
