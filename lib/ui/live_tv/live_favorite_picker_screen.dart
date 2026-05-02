import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../data/library_controller.dart';
import '../../data/live_favorite_channel_ref.dart';
import '../../data/playlist_live_catalog_cache.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../catalog/catalog_status_widgets.dart';
import '../focus/tv_focusable.dart';
import '../settings/player_settings_overlay_scope.dart';
import 'live_tv_channel_browse_tile.dart';
import 'mock_live_tv_data.dart';

/// Fullscreen picker: categories + grid; OK toggles draft selection (ordered list).
/// [showOrderBadges]: show 1,2,3… on tiles; [showCategoryBulkActions]: All in category / Clear category.
class LiveFavoritePickerScreen extends StatefulWidget {
  const LiveFavoritePickerScreen({
    super.key,
    this.initialRefs,
    this.onSaveRefs,
    this.showOrderBadges = true,
    this.showCategoryBulkActions = true,
  });

  /// Starting selection order (first = first in list).
  final List<LiveFavoriteChannelRef>? initialRefs;

  /// Called with ordered refs then route pops.
  final Future<void> Function(List<LiveFavoriteChannelRef> refs)? onSaveRefs;

  /// Show 1,2,3 on selected tiles instead of a checkmark.
  final bool showOrderBadges;

  /// Add “All in category” / “Clear category” for the category strip.
  final bool showCategoryBulkActions;

  @override
  State<LiveFavoritePickerScreen> createState() =>
      _LiveFavoritePickerScreenState();
}

class _LiveFavoritePickerScreenState extends State<LiveFavoritePickerScreen> {
  late List<FocusNode> _categoryFocusNodes;
  late List<FocusNode> _playlistFocusNodes;
  late String _pickerCategoryId;
  late List<LiveFavoriteChannelRef> _draftRefs;
  late String _selectedPlaylistId;

  final FocusNode _headerBackFocus = FocusNode(debugLabel: 'favPickHeaderBack');
  final FocusNode _pickerSaveFocus = FocusNode(debugLabel: 'favPickSave');
  final FocusNode _pickerCancelFocus = FocusNode(debugLabel: 'favPickCancel');

  final ScrollController _pickerGridScrollController = ScrollController();

  static const int _pickerGridCrossAxisCount = 6;

  List<StoredPlaylist> get _xtreamPlaylists =>
      libraryController.playlists.where((p) => p.isXtream).toList(growable: false);

  List<MockLiveCategory> _categoriesDemo() => kMockLiveCategories;

  /// All live categories for this playlist from the catalog — same list regardless of
  /// Manage groups on/off (favorites can pull from any group).
  List<MockLiveCategory> _categoriesXtream() {
    return playlistLiveCatalogCache.categoriesFor(_selectedPlaylistId);
  }

  List<MockLiveChannel> _channelsForCatDemo(String id) =>
      mockChannelsForCategory(id);

  List<MockLiveChannel> _channelsForCatXtream(String id) {
    return playlistLiveCatalogCache.channelsForCategory(_selectedPlaylistId, id);
  }

