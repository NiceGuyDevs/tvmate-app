import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/epg_time_display.dart';
import '../../data/epg_timezone_catalog.dart';
import '../../data/library_controller.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/playlist_epg_timezone_store.dart';
import '../../data/recording_approval_store.dart';
import '../../data/recording_epg_loader.dart';
import '../../data/shell_search_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../../xtream/xtream_short_epg_parser.dart';
import '../../player/player_navigation.dart';
import '../../shell/shell_back_coordinator.dart';
import '../../shell/shell_content_focus_registry.dart';
import '../../shell/shell_destination.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/team_palette.dart';
import '../../theme/team_palette_theme.dart';
import '../../xtream/xtream_stream_urls.dart';
import '../focus/tv_focusable.dart';
import '../live_tv/mock_live_tv_data.dart';
import '../widgets/tv_catalog_image.dart';
import '../widgets/tv_media_urls.dart';
import 'recording_channel_availability.dart';

String _recordingEpgTzLine(AppLocalizations? l10n, String playlistId) {
  final mode = playlistEpgTimezoneStore.epgDisplayMode(playlistId);
  if (mode == kEpgDisplayModeLocal || mode.isEmpty) {
    return l10n?.playlistEpgTimeRowLocal ?? 'Local';
  }
  if (mode == kEpgDisplayModeOriginal) {
    return l10n?.playlistEpgTimeRowOriginal ?? 'Original (server)';
  }
  for (final e in kEpgTimezoneCatalog) {
    if (e.ianaId == mode) return e.label;
  }
  return mode.split('/').last;
}

/// Softer focus than default [TvFocusable]: less scale so list rows are not
/// clipped; EPG list uses [_kRecordingEpgListFocusScale] (no pop).
const double _kRecordingFocusScale = 1.006;
const double _kRecordingEpgListFocusScale = 1.0;
const double _kRecordingParallaxSlide = 0.002;
const double _kRecordingEpgListParallaxSlide = 0.0;
/// Subtle [TvFocusable] fill in the focus margin (very low; pairs with
/// [showFocusElevation: false]).
const double _kRecordingFocusBackgroundAlpha = 0.08;

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    this.embeddedInPlayerOverlay = false,
    this.initialChannelIdForOverlay,
  });

  /// When true (catch-up from live), same UI stacked over the player; Back pops
  /// to live. Shell focus / back coordinator are not registered.
  final bool embeddedInPlayerOverlay;

  /// Pre-selects this channel in EPG mode (overlay entry only).
  final String? initialChannelIdForOverlay;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

enum _RecordingMode { browse, epg }

class _RecordingScreenState extends State<RecordingScreen> {
  String? _selectedCategoryId;
  late DateTime _selectedDate;
  _RecordingMode _mode = _RecordingMode.browse;
  MockLiveChannel? _selectedChannel;

  final _categoryFocusNodes = <String, FocusNode>{};
  final _dateFocusNodes = <int, FocusNode>{};
  final _channelGridFirstFocus = FocusNode(debugLabel: 'channelGridFirst');

  String? _lastRecordingSearchNotified;

  int _epgRebuildSeed = 0;

  static const int _kMaxCatchupDays = 10;
  String get _recordingSearchQuery =>
      shellSearchStore.queryFor(ShellDestination.recording).toLowerCase();

