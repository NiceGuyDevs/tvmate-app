/// Manage Recording — Step C: per-category channel approval.
///
/// 1:1 port of `renderRecordingChannelsPage()` + bindings
/// (settings.html line 7547).
///
/// Layout:
///   [sub-page head] title=<cat name>, subtitle=<playlist> · X of Y
///     approved (+ "filter on (N hidden)" when catch-up filter on),
///     actions=[Select all] [Clear all]
///
///   (optional) .rec-banner when the catch-up filter is on, warning
///   that N channels are hidden.
///
///   .card.rec-ch-card — stacked rec-ch-row items:
///     38 logo · info (title + pills for catch-up / hidden / original)
///     value label ("Approved" / "Off") · pill toggle
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsRecordingChannelsPage extends StatelessWidget {
  const NsRecordingChannelsPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.categoryId,
    required this.onBack,
  });

  final NewSettingsState state;
  final String playlistId;
  final String categoryId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
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
        final cat = (p.groups['live'] ?? const <NsPlaylistGroup>[])
            .cast<NsPlaylistGroup?>()
            .firstWhere((g) => g?.id == categoryId, orElse: () => null);
        if (cat == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              d.listHorizontalPadding,
              d.listTopPadding,
              d.listHorizontalPadding,
              d.listBottomPadding,
            ),
            children: [
              NsSubPageHead(
                title: 'Category not found',
                onBack: onBack,
              ),
            ],
          );
        }
        final r = state.recordingFor(playlistId);
        final list = p.channelsMap[categoryId] ??
            const <NsPlaylistChannel>[];
        final approved = (r.channels[categoryId] ?? const <String>[]).toSet();
        final visible = r.filterCatchup
            ? list.where((c) => c.catchup).toList()
            : list;
        final visApproved =
            visible.where((c) => approved.contains(c.id)).length;
        final noCatchupCount = list.where((c) => !c.catchup).length;

        final subBuf = StringBuffer();
        subBuf.write('${p.name} · $visApproved of ${visible.length} '
            'channels approved');
        if (r.filterCatchup) {
          subBuf.write(' · filter on ($noCatchupCount hidden)');
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: cat.alias ?? cat.name,
              subtitle: subBuf.toString(),
              onBack: onBack,
              actions: [
                NsButton(
                  label: l10n.catchupSelectAll,
                  icon: Icons.check_rounded,
                  variant: NsButtonVariant.ghost,
                  onPressed: () =>
                      state.recordingSelectAllChannels(playlistId, categoryId),
                ),
                NsButton(
                  label: l10n.catchupClearAll,
                  icon: Icons.close_rounded,
                  variant: NsButtonVariant.ghost,
                  onPressed: () =>
                      state.recordingClearVisibleChannels(playlistId, categoryId),
                ),
              ],
            ),
            if (r.filterCatchup)
              _FilterBanner(l10n: l10n, noCatchupCount: noCatchupCount),
            if (visible.isEmpty)
              _EmptyState(filterOn: r.filterCatchup)
            else
              _ChannelsCard(
                channels: visible,
                approvedSet: approved,
                onToggle: (chId) =>
                    state.toggleRecordingChannel(playlistId, categoryId, chId),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  `.rec-banner` — 28px warn icon | 1fr text. Warn-yellow bg with
//  matching border, 8 radius.
// ═══════════════════════════════════════════════════════════════════════

class _FilterBanner extends StatelessWidget {
  const _FilterBanner({required this.l10n, required this.noCatchupCount});
  final AppLocalizations l10n;
  final int noCatchupCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 6, 0, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0x0FFBBF24), // rgba(251,191,36,0.06)
        border: Border.all(color: const Color(0x38FBBF24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x1AFBBF24),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              size: 13,
              color: NsColors.warn,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: NsColors.text2,
                  fontSize: 11.5,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
                children: [
                  TextSpan(
                    text: l10n.catchupFilterBannerLead,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: l10n.catchupFilterHiddenMessage(noCatchupCount),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  `.card.rec-ch-card` — stacked `.rec-ch-row` items with dividers.
// ═══════════════════════════════════════════════════════════════════════

class _ChannelsCard extends StatelessWidget {
  const _ChannelsCard({
    required this.channels,
    required this.approvedSet,
    required this.onToggle,
  });

  final List<NsPlaylistChannel> channels;
  final Set<String> approvedSet;
  final void Function(String chId) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
        boxShadow: NsShadow.s1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < channels.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: NsColors.line,
              ),
            _RecChRow(
              channel: channels[i],
              approved: approvedSet.contains(channels[i].id),
              onToggle: () => onToggle(channels[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

// `.rec-ch-row` — grid 38 / 1fr / auto / auto, padding 10/12. Toggle
// flips approval. Whole row is clickable.
class _RecChRow extends StatelessWidget {
  const _RecChRow({
    required this.channel,
    required this.approved,
    required this.onToggle,
  });

  final NsPlaylistChannel channel;
  final bool approved;
  final VoidCallback onToggle;

  String get _initials {
    final display = channel.alias ?? channel.name;
    final parts = display
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.isEmpty ? '' : p[0])
        .join()
        .toUpperCase();
    final clipped = parts.length > 3 ? parts.substring(0, 3) : parts;
    return clipped.isEmpty ? '·' : clipped;
  }

  @override
  Widget build(BuildContext context) {
    final display = channel.alias ?? channel.name;
    // `.rec-ch-row.no-catchup { opacity: .55 }` and `.is-hidden { .4 }`.
    final opacity =
        channel.hidden ? 0.40 : (!channel.catchup ? 0.55 : 1.0);

    return NsFocusable(
      onActivate: onToggle,
      semanticLabel: display,
      // Row is flat (no borderRadius), so the focus accent is a
      // straight vertical stripe with no corner curves.
      focusAccentRadius: 0,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        color: focused ? NsColors.surface2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Opacity(
          opacity: opacity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Logo(initials: _initials, approved: approved),
              const SizedBox(width: 10),
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
                        letterSpacing: -0.06,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _RecPill(
                          label: channel.catchup
                              ? 'Catch-up'
                              : 'No catch-up',
                          variant: channel.catchup
                              ? _PillVariant.ok
                              : _PillVariant.muted,
                        ),
                        if (channel.hidden)
                          const _RecPill(
                            label: 'Hidden in Manage channels',
                            variant: _PillVariant.warn,
                          ),
                        if (channel.alias != null)
                          _RecPill(
                            label: 'Originally ${channel.name}',
                            variant: _PillVariant.muted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                approved ? 'Approved' : 'Off',
                style: TextStyle(
                  color: approved ? NsColors.accent : NsColors.text3,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 10),
              _MiniToggle(on: approved),
            ],
          ),
        ),
      ),
    );
  }
}

// `.rec-ch-row .rec-logo` — 38×38 bg-2 box; when the row is approved
// the bg shifts to accent-soft with accent border + accent text.
class _Logo extends StatelessWidget {
  const _Logo({required this.initials, required this.approved});
  final String initials;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: approved ? NsColors.accentSoft : NsColors.bg2,
        border: Border.all(
          color: approved ? NsColors.accentLine : NsColors.line,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: approved ? NsColors.accent : NsColors.text2,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// `.toggle` clone tuned to TV compact scale (used inside rec-ch-row).
class _MiniToggle extends StatelessWidget {
  const _MiniToggle({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: NsEase.ease,
      width: 30,
      height: 18,
      decoration: BoxDecoration(
        color: on ? NsColors.accent : NsColors.line2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: NsEase.ease,
            top: 2,
            left: on ? 14 : 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: on ? Colors.white : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  `.rec-pill` — monospace uppercase pill. ok = accent, muted =
//  text-3, warn = yellow.
// ═══════════════════════════════════════════════════════════════════════

enum _PillVariant { ok, muted, warn }

class _RecPill extends StatelessWidget {
  const _RecPill({required this.label, required this.variant});
  final String label;
  final _PillVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color border, Color fg) = switch (variant) {
      _PillVariant.ok => (
          NsColors.accentSoft,
          NsColors.accentLine,
          NsColors.accent,
        ),
      _PillVariant.muted => (
          NsColors.bg2,
          NsColors.line,
          NsColors.text3,
        ),
      _PillVariant.warn => (
          const Color(0x14FBBF24),
          const Color(0x4DFBBF24),
          NsColors.warn,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'monospace',
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filterOn});
  final bool filterOn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
              Icons.fiber_manual_record_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No channels to approve',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            filterOn
                ? 'Every channel here is hidden by the catch-up filter.'
                : 'This category is empty.',
            textAlign: TextAlign.center,
            style: const TextStyle(
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