  @override
  void initState() {
    super.initState();
    playlistLiveCatalogCache.addListener(_onCacheUpdate);
    _draftRefs = List<LiveFavoriteChannelRef>.from(widget.initialRefs ?? []);

    if (libraryController.useDemoData) {
      _selectedPlaylistId = '';
      final cats = _categoriesDemo();
      _pickerCategoryId = cats.isNotEmpty ? cats.first.id : '';
      _categoryFocusNodes = List.generate(
        cats.length,
        (i) => FocusNode(debugLabel: 'favPickCat$i'),
      );
      _playlistFocusNodes = [];
    } else {
      final xp = _xtreamPlaylists;
      _selectedPlaylistId = _pickInitialPlaylistId(xp);
      unawaited(_ensureSelectedLoaded());
      final cats = _categoriesXtream();
      _pickerCategoryId = cats.isNotEmpty ? cats.first.id : '';
      _categoryFocusNodes = List.generate(
        cats.length,
        (i) => FocusNode(debugLabel: 'favPickCat$i'),
      );
      _playlistFocusNodes = List.generate(
        xp.length,
        (i) => FocusNode(debugLabel: 'favPickPl$i'),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  String _pickInitialPlaylistId(List<StoredPlaylist> xp) {
    if (xp.isEmpty) return '';
    final initial = widget.initialRefs ?? const <LiveFavoriteChannelRef>[];
    final fromRefs = initial.map((r) => r.playlistId).where((p) => p.isNotEmpty).toSet();
    if (fromRefs.length == 1) return fromRefs.first;
    final active = libraryController.activePlaylist;
    if (active != null && active.isXtream) return active.id;
    return xp.first.id;
  }

  void _onCacheUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _ensureSelectedLoaded() async {
    if (libraryController.useDemoData || _selectedPlaylistId.isEmpty) return;
    await playlistLiveCatalogCache.ensurePlaylistLoaded(_selectedPlaylistId);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    playlistLiveCatalogCache.removeListener(_onCacheUpdate);
    _headerBackFocus.dispose();
    _pickerSaveFocus.dispose();
    _pickerCancelFocus.dispose();
    for (final n in _categoryFocusNodes) {
      n.dispose();
    }
    for (final n in _playlistFocusNodes) {
      n.dispose();
    }
    _pickerGridScrollController.dispose();
    super.dispose();
  }

  void _onCategoryPillActivated(String categoryId) {
    setState(() => _pickerCategoryId = categoryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pickerGridScrollController.hasClients) {
        _pickerGridScrollController.jumpTo(0);
      }
    });
  }

  /// Remote **Back** from the grid / filters moves focus to **Save** so you do
  /// not D-pad through the whole list. Back again (or from Save/Cancel/Back)
  /// closes the picker.
  void _onPickerBackKey() {
    final p = FocusManager.instance.primaryFocus;
    if (p == null) {
      Navigator.of(context).pop();
      return;
    }
    if (p == _pickerSaveFocus || p == _pickerCancelFocus || p == _headerBackFocus) {
      Navigator.of(context).pop();
      return;
    }
    if (_pickerSaveFocus.canRequestFocus) {
      _pickerSaveFocus.requestFocus();
    }
  }

  void _toggleDraft(String channelId) {
    final pid = libraryController.useDemoData ? '' : _selectedPlaylistId;
    final ref = LiveFavoriteChannelRef(playlistId: pid, channelId: channelId);
    _toggleRef(ref);
  }

  void _toggleRef(LiveFavoriteChannelRef ref) {
    setState(() {
      if (_draftRefs.contains(ref)) {
        _draftRefs.remove(ref);
      } else {
        _draftRefs.add(ref);
      }
    });
  }

  MockLiveChannel? _channelForRef(LiveFavoriteChannelRef ref) {
    if (libraryController.useDemoData) {
      for (final c in kMockLiveChannels) {
        if (c.id == ref.channelId) return c;
      }
      return null;
    }
    final pid =
        ref.playlistId.isEmpty ? _selectedPlaylistId : ref.playlistId;
    return playlistLiveCatalogCache.channelById(pid, ref.channelId);
  }

  void _selectAllInCategory() {
    final pid = libraryController.useDemoData ? '' : _selectedPlaylistId;
    final channels = libraryController.useDemoData
        ? _channelsForCatDemo(_pickerCategoryId)
        : _channelsForCatXtream(_pickerCategoryId);
    setState(() {
      for (final ch in channels) {
        final ref = LiveFavoriteChannelRef(playlistId: pid, channelId: ch.id);
        if (!_draftRefs.contains(ref)) {
          _draftRefs.add(ref);
        }
      }
    });
  }

  void _clearCategory() {
    final pid = libraryController.useDemoData ? '' : _selectedPlaylistId;
    final channels = libraryController.useDemoData
        ? _channelsForCatDemo(_pickerCategoryId)
        : _channelsForCatXtream(_pickerCategoryId);
    final catIds = channels.map((c) => c.id).toSet();
    setState(() {
      _draftRefs.removeWhere(
        (r) =>
            r.playlistId == pid &&
            catIds.contains(r.channelId),
      );
    });
  }

  Future<void> _save() async {
    if (widget.onSaveRefs != null) {
      await widget.onSaveRefs!(List<LiveFavoriteChannelRef>.from(_draftRefs));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onPlaylistActivated(String playlistId) async {
    if (_selectedPlaylistId != playlistId) {
      setState(() => _selectedPlaylistId = playlistId);
      await playlistLiveCatalogCache.ensurePlaylistLoaded(playlistId);
      if (!mounted) return;
      final cats = _categoriesXtream();
      setState(() {
        _pickerCategoryId = cats.isNotEmpty ? cats.first.id : '';
        for (final n in _categoryFocusNodes) {
          n.dispose();
        }
        _categoryFocusNodes = List.generate(
          cats.length,
          (i) => FocusNode(debugLabel: 'favPickCat$i'),
        );
      });
    }
    // After choosing (or re-confirming) a playlist, move to category pills.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_categoryFocusNodes.isNotEmpty) {
        _categoryFocusNodes.first.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (libraryController.useDemoData) {
      return _buildBody(
        context,
        theme,
        l10n,
        cats: _categoriesDemo(),
        channelsForCat: _channelsForCatDemo,
        showPlaylistStrip: false,
      );
    }

    if (_xtreamPlaylists.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogErrorBody(
          message: l10n.favPickNoXtream,
          subtitle: l10n.favPickNoXtreamSubtitle,
        ),
      );
    }

    if (xtreamCatalogRepository.phase == XtreamCatalogPhase.loading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogLoadingBody(message: l10n.catalogLoading),
      );
    }
    if (xtreamCatalogRepository.phase == XtreamCatalogPhase.error) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogErrorBody(
          message: l10n.catalogErrorLibrary,
          subtitle: xtreamCatalogRepository.errorMessage,
        ),
      );
    }