  @override
  void initState() {
    super.initState();
    _selectedDate = _today();
    if (!widget.embeddedInPlayerOverlay) {
      ShellContentFocusRegistry.register(
        ShellDestination.recording,
        _requestShellPrimaryFocus,
      );
      ShellBackCoordinator.register(this, _onShellBack);
    }
    _syncCategorySelection();
    xtreamCatalogRepository.addListener(_onCatalogChanged);
    recordingApprovalStore.addListener(_onCatalogChanged);
    playlistEpgTimezoneStore.addListener(_onTzChanged);
    shellSearchStore.addListener(_onCatalogChanged);
    refreshServerTimezone();
    RecordingEpgLoader.instance.preloadXmltv();
    if (widget.embeddedInPlayerOverlay &&
        widget.initialChannelIdForOverlay != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyInitialChannelFromId(widget.initialChannelIdForOverlay!);
      });
    }
  }

  void _applyInitialChannelFromId(String id) {
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) return;
    final channels = recordingApprovedChannelsFlattened(playlistId);
    MockLiveChannel? match;
    for (final c in channels) {
      if (c.id == id) {
        match = c;
        break;
      }
    }
    if (match == null) return;
    final m = match;
    setState(() {
      _selectedCategoryId = m.categoryId;
      _selectedChannel = m;
      _mode = _RecordingMode.epg;
      _selectedDate = _today();
      _epgRebuildSeed++;
    });
    RecordingEpgLoader.instance.fetchDay(
      streamId: m.id,
      day: _selectedDate,
      epgChannelId: m.epgChannelId,
    );
  }

  void _requestShellPrimaryFocus() {
    if (!mounted) return;
    scheduleRequestFocusWhenReady(_channelGridFirstFocus);
  }

  bool _onShellBack() {
    if (shellSearchStore.hasQuery(ShellDestination.recording)) {
      shellSearchStore.clear(ShellDestination.recording);
      return true;
    }
    if (_mode == _RecordingMode.epg) {
      setState(() {
        _mode = _RecordingMode.browse;
        _selectedChannel = null;
      });
      scheduleRequestFocusWhenReady(_channelGridFirstFocus);
      return true;
    }
    return false;
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    _syncCategorySelection();
    final channels = _channelsForSelectedCategory;
    if (_mode == _RecordingMode.epg &&
        (_selectedChannel == null ||
            !channels.any((c) => c.id == _selectedChannel!.id))) {
      _mode = _RecordingMode.browse;
      _selectedChannel = null;
    }
    final q = shellSearchStore.queryFor(ShellDestination.recording);
    if (q != (_lastRecordingSearchNotified ?? '')) {
      _lastRecordingSearchNotified = q;
      if (q.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          scheduleRequestFocusWhenReady(_channelGridFirstFocus);
        });
      }
    }
    setState(() {});
  }

  void _onTzChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncCategorySelection() {
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) return;
    final approved = recordingApprovalStore.approvedCategoryIds(playlistId);
    if (approved.isEmpty) {
      _selectedCategoryId = null;
      return;
    }
    if (_selectedCategoryId == null ||
        !approved.contains(_selectedCategoryId)) {
      _selectedCategoryId = approved.first;
    }
  }

  @override
  void dispose() {
    if (!widget.embeddedInPlayerOverlay) {
      ShellContentFocusRegistry.unregister(ShellDestination.recording);
      ShellBackCoordinator.unregister(this);
    }
    xtreamCatalogRepository.removeListener(_onCatalogChanged);
    recordingApprovalStore.removeListener(_onCatalogChanged);
    playlistEpgTimezoneStore.removeListener(_onTzChanged);
    shellSearchStore.removeListener(_onCatalogChanged);
    for (final n in _categoryFocusNodes.values) {
      n.dispose();
    }
    for (final n in _dateFocusNodes.values) {
      n.dispose();
    }
    _channelGridFirstFocus.dispose();
    super.dispose();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<MockLiveCategory> get _approvedCategories {
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) return const [];
    final approved = recordingApprovalStore.approvedCategoryIds(playlistId);
    return xtreamCatalogRepository.liveCategories
        .where((c) => approved.contains(c.id))
        .map(
          (c) => MockLiveCategory(
            id: c.id,
            name: playlistGroupVisibilityStore.categoryDisplayName(
              playlistId,
              PlaylistGroupSection.live,
              c.id,
              c.name,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<MockLiveChannel> get _channelsForSelectedCategory {
    final playlistId = libraryController.activePlaylistId;
    if (playlistId == null) return const [];
    if (_recordingSearchQuery.isNotEmpty) {
      final all = _allApprovedChannels(playlistId);
      return all
          .where((c) => c.name.toLowerCase().contains(_recordingSearchQuery))
          .toList(growable: false);
    }
    if (_selectedCategoryId == null) return const [];
    final approvedChannels = recordingApprovalStore.approvedChannelIds(
      playlistId,
      _selectedCategoryId!,
    );
    final all =
        xtreamCatalogRepository.liveChannelsForCategory(_selectedCategoryId!);
    List<MockLiveChannel> base;
    if (approvedChannels.isEmpty) {
      base = all;
    } else {
      base = all
          .where((c) => approvedChannels.contains(c.id))
          .toList(growable: false);
    }
    // Settings → Recording: show only streams with catch-up / archive (rewind
    // icon). EPG-only backups often have schedule but not tv_archive.
    if (recordingApprovalStore.filterCatchupOnly(playlistId)) {
      return base.where((c) => c.hasCatchup).toList(growable: false);
    }
    return base;
  }

  List<MockLiveChannel> _allApprovedChannels(String playlistId) {
    return recordingApprovedChannelsFlattened(playlistId);
  }

  int get _maxCatchupDays {
    final channels = _channelsForSelectedCategory;
    if (channels.isEmpty) return _kMaxCatchupDays;
    int max = 0;
    for (final c in channels) {
      if (c.catchupDays > max) max = c.catchupDays;
    }
    final raw = max > 0 ? max : MockLiveChannel.kDefaultCatchupDays;
    return raw.clamp(1, _kMaxCatchupDays);
  }

  List<DateTime> get _dateList {
    final days = _maxCatchupDays;
    final today = _today();
    return List.generate(days, (i) => today.subtract(Duration(days: i)));
  }

  void _selectCategory(String catId) {
    if (_selectedCategoryId == catId) return;
    setState(() {
      _selectedCategoryId = catId;
      _mode = _RecordingMode.browse;
      _selectedChannel = null;
    });
  }

  void _selectDate(DateTime date) {
    if (_selectedDate == date) return;
    setState(() {
      _selectedDate = date;
      _epgRebuildSeed++;
    });
    if (_mode == _RecordingMode.epg && _selectedChannel != null) {
      RecordingEpgLoader.instance.fetchDay(
        streamId: _selectedChannel!.id,
        day: date,
        epgChannelId: _selectedChannel!.epgChannelId,
      );
    }
  }

  void _selectChannel(MockLiveChannel channel) {
    setState(() {
      _selectedChannel = channel;
      _mode = _RecordingMode.epg;
      _epgRebuildSeed++;
    });
    RecordingEpgLoader.instance.fetchDay(
      streamId: channel.id,
      day: _selectedDate,
      epgChannelId: channel.epgChannelId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.teamPalette;
    final categories = _approvedCategories;
    final dates = _dateList;
    final channels = _channelsForSelectedCategory;
    final playlistId = libraryController.activePlaylistId;

    if (playlistId == null || categories.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return ColoredBox(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fiber_smart_record_rounded,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.catchupEmptyStateTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.catchupEmptyStateBody(l10n.settingsRecordingEdit),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // ~7% total width inset so focus scale does not crowd edges / date column.
        final hPad = math.max(16.0, w * 0.035);
        return ColoredBox(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final selected = cat.id == _selectedCategoryId;
                      return TvFocusable(
                        focusNode: _categoryFocusNodes.putIfAbsent(
                          cat.id,
                          () => FocusNode(debugLabel: 'recCat_${cat.id}'),
                        ),
                        autofocus: false,
                        showFocusElevation: false,
                        focusBackgroundColor:
                            palette.accent.withValues(alpha: _kRecordingFocusBackgroundAlpha),
                        focusPadding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        focusScale: _kRecordingFocusScale,
                        parallaxSlide: _kRecordingParallaxSlide,
                        focusedBorderWidth: 1.4,
                        onActivate: () => _selectCategory(cat.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: selected
                                ? palette.accent.withOpacity(0.28)
                                : Colors.white.withOpacity(0.06),
                            border: Border.all(
                              color: selected
                                  ? palette.accent.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              cat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.75),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, rowConstraints) {
                      final rowW = rowConstraints.maxWidth;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: rowW * 0.10,
                            child: _DateColumn(
                              dates: dates,
                              selectedDate: _selectedDate,
                              onSelect: _selectDate,
                              dateFocusNodes: _dateFocusNodes,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _mode == _RecordingMode.browse
                                  ? _BrowseChannelGrid(
                                      key: ValueKey(
                                        'browse_${_selectedCategoryId}_${_selectedDate}',
                                      ),
                                      channels: channels,
                                      onSelect: _selectChannel,
                                      firstFocusNode: _channelGridFirstFocus,
                                    )
                                  : _EpgModeView(
                                      key: ValueKey(
                                        'epg_${_selectedChannel?.id}_${_selectedDate}_$_epgRebuildSeed',
                                      ),
                                      channels: channels,
                                      selectedChannel: _selectedChannel!,
                                      selectedDate: _selectedDate,
                                      onChannelSwitch: (ch) {
                                        setState(() {
                                          _selectedChannel = ch;
                                          _epgRebuildSeed++;
                                        });
                                        RecordingEpgLoader.instance.fetchDay(
                                          streamId: ch.id,
                                          day: _selectedDate,
                                          epgChannelId: ch.epgChannelId,
                                        );
                                      },
                                      palette: palette,
                                      selectedDateFocusNode: _dateFocusNodes[dates.indexOf(_selectedDate)],
                                      useTvFrame: recordingApprovalStore.tvFrameEpg(playlistId),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Date column
// ---------------------------------------------------------------------------

class _DateColumn extends StatelessWidget {
  const _DateColumn({
    required this.dates,
    required this.selectedDate,
    required this.onSelect,
    required this.dateFocusNodes,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;
  final Map<int, FocusNode> dateFocusNodes;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.teamPalette;
    final today = DateTime.now();

    return ListView.separated(
      clipBehavior: Clip.none,
      itemCount: dates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final d = dates[i];
        final isToday = d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
        final selected = d == selectedDate;
        return TvFocusable(
          focusNode: dateFocusNodes.putIfAbsent(
            i,
            () => FocusNode(debugLabel: 'recDate_$i'),
          ),
          showFocusElevation: false,
          focusBackgroundColor:
              palette.accent.withValues(alpha: _kRecordingFocusBackgroundAlpha),
          focusPadding:
              const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          focusScale: _kRecordingFocusScale,
          parallaxSlide: _kRecordingParallaxSlide,
          focusedBorderWidth: 1.4,
          onActivate: () => onSelect(d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? palette.accent.withOpacity(0.22)
                  : Colors.white.withOpacity(0.04),
              border: Border.all(
                color: selected
                    ? palette.accent.withOpacity(0.55)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              isToday
                  ? 'Today'
                  : '${_dayNames[d.weekday - 1]}  ${d.day}/${d.month}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : Colors.white.withOpacity(0.65),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Browse state — channel grid
// ---------------------------------------------------------------------------

class _BrowseChannelGrid extends StatelessWidget {
  const _BrowseChannelGrid({
    super.key,
    required this.channels,
    required this.onSelect,
    required this.firstFocusNode,
  });

  final List<MockLiveChannel> channels;
  final ValueChanged<MockLiveChannel> onSelect;
  final FocusNode firstFocusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.teamPalette;

    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No approved channels for this category.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    return GridView.builder(
      clipBehavior: Clip.none,
      itemCount: channels.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, i) {
        final ch = channels[i];
        final isFirst = i == 0;
        final g0 = Color.lerp(palette.surface, palette.accent, 0.2)!;
        final g1 = Color.lerp(palette.canvas, palette.surface, 0.5)!;
        final tileBorder = Color.lerp(palette.surface, palette.canvas, 0.4) ??
            palette.canvas;
        return TvFocusable(
          focusNode: isFirst ? firstFocusNode : null,
          autofocus: isFirst,
          showFocusElevation: false,
          focusBackgroundColor:
              palette.accent.withValues(alpha: _kRecordingFocusBackgroundAlpha),
          focusPadding: const EdgeInsets.all(2),
          focusScale: _kRecordingFocusScale,
          parallaxSlide: _kRecordingParallaxSlide,
          focusBorderColor: palette.defaultFocusRingColor,
          focusedBorderWidth: 1.4,
          onActivate: () => onSelect(ch),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g0, g1],
              ),
              border: Border.all(
                color: tileBorder,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (liveChannelArtUrl(ch).isNotEmpty)
                  Expanded(
                    child: TvCatalogImage(
                      url: liveChannelArtUrl(ch),
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Expanded(
                    child: Icon(
                      Icons.live_tv_rounded,
                      size: 22,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (ch.hasCatchup || ch.hasPanelEpg)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (ch.hasCatchup)
                          Icon(
                            Icons.history_rounded,
                            size: 10,
                            color: palette.accent.withOpacity(0.6),
                          ),
                        if (ch.hasPanelEpg) ...[
                          if (ch.hasCatchup) const SizedBox(width: 3),
                          Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// EPG mode — compact channel row + timeline
// ---------------------------------------------------------------------------

class _EpgModeView extends StatelessWidget {
  const _EpgModeView({
    super.key,
    required this.channels,
    required this.selectedChannel,
    required this.selectedDate,
    required this.onChannelSwitch,
    required this.palette,
    this.selectedDateFocusNode,
    required this.useTvFrame,
  });

  final List<MockLiveChannel> channels;
  final MockLiveChannel selectedChannel;
  final DateTime selectedDate;
  final ValueChanged<MockLiveChannel> onChannelSwitch;
  final TeamPalette palette;
  final FocusNode? selectedDateFocusNode;

  /// Recording-only: show channel logos inside TV frame asset on EPG programme rows.
  final bool useTvFrame;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            clipBehavior: Clip.hardEdge,
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final ch = channels[i];
              final selected = ch.id == selectedChannel.id;
              return TvFocusable(
                showFocusElevation: false,
                focusBackgroundColor: palette.accent
                    .withValues(alpha: _kRecordingFocusBackgroundAlpha),
                focusPadding: const EdgeInsets.all(2),
                focusScale: _kRecordingFocusScale,
                parallaxSlide: _kRecordingParallaxSlide,
                focusBorderColor: palette.defaultFocusRingColor,
                focusedBorderWidth: 1.4,
                onActivate: () => onChannelSwitch(ch),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 80,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: selected
                        ? palette.accent.withOpacity(0.25)
                        : Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: selected
                          ? palette.accent.withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (liveChannelArtUrl(ch).isNotEmpty)
                        Expanded(
                          child: TvCatalogImage(
                            url: liveChannelArtUrl(ch),
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Expanded(
                          child: Icon(
                            Icons.live_tv_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _EpgTimeline(
            channel: selectedChannel,
            date: selectedDate,
            palette: palette,
            selectedDateFocusNode: selectedDateFocusNode,
            useTvFrame: useTvFrame,
          ),
        ),
      ],
    );
  }
}

/// Channel logo on the right of each Recording EPG programme row.
/// [useTvFrame] wraps the logo in [assets/images/recording_tv_frame.png] (optional).
class _RecordingEpgChannelLogo extends StatelessWidget {
  const _RecordingEpgChannelLogo({
    required this.channel,
    required this.useTvFrame,
  });

  final MockLiveChannel channel;
  final bool useTvFrame;

  /// Tall slot so the logo / TV frame dominates the row (same size with frame on or off).
  static const double _slotW = 72;
  static const double _slotH = 56;

  @override
  Widget build(BuildContext context) {
    final url = liveChannelArtUrl(channel);
    if (url.isEmpty) {
      return const SizedBox(width: _slotW, height: _slotH);
    }

    Widget logo() => TvCatalogImage(
          url: url,
          fit: BoxFit.contain,
        );

    if (!useTvFrame) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: _slotW,
          height: _slotH,
          child: logo(),
        ),
      );
    }

    return SizedBox(
      width: _slotW,
      height: _slotH,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/recording_tv_frame.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 8),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: logo(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EPG timeline list
// ---------------------------------------------------------------------------

class _EpgTimeline extends StatefulWidget {
  const _EpgTimeline({
    required this.channel,
    required this.date,
    required this.palette,
    this.selectedDateFocusNode,
    required this.useTvFrame,
  });

  final MockLiveChannel channel;
  final DateTime date;
  final TeamPalette palette;
  final FocusNode? selectedDateFocusNode;
  final bool useTvFrame;

  @override
  State<_EpgTimeline> createState() => _EpgTimelineState();
}

class _EpgTimelineState extends State<_EpgTimeline> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, FocusNode> _itemFocusNodes = {};
  int? _lastPlayedIndex;
  bool _didInitialFocus = false;

  @override
  void initState() {
    super.initState();
    RecordingEpgLoader.instance.addListener(_onEpgChanged);
    _fetchIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _EpgTimeline old) {
    super.didUpdateWidget(old);
    if (old.channel.id != widget.channel.id || old.date != widget.date) {
      _lastPlayedIndex = null;
      _didInitialFocus = false;
      _disposeItemFocusNodes();
      _fetchIfNeeded();
      return;
    }
    if (old.useTvFrame != widget.useTvFrame) {
      setState(() {});
    }
  }

  void _fetchIfNeeded() {
    RecordingEpgLoader.instance.fetchDay(
      streamId: widget.channel.id,
      day: widget.date,
      epgChannelId: widget.channel.epgChannelId,
    );
  }

  void _onEpgChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_didInitialFocus) {
      _scrollToEndAndFocusLast();
    }
  }

  void _scrollToEndAndFocusLast() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final listings = RecordingEpgLoader.instance.lookup(
        widget.channel.id,
        widget.date,
      );
      if (listings.isEmpty) return;

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }

      final targetIdx = listings.length - 1;
      _didInitialFocus = true;

      // Items may not be built yet after jumpTo; retry across several frames
      void focusTarget(int frame) {
        if (!mounted || frame > 10) return;
        final node = _itemFocusNodes[targetIdx];
        if (node != null && node.canRequestFocus) {
          node.requestFocus();
          return;
        }
        SchedulerBinding.instance.addPostFrameCallback((_) {
          focusTarget(frame + 1);
        });
      }

      focusTarget(0);
    });
  }

  void _restoreFocusToItem(int index) {
    final node = _itemFocusNodes[index];
    if (node == null) return;
    scheduleSteadyChannelTileFocus(() => mounted, node);
  }

  void _disposeItemFocusNodes() {
    for (final n in _itemFocusNodes.values) {
      n.dispose();
    }
    _itemFocusNodes.clear();
  }

  FocusNode _nodeForIndex(int i) {
    return _itemFocusNodes.putIfAbsent(
      i,
      () => FocusNode(debugLabel: 'epgItem_$i'),
    );
  }

  @override
  void dispose() {
    RecordingEpgLoader.instance.removeListener(_onEpgChanged);
    _scrollController.dispose();
    _disposeItemFocusNodes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loader = RecordingEpgLoader.instance;
    final loading = loader.isLoading(widget.channel.id, widget.date);
    final listings = loader.lookup(widget.channel.id, widget.date);

    if (loading && listings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (listings.isEmpty) {
      return Center(
        child: Text(
          'No program data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    final playlistId = libraryController.activePlaylistId ?? '';
    final l10n = AppLocalizations.of(context);
    final tzLabel = _recordingEpgTzLine(l10n, playlistId);
    final dateLabel = _dateLabel(widget.date);

    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(
              '$dateLabel — ${listings.length} programs — $tzLabel',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
      clipBehavior: Clip.hardEdge,
      controller: _scrollController,
      itemCount: listings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final listing = listings[i];
        final startStr = formatEpgProgramTime(
          listing.start,
          listing.startRaw,
          listing.startUnix,
          playlistId,
        );
        final endStr = formatEpgProgramTime(
          listing.end,
          listing.endRaw,
          listing.endUnix,
          playlistId,
        );
        final isLast = i == listings.length - 1;
        return TvFocusable(
          focusNode: _nodeForIndex(i),
          autofocus: isLast,
          showFocusElevation: false,
          // Focus ring + fill match [openPlayerLiveEpgOverlay] programme rows
          // (inner [AnimatedContainer]; no second border from [TvFocusable]).
          focusPadding: EdgeInsets.zero,
          focusScale: _kRecordingEpgListFocusScale,
          parallaxSlide: _kRecordingEpgListParallaxSlide,
          focusedBorderWidth: 0,
          onActivate: () => _playProgram(listing, i),
          onKeyIntercept: (node, event) {
            if (event is! KeyDownEvent) return null;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final dateNode = widget.selectedDateFocusNode;
              if (dateNode != null && dateNode.canRequestFocus) {
                dateNode.requestFocus();
                return KeyEventResult.handled;
              }
            }
            return null;
          },
          child: Builder(
            builder: (context) {
              final accent = widget.palette.accent;
              final hasRowFocus = Focus.of(context).hasFocus;
              final onAir = listingIsOnAirNow(listing);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: hasRowFocus
                      ? accent.withValues(alpha: 0.18)
                      : Colors.white.withValues(
                          alpha: onAir ? 0.07 : 0.05,
                        ),
                  border: Border.all(
                    color: hasRowFocus
                        ? accent.withValues(alpha: 0.65)
                        : (onAir
                            ? accent.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1)),
                    width: hasRowFocus ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            startStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent.withValues(alpha: 0.9),
                            ),
                          ),
                          Text(
                            endStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (listing.description.isNotEmpty)
                            Text(
                              listing.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.55),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RecordingEpgChannelLogo(
                      channel: widget.channel,
                      useTvFrame: widget.useTvFrame,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
          ),
        ],
      ),
    );
  }

  void _playProgram(XtreamEpgListing listing, int index) {
    if (listing.startUnix == null || listing.startUnix == 0) return;

    final p = libraryController.activePlaylist;
    if (p == null || !p.isXtream) return;

    final server = p.serverUrl?.trim() ?? '';
    final u = p.username?.trim() ?? '';
    final pw = p.password ?? '';
    if (server.isEmpty || u.isEmpty || pw.isEmpty) return;

    int durationMin = 60;
    if (listing.start != null && listing.end != null) {
      final diff = listing.end!.difference(listing.start!).inMinutes;
      if (diff > 0 && diff < 720) durationMin = diff;
    }

    final serverOffset = playlistEpgTimezoneStore.serverUtcOffsetHours(p.id);
    final links = _buildLinks(server, u, pw);
    final streamId = widget.channel.id;

    final streamUrl = links.catchupUrlWithDuration(
      streamId: streamId,
      startRaw: listing.startRaw,
      startUnix: listing.startUnix!,
      durationMin: durationMin,
      serverUtcOffsetHours: serverOffset,
    );

    debugPrint('[EPG Catchup] startRaw=${listing.startRaw} '
        'startUnix=${listing.startUnix} durationMin=$durationMin '
        'serverOffset=$serverOffset → $streamUrl');

    _lastPlayedIndex = index;
    if (!mounted) return;

    openTvMatePlayer(
      context,
      title: listing.title,
      streamUrl: streamUrl,
      isLive: false,
      contentDescription: listing.description,
      suppressPreviousFocusRestore: true,
      onPlayerClosed: (_) {
        if (!mounted) return;
        _restoreFocusToItem(index);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

XtreamStreamLinkBuilder _buildLinks(String server, String user, String pass) {
  return XtreamStreamLinkBuilder(
    serverUrl: server,
    username: user,
    password: pass,
  );
}

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final isToday = date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
  if (isToday) return 'Today';
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${dayNames[date.weekday - 1]} ${date.day}/${date.month}/${date.year}';
}
