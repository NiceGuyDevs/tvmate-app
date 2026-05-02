/// Playlist card — one-to-one with settings.html `.pl-card` (CSS lines
/// 962–1193; markup `renderPlaylistsPage` line 5608).
///
/// Written at HTML-exact pixel values in a fixed 320 × 296 box. The grid
/// wraps each instance in a [FittedBox] so the HTML design gets **scaled
/// as a whole** to whatever cell width the grid gives — same strategy
/// the HTML uses (`--pl-card-scale: 0.7` applies to everything inside).
///
/// Absolutely no density scaling on the card internals — every padding,
/// font size, border radius, shadow offset, and icon size is copy-pasted
/// straight from the CSS. Whatever the HTML designed at, that's what
/// ships.
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

/// HTML `--pl-card-w: 320px`. The grid scales this whole block down via
/// [FittedBox] to whatever cell width it chose.
const double kNsPlaylistCardBaseW = 320;

/// Height tightened from HTML's 296 → 250 to remove the dead-zone below
/// the Manage button. The layout still fits all five rows with a small
/// gap before the foot.
const double kNsPlaylistCardBaseH = 250;

/// The card is NOT outer-focusable. Only the inner action buttons
/// (Manage · EPG · Sync now · Delete) are real D-pad focus targets. The
/// outer `Focus` wrapper is a passive scope that detects descendant
/// focus and paints the card's accent border + halo when any inner
/// button is selected — matches the HTML's `:focus-within` treatment.
class NsPlaylistCard extends StatefulWidget {
  const NsPlaylistCard({
    super.key,
    required this.playlist,
    required this.manageFocusNode,
    required this.onManage,
    required this.onEpgTap,
    required this.onSync,
    required this.onDelete,
    this.autofocusManage = false,
    this.manageLeftNeighbor,
    this.manageRightNeighbor,
  });

  final NsPlaylist playlist;

  /// In-grid D-pad neighbors for the **Manage** button (main row entry).
  final FocusNode? manageLeftNeighbor;
  final FocusNode? manageRightNeighbor;

  /// Manage button's [FocusNode] — owned by the screen so
  /// back-from-detail can return focus to the correct card's Manage.
  final FocusNode manageFocusNode;

  /// When true the Manage button claims focus on first build — used for
  /// the first card in the Playlists grid so the user lands on the
  /// first actionable item instead of the sub-page Back button.
  final bool autofocusManage;

  final VoidCallback onManage;

  /// Tapping the EPG row opens the anchored zone dropdown. The callback
  /// receives the button's [BuildContext] so the dropdown can compute
  /// its overlay anchor rect.
  final void Function(BuildContext anchorContext) onEpgTap;

  final VoidCallback onSync;
  final VoidCallback onDelete;

  @override
  State<NsPlaylistCard> createState() => _NsPlaylistCardState();
}

class _NsPlaylistCardState extends State<NsPlaylistCard> {
  late final FocusNode _scope;
  late final FocusNode _syncFocus;
  late final FocusNode _deleteFocus;
  bool _innerFocus = false;

  @override
  void initState() {
    super.initState();
    final id = widget.playlist.id;
    _scope = FocusNode(
      debugLabel: 'ns:card-scope:$id',
      // Must not skip traversal: card shell participates in the grid's
      // [ReadingOrderTraversalPolicy] so D-pad Left moves to the previous card.
      skipTraversal: false,
      canRequestFocus: false,
    );
    _syncFocus = FocusNode(debugLabel: 'ns:pl:sync:$id');
    _deleteFocus = FocusNode(debugLabel: 'ns:pl:delete:$id');
    _scope.addListener(_onScope);
  }

  @override
  void dispose() {
    _scope.removeListener(_onScope);
    _scope.dispose();
    _syncFocus.dispose();
    _deleteFocus.dispose();
    super.dispose();
  }

