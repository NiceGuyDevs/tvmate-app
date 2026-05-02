/// Renders a single top-level category into the right detail pane.
///
/// Walks the category's `groups` and, for each group, emits a [NsGroupHeader]
/// above a [NsCard] containing the rows. Landing-page categories (playlists,
/// favorites) are handled by the screen — they route to the phase-6 / phase-7
/// sub-pages directly and never reach this widget.
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../widgets/ns_chrome.dart';
import '../widgets/ns_settings_row.dart';

class NsCategoryPage extends StatelessWidget {
  const NsCategoryPage({
    super.key,
    required this.category,
    required this.state,
    required this.onOpenPage,
    required     this.onAction,
    this.firstRowFocusNode,
  });

  final NsCategory category;
  final NewSettingsState state;
  final void Function(String pageId) onOpenPage;
  final void Function(String actionId) onAction;

  /// External focus node bound to this category's **first** row so the
  /// rail can focus the first option when the tile is activated (e.g.
  /// `Performance mode` in Playback). Passed through to [NsSettingsRow]
  /// for the first row only; nil on all other rows.
  final FocusNode? firstRowFocusNode;

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
        NsPaneHead(
          eyebrow: category.eyebrow,
          title: category.title,
          desc: category.desc,
        ),
        SizedBox(height: d.paneHeadBottomGap),
        for (int g = 0; g < category.groups.length; g++) ...[
          if (category.groups[g].label != null)
            NsGroupHeader(label: category.groups[g].label!),
          NsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < category.groups[g].rows.length; i++)
                  _rowWithTrimmedDivider(
                    context: context,
                    row: category.groups[g].rows[i],
                    isLast: i == category.groups[g].rows.length - 1,
                    // Attach the external focus node to the very first
                    // row of the first group so rail activation lands
                    // on the category's first option.
                    focusNode: (g == 0 && i == 0) ? firstRowFocusNode : null,
                  ),
              ],
            ),
          ),
          if (g != category.groups.length - 1)
            SizedBox(height: d.interGroupGap),
        ],
      ],
    );
  }

  Widget _rowWithTrimmedDivider({
    required BuildContext context,
    required NsRow row,
    required bool isLast,
    FocusNode? focusNode,
  }) {
    final rowKey = '${category.id}:${row.id}';
    final isExpanded = state.expanded == rowKey;

    // The row renderer itself adds a bottom divider; hide it for the last
    // row by wrapping in a clipped container so the card's own rounded
    // corners aren't interrupted.
    final child = NsSettingsRow(
      row: row,
      state: state,
      categoryId: category.id,
      isExpanded: isExpanded,
      onToggleExpanded: () => state.toggleExpanded(rowKey),
      onOpenPage: onOpenPage,
      onAction: onAction,
      focusNode: focusNode,
    );

    if (!isLast) return child;
    // Drop the trailing divider on the last row by wrapping in a Container
    // that clips the bottom 1 px border the row shell draws.
    return ClipRect(
      clipper: _TrimBottomBorderClipper(),
      child: child,
    );
  }
}

class _TrimBottomBorderClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height - 1);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
