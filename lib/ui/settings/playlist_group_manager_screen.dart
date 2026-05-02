import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/library_controller.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'player_settings_overlay_scope.dart';
import 'shield_tv_text_field.dart';

class PlaylistGroupManagerScreen extends StatefulWidget {
  const PlaylistGroupManagerScreen({super.key, required this.playlist});

  final StoredPlaylist playlist;

  @override
  State<PlaylistGroupManagerScreen> createState() =>
      _PlaylistGroupManagerScreenState();
}

class _PlaylistGroupManagerScreenState
    extends State<PlaylistGroupManagerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await playlistGroupVisibilityStore.ensureLoaded();
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = libraryController.activePlaylistId == widget.playlist.id;

    return ListenableBuilder(
      listenable: Listenable.merge(
        [
          libraryController,
          xtreamCatalogRepository,
          playlistGroupVisibilityStore
        ],
      ),
      builder: (context, _) {
        final sections = _sectionSummaries(widget.playlist.id);
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
                              'Manage groups',
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
                      const SizedBox(height: 8),
                      Text(
                        widget.playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      if (!isActive) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Activate this playlist first.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          itemCount: sections.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.35,
                          ),
                          itemBuilder: (context, i) {
                            final section = sections[i];
                            final icon = switch (section.section) {
                              PlaylistGroupSection.live =>
                                Icons.live_tv_rounded,
                              PlaylistGroupSection.vod => Icons.movie_outlined,
                              PlaylistGroupSection.series =>
                                Icons.subscriptions_rounded,
                            };
                            return TvFocusable(
                              onActivate: !isActive
                                  ? null
                                  : () {
                                      pushSettingsRoute<void>(
                                        context,
                                        (_) => PlaylistGroupSectionScreen(
                                          playlist: widget.playlist,
                                          section: section.section,
                                        ),
                                      );
                                    },
                              focusPadding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 5,
                              ),
                              child: Opacity(
                                opacity: isActive ? 1 : 0.55,
                                child: _SectionTile(
                                  label: section.label,
                                  subtitle:
                                      '${section.enabledCount} / ${section.totalCount}',
                                  icon: icon,
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

  List<_SectionSummary> _sectionSummaries(String playlistId) {
    final live = xtreamCatalogRepository.liveCategories;
    final vod = xtreamCatalogRepository.vodCategories;
    final series = xtreamCatalogRepository.seriesCategories;
    return [
      _SectionSummary(
        section: PlaylistGroupSection.live,
        label: 'TV',
        enabledCount: playlistGroupVisibilityStore.countVisibleCategories(
          playlistId,
          PlaylistGroupSection.live,
          live.map((e) => e.id),
        ),
        totalCount: live.length,
      ),
      _SectionSummary(
        section: PlaylistGroupSection.vod,
        label: 'Movies',
        enabledCount: playlistGroupVisibilityStore.countVisibleCategories(
          playlistId,
          PlaylistGroupSection.vod,
          vod.map((e) => e.id),
        ),
        totalCount: vod.length,
      ),
      _SectionSummary(
        section: PlaylistGroupSection.series,
        label: 'Shows',
        enabledCount: playlistGroupVisibilityStore.countVisibleCategories(
          playlistId,
          PlaylistGroupSection.series,
          series.map((e) => e.id),
        ),
        totalCount: series.length,
      ),
    ];
  }
}

class PlaylistGroupSectionScreen extends StatefulWidget {
  const PlaylistGroupSectionScreen({
    super.key,
    required this.playlist,
    required this.section,
  });

  final StoredPlaylist playlist;
  final PlaylistGroupSection section;

  @override
  State<PlaylistGroupSectionScreen> createState() =>
      _PlaylistGroupSectionScreenState();
}

class _PlaylistGroupSectionScreenState
    extends State<PlaylistGroupSectionScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: playlistGroupVisibilityStore,
      builder: (context, _) {
        final entries = _entriesForSection(widget.section);
        final visibleCount =
            playlistGroupVisibilityStore.countVisibleCategories(
          widget.playlist.id,
          widget.section,
          entries.map((e) => e.id),
        );
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
                                  _sectionLabel(widget.section),
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
                            'Enabled $visibleCount / ${entries.length}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.72),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TvFocusable(
                                  focusScale: 1.0,
                                  parallaxSlide: 0.0,
                                  showFocusElevation: false,
                                  focusedBorderWidth: 1.4,
                                  onActivate: entries.isEmpty
                                      ? null
                                      : () => playlistGroupVisibilityStore
                                              .setAllVisible(
                                            playlistId: widget.playlist.id,
                                            section: widget.section,
                                            categoryIds:
                                                entries.map((e) => e.id),
                                            visible: true,
                                          ),
                                  child: const _QuickActionTile(
                                    label: 'Show all',
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
                                  onActivate: entries.isEmpty
                                      ? null
                                      : () => playlistGroupVisibilityStore
                                              .setAllVisible(
                                            playlistId: widget.playlist.id,
                                            section: widget.section,
                                            categoryIds:
                                                entries.map((e) => e.id),
                                            visible: false,
                                          ),
                                  child: const _QuickActionTile(
                                    label: 'Hide all',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: entries.isEmpty
                                ? Center(
                                    child: Text(
                                      'No groups available. Sync this playlist first.',
                                      style: theme.textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: ListView.separated(
                                      itemCount: entries.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 4),
                                      itemBuilder: (context, i) {
                                        final entry = entries[i];
                                        final visible =
                                            playlistGroupVisibilityStore
                                                .isCategoryVisible(
                                          widget.playlist.id,
                                          widget.section,
                                          entry.id,
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: _GroupCategoryEditRow(
                                            playlistId: widget.playlist.id,
                                            section: widget.section,
                                            entry: entry,
                                            visible: visible,
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

  List<_GroupEntry> _entriesForSection(PlaylistGroupSection section) {
    switch (section) {
      case PlaylistGroupSection.live:
        return [
          for (final c in xtreamCatalogRepository.liveCategories)
            _GroupEntry(id: c.id, name: c.name),
        ];
      case PlaylistGroupSection.vod:
        return [
          for (final c in xtreamCatalogRepository.vodCategories)
            _GroupEntry(id: c.id, name: c.name),
        ];
      case PlaylistGroupSection.series:
        return [
          for (final c in xtreamCatalogRepository.seriesCategories)
            _GroupEntry(id: c.id, name: c.name),
        ];
    }
  }
}

String _sectionLabel(PlaylistGroupSection section) {
  return switch (section) {
    PlaylistGroupSection.live => 'TV',
    PlaylistGroupSection.vod => 'Movies',
    PlaylistGroupSection.series => 'Shows',
  };
}

class _SectionSummary {
  const _SectionSummary({
    required this.section,
    required this.label,
    required this.enabledCount,
    required this.totalCount,
  });

  final PlaylistGroupSection section;
  final String label;
  final int enabledCount;
  final int totalCount;
}

class _GroupEntry {
  const _GroupEntry({required this.id, required this.name});

  final String id;
  final String name;
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: Icon(icon, size: 15, color: Colors.white.withOpacity(0.92)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
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

class _GroupCategoryEditRow extends StatefulWidget {
  const _GroupCategoryEditRow({
    required this.playlistId,
    required this.section,
    required this.entry,
    required this.visible,
  });

  final String playlistId;
  final PlaylistGroupSection section;
  final _GroupEntry entry;
  final bool visible;

  @override
  State<_GroupCategoryEditRow> createState() => _GroupCategoryEditRowState();
}

class _GroupCategoryEditRowState extends State<_GroupCategoryEditRow> {
  var _editing = false;
  var _orderPanelOpen = false;
  /// When the pill-order panel is open: pin this category before favorite groups.
  var _panelBeforeFavorites = false;

  late final TextEditingController _aliasController;
  late final TextEditingController _orderPosController;
  late final FocusNode _aliasFocus;
  late final FocusNode _saveFocus;
  late final FocusNode _cancelFocus;
  late final FocusNode _toggleFocus;
  late final FocusNode _orderPosFocus;
  late final FocusNode _orderSaveFocus;
  late final FocusNode _orderCancelFocus;
  late final FocusNode _orderAfterFocus;
  late final FocusNode _orderBeforeFocus;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController();
    _orderPosController = TextEditingController(text: '1');
    _aliasFocus = FocusNode();
    _saveFocus = FocusNode();
    _cancelFocus = FocusNode();
    _toggleFocus = FocusNode(debugLabel: 'groupToggle');
    _orderPosFocus = FocusNode(debugLabel: 'pillOrderPos');
    _orderSaveFocus = FocusNode(debugLabel: 'pillOrderSave');
    _orderCancelFocus = FocusNode(debugLabel: 'pillOrderCancel');
    _orderAfterFocus = FocusNode(debugLabel: 'pillOrderAfter');
    _orderBeforeFocus = FocusNode(debugLabel: 'pillOrderBefore');
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _orderPosController.dispose();
    _aliasFocus.dispose();
    _saveFocus.dispose();
    _cancelFocus.dispose();
    _toggleFocus.dispose();
    _orderPosFocus.dispose();
    _orderSaveFocus.dispose();
    _orderCancelFocus.dispose();
    _orderAfterFocus.dispose();
    _orderBeforeFocus.dispose();
    super.dispose();
  }

  void _openEdit() {
    if (_orderPanelOpen) {
      setState(() => _orderPanelOpen = false);
    }
    final alias = playlistGroupVisibilityStore.categoryAlias(
      widget.playlistId,
      widget.section,
      widget.entry.id,
    );
    setState(() {
      _editing = true;
      _aliasController.text = alias ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _aliasFocus.requestFocus();
    });
  }

  void _closeEdit() {
    setState(() => _editing = false);
  }

  Future<void> _saveAlias() async {
    await playlistGroupVisibilityStore.setCategoryAlias(
      playlistId: widget.playlistId,
      section: widget.section,
      categoryId: widget.entry.id,
      alias: _aliasController.text,
    );
    if (mounted) _closeEdit();
  }

  Future<void> _resetAlias() async {
    await playlistGroupVisibilityStore.setCategoryAlias(
      playlistId: widget.playlistId,
      section: widget.section,
      categoryId: widget.entry.id,
      alias: null,
    );
    if (mounted) {
      _aliasController.clear();
      _closeEdit();
    }
  }

  void _openOrderPanel() {
    if (widget.section != PlaylistGroupSection.live) return;
    if (_editing) _closeEdit();
    final isB = playlistGroupVisibilityStore.isLiveCategoryBeforeFavorites(
      widget.playlistId,
      widget.entry.id,
    );
    final pos = playlistGroupVisibilityStore.liveBeforeFavoritesOneBasedPosition(
      widget.playlistId,
      widget.entry.id,
    );
    setState(() {
      _orderPanelOpen = true;
      _panelBeforeFavorites = isB;
      _orderPosController.text = (pos > 0 ? pos : 1).toString();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isB) {
        _orderPosFocus.requestFocus();
      } else {
        _orderAfterFocus.requestFocus();
      }
    });
  }

  void _closeOrderPanel() {
    setState(() => _orderPanelOpen = false);
  }

  Future<void> _saveOrderPanel() async {
    if (widget.section != PlaylistGroupSection.live) return;
    if (!_panelBeforeFavorites) {
      await playlistGroupVisibilityStore.setLiveCategoryBeforeFavorites(
        playlistId: widget.playlistId,
        categoryId: widget.entry.id,
        before: false,
      );
      if (mounted) _closeOrderPanel();
      return;
    }
    await playlistGroupVisibilityStore.setLiveCategoryBeforeFavorites(
      playlistId: widget.playlistId,
      categoryId: widget.entry.id,
      before: true,
    );
    final list = playlistGroupVisibilityStore.liveBeforeFavoritesOrderedIds(
      widget.playlistId,
    );
    var p = int.tryParse(_orderPosController.text.trim()) ?? 1;
    p = p.clamp(1, list.isEmpty ? 1 : list.length);
    await playlistGroupVisibilityStore.setLiveBeforeFavoritesOneBasedPosition(
      playlistId: widget.playlistId,
      categoryId: widget.entry.id,
      oneBasedPosition: p,
    );
    if (mounted) _closeOrderPanel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final serverName = widget.entry.name;
    final dn = playlistGroupVisibilityStore.categoryDisplayName(
      widget.playlistId,
      widget.section,
      widget.entry.id,
      serverName,
    );
    final ha = dn != serverName;
    final isLive = widget.section == PlaylistGroupSection.live;
    final isBeforeFav = isLive &&
        playlistGroupVisibilityStore.isLiveCategoryBeforeFavorites(
          widget.playlistId,
          widget.entry.id,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: context.teamPalette.surfaceElevated,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ha ? dn : serverName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        if (ha) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.playlistGroupOriginalLabel(serverName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              color: Colors.white.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TvFocusable(
                    focusScale: 1.0,
                    parallaxSlide: 0.0,
                    showFocusElevation: false,
                    focusedBorderWidth: 1.4,
                    focusNode: _toggleFocus,
                    onActivate: () =>
                        playlistGroupVisibilityStore.setCategoryVisible(
                      playlistId: widget.playlistId,
                      section: widget.section,
                      categoryId: widget.entry.id,
                      visible: !widget.visible,
                    ),
                    focusPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: _VisibilitySwitchPill(enabled: widget.visible),
                  ),
                  const SizedBox(width: 4),
                  TvFocusable(
                    focusScale: 1.0,
                    parallaxSlide: 0.0,
                    showFocusElevation: false,
                    focusedBorderWidth: 1.4,
                    onActivate: _openEdit,
                    focusPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      child: Text(
                        l10n.playlistGroupEdit,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (isLive) ...[
                    const SizedBox(width: 4),
                    TvFocusable(
                      focusScale: 1.0,
                      parallaxSlide: 0.0,
                      showFocusElevation: false,
                      focusedBorderWidth: 1.4,
                      onActivate: _openOrderPanel,
                      focusPadding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 5,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isBeforeFav
                              ? context.teamPalette.accent.withOpacity(0.22)
                              : Colors.white.withOpacity(0.08),
                          border: Border.all(
                            color: isBeforeFav
                                ? context.teamPalette.accent.withOpacity(0.55)
                                : Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Icon(
                          Icons.move_up_rounded,
                          size: 18,
                          color: isBeforeFav
                              ? context.teamPalette.accent
                              : Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShieldTvTextField(
                      dense: true,
                      label: l10n.playlistGroupCustomNameHint,
                      controller: _aliasController,
                      focusNode: _aliasFocus,
                      nextFieldFocus: _saveFocus,
                      hint: l10n.playlistGroupCustomNameHint,
                      showTvRemotePad: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveAlias(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TvFocusable(
                            focusScale: 1.0,
                            parallaxSlide: 0.0,
                            showFocusElevation: false,
                            focusedBorderWidth: 1.4,
                            focusNode: _saveFocus,
                            onActivate: _saveAlias,
                            child: _MiniActionChip(label: l10n.commonSave),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TvFocusable(
                            focusScale: 1.0,
                            parallaxSlide: 0.0,
                            showFocusElevation: false,
                            focusedBorderWidth: 1.4,
                            focusNode: _cancelFocus,
                            onActivate: _closeEdit,
                            child: _MiniActionChip(label: l10n.commonCancel),
                          ),
                        ),
                      ],
                    ),
                    if (ha) ...[
                      const SizedBox(height: 6),
                      TvFocusable(
                        focusScale: 1.0,
                        parallaxSlide: 0.0,
                        showFocusElevation: false,
                        focusedBorderWidth: 1.4,
                        onActivate: _resetAlias,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              l10n.playlistGroupResetAlias,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.teamPalette.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_orderPanelOpen && isLive) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.playlistGroupPillOrderTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TvFocusable(
                            focusScale: 1.0,
                            parallaxSlide: 0.0,
                            showFocusElevation: false,
                            focusedBorderWidth: 1.4,
                            focusBackgroundColor: Colors.transparent,
                            focusNode: _orderAfterFocus,
                            onActivate: () => setState(
                              () => _panelBeforeFavorites = false,
                            ),
                            child: _MiniActionChip(
                              label: l10n.playlistGroupPillAfterFavorites,
                              selected: !_panelBeforeFavorites,
                              subtleSelection: true,
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
                            focusBackgroundColor: Colors.transparent,
                            focusNode: _orderBeforeFocus,
                            onActivate: () => setState(
                              () => _panelBeforeFavorites = true,
                            ),
                            child: _MiniActionChip(
                              label: l10n.playlistGroupPillBeforeFavorites,
                              selected: _panelBeforeFavorites,
                              subtleSelection: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_panelBeforeFavorites) ...[
                      const SizedBox(height: 8),
                      ShieldTvTextField(
                        dense: true,
                        label: l10n.playlistGroupPillPositionLabel,
                        controller: _orderPosController,
                        focusNode: _orderPosFocus,
                        previousFieldFocus: _orderBeforeFocus,
                        nextFieldFocus: _orderSaveFocus,
                        hint: l10n.playlistGroupPillPositionHint,
                        showTvRemotePad: true,
                        dpadMovesFocusWhenImeOpen: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TvFocusable(
                            focusScale: 1.0,
                            parallaxSlide: 0.0,
                            showFocusElevation: false,
                            focusedBorderWidth: 1.4,
                            focusBackgroundColor: Colors.transparent,
                            focusNode: _orderSaveFocus,
                            onActivate: _saveOrderPanel,
                            child: _MiniActionChip(label: l10n.commonSave),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TvFocusable(
                            focusScale: 1.0,
                            parallaxSlide: 0.0,
                            showFocusElevation: false,
                            focusedBorderWidth: 1.4,
                            focusBackgroundColor: Colors.transparent,
                            focusNode: _orderCancelFocus,
                            onActivate: _closeOrderPanel,
                            child: _MiniActionChip(label: l10n.commonCancel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
  }
}

class _VisibilitySwitchPill extends StatelessWidget {
  const _VisibilitySwitchPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: enabled
            ? context.teamPalette.accent.withOpacity(0.42)
            : Colors.white.withOpacity(0.14),
        border: Border.all(
          color: enabled
              ? context.teamPalette.accent.withOpacity(0.65)
              : Colors.white.withOpacity(0.15),
        ),
      ),
      child: Align(
        alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MiniActionChip extends StatelessWidget {
  const _MiniActionChip({
    required this.label,
    this.selected = false,
    this.subtleSelection = false,
  });

  final String label;
  final bool selected;

  /// When true and [selected], use outline-style chip (no accent fill) so the
  /// [TvFocusable] ring reads as the primary focus affordance (TV pill order row).
  final bool subtleSelection;

  @override
  Widget build(BuildContext context) {
    final accent = context.teamPalette.accent;
    final fill = subtleSelection
        ? Colors.white.withOpacity(0.08)
        : (selected ? accent.withOpacity(0.22) : Colors.white.withOpacity(0.08));
    final borderColor = selected
        ? accent.withOpacity(subtleSelection ? 0.55 : 0.5)
        : Colors.white.withOpacity(0.14);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: fill,
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? accent : null,
            ),
      ),
    );
  }
}