  void _onScope() {
    if (!mounted) return;
    final has = _scope.hasFocus;
    if (_innerFocus != has) setState(() => _innerFocus = has);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _scope,
      child: _CardSurface(
        focused: _innerFocus,
        child: _CardBody(
          playlist: widget.playlist,
          manageFocusNode: widget.manageFocusNode,
          manageLeftNeighbor: widget.manageLeftNeighbor,
          manageRightNeighbor: widget.manageRightNeighbor,
          footSyncFocus: _syncFocus,
          footDeleteFocus: _deleteFocus,
          autofocusManage: widget.autofocusManage,
          onManage: widget.onManage,
          onEpgTap: widget.onEpgTap,
          onSync: widget.onSync,
          onDelete: widget.onDelete,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Card surface — HTML `.pl-card`
// ═══════════════════════════════════════════════════════════════════════

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.focused, required this.child});
  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kNsPlaylistCardBaseW,
      height: kNsPlaylistCardBaseH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: NsEase.ease,
        decoration: BoxDecoration(
          color: NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.accentLine : NsColors.line,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(13),
          // `.pl-card` base shadow: 0 18px 50px rgba(0,0,0,.45)
          // Hover: 0 14px 36px rgba(0,0,0,.4) + 0 0 0 1px accent-soft halo
          // Focus-visible: adds a 0 0 0 3px accent-soft halo on top.
          boxShadow: focused
              ? const [
                  BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 14),
                    blurRadius: 36,
                  ),
                  BoxShadow(
                    color: NsColors.accentSoft,
                    spreadRadius: 3,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x73000000),
                    offset: Offset(0, 18),
                    blurRadius: 50,
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.playlist,
    required this.manageFocusNode,
    this.manageLeftNeighbor,
    this.manageRightNeighbor,
    required this.footSyncFocus,
    required this.footDeleteFocus,
    required this.autofocusManage,
    required this.onManage,
    required this.onEpgTap,
    required this.onSync,
    required this.onDelete,
  });
  final NsPlaylist playlist;
  final FocusNode manageFocusNode;
  final FocusNode? manageLeftNeighbor;
  final FocusNode? manageRightNeighbor;
  final FocusNode footSyncFocus;
  final FocusNode footDeleteFocus;
  final bool autofocusManage;
  final VoidCallback onManage;
  final void Function(BuildContext anchorContext) onEpgTap;
  final VoidCallback onSync;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(playlist: playlist),
        _Stats(playlist: playlist),
        _EpgRow(playlist: playlist, onTap: onEpgTap),
        _ManageRow(
          focusNode: manageFocusNode,
          focusLeftNeighbor: manageLeftNeighbor,
          focusRightNeighbor: manageRightNeighbor,
          focusDownNeighbor: footSyncFocus,
          autofocus: autofocusManage,
          onPressed: onManage,
        ),
        const Spacer(),
        _Foot(
          playlist: playlist,
          onSync: onSync,
          onDelete: onDelete,
          manageFocus: manageFocusNode,
          syncFocus: footSyncFocus,
          deleteFocus: footDeleteFocus,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// .head — 44px tall, padding 10 12 0, grid 26px 1fr auto, gap 9px
// ═══════════════════════════════════════════════════════════════════════

class _Head extends StatelessWidget {
  const _Head({required this.playlist});
  final NsPlaylist playlist;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // .ico — 26×26, gradient bg, accent-line border, 8px radius
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [NsColors.accentSoft, Colors.transparent],
                ),
                border: Border.all(color: NsColors.accentLine),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storage_rounded,
                size: 12,
                color: NsColors.accent,
              ),
            ),
            const SizedBox(width: 9),
            // .name — 700 13.5px/1.1, letter-spacing -0.012em
            Expanded(
              child: Text(
                playlist.name,
                style: const TextStyle(
                  color: NsColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -0.012 * 13.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            _ActivePill(active: playlist.active),
          ],
        ),
      ),
    );
  }
}

// `.active-pill` — 20px tall, padding 0 8, font 700 9.5px/1, letter-spacing .8px
class _ActivePill extends StatelessWidget {
  const _ActivePill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color bg = active ? NsColors.successSoft : NsColors.surface2;
    final Color border =
        active ? const Color(0x524ADE80) : NsColors.line;
    final Color fg = active ? NsColors.success : NsColors.text3;
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            _PulseDot(color: fg)
          else
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
          const SizedBox(width: 5),
          Text(
            active ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              color: fg,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
        ],
      ),
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
      duration: const Duration(milliseconds: 1600),
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
        final haloAlpha = t < 0.7 ? (1 - t / 0.7) * 0.40 : 0.0;
        final haloSpread = t < 0.7 ? (t / 0.7) * 5.0 : 5.0;
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: haloAlpha),
                spreadRadius: haloSpread,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// .stats — margin 12 12 0, 3 columns gap 4
