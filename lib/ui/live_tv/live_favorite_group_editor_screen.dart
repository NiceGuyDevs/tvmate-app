import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../data/device_memory_channel.dart';
import '../../data/library_controller.dart';
import '../../data/live_favorite_channel_ref.dart';
import '../../data/live_favorite_groups_store.dart';
import '../../data/playlist_live_catalog_cache.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../theme/team_palette_theme.dart';
import '../catalog/catalog_status_widgets.dart';
import '../focus/tv_focusable.dart'
    show TvFocusable, scheduleSteadyChannelTileFocus;
import '../settings/player_settings_overlay_scope.dart';
import '../settings/shield_tv_text_field.dart';
import '../settings/tv_remote_keys.dart';
import 'live_favorite_picker_screen.dart';
import 'mock_live_tv_data.dart';

/// Create or edit one favorite group: name, sort order, ordered channel list.
class LiveFavoriteGroupEditorScreen extends StatefulWidget {
  const LiveFavoriteGroupEditorScreen({super.key, this.existing});

  final LiveFavoriteGroup? existing;

  @override
  State<LiveFavoriteGroupEditorScreen> createState() =>
      _LiveFavoriteGroupEditorScreenState();
}

class _LiveFavoriteGroupEditorScreenState
    extends State<LiveFavoriteGroupEditorScreen>
    with WidgetsBindingObserver {
  var _scheduledInitialNameFocus = false;
  final ScrollController _scrollController = ScrollController();

  late final TextEditingController _nameController;
  late final TextEditingController _sortController;
  late final FocusNode _nameFocus = FocusNode(debugLabel: 'favEditName');
  late final FocusNode _sortFocus = FocusNode(debugLabel: 'favEditSort');
  late final FocusNode _backFocus = FocusNode(debugLabel: 'favEditBack');
  late final FocusNode _chooseChannelsFocus =
      FocusNode(debugLabel: 'favEditChoose');
  late final FocusNode _saveFocus = FocusNode(debugLabel: 'favEditSave');
  late final FocusNode _deleteFocus = FocusNode(debugLabel: 'favEditDelete');
  late List<LiveFavoriteChannelRef> _channelRefs;

  List<FocusNode> _verticalChain() {
    return [
      _backFocus,
      _nameFocus,
      _sortFocus,
      _chooseChannelsFocus,
      _saveFocus,
      if (widget.existing != null) _deleteFocus,
    ];
  }

  /// Same [TvFocusable] + [ShieldTvTextField] D-pad order as [AddPlaylistScreen].
  /// [showTvRemotePad] on text fields matches Add Playlist — required on Chromecast / Google TV
  /// ([DeviceMemoryChannel.inAppPad]) so typing uses the in-app pad; system IME alone is unreliable there.
  KeyEventResult? _interceptVerticalNav(FocusNode node, KeyEvent event) {
    if (!tvRemoteIsDpadDown(event) && !tvRemoteIsDpadUp(event)) {
      return null;
    }
    final chain = _verticalChain();
    final i = chain.indexOf(node);
    if (i < 0) return null;
    if (tvRemoteIsDpadDown(event) && i < chain.length - 1) {
      chain[i + 1].requestFocus();
      return KeyEventResult.handled;
    }
    if (tvRemoteIsDpadUp(event) && i > 0) {
      chain[i - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onNameOrSortFocus() {
    if (_nameFocus.hasFocus) _scrollFieldIntoView(_nameFocus);
    if (_sortFocus.hasFocus) _scrollFieldIntoView(_sortFocus);
  }

  void _scrollFieldIntoView(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = node.context;
      if (ctx == null || !ctx.mounted) return;
      if (!_scrollController.hasClients) return;
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: node == _sortFocus ? 0.0 : 0.08,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        ),
      );
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_nameFocus.hasFocus) _scrollFieldIntoView(_nameFocus);
    if (_sortFocus.hasFocus) _scrollFieldIntoView(_sortFocus);
  }

  @override
  void initState() {
    super.initState();
    unawaited(DeviceMemoryChannel.prepareForTextInput());
    WidgetsBinding.instance.addObserver(this);
    _nameFocus.addListener(_onNameOrSortFocus);
    _sortFocus.addListener(_onNameOrSortFocus);
    playlistLiveCatalogCache.addListener(_onPlaylistCacheUpdate);
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _sortController = TextEditingController(
      text: e != null ? '${e.sortOrder}' : '0',
    );
    _channelRefs =
        e != null ? List<LiveFavoriteChannelRef>.from(e.channelRefs) : [];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LiveFavoriteGroupsStore.instance.ensureLoaded();
      await _preloadRefsCaches();
      if (mounted && e == null) {
        setState(() {
          _sortController.text =
              '${LiveFavoriteGroupsStore.instance.suggestedSortOrder()}';
        });
      }
    });
  }

  Future<void> _preloadRefsCaches() async {
    if (libraryController.useDemoData) return;
    final ids =
        _channelRefs.map((r) => r.playlistId).where((p) => p.isNotEmpty).toSet();
    for (final id in ids) {
      await playlistLiveCatalogCache.ensurePlaylistLoaded(id);
    }
    if (mounted) setState(() {});
  }

  void _onPlaylistCacheUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameFocus.removeListener(_onNameOrSortFocus);
    _sortFocus.removeListener(_onNameOrSortFocus);
    _scrollController.dispose();
    _nameController.dispose();
    _sortController.dispose();
    _nameFocus.dispose();
    _sortFocus.dispose();
    _backFocus.dispose();
    _chooseChannelsFocus.dispose();
    _saveFocus.dispose();
    _deleteFocus.dispose();
    super.dispose();
  }

  int _parseSortOrder() {
    final t = _sortController.text.trim();
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? 0;
  }

  Future<void> _openPicker() async {
    await pushSettingsRoute<void>(
      context,
      (context) => LiveFavoritePickerScreen(
        initialRefs: List<LiveFavoriteChannelRef>.from(_channelRefs),
        showOrderBadges: true,
        showCategoryBulkActions: true,
        onSaveRefs: (refs) async {
          setState(() => _channelRefs = List<LiveFavoriteChannelRef>.from(refs));
        },
      ),
      fullscreenDialog: true,
    );
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim().isEmpty
        ? l10n.defaultFavoriteName
        : _nameController.text.trim();
    final sort = _parseSortOrder();
    final store = LiveFavoriteGroupsStore.instance;
    if (widget.existing == null) {
      await store.addGroup(
        name: name,
        sortOrder: sort,
        channelRefs: _channelRefs,
      );
    } else {
      await store.updateGroup(
        widget.existing!.copyWith(
          name: name,
          sortOrder: sort,
          channelRefs: _channelRefs,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    await LiveFavoriteGroupsStore.instance.removeGroup(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  MockLiveChannel? _resolveOne(LiveFavoriteChannelRef ref) {
    if (libraryController.useDemoData) {
      for (final c in kMockLiveChannels) {
        if (c.id == ref.channelId) return c;
      }
      return null;
    }
    if (ref.isLegacy) {
      for (final c in xtreamCatalogRepository.liveChannelsAll) {
        if (c.id == ref.channelId) return c;
      }
      return null;
    }
    final cached =
        playlistLiveCatalogCache.channelById(ref.playlistId, ref.channelId);
    if (cached != null) return cached;
    if (ref.playlistId == libraryController.activePlaylistId) {
      for (final c in xtreamCatalogRepository.liveChannelsAll) {
        if (c.id == ref.channelId) return c;
      }
    }
    return null;
  }

  List<MockLiveChannel> _resolveChannels() {
    final out = <MockLiveChannel>[];
    for (final ref in _channelRefs) {
      final ch = _resolveOne(ref);
      if (ch != null) out.add(ch);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;

    if (!libraryController.useDemoData) {
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
            message: l10n.catalogErrorPlaylist,
            subtitle: xtreamCatalogRepository.errorMessage,
          ),
        );
      }
    }

    final resolved = _resolveChannels();
    final viewInsets = MediaQuery.viewInsetsOf(context);

    if (!_scheduledInitialNameFocus) {
      _scheduledInitialNameFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          scheduleSteadyChannelTileFocus(() => mounted, _nameFocus);
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          playerSettingsRouteBackdrop(context),
          Material(
        color: Colors.transparent,
        child: SafeArea(
          child: FocusScope(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TvFocusable(
                        focusNode: _backFocus,
                        onKeyIntercept: _interceptVerticalNav,
                        onActivate: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit ? l10n.favEditEdit : l10n.favEditNew,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: viewInsets.bottom +
                            (viewInsets.bottom > 0 ? 100 : 0),
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShieldTvTextField(
                          label: l10n.favEditNameLabel,
                          hint: l10n.favEditNameHint,
                          controller: _nameController,
                          focusNode: _nameFocus,
                          previousFieldFocus: _backFocus,
                          nextFieldFocus: _sortFocus,
                          textInputAction: TextInputAction.next,
                          dense: true,
                          keyboardType: TextInputType.text,
                          showTvRemotePad: true,
                        ),
                        const SizedBox(height: 10),
                        ShieldTvTextField(
                          label: l10n.favEditOrderLabel,
                          hint: l10n.favEditOrderHint,
                          controller: _sortController,
                          focusNode: _sortFocus,
                          previousFieldFocus: _nameFocus,
                          nextFieldFocus: _chooseChannelsFocus,
                          textInputAction: TextInputAction.next,
                          dense: true,
                          keyboardType: TextInputType.number,
                          showTvRemotePad: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9\-]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TvFocusable(
                          focusNode: _chooseChannelsFocus,
                          onKeyIntercept: _interceptVerticalNav,
                          onActivate: () => unawaited(_openPicker()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.playlist_add_rounded,
                                  color: context.teamPalette.accent
                                      .withOpacity(0.95),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.favEditChooseChannels,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  l10n.selectedCount(_channelRefs.length),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.favEditOrderHelp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.62),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.favEditChannelsHeading,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.88),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (resolved.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              l10n.favEditNoChannels,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < resolved.length; i++)
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 260,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                    ),
                                    color: Colors.white.withOpacity(0.04),
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${i + 1}. ',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: context.teamPalette.accent
                                                .withOpacity(0.85),
                                          ),
                                        ),
                                        TextSpan(
                                          text: resolved[i].name,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                            fontSize: 11.6,
                                            height: 1.1,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white
                                                .withOpacity(0.92),
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TvFocusable(
                      focusNode: _saveFocus,
                      onKeyIntercept: _interceptVerticalNav,
                      onActivate: () => unawaited(_save()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: context.teamPalette.accent
                                  .withOpacity(0.95),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.favEditSave,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(width: 12),
                      TvFocusable(
                        focusNode: _deleteFocus,
                        onKeyIntercept: _interceptVerticalNav,
                        onActivate: () => unawaited(_delete()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Text(
                            l10n.favEditDelete,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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
  }
}
