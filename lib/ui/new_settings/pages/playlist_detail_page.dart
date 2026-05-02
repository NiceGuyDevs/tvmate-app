/// Playlist Detail — 1:1 port of `renderPlaylistDetailPage()` in
/// settings.html (line 6112).
///
/// Layout:
///
///     [sub-page head]  title=name, subtitle="Xtream · Synced N min ago"
///       actions: [Set as active / Active ✓] [Sync now]
///
///     .detail-hero   (grid: 1fr auto, radial cyan glow top-right)
///       h-title  NAME • .status-dot ok|sync|err • .pill-mini.active
///       h-meta   URL (monospace, break-all)
///       h-stats  • channels • movies • series • groups visible • renamed • hidden
///       h-actions [Edit playlist]
///
///     section.group
///       .group-label "MANAGE THIS PLAYLIST"
///       .tools-grid   [Manage groups] [Manage channels] [Manage recording]
///
///     .danger-zone   "Delete this playlist" + [Delete] (red)
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_confirm_dialog.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';
import '../widgets/ns_edit_playlist_dialog.dart';

class NsPlaylistDetailPage extends StatelessWidget {
  const NsPlaylistDetailPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.onBack,
    required this.onDeleted,
    required this.onOpenGroups,
    required this.onOpenChannels,
    required this.onOpenRecording,
  });

  final NewSettingsState state;
  final String playlistId;
  final VoidCallback onBack;

  /// Fired after the playlist has been deleted — caller pops to the
  /// landing page.
  final VoidCallback onDeleted;

  final VoidCallback onOpenGroups;
  final VoidCallback onOpenChannels;
  final VoidCallback onOpenRecording;

  Future<void> _confirmDelete(BuildContext context, NsPlaylist p) async {
    final r = await showNsConfirmDialog(
      context,
      title: 'Delete "${p.name}"?',
      message:
          'All cached metadata, group visibility and channel renames '
          "for this source will be removed. The remote source itself "
          "isn't touched.",
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (r == NsConfirmResult.confirmed && context.mounted) {
      await state.deletePlaylist(p.id);
      onDeleted();
    }
  }

  void _setActive(NsPlaylist p) {
    for (final other in state.playlists) {
      if (other.id == p.id) continue;
      state.setPlaylist(other.id, (x) => x.active = false);
    }
    state.setPlaylist(p.id, (x) => x.active = true);
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final p = state.playlistById(playlistId);
        if (p == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              d.listHorizontalPadding,
              d.listTopPadding,
              d.listHorizontalPadding,
              d.listBottomPadding,
            ),
            children: [
              NsSubPageHead(
                title: 'Playlist not found',
                onBack: onBack,
              ),
            ],
          );
        }
        final liveTotal = (p.groups['live'] ?? const <NsPlaylistGroup>[]).length;
        final vodTotal = (p.groups['vod'] ?? const <NsPlaylistGroup>[]).length;
        final seriesTotal =
            (p.groups['series'] ?? const <NsPlaylistGroup>[]).length;
        final liveOn = nsVisibleGroupsCount(p, 'live');
        final vodOn = nsVisibleGroupsCount(p, 'vod');
        final seriesOn = nsVisibleGroupsCount(p, 'series');
        final chTotal = p.channels;
        final renamedCh = p.renamedChannelsCount;
        final hiddenCh = p.hiddenChannelsCount;
        final groupsVisible = liveOn + vodOn + seriesOn;
        final groupsTotal = liveTotal + vodTotal + seriesTotal;
        final isXt = p.type == NsPlaylistType.xtream;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: p.name,
              subtitle:
                  '${isXt ? 'Xtream' : 'M3U'} · ${p.lastSync}',
              onBack: onBack,
              actions: [
                NsButton(
                  label: p.active ? 'Active' : 'Set as active',
                  icon: p.active ? Icons.check_rounded : null,
                  variant: NsButtonVariant.ghost,
                  onPressed: p.active ? null : () => _setActive(p),
                ),
                NsButton(
                  label: 'Sync now',
                  icon: Icons.refresh_rounded,
                  onPressed: () => state.syncPlaylist(p.id),
                ),
              ],
            ),
            _DetailHero(
              playlist: p,
              liveOn: liveOn,
              liveTotal: liveTotal,
              renamedCh: renamedCh,
              hiddenCh: hiddenCh,
              onEditPlaylist: () => unawaited(_openEditPlaylist(context, p.id)),
            ),
            const SizedBox(height: 14),
            _GroupLabel(label: 'Manage this playlist'),
            const SizedBox(height: 8),
            _ToolsGrid(
              isXtream: isXt,
              groupsVisible: groupsVisible,
              groupsTotal: groupsTotal,
              channelsTotal: chTotal,
              recordingMeta: isXt ? _recordingMeta(p) : null,
              onOpenGroups: onOpenGroups,
              onOpenChannels: onOpenChannels,
              onOpenRecording: isXt ? onOpenRecording : null,
            ),
            const SizedBox(height: 16),
            _DangerZone(
              onDelete: () => _confirmDelete(context, p),
            ),
          ],
        );
      },
    );
  }

  /// Port of `recSummary()` (settings.html line 7398) formatted for
  /// the Manage recording tool tile's `.meta` line.
  String _recordingMeta(NsPlaylist p) {
    final r = state.recordingFor(p.id);
    final totalCats = (p.groups['live'] ?? const <NsPlaylistGroup>[]).length;
    final approvedCats = r.categories.length;
    final approvedChs = state.recordingApprovedChannelsCount(p.id);
    final buf = StringBuffer()
      ..write('$approvedCats of $totalCats categories · ')
      ..write('$approvedChs channel${approvedChs == 1 ? '' : 's'} approved');
    final flags = <String>[];
    if (r.filterCatchup) flags.add('Filter on');
    if (r.tvFrameEpg) flags.add('TV frame on');
    if (flags.isNotEmpty) {
      buf
        ..write(' · ')
        ..write(flags.join(' · '));
    }
    return buf.toString();
  }

  Future<void> _openEditPlaylist(BuildContext context, String playlistId) async {
    await showNsEditPlaylistDialog(context, playlistId: playlistId);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.detail-hero` — 2-col grid: info | actions. Radial cyan glow top-right.
// ═══════════════════════════════════════════════════════════════════════

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.playlist,
    required this.liveOn,
    required this.liveTotal,
    required this.renamedCh,
    required this.hiddenCh,
    required this.onEditPlaylist,
  });

  final NsPlaylist playlist;
  final int liveOn;
  final int liveTotal;
  final int renamedCh;
  final int hiddenCh;
  final VoidCallback onEditPlaylist;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.card),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [NsColors.surface2, NsColors.surface],
        ),
      ),
      foregroundDecoration: const BoxDecoration(
        // `radial-gradient(70% 100% at 100% 0%, accent-soft, transparent 70%)`
        gradient: RadialGradient(
          center: Alignment(1.0, -1.0),
          radius: 1.0,
          colors: [NsColors.accentSoft, Color(0x00000000)],
          stops: [0, 0.7],
        ),
        borderRadius:
            BorderRadius.all(Radius.circular(NsRadius.card)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          final info = _HeroInfo(
            playlist: playlist,
            liveOn: liveOn,
            liveTotal: liveTotal,
            renamedCh: renamedCh,
            hiddenCh: hiddenCh,
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              NsButton(
                label: 'Edit playlist',
                icon: Icons.edit_rounded,
                onPressed: onEditPlaylist,
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                info,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: actions,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              const SizedBox(width: 18),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.playlist,
    required this.liveOn,
    required this.liveTotal,
    required this.renamedCh,
    required this.hiddenCh,
  });

  final NsPlaylist playlist;
  final int liveOn;
  final int liveTotal;
  final int renamedCh;
  final int hiddenCh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // .h-title
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              playlist.name,
              style: const TextStyle(
                color: NsColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
                height: 1.15,
                decoration: TextDecoration.none,
              ),
            ),
            _StatusDot(status: playlist.status),
            if (playlist.active) const _ActivePill(),
          ],
        ),
        const SizedBox(height: 4),
        // .h-meta
        Text(
          playlist.url.isEmpty ? '—' : playlist.url,
          style: const TextStyle(
            color: NsColors.text3,
            fontSize: 11,
            fontFamily: 'monospace',
            height: 1.3,
            decoration: TextDecoration.none,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // .h-stats
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _HeroStat(value: playlist.channels, label: 'channels'),
            if (playlist.vod > 0)
              _HeroStat(value: playlist.vod, label: 'movies'),
            if (playlist.series > 0)
              _HeroStat(value: playlist.series, label: 'series'),
            _HeroStat(
              value: liveOn,
              trailing: '/$liveTotal live groups visible',
            ),
            if (renamedCh > 0)
              _HeroStat(value: renamedCh, label: 'renamed'),
            if (hiddenCh > 0)
              _HeroStat(value: hiddenCh, label: 'hidden'),
          ],
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    this.label,
    this.trailing,
  });
  final int value;
  final String? label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: NsColors.text2,
          fontSize: 11.5,
          height: 1.2,
          decoration: TextDecoration.none,
        ),
        children: [
          TextSpan(
            text: value.toString(),
            style: const TextStyle(
              color: NsColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' ${label ?? trailing ?? ''}'),
        ],
      ),
    );
  }
}

/// `.status-dot` — uppercase label + a 7×7 dot prefix. Sync state
/// pulses warn, error is solid red, ok glows success.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final NsPlaylistStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      NsPlaylistStatus.ok => (NsColors.success, 'Synced'),
      NsPlaylistStatus.syncing => (NsColors.warn, 'Syncing'),
      NsPlaylistStatus.error => (NsColors.danger, 'Error'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == NsPlaylistStatus.syncing)
          _PulseDot(color: color)
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: status == NsPlaylistStatus.ok
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final alpha = t < 0.7 ? (1 - t / 0.7) * 0.45 : 0.0;
        final spread = t < 0.7 ? (t / 0.7) * 6.0 : 6.0;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: alpha),
                spreadRadius: spread,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// `.pill-mini.active` — small uppercase green pill with a check.
class _ActivePill extends StatelessWidget {
  const _ActivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: NsColors.successSoft,
        border: Border.all(color: const Color(0x594ADE80)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_rounded, size: 10, color: NsColors.success),
          SizedBox(width: 4),
          Text(
            'ACTIVE',
            style: TextStyle(
              color: NsColors.success,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.group-label` — 10.5px uppercase 1.5px letter-spacing.
// ═══════════════════════════════════════════════════════════════════════

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: NsColors.text3,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.tools-grid` — repeat(auto-fill, minmax(240, 1fr)), gap 12.
// `.tool-tile` — 40px icon | 1fr text | 16px chev, 16px padding, card bg.
// ═══════════════════════════════════════════════════════════════════════

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid({
    required this.isXtream,
    required this.groupsVisible,
    required this.groupsTotal,
    required this.channelsTotal,
    required this.recordingMeta,
    required this.onOpenGroups,
    required this.onOpenChannels,
    required this.onOpenRecording,
  });
  final bool isXtream;
  final int groupsVisible;
  final int groupsTotal;
  final int channelsTotal;

  /// Pre-formatted recording summary string (null when not Xtream).
  final String? recordingMeta;

  final VoidCallback onOpenGroups;
  final VoidCallback onOpenChannels;
  final VoidCallback? onOpenRecording;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `repeat(auto-fill, minmax(240px, 1fr))` — pack as many 240-wide
        // tiles as fit and stretch to fill.
        const minTile = 240.0;
        const gap = 12.0;
        final l10n = AppLocalizations.of(context);
        final cols = ((constraints.maxWidth + gap) / (minTile + gap))
            .floor()
            .clamp(1, 3);
        final tileW =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        final tiles = <Widget>[
          SizedBox(
            width: tileW,
            child: _ToolTile(
              icon: Icons.folder_rounded,
              title: 'Manage groups',
              meta:
                  "Hide categories you don't watch and rename them. "
                  "$groupsVisible of $groupsTotal visible.",
              onPressed: onOpenGroups,
              autofocus: true,
            ),
          ),
          SizedBox(
            width: tileW,
            child: _ToolTile(
              icon: Icons.live_tv_rounded,
              title: 'Manage channels',
              meta:
                  "Rename, set custom logos, hide channels you don't "
                  "want. $channelsTotal channels indexed.",
              onPressed: onOpenChannels,
            ),
          ),
          SizedBox(
            width: tileW,
            child: _ToolTile(
              icon: Icons.fiber_manual_record_rounded,
              title: l10n.catchupManage,
              trailingPill: isXtream ? null : 'XTREAM ONLY',
              meta: isXtream
                  ? (recordingMeta ?? '')
                  : "Catch-up needs Xtream credentials — this source "
                      "doesn't expose catch-up.",
              onPressed: onOpenRecording,
              disabled: !isXtream,
            ),
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles,
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.meta,
    required this.onPressed,
    this.trailingPill,
    this.disabled = false,
    this.autofocus = false,
  });
  final IconData icon;
  final String title;
  final String meta;
  final VoidCallback? onPressed;
  final String? trailingPill;
  final bool disabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      autofocus: autofocus && !disabled,
      canRequestFocus: !disabled,
      onActivate: disabled ? null : onPressed,
      semanticLabel: title,
      builder: (context, focused) {
        final effFocused = focused && !disabled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: NsEase.ease,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: effFocused ? NsColors.surface2 : NsColors.surface,
            border: Border.all(
              color: effFocused ? NsColors.accentLine : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(NsRadius.card),
            boxShadow: disabled ? null : NsShadow.s1,
          ),
          child: Opacity(
            opacity: disabled ? 0.55 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: disabled
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              NsColors.accentSoft,
                              Colors.transparent,
                            ],
                          ),
                    color: disabled ? NsColors.bg2 : null,
                    border: Border.all(
                      color: disabled
                          ? NsColors.line
                          : NsColors.accentLine,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: disabled ? NsColors.text3 : NsColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: NsColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.07,
                                height: 1.15,
                                decoration: TextDecoration.none,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trailingPill != null) ...[
                            const SizedBox(width: 5),
                            _XtPill(label: trailingPill!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: NsColors.text3,
                          fontSize: 11,
                          height: 1.35,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: effFocused
                      ? NsColors.accent
                      : NsColors.text3,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _XtPill extends StatelessWidget {
  const _XtPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: NsColors.text3,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// `.danger-zone` — danger-soft bg, dashed red border, 16/18 padding.
// ═══════════════════════════════════════════════════════════════════════

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NsColors.dangerSoft,
        border: Border.all(
          color: const Color(0x59F87171),
          style: BorderStyle.solid, // Flutter can't dash natively
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: NsColors.text2,
                  fontSize: 11.5,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
                children: [
                  TextSpan(
                    text: 'Delete this playlist',
                    style: TextStyle(
                      color: NsColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' · removes all cached groups, channel overrides '
                        'and EPG settings for it.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          NsButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            variant: NsButtonVariant.danger,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