    final err = playlistLiveCatalogCache.errorFor(_selectedPlaylistId);
    final ready = playlistLiveCatalogCache.isReady(_selectedPlaylistId);
    if (!ready && err == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogLoadingBody(message: l10n.catalogLoadingChannels),
      );
    }
    if (err != null && !ready) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogErrorBody(
          message: l10n.catalogErrorPlaylist,
          subtitle: err,
        ),
      );
    }

    final cats = _categoriesXtream();
    if (cats.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogErrorBody(
          message: l10n.catalogNoCategories,
          subtitle: l10n.catalogNoCategoriesSubtitle,
        ),
      );
    }

    if (_playlistFocusNodes.length != _xtreamPlaylists.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final n in _playlistFocusNodes) {
          n.dispose();
        }
        _playlistFocusNodes = List.generate(
          _xtreamPlaylists.length,
          (i) => FocusNode(debugLabel: 'favPickPl$i'),
        );
        setState(() {});
      });
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogLoadingBody(message: l10n.catalogPreparing),
      );
    }

    if (_categoryFocusNodes.length != cats.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final n in _categoryFocusNodes) {
          n.dispose();
        }
        _categoryFocusNodes = List.generate(
          cats.length,
          (i) => FocusNode(debugLabel: 'favPickCat$i'),
        );
        if (_pickerCategoryId.isEmpty ||
            !cats.any((c) => c.id == _pickerCategoryId)) {
          _pickerCategoryId = cats.first.id;
        }
        setState(() {});
      });
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: CatalogLoadingBody(message: l10n.catalogPreparing),
      );
    }

    return _buildBody(
      context,
      theme,
      l10n,
      cats: cats,
      channelsForCat: _channelsForCatXtream,
      showPlaylistStrip: _xtreamPlaylists.length > 1,
      onPlaylistTap: _onPlaylistActivated,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    required List<MockLiveCategory> cats,
    required List<MockLiveChannel> Function(String) channelsForCat,
    required bool showPlaylistStrip,
    Future<void> Function(String playlistId)? onPlaylistTap,
  }) {
    if (cats.isNotEmpty && !cats.any((c) => c.id == _pickerCategoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _pickerCategoryId = cats.first.id);
      });
    }
    final effectiveCatId = cats.isEmpty
        ? ''
        : (cats.any((c) => c.id == _pickerCategoryId)
            ? _pickerCategoryId
            : cats.first.id);
    final channels = effectiveCatId.isEmpty
        ? const <MockLiveChannel>[]
        : channelsForCat(effectiveCatId);

    final isDemo = libraryController.useDemoData;
    final pid = isDemo ? '' : _selectedPlaylistId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onPickerBackKey();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            playerSettingsRouteBackdrop(context),
            SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 12, 6),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              FocusTraversalOrder(
                order: NumericFocusOrder(1),
                child: Row(
                children: [
                  TvFocusable(
                    focusNode: _headerBackFocus,
                    onActivate: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.commonBack,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.favEditChooseChannels,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              ),
              FocusTraversalOrder(
                order: NumericFocusOrder(2),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    showPlaylistStrip
                        ? l10n.favPickHelpWithPlaylist
                        : (widget.showOrderBadges
                            ? l10n.favPickHelpOrderBadges
                            : l10n.favPickHelpSimple),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      height: 1.25,
                      color: Colors.white.withOpacity(0.62),
                    ),
                  ),
                ),
              ),
              if (showPlaylistStrip) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 30,
                  child: FocusTraversalGroup(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _xtreamPlaylists.length; i++) ...[
                            if (i != 0) const SizedBox(width: 8),
                            _PlaylistPill(
                              label: _xtreamPlaylists[i].name,
                              selected: _xtreamPlaylists[i].id == _selectedPlaylistId,
                              focusNode: _playlistFocusNodes[i],
                              autofocus: i == 0,
                              onActivated: () => unawaited(
                                onPlaylistTap!(_xtreamPlaylists[i].id),
                              ),
                              onArrowDownToCategories: cats.isNotEmpty
                                  ? () {
                                      if (_categoryFocusNodes.isNotEmpty) {
                                        _categoryFocusNodes.first
                                            .requestFocus();
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.favPickInFavorite,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.88),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 58,
                child: FocusTraversalGroup(
                  child: _draftRefs.isEmpty
                      ? Center(
                          child: Text(
                            l10n.favPickNoChannelsDraft,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.55),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          clipBehavior: Clip.none,
                          itemCount: _draftRefs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final ref = _draftRefs[i];
                            final ch = _channelForRef(ref);
                            if (ch == null) {
                              return SizedBox(
                                width: 100,
                                child: ExcludeFocus(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.cardRadius,
                                      ),
                                      color: context.teamPalette.surfaceElevated,
                                      border: Border.all(
                                        color: context.teamPalette.accent
                                            .withOpacity(0.45),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Center(
                                      child: Text(
                                        l10n.favPickChannelUnavailable,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color:
                                              Colors.white.withOpacity(0.75),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return SizedBox(
                              width: 82,
                              height: 52,
                              child: ExcludeFocus(
                                child: LiveChannelBrowseTile(
                                  channel: ch,
                                  compact: true,
                                  onFocused: () {},
                                  onPlay: () => _toggleRef(ref),
                                  onKeyIntercept: (_, __) => null,
                                  favoriteOrderIndex: widget.showOrderBadges
                                      ? i + 1
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.favPickAddMore,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: FocusTraversalGroup(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < cats.length; i++) ...[
                          if (i != 0) const SizedBox(width: 6),
                          _PickerCategoryPill(
                            category: cats[i],
                            selected: cats[i].id == effectiveCatId,
                            focusNode: _categoryFocusNodes[i],
                            autofocus: !showPlaylistStrip && i == 0,
                            onActivated: () =>
                                _onCategoryPillActivated(cats[i].id),
                            onKeyIntercept: (_, __) => null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FocusTraversalOrder(
                order: NumericFocusOrder(10),
                child: Expanded(
                child: channels.isNotEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = _pickerGridCrossAxisCount;
                          const spacing = 6.0;
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          final cellW =
                              (w - spacing * (crossAxisCount - 1)) /
                                  crossAxisCount;
                          // Taller cells (lower aspect ratio) so logos aren’t clipped;
                          // aim for ~2+ full rows visible, scroll for the rest.
                          const targetRowsVisible = 2.15;
                          final cellH =
                              (h - spacing * (targetRowsVisible - 1)) /
                                  targetRowsVisible;
                          final aspect =
                              (cellW / cellH).clamp(0.68, 1.22);
                          return GridView.builder(
                            controller: _pickerGridScrollController,
                            padding: EdgeInsets.zero,
                            clipBehavior: Clip.none,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: spacing,
                              crossAxisSpacing: spacing,
                              childAspectRatio: aspect,
                            ),
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final ch = channels[index];
                              final ref = LiveFavoriteChannelRef(
                                playlistId: pid,
                                channelId: ch.id,
                              );
                              final sel = _draftRefs.contains(ref);
                              final orderIdx = sel
                                  ? _draftRefs.indexOf(ref) + 1
                                  : null;
                              return LiveChannelBrowseTile(
                                channel: ch,
                                compact: true,
                                onFocused: () {},
                                onPlay: () => _toggleDraft(ch.id),
                                onKeyIntercept: (_, __) => null,
                                favoriteOrderIndex:
                                    widget.showOrderBadges ? orderIdx : null,
                              );
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          l10n.favPickNoChannelsCategory,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
              ),
              ),
              if (widget.showCategoryBulkActions) ...[
                FocusTraversalOrder(
                  order: NumericFocusOrder(20),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        TvFocusable(
                          onActivate: _selectAllInCategory,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              l10n.favPickAllInCategory,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.teamPalette.accent
                                    .withOpacity(0.95),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TvFocusable(
                          onActivate: _clearCategory,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Text(
                              l10n.favPickClearCategory,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              FocusTraversalOrder(
                order: NumericFocusOrder(30),
                child: Row(
                children: [
                  TvFocusable(
                    focusNode: _pickerSaveFocus,
                    onActivate: () => unawaited(_save()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            color: context.teamPalette.accent.withOpacity(0.95),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.commonSave,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TvFocusable(
                    focusNode: _pickerCancelFocus,
                    onActivate: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Text(
                        l10n.commonCancel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.selectedCount(_draftRefs.length),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
              ),
            ],
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

class _PlaylistPill extends StatelessWidget {
  const _PlaylistPill({
    required this.label,
    required this.selected,
    required this.autofocus,
    required this.onActivated,
    required this.focusNode,
    this.onArrowDownToCategories,
  });

  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onActivated;
  final FocusNode focusNode;
  /// Down from playlist moves to first category pill (same ladder as after OK).
  final VoidCallback? onArrowDownToCategories;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      showFocusElevation: false,
      focusPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      onActivate: onActivated,
      onKeyIntercept: (node, event) {
        if (event is! KeyDownEvent) return null;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            onArrowDownToCategories != null) {
          onArrowDownToCategories!();
          return KeyEventResult.handled;
        }
        return null;
      },
      child: AnimatedContainer(
        duration: AppTheme.focusAnimationDuration,
        curve: AppTheme.focusAnimationCurve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: selected
                ? context.teamPalette.accent.withOpacity(0.55)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.96),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerCategoryPill extends StatelessWidget {
  const _PickerCategoryPill({
    required this.category,
    required this.selected,
    required this.autofocus,
    required this.onActivated,
    required this.focusNode,
    required this.onKeyIntercept,
  });

  final MockLiveCategory category;
  final bool selected;
  final bool autofocus;
  final VoidCallback onActivated;
  final FocusNode focusNode;
  final KeyEventResult? Function(FocusNode node, KeyEvent event) onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      showFocusElevation: false,
      focusPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      onActivate: onActivated,
      onKeyIntercept: onKeyIntercept,
      child: AnimatedContainer(
        duration: AppTheme.focusAnimationDuration,
        curve: AppTheme.focusAnimationCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: selected
                ? context.teamPalette.accent.withOpacity(0.55)
                : Colors.white.withOpacity(0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                category.name,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 10.5,
                      height: 1.05,
                      letterSpacing: 0.15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.96),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
