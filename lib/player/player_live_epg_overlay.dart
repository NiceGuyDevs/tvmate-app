import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/epg_time_display.dart';
import '../data/live_epg_controller.dart';
import '../data/playlist_epg_timezone_store.dart';
import '../data/playlist_channel_override_store.dart';
import '../l10n/app_localizations.dart';
import '../ui/settings/player_settings_overlay_scope.dart';
import '../xtream/xtream_short_epg_parser.dart';
import 'player_recording_catchup_overlay.dart';
import 'recording_style_tv_frame_channel_logo.dart';

/// Full-screen guide over live TV — same root stack, scrim, and panel shell as catch-up.
Future<void> openPlayerLiveEpgOverlay(
  BuildContext context, {
  required String streamId,
  String? epgChannelId,
  required String channelTitle,
  String? channelIconUrl,
  required String? playlistId,
  required Color accent,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: PlayerSettingsOverlayScope(
            isActive: true,
            child: RecordingCatchupOverlayShell(
              child: _PlayerLiveEpgOverlayPage(
                streamId: streamId,
                epgChannelId: epgChannelId,
                channelTitle: channelTitle,
                channelIconUrl: channelIconUrl,
                playlistId: playlistId,
                accent: accent,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _PlayerLiveEpgOverlayPage extends StatefulWidget {
  const _PlayerLiveEpgOverlayPage({
    required this.streamId,
    this.epgChannelId,
    required this.channelTitle,
    this.channelIconUrl,
    required this.playlistId,
    required this.accent,
  });

  final String streamId;
  final String? epgChannelId;
  final String channelTitle;
  final String? channelIconUrl;
  final String? playlistId;
  final Color accent;

  @override
  State<_PlayerLiveEpgOverlayPage> createState() =>
      _PlayerLiveEpgOverlayPageState();
}

class _PlayerLiveEpgOverlayPageState extends State<_PlayerLiveEpgOverlayPage> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _rowKeys = <GlobalKey>[];
  int _focusFlatIndex = 0;
  var _autoFocused = false;

  @override
  void initState() {
    super.initState();
    unawaited(playlistChannelOverrideStore.ensureLoaded());
    unawaited(
      LiveEpgController.instance.loadOverlayListings(
        widget.streamId,
        epgChannelId: widget.epgChannelId,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Header back button only — TV Back is handled solely by [PlayerScreen] (same as catch-up).
  void _popFromHeaderTap() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  List<_EpgOverlayRow> _buildRows(List<XtreamEpgListing> listings) {
    if (listings.isEmpty) return [];
    final out = <_EpgOverlayRow>[];
    DateTime? lastDay;
    for (final e in listings) {
      final s = e.start;
      if (s != null) {
        final day = DateTime(s.year, s.month, s.day);
        if (lastDay == null || day != lastDay) {
          lastDay = day;
          out.add(_EpgOverlayRow.header(day));
        }
      }
      out.add(_EpgOverlayRow.program(e));
    }
    return out;
  }

  void _nudgeFlatFocus(int delta, List<_EpgOverlayRow> rows) {
    if (rows.isEmpty) return;
    var i = _focusFlatIndex.clamp(0, rows.length - 1);
    for (var guard = 0; guard < rows.length + 2; guard++) {
      final next = (i + delta).clamp(0, rows.length - 1);
      if (next == i) return;
      i = next;
      if (!rows[i].isHeader) {
        setState(() => _focusFlatIndex = i);
        _scheduleScrollFocusedToView();
        return;
      }
    }
  }

  void _scheduleScrollFocusedToView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final i = _focusFlatIndex;
      if (i < 0 || i >= _rowKeys.length) return;
      final ctx = _rowKeys[i].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.38,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _firstProgramFlatIndex(List<_EpgOverlayRow> rows) {
    final idx = rows.indexWhere((r) => !r.isHeader);
    return idx >= 0 ? idx : 0;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    // Do not pop here — [PlayerScreen._onPlayerHardwareKey] pops the route once.
    // Handling Back here too removed EPG then popped the player (grid). Same pattern as Recording.
    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final listings =
        LiveEpgController.instance.overlayListingsFor(widget.streamId);
    final rows = _buildRows(listings);
    if (rows.isEmpty) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowUp) {
      _nudgeFlatFocus(-1, rows);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _nudgeFlatFocus(1, rows);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pid = widget.playlistId;
    final displayTitle = pid != null
        ? playlistChannelOverrideStore.displayName(
            pid,
            widget.streamId,
            widget.channelTitle,
          )
        : widget.channelTitle;
    final logoOverride = pid != null
        ? playlistChannelOverrideStore.logoUrlOverride(pid, widget.streamId)
        : null;
    final iconUrl = (logoOverride != null && logoOverride.isNotEmpty)
        ? logoOverride
        : widget.channelIconUrl;

    // No [PopScope] here — catch-up overlay doesn't add one; avoids competing with
    // [PlayerScreen] for the same Back (which caused double [pop] → grid).
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EpgHeaderStrip(
              accent: widget.accent,
              channelName: displayTitle,
              iconUrl: iconUrl,
              onClose: _popFromHeaderTap,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  LiveEpgController.instance,
                  playlistEpgTimezoneStore,
                ]),
                builder: (context, _) {
                  final loading = LiveEpgController.instance
                      .isOverlayLoadingFor(widget.streamId);
                  final listings =
                      LiveEpgController.instance.overlayListingsFor(widget.streamId);
                  final rows = _buildRows(listings);
                  while (_rowKeys.length < rows.length) {
                    _rowKeys.add(GlobalKey());
                  }
                  if (_rowKeys.length > rows.length) {
                    _rowKeys.length = rows.length;
                  }
                  final firstProg = _firstProgramFlatIndex(rows);

                  if (!_autoFocused && rows.isNotEmpty && firstProg >= 0) {
                    _autoFocused = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _focusFlatIndex = firstProg;
                        });
                        _scheduleScrollFocusedToView();
                      }
                    });
                  }

                  if (_focusFlatIndex >= rows.length && rows.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _focusFlatIndex = rows.length - 1;
                        });
                      }
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: Text(
                      l10n.playerEpgOverlaySchedule,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (loading && listings.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: widget.accent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.playerEpgOverlayLoading,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!loading && listings.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.playerEpgOverlayEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final rowKey = _rowKeys[index];
                          if (row.isHeader) {
                            return KeyedSubtree(
                              key: rowKey,
                              child: _DayHeader(day: row.headerDay!),
                            );
                          }
                          final e = row.listing!;
                          final focused = index == _focusFlatIndex;
                          final onAir = listingIsOnAirNow(e);
                          return KeyedSubtree(
                            key: rowKey,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: focused
                                      ? widget.accent.withValues(alpha: 0.18)
                                      : Colors.white.withValues(
                                          alpha: onAir ? 0.07 : 0.05,
                                        ),
                                  border: Border.all(
                                    color: focused
                                        ? widget.accent.withValues(alpha: 0.65)
                                        : (onAir
                                            ? widget.accent
                                                .withValues(alpha: 0.4)
                                            : Colors.white
                                                .withValues(alpha: 0.1)),
                                    width: focused ? 1.4 : 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.96),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                        if (onAir)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB71C1C),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.fiber_manual_record,
                                                  size: 9,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.95),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  l10n.playerEpgLiveRightNow,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatEpgTimeRangeForPlaylist(
                                            e,
                                            widget.playlistId,
                                          ) ??
                                          '—',
                                      style: TextStyle(
                                        color: widget.accent
                                            .withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (e.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        e.description,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.58),
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                    if (onAir &&
                                        e.start != null &&
                                        e.end != null) ...[
                                      const SizedBox(height: 10),
                                      _ProgressBar(
                                        progress: progress01ForListing(e),
                                        accent: widget.accent,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
  }
}

class _EpgOverlayRow {
  _EpgOverlayRow._({
    this.headerDay,
    this.listing,
  });

  factory _EpgOverlayRow.header(DateTime day) =>
      _EpgOverlayRow._(headerDay: day);

  factory _EpgOverlayRow.program(XtreamEpgListing listing) =>
      _EpgOverlayRow._(listing: listing);

  final DateTime? headerDay;
  final XtreamEpgListing? listing;

  bool get isHeader => headerDay != null;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(day.year, day.month, day.day);
    final label = d == today
        ? l10n.playerEpgDayToday
        : d == tomorrow
            ? l10n.playerEpgDayTomorrow
            : DateFormat('EEEE, MMM d').format(day);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2, right: 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgHeaderStrip extends StatelessWidget {
  const _EpgHeaderStrip({
    required this.accent,
    required this.channelName,
    this.iconUrl,
    required this.onClose,
  });

  final Color accent;
  final String channelName;
  final String? iconUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: accent.withValues(alpha: 0.95),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.playerEpgOverlayTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  channelName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RecordingStyleTvFrameChannelLogo(
            iconUrl: iconUrl,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.accent,
  });

  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 4,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        valueColor: AlwaysStoppedAnimation<Color>(
          accent.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
