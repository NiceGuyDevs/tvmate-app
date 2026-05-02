/// Shown on the right pane for:
///   * every sub-page that has not been ported yet (phase 3+ work),
///   * every landing-page category (playlists, favorites) until phase 6 / 7.
///
/// Kept intentionally simple — an eyebrow / title / description header and
/// a single card saying "Coming next". This lets the rail, focus, breadcrumb
/// and navigation rules be tested against all 6 categories during phase 1,
/// while only Playback exercises the full row-rendering path end-to-end.
library;

import 'package:flutter/material.dart';

import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_chrome.dart';

class NsComingNextPage extends StatelessWidget {
  const NsComingNextPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.desc,
    this.hint,
  });

  final String eyebrow;
  final String title;
  final String desc;

  /// Optional extra note under the card (e.g. "Ported in phase 6").
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        d.listHorizontalPadding,
        d.listTopPadding,
        d.listHorizontalPadding,
        d.listBottomPadding,
      ),
      children: [
        NsPaneHead(eyebrow: eyebrow, title: title, desc: desc),
        SizedBox(height: d.paneHeadBottomGap + 8),
        NsCard(
          padding: EdgeInsets.all(d.isCompact ? 18 : 28),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: NsColors.accentSoft,
                  border: Border.all(color: NsColors.accentLine),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: NsColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Coming next',
                      style: NsType.rowTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This surface is still being ported from the HTML reference. '
                      'Phase 1 covers the shell, the left rail and the Playback '
                      'category. The rest of the categories and sub-pages land in '
                      'the following phases, one at a time.',
                      style: NsType.rowSub,
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        hint!,
                        style: NsType.rowSub.copyWith(color: NsColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