//   .tile — column, gap 6, padding 4 0
//     .ico — 26×26 gradient-tinted box, border 8px radius
//     .num — 800 16px monospace, letter-spacing -0.025em, tnum
//     .lbl — 700 8.5px, letter-spacing 1.4px, uppercase
// ═══════════════════════════════════════════════════════════════════════

class _Stats extends StatelessWidget {
  const _Stats({required this.playlist});
  final NsPlaylist playlist;

  String _fmt(int n) => n <= 0 ? '—' : n.toString();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.live_tv_rounded,
              value: _fmt(playlist.channels),
              label: 'CHANNELS',
              empty: playlist.channels == 0,
              iconColor: NsColors.accent,
              iconBg: NsColors.accentSoft,
              iconBorder: NsColors.accentLine,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _StatTile(
              icon: Icons.movie_rounded,
              value: _fmt(playlist.vod),
              label: 'MOVIES',
              empty: playlist.vod == 0,
              iconColor: NsColors.movie,
              iconBg: NsColors.movieSoft,
              iconBorder: NsColors.movieLine,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _StatTile(
              icon: Icons.video_library_rounded,
              value: _fmt(playlist.series),
              label: 'SERIES',
              empty: playlist.series == 0,
              iconColor: NsColors.series,
              iconBg: NsColors.seriesSoft,
              iconBorder: NsColors.seriesLine,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.empty,
    required this.iconColor,
    required this.iconBg,
    required this.iconBorder,
  });
  final IconData icon;
  final String value;
  final String label;
  final bool empty;
  final Color iconColor;
  final Color iconBg;
  final Color iconBorder;

