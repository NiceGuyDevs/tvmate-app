/// Playlists landing — port of `renderPlaylistsPage` (settings.html
/// line 5608). Sub-page head + responsive card grid.
///
/// Each card is rendered at HTML-exact 320×296 pixel values and wrapped
/// in a [FittedBox] so the grid can shrink it down as a whole — same
/// strategy the HTML uses with `transform: scale(0.7)`.
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_confirm_dialog.dart';
import '../widgets/ns_epg_zone_menu.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_playlist_card.dart';
import '../widgets/ns_sub_page_head.dart';

class NsPlaylistsPage extends StatelessWidget {
  const NsPlaylistsPage({
    super.key,
    required this.state,
    required this.manageFocusNodeFor,
    required this.onOpenDetail,
    required this.onAddPlaylist,
    this.onBack,
  });

  final NewSettingsState state;
  final VoidCallback? onBack;

  /// Returns the stable [FocusNode] of a playlist's **Manage** button.
  /// Owned by the screen so back-from-detail can restore focus there.
  final FocusNode Function(String playlistId) manageFocusNodeFor;
  final void Function(NsPlaylist p) onOpenDetail;
  final VoidCallback onAddPlaylist;

  Future<void> _openEpgMenu(
    BuildContext anchorContext,
    NsPlaylist p,
  ) async {
    final picked = await showNsEpgZoneMenu(
      anchorContext: anchorContext,
      playlistName: p.name,
      currentMode: p.epgMode,
    );
    if (picked != null && anchorContext.mounted) {
      state.setPlaylist(p.id, (x) => x.epgMode = picked);
    }
  }

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final playlists = state.playlists;
        return LayoutBuilder(
          builder: (context, constraints) {
            // Target ~190 px per rendered card — fits 5 on a typical TV
            // pane (~1000 px) and 3 on ~600 px. Each card renders the
            // HTML's 320×296 design scaled to (cardW, cardW·296/320).
            final cols =
                (constraints.maxWidth / 190).floor().clamp(3, 6);
            const gap = 10.0;
            final cardW =
                (constraints.maxWidth - gap * (cols - 1)) / cols;
            final cardH = cardW * (kNsPlaylistCardBaseH / kNsPlaylistCardBaseW);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                d.listHorizontalPadding,
                d.listTopPadding,
                d.listHorizontalPadding,
                d.listBottomPadding,
              ),
              children: [
                NsSubPageHead(
                  title: 'Playlists',
                  subtitle:
                      'Sync, manage and remove your IPTV sources. Click '
                      'a card to open it.',
                  onBack: onBack,
                  actions: [
                    _AddPlaylistButton(onPressed: onAddPlaylist),
                  ],
                ),
                if (playlists.isEmpty)
                  // Empty state: Add Playlist button autofocuses on mount
                  // so activating the Playlists rail tile still lands on
                  // a meaningful control (the screen's first-focus logic
                  // can't target a list that isn't there).
                  _EmptyState(onAdd: onAddPlaylist, autofocus: true)
                else
                  // [WidgetOrder] alone often fails in-row Left on TV; this
                  // group matches reading order so the global
                  // [newSettingsRootLeft] sees a real in-grid move.
                  FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        // Per-card focus nodes are owned by the parent
                        // screen and looked up via [manageFocusNodeFor].
                        // The screen's `_focusActiveCategoryFirstRow`
                        // requests focus on the first card's node after
                        // the user activates the Playlists rail tile —
                        // no on-mount autofocus hack needed here.
                        for (var i = 0; i < playlists.length; i++)
                          SizedBox(
                            width: cardW,
                            height: cardH,
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: NsPlaylistCard(
                                playlist: playlists[i],
                                manageFocusNode: manageFocusNodeFor(
                                  playlists[i].id,
                                ),
                                manageLeftNeighbor: i > 0
                                    ? manageFocusNodeFor(
                                        playlists[i - 1].id,
                                      )
                                    : null,
                                manageRightNeighbor: i + 1 < playlists.length
                                    ? manageFocusNodeFor(
                                        playlists[i + 1].id,
                                      )
                                    : null,
                                onManage: () => onOpenDetail(playlists[i]),
                                onEpgTap: (anchorCtx) => _openEpgMenu(
                                  anchorCtx,
                                  playlists[i],
                                ),
                                onSync: () =>
                                    state.syncPlaylist(playlists[i].id),
                                onDelete: () =>
                                    _confirmDelete(context, playlists[i]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AddPlaylistButton extends StatelessWidget {
  const _AddPlaylistButton({required this.onPressed, this.autofocus = false});
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      autofocus: autofocus,
      onActivate: onPressed,
      semanticLabel: 'Add playlist',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: focused ? NsColors.accent2 : NsColors.accent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: focused
              ? const [
                  BoxShadow(
                    color: Color(0x554DD0E1),
                    offset: Offset(0, 5),
                    blurRadius: 14,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x2E4DD0E1),
                    offset: Offset(0, 3),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 13, color: Color(0xFF001317)),
            SizedBox(width: 6),
            Text(
              'Add playlist',
              style: TextStyle(
                color: Color(0xFF001317),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, this.autofocus = false});
  final bool autofocus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storage_rounded,
            size: 22,
            color: NsColors.text4,
          ),
          const SizedBox(height: 8),
          const Text(
            'No playlists yet',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Add playlist" to connect an IPTV source.',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          _AddPlaylistButton(onPressed: onAdd, autofocus: autofocus),
        ],
      ),
    );
  }
}
