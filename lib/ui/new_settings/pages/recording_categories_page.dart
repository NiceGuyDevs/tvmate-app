/// Manage Recording — Step B: Categories approval page.
///
/// 1:1 port of `renderRecordingCategoriesPage()` + its bindings
/// (settings.html line 7410).
///
/// Layout:
///   [sub-page head]  title=Manage recording, subtitle=<name> · N of M
///     cats · X chs approved, actions=[Select all] [Clear all]
///
///   section.group  "RECORDING OPTIONS"
///     .card with two switch rows:
///       • Catch-up filter
///       • TV frame on EPG
///
///   section.group  "CATEGORIES"
///     .card.rec-cat-card containing:
///       .rec-row (per live category):
///         .rec-main (32 ic | label/meta | chev) — opens channels list
///         .rec-toggle — approve/disapprove
library;

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

class NsRecordingCategoriesPage extends StatelessWidget {
  const NsRecordingCategoriesPage({
    super.key,
    required this.state,
    required this.playlistId,
    required this.onBack,
    required this.onOpenCategory,
  });

  final NewSettingsState state;
  final String playlistId;
  final VoidCallback onBack;

  /// Opens the per-category channel approval page. Only fires when
  /// the category is already approved (the HTML disables the `open`
  /// action otherwise and shows a toast — we just no-op here).
  final void Function(NsPlaylistGroup category) onOpenCategory;

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
              NsSubPageHead(title: 'Playlist not found', onBack: onBack),
            ],
          );
        }
        final live = p.groups['live'] ?? const <NsPlaylistGroup>[];
        final r = state.recordingFor(playlistId);
        final approvedSet = r.categories.toSet();
        final approvedChs = state.recordingApprovedChannelsCount(playlistId);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: l10n.catchupManage,
              subtitle:
                  '${p.name} · ${approvedSet.length} of ${live.length} '
                  'categories · $approvedChs channels approved',
              onBack: onBack,
              actions: [
                NsButton(
                  label: l10n.catchupSelectAll,
                  icon: Icons.check_rounded,
                  variant: NsButtonVariant.ghost,
                  onPressed: () =>
                      state.recordingSelectAllCategories(playlistId),
                ),
                NsButton(
                  label: l10n.catchupClearAll,
                  icon: Icons.close_rounded,
                  variant: NsButtonVariant.ghost,
                  onPressed: () => _confirmClearAll(context, p, l10n),
                ),
              ],
            ),
            _GroupLabel(label: l10n.catchupGroupOptions),
            const SizedBox(height: 6),
            _OptionsCard(
              filter: r.filterCatchup,
              tvFrame: r.tvFrameEpg,
              catchupFilterSub: l10n.catchupFilterSub(l10n.navRecording),
              onToggleFilter: () => state.toggleRecordingFilter(playlistId),
              onToggleFrame: () => state.toggleRecordingTvFrame(playlistId),
            ),
            const SizedBox(height: 14),
            _GroupLabel(label: l10n.catchupGroupCategories),
            const SizedBox(height: 6),
            if (live.isEmpty)
              const _EmptyCategories()
            else
              _CategoriesCard(
                categories: live,
                approvedSet: approvedSet,
                playlist: p,
                approvedChFor: (gid) =>
                    (r.channels[gid] ?? const <String>[]).length,
                onOpen: onOpenCategory,
                onToggle: (gid) =>
                    state.toggleRecordingCategory(playlistId, gid),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    NsPlaylist p,
    AppLocalizations l10n,
  ) async {
    if (state.recordingFor(playlistId).categories.isEmpty) return;
    final r = await showNsConfirmDialog(
      context,
      title: l10n.catchupClearConfirmTitle,
      message: l10n.catchupClearConfirmMessage(p.name),
      confirmLabel: l10n.searchClear,
      isDanger: true,
    );
    if (r == NsConfirmResult.confirmed && context.mounted) {
      state.recordingClearAll(playlistId);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  .group-label — uppercase section heading (shared with Detail page).
// ═══════════════════════════════════════════════════════════════════════

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: NsColors.text3,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.3,
          height: 1,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Options card — two switch rows (`.card > .row[role=switch]`).
// ═══════════════════════════════════════════════════════════════════════

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({
    required this.filter,
    required this.tvFrame,
    required this.catchupFilterSub,
    required this.onToggleFilter,
    required this.onToggleFrame,
  });
  final bool filter;
  final bool tvFrame;
  final String catchupFilterSub;
  final VoidCallback onToggleFilter;
  final VoidCallback onToggleFrame;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
        boxShadow: NsShadow.s1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchRow(
            title: 'Catch-up filter',
            sub: catchupFilterSub,
            on: filter,
            onPressed: onToggleFilter,
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: NsColors.line,
          ),
          _SwitchRow(
            title: 'TV frame on EPG',
            sub:
                'Show a small TV frame around the live tile while '
                'browsing the EPG for this playlist.',
            on: tvFrame,
            onPressed: onToggleFrame,
          ),
        ],
      ),
    );
  }
}

