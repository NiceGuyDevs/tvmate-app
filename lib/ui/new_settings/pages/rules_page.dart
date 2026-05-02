/// Restricted rules — same Ns layout as the HTML port; data from
/// [parentalControlStore] (remove-only rows).
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../data/library_controller.dart';
import '../../../data/live_favorite_groups_store.dart';
import '../../../data/parental_control_store.dart';
import '../../../data/xtream_catalog_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/parental_rule_labels.dart';
import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';

class NsRulesPage extends StatelessWidget {
  const NsRulesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        parentalControlStore,
        libraryController,
        xtreamCatalogRepository,
        LiveFavoriteGroupsStore.instance,
      ]),
      builder: (context, _) {
        final count = parentalControlStore.granularLockRuleCount;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Restricted rules',
              subtitle:
                  'Per-category and per-channel restrictions. '
                  'Hidden items require the PIN to view.',
              onBack: onBack,
              actions: [
                NsButton(
                  label: 'New rule',
                  icon: Icons.add_rounded,
                  variant: NsButtonVariant.primary,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'To add a lock, use a channel, category, or title '
                          'menu in Live TV, Movies, or Series.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            if (count == 0)
              const _EmptyState()
            else
              _RulesCard(),
          ],
        );
      },
    );
  }
}

class _RulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = _buildStoreRuleRows(context, l10n);
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(11),
        boxShadow: NsShadow.s1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: NsColors.line,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

List<Widget> _buildStoreRuleRows(
  BuildContext context,
  AppLocalizations l10n,
) {
  final out = <Widget>[];

  void addRow(String title, String scopeLine, Future<void> Function() onDelete) {
    out.add(
      _StoreRuleRow(
        title: title,
        scopeLine: scopeLine,
        onDelete: onDelete,
      ),
    );
  }

  for (final id in parentalControlStore.lockedFavoriteGroupIdsSorted) {
    addRow(
      formatFavoriteGroupRuleLabel(l10n, id),
      'Live TV',
      () => parentalControlStore.removeLockedFavoriteGroup(id),
    );
  }
  for (final e in parentalControlStore.lockedLiveCategoriesByPlaylist.entries) {
    final pid = e.key;
    for (final id in e.value) {
      addRow(
        formatLiveCategoryRuleLabel(l10n, pid, id),
        'Live TV',
        () => parentalControlStore.removeLockedLiveCategory(
          pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
          id,
        ),
      );
    }
  }
  for (final e in parentalControlStore.lockedLiveChannelsByPlaylist.entries) {
    final pid = e.key;
    for (final id in e.value) {
      addRow(
        formatLiveChannelRuleLabel(l10n, pid, id),
        'Live TV',
        () => parentalControlStore.removeLockedLiveChannel(
          pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
          id,
        ),
      );
    }
  }
  for (final e in parentalControlStore.lockedVodCategoriesByPlaylist.entries) {
    final pid = e.key;
    for (final id in e.value) {
      addRow(
        formatVodCategoryRuleLabel(l10n, pid, id),
        'Movies',
        () => parentalControlStore.removeLockedVodCategory(
          pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
          id,
        ),
      );
    }
  }
  for (final e in parentalControlStore.lockedMovieIdsByPlaylist.entries) {
    final pid = e.key;
    for (final id in e.value) {
      addRow(
        formatMovieRuleLabel(l10n, pid, id),
        'Movies',
        () => parentalControlStore.removeLockedMovie(
          pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
          id,
        ),
      );
    }
  }
  for (final e in parentalControlStore.lockedSeriesCategoriesByPlaylist.entries) {
    final pid = e.key;
    for (final id in e.value) {
      addRow(
        formatSeriesCategoryRuleLabel(l10n, pid, id),
        'Series',
        () => parentalControlStore.removeLockedSeriesCategory(
          pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
          id,
        ),
      );
    }
  }
  for (final e in parentalControlStore.lockedSeriesIdsByPlaylist.entries) {
    final pid = e.key;
    for (final id in e.value) {
      addRow(
        formatSeriesRuleLabel(l10n, pid, id),
        'Series',
        () => parentalControlStore.removeLockedSeries(
          pid == ParentalControlStore.kDemoPlaylistId ? null : pid,
          id,
        ),
      );
    }
  }

  return out;
}

Future<void> _removeRuleAndNotify(
  BuildContext context,
  AppLocalizations l10n,
  Future<void> Function() onDelete,
) async {
  await onDelete();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.parentalUnlocked)),
    );
  }
}

class _StoreRuleRow extends StatelessWidget {
  const _StoreRuleRow({
    required this.title,
    required this.scopeLine,
    required this.onDelete,
  });

  final String title;
  final String scopeLine;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  scopeLine,
                  style: const TextStyle(
                    color: NsColors.text3,
                    fontSize: 11,
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Locked',
            style: TextStyle(
              color: NsColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 10),
          const _Toggle(on: true),
          const SizedBox(width: 8),
          _TrashBtn(
            onPressed: () {
              unawaited(_removeRuleAndNotify(context, l10n, onDelete));
            },
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: AnimatedContainer(
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
      ),
    );
  }
}

class _TrashBtn extends StatelessWidget {
  const _TrashBtn({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: 'Delete rule',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: focused ? NsColors.dangerSoft : Colors.transparent,
          border: Border.all(
            color: focused ? NsColors.danger : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          size: 13,
          color: NsColors.danger,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
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
              Icons.lock_outline_rounded,
              size: 22,
              color: NsColors.text3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No rules yet',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use Live TV, Movies, or Series to add a lock, or try '
            '“New rule” for a hint.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NsColors.text3,
              fontSize: 11.5,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
