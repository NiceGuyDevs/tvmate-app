/// Manage Groups landing — 1:1 port of `renderGroupsPage()` in
/// settings.html (line 6248). Three big section tiles (TV / Movies /
/// Shows) with `visible / total` counts. Tapping one opens the section
/// list for that kind.
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsGroupsPage extends StatelessWidget {
  const NsGroupsPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.onBack,
    required this.onOpenSection,
  });

  final NewSettingsState state;
  final String playlistId;
  final VoidCallback onBack;

  /// Invoked when the user taps one of the section tiles. `section` is
  /// `'live' | 'vod' | 'series'`.
  final void Function(String section) onOpenSection;

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
        final vod = p.groups['vod'] ?? const <NsPlaylistGroup>[];
        final series = p.groups['series'] ?? const <NsPlaylistGroup>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Manage groups',
              subtitle:
                  "${p.name} · hide categories you don't watch, rename "
                  "them, or pin Live ones above Favorites.",
              onBack: onBack,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // `.section-grid` — HTML uses minmax(220, 1fr). Tightened
                // to 180 on TV so three tiles comfortably fit a narrower
                // pane without each tile being oversized.
                const minTile = 180.0;
                const gap = 8.0;
                final cols =
                    ((constraints.maxWidth + gap) / (minTile + gap))
                        .floor()
                        .clamp(1, 3);
                final tileW =
                    (constraints.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileW,
                      child: _SectionTile(
                        icon: Icons.live_tv_rounded,
                        label: 'TV',
                        count: live.where((g) => g.visible).length,
                        total: live.length,
                        onPressed: live.isEmpty
                            ? null
                            : () => onOpenSection('live'),
                        autofocus: true,
                      ),
                    ),
                    SizedBox(
                      width: tileW,
                      child: _SectionTile(
                        icon: Icons.movie_rounded,
                        label: 'Movies',
                        count: vod.where((g) => g.visible).length,
                        total: vod.length,
                        onPressed: vod.isEmpty
                            ? null
                            : () => onOpenSection('vod'),
                      ),
                    ),
                    SizedBox(
                      width: tileW,
                      child: _SectionTile(
                        icon: Icons.video_library_rounded,
                        label: 'Shows',
                        count: series.where((g) => g.visible).length,
                        total: series.length,
                        onPressed: series.isEmpty
                            ? null
                            : () => onOpenSection('series'),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (vod.isEmpty && series.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'This source only provides Live TV. Add an Xtream '
                  'playlist with VOD/Series to see those sections.',
                  style: TextStyle(
                    color: NsColors.text3,
                    fontSize: 12.5,
                    height: 1.4,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// `.section-tile` — grid 32 / 1fr / auto, 12 gap, 12/14 padding.
class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.onPressed,
    this.autofocus = false,
  });
  final IconData icon;
  final String label;
  final int count;
  final int total;
  final VoidCallback? onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return NsFocusable(
      autofocus: autofocus && !disabled,
      canRequestFocus: !disabled,
      onActivate: onPressed,
      semanticLabel: '$label groups',
      focusAccentRadius: 11,
      builder: (context, focused) {
        final effFocused = focused && !disabled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: NsEase.ease,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: effFocused ? NsColors.surface2 : NsColors.surface,
            border: Border.all(
              color: effFocused ? NsColors.accentLine : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Opacity(
            opacity: disabled ? 0.5 : 1.0,
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
                  child: Icon(icon, size: 13, color: NsColors.text2),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _CountPill(count: count, total: total),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `.section-tile .cnt` — monospace count pill, accent `b` for the
/// visible number.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final empty = total == 0;
    if (empty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: NsColors.bg2,
          border: Border.all(color: NsColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '—',
          style: TextStyle(
            color: NsColors.text3,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: NsColors.bg2,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: NsColors.text3,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            height: 1,
            decoration: TextDecoration.none,
          ),
          children: [
            TextSpan(
              text: '$count',
              style: const TextStyle(
                color: NsColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: ' / $total'),
          ],
        ),
      ),
    );
  }
}