  @override
  Widget build(BuildContext context) {
    final effIconBg = empty ? NsColors.surface2 : iconBg;
    final effIconBorder = empty ? NsColors.line : iconBorder;
    final effIcon = empty ? NsColors.text4 : iconColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: effIconBg,
              border: Border.all(color: effIconBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: effIcon),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: empty ? NsColors.text4 : NsColors.text,
              fontSize: empty ? 14 : 16,
              fontWeight: empty ? FontWeight.w600 : FontWeight.w800,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.025 * 16,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: NsColors.text3,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// .epg-row — margin 10 12 0, height 26, grid 38 1fr, gap 8
//   .lbl — 700 9px, letter-spacing 1.4px
//   .val — height 26, padding 0 10, 7px radius, bg surface-2, 600 11px
//     .clk — 11×11 color text-3
//     .zone — 1fr, ellipsis
//     .chev — 11×11 color text-3
// ═══════════════════════════════════════════════════════════════════════

class _EpgRow extends StatelessWidget {
  const _EpgRow({required this.playlist, required this.onTap});
  final NsPlaylist playlist;
  final void Function(BuildContext anchorContext) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 38,
            child: Text(
              'EPG',
              style: TextStyle(
                color: NsColors.text3,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (btnContext) => NsFocusable(
                onActivate: () => onTap(btnContext),
                semanticLabel: 'Change EPG time zone',
                builder: (context, focused) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: NsEase.ease,
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: NsColors.surface2,
                    border: Border.all(
                      color: focused ? NsColors.line2 : NsColors.line,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: NsColors.text3,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          nsEpgLabel(playlist.epgMode),
                          style: TextStyle(
                            color:
                                focused ? NsColors.text : NsColors.text2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.005 * 11,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 11,
                        color: NsColors.text3,
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

// ═══════════════════════════════════════════════════════════════════════
// .manage-row — margin 10 12 0, flex-start
//   .manage-btn — height 28, padding 0 16, 8px radius, accent bg, #001317 text
// ═══════════════════════════════════════════════════════════════════════

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.focusNode,
    required this.onPressed,
    this.autofocus = false,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusDownNeighbor,
  });
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final bool autofocus;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusDownNeighbor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: NsFocusable(
          focusNode: focusNode,
          autofocus: autofocus,
          onActivate: onPressed,
          semanticLabel: 'Manage',
          focusLeftNeighbor: focusLeftNeighbor,
          focusRightNeighbor: focusRightNeighbor,
          focusDownNeighbor: focusDownNeighbor,
          builder: (context, focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: NsEase.ease,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              // HTML filter: brightness(1.06) on hover — approximate by
              // shifting to the brighter accent2 on focus.
              color: focused ? NsColors.accent2 : NsColors.accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: focused
                  ? const [
                      BoxShadow(
                        color: Color(0x474DD0E1), // rgba(77,208,225,.28)
                        offset: Offset(0, 6),
                        blurRadius: 16,
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x2E4DD0E1), // rgba(77,208,225,.18)
                        offset: Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.edit_rounded,
                  size: 12,
                  color: Color(0xFF001317),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Manage',
                  style: TextStyle(
                    color: Color(0xFF001317),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// .foot — 36 tall, padding 0 8 0 12, border-top 1px line, gradient
//   .left — sync-ico 11 + label 10.5
//   .right — sync-now small pill + icon-btn
// ═══════════════════════════════════════════════════════════════════════

class _Foot extends StatelessWidget {
  const _Foot({
    required this.playlist,
    required this.onSync,
    required this.onDelete,
    required this.manageFocus,
    required this.syncFocus,
    required this.deleteFocus,
  });
  final NsPlaylist playlist;
  final VoidCallback onSync;
  final VoidCallback onDelete;
  final FocusNode manageFocus;
  final FocusNode syncFocus;
  final FocusNode deleteFocus;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (playlist.status) {
      NsPlaylistStatus.ok => (
          Icons.check_rounded,
          'Synced ${playlist.lastSync}',
          NsColors.text3,
        ),
      NsPlaylistStatus.syncing => (
          Icons.sync_rounded,
          'Syncing…',
          NsColors.warn,
        ),
      NsPlaylistStatus.error => (
          Icons.warning_amber_rounded,
          'Sync failed',
          NsColors.danger,
        ),
    };
    return Container(
      height: 36,
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NsColors.line)),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x2E000000), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _SyncNow(
            focusNode: syncFocus,
            onPressed: onSync,
            focusLeftNeighbor: manageFocus,
            focusRightNeighbor: deleteFocus,
            focusUpNeighbor: manageFocus,
          ),
          const SizedBox(width: 4),
          _DeleteIcon(
            focusNode: deleteFocus,
            onPressed: onDelete,
            focusLeftNeighbor: syncFocus,
            focusUpNeighbor: manageFocus,
          ),
        ],
      ),
    );
  }
}

class _SyncNow extends StatelessWidget {
  const _SyncNow({
    required this.focusNode,
    required this.onPressed,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    this.focusUpNeighbor,
  });
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final FocusNode? focusUpNeighbor;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: 'Sync now',
      focusLeftNeighbor: focusLeftNeighbor,
      focusRightNeighbor: focusRightNeighbor,
      focusUpNeighbor: focusUpNeighbor,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface3 : Colors.transparent,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 11,
              color: focused ? NsColors.text : NsColors.text3,
            ),
            const SizedBox(width: 5),
            Text(
              'Sync now',
              style: TextStyle(
                color: focused ? NsColors.text : NsColors.text3,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteIcon extends StatelessWidget {
  const _DeleteIcon({
    required this.focusNode,
    required this.onPressed,
    this.focusLeftNeighbor,
    this.focusUpNeighbor,
  });
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusUpNeighbor;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: 'Delete',
      focusLeftNeighbor: focusLeftNeighbor,
      focusUpNeighbor: focusUpNeighbor,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? NsColors.dangerSoft : Colors.transparent,
          border: Border.all(
            color: focused ? const Color(0x59F87171) : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          size: 11,
          color: focused ? NsColors.danger : NsColors.text3,
        ),
      ),
    );
  }
}
