/// Manage Channels — category landing. 1:1 port of
/// `renderChannelsCategoriesPage()` in settings.html (line 6625).
///
/// Shows every Live group as a [_CategoryTile] with folder icon, name,
/// "N channels · M renamed · K hidden" subtext, and a `<b>total</b>`
/// accent count pill. Tapping one opens the per-category channel list.
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsChannelsCategoriesPage extends StatelessWidget {
  const NsChannelsCategoriesPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.onBack,
    required this.onOpenCategory,
  });

  final NewSettingsState state;
  final String playlistId;
  final VoidCallback onBack;

  /// Invoked with the group id when the user taps a tile.
  final void Function(NsPlaylistGroup category) onOpenCategory;

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
              NsSubPageHead(title: 'Playlist not found', onBack: onBack),
            ],
          );
        }
        final live = p.groups['live'] ?? const <NsPlaylistGroup>[];

        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Manage channels',
              subtitle:
                  '${p.name} · open a category to rename, set logos, '
                  'or hide channels.',
              onBack: onBack,
            ),
            if (live.isEmpty)
              const _EmptyCategories()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  // `.section-grid` — minmax(220, 1fr), 10 gap. On TV
                  // we use 200 min so three tiles fit on typical panes.
                  const minTile = 200.0;
                  const gap = 8.0;
                  final cols =
                      ((constraints.maxWidth + gap) / (minTile + gap))
                          .floor()
                          .clamp(1, 4);
                  final tileW =
                      (constraints.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final g in live)
                        SizedBox(
                          width: tileW,
                          child: _CategoryTile(
                            group: g,
                            channels: p.channelsMap[g.id] ??
                                const <NsPlaylistChannel>[],
                            onPressed: () => onOpenCategory(g),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

// `.section-tile` adapted for Channels — compact TV sizing.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.group,
    required this.channels,
    required this.onPressed,
  });

  final NsPlaylistGroup group;
  final List<NsPlaylistChannel> channels;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final total = channels.length;
    final hidden = channels.where((c) => c.hidden).length;
    final renamed = channels.where((c) => c.alias != null).length;
    final display = group.alias ?? group.name;
    final subParts = <String>['$total channels'];
    if (renamed > 0) subParts.add('$renamed renamed');
    if (hidden > 0) subParts.add('$hidden hidden');
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: display,
      focusAccentRadius: 11,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.accentLine : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NsColors.bg2,
                border: Border.all(color: NsColors.line),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.folder_rounded,
                size: 13,
                color: NsColors.text2,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    display,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subParts.join(' · '),
                    style: const TextStyle(
                      color: NsColors.text3,
                      fontSize: 10.5,
                      height: 1.3,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _CountPill(total: total),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        total == 0 ? '—' : '$total',
        style: const TextStyle(
          color: NsColors.accent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.folder_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No categories',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Sync this playlist first.',
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