// `.card > .row[role=switch]` — grid 1fr / auto / auto, 13/18 padding,
// ends with a value label and a 38×22 pill toggle.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.sub,
    required this.on,
    required this.onPressed,
  });
  final String title;
  final String sub;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: title,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        color: focused ? NsColors.surface2 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.06,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: NsColors.text3,
                      fontSize: 11,
                      height: 1.35,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              on ? 'On' : 'Off',
              style: const TextStyle(
                color: NsColors.text3,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 10),
            _ToggleSwitch(on: on),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  .toggle — 38×22 pill with 18 px knob (HTML). Same component used by
//  the rec-toggle inside each category row.
// ═══════════════════════════════════════════════════════════════════════

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: NsEase.ease,
      width: 32,
      height: 19,
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
            left: on ? 15 : 2,
            child: Container(
              width: 15,
              height: 15,
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
//  Categories card — `.card.rec-cat-card` containing stacked `.rec-row`s.
// ═══════════════════════════════════════════════════════════════════════

class _CategoriesCard extends StatelessWidget {
  const _CategoriesCard({
    required this.categories,
    required this.approvedSet,
    required this.playlist,
    required this.approvedChFor,
    required this.onOpen,
    required this.onToggle,
  });

  final List<NsPlaylistGroup> categories;
  final Set<String> approvedSet;
  final NsPlaylist playlist;
  final int Function(String gid) approvedChFor;
  final void Function(NsPlaylistGroup g) onOpen;
  final void Function(String gid) onToggle;

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
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _RecRow(
              group: categories[i],
              approved: approvedSet.contains(categories[i].id),
              total:
                  (playlist.channelsMap[categories[i].id] ?? const [])
                      .length,
              approvedHere: approvedChFor(categories[i].id),
              onOpen: () => onOpen(categories[i]),
              onToggle: () => onToggle(categories[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

// `.rec-row` — grid 1fr / auto, 4 padding, 12 radius, accent-tinted
// when approved. `.rec-main` fills the left cell (opens channels);
// `.rec-toggle` on the right toggles approval.
class _RecRow extends StatelessWidget {
  const _RecRow({
    required this.group,
    required this.approved,
    required this.total,
    required this.approvedHere,
    required this.onOpen,
    required this.onToggle,
  });

  final NsPlaylistGroup group;
  final bool approved;
  final int total;
  final int approvedHere;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: approved ? const Color(0x0A4DD0E1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _RecMain(
              group: group,
              approved: approved,
              total: total,
              approvedHere: approvedHere,
              onOpen: onOpen,
            ),
          ),
          const SizedBox(width: 8),
          // `.rec-toggle` — slightly smaller than the HTML 38×22.
          NsFocusable(
            onActivate: onToggle,
            semanticLabel: approved ? 'Disapprove' : 'Approve',
            builder: (context, focused) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _ToggleSwitch(on: approved),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecMain extends StatelessWidget {
  const _RecMain({
    required this.group,
    required this.approved,
    required this.total,
    required this.approvedHere,
    required this.onOpen,
  });
  final NsPlaylistGroup group;
  final bool approved;
  final int total;
  final int approvedHere;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // `.rec-main` — grid 32 / 1fr / 16 chev, padding 10/12.
    // The HTML marks the button aria-disabled when the category isn't
    // approved; we keep it focusable so the user can still open it —
    // the screen handler toasts if they're not allowed. We follow the
    // HTML's "approve first" rule by only opening when approved.
    return NsFocusable(
      canRequestFocus: approved,
      onActivate: approved ? onOpen : null,
      semanticLabel: approved
          ? 'Edit channels in ${group.alias ?? group.name}'
          : 'Approve to manage its channels',
      focusAccentRadius: 9,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: focused && approved
              ? NsColors.bg2
              : Colors.transparent,
          border: Border.all(
            color: focused && approved
                ? NsColors.line
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Opacity(
          opacity: approved ? 1.0 : 0.65,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: approved
                      ? NsColors.accentSoft
                      : NsColors.bg2,
                  border: Border.all(
                    color: approved
                        ? NsColors.accentLine
                        : NsColors.line,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  size: 13,
                  color:
                      approved ? NsColors.accent : NsColors.text2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.alias ?? group.name,
                      style: const TextStyle(
                        color: NsColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.06,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _MetaLine(
                      approved: approved,
                      total: total,
                      approvedHere: approvedHere,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 13,
                color: focused && approved
                    ? NsColors.accent
                    : NsColors.text4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.rec-main .lab .meta` — text-3 base, `<b>` promoted to text-2,
/// `<b>` accent-coloured when the row is approved (`.is-on`).
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.approved,
    required this.total,
    required this.approvedHere,
  });
  final bool approved;
  final int total;
  final int approvedHere;

  @override
  Widget build(BuildContext context) {
    final bColor = approved ? NsColors.accent : NsColors.text2;
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: NsColors.text3,
          fontSize: 11,
          height: 1.35,
          decoration: TextDecoration.none,
        ),
        children: approved
            ? [
                TextSpan(
                  text: '$approvedHere',
                  style: TextStyle(
                    color: bColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' of '),
                TextSpan(
                  text: '$total',
                  style: TextStyle(
                    color: bColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' channels approved'),
              ]
            : [
                TextSpan(text: '$total channels · not approved'),
              ],
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

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
