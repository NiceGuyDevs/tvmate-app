/// Favorites landing — 1:1 port of `renderFavoritesPage()` in
/// settings.html (line 6874).
///
/// A card grid of cross-playlist favorite groups. Each `.fav-card`:
///   * 56×56 gradient cover with initials + `#sortOrder` sash pill.
///   * Body: 13 px name + monospace `N channels` meta + preview line
///     (up to 3 channel names · separators · `+N` overflow).
///   * Right-side "Edit" chip on the right (uppercase pill).
/// Trailing `.fav-card.add` dashed-border tile for creating a new
/// group. On empty state, a centred illustration + prompt.
///
/// Sizing note: compact TV density (HTML desktop is 64 px cover →
/// 56 px here, 15 px name → 13 px, 260 min tile → 240 min).
library;

import 'package:flutter/material.dart';

import '../new_settings_data.dart';
import '../new_settings_density.dart';
import '../new_settings_state.dart';
import '../new_settings_theme.dart';
import '../widgets/ns_button.dart';
import '../widgets/ns_focusable.dart';
import '../widgets/ns_sub_page_head.dart';
import '../widgets/ns_text_prompt_dialog.dart';

class NsFavoritesPage extends StatelessWidget {
  const NsFavoritesPage({
    super.key,
    required this.state,
    required this.onOpenEditor,
    this.onBack,
    this.firstContentFocus,
  });

  final NewSettingsState state;
  final VoidCallback? onBack;

  /// Owned by [NewSettingsScreen] — first fav card, or empty-state CTA.
  final FocusNode? firstContentFocus;

  /// Invoked after a card is picked (or the "New favorite" tile adds
  /// a group). The caller is expected to reset the editor state and
  /// push the editor sub-page.
  final void Function(NsFavGroup group) onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final groups = state.favGroupsSorted;
        final total = state.favTotalRefs;
        final subtitle = groups.isEmpty
            ? 'Build your first cross-playlist favorite list. '
                'Channels can come from any playlist.'
            : '${groups.length} list${groups.length == 1 ? '' : 's'} '
                '· $total channel${total == 1 ? '' : 's'} total';

        return ListView(
          padding: EdgeInsets.fromLTRB(
            d.listHorizontalPadding,
            d.listTopPadding,
            d.listHorizontalPadding,
            d.listBottomPadding,
          ),
          children: [
            NsSubPageHead(
              title: 'Favorites',
              subtitle: subtitle,
              onBack: onBack,
              actions: [
                NsButton(
                  label: 'New favorite',
                  icon: Icons.add_rounded,
                  variant: NsButtonVariant.primary,
                  onPressed: () => _createAndOpen(context),
                ),
              ],
            ),
            if (groups.isEmpty)
              _EmptyState(
                onNew: () => _createAndOpen(context),
                firstContentFocus: firstContentFocus,
              )
            else
              _CardGrid(
                groups: groups,
                resolver: state.favResolve,
                onOpen: onOpenEditor,
                onNew: () => _createAndOpen(context),
                firstGroupFocus: firstContentFocus,
              ),
          ],
        );
      },
    );
  }

  Future<void> _createAndOpen(BuildContext context) async {
    final name = await showNsTextPromptDialog(
      context,
      title: 'Name this favorite list',
      initial: 'Favorite ${state.favGroupsCount + 1}',
      confirmLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty) return;
    final g = await state.createFavGroup(name.trim());
    if (g == null) return;
    onOpenEditor(g);
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  `.fav-card-grid` — `repeat(auto-fill, minmax(260, 1fr))`. TV uses
//  240 min + 8 gap (vs HTML 260 + 12).
// ═══════════════════════════════════════════════════════════════════════

class _CardGrid extends StatefulWidget {
  const _CardGrid({
    required this.groups,
    required this.resolver,
    required this.onOpen,
    required this.onNew,
    this.firstGroupFocus,
  });

  final List<NsFavGroup> groups;
  final NsFavResolved? Function(NsFavRef ref) resolver;
  final void Function(NsFavGroup group) onOpen;
  final VoidCallback onNew;
  final FocusNode? firstGroupFocus;

  @override
  State<_CardGrid> createState() => _CardGridState();
}

class _CardGridState extends State<_CardGrid> {
  final Map<String, FocusNode> _byId = {};
  FocusNode? _addFocus;

  @override
  void dispose() {
    for (final n in _byId.values) {
      n.dispose();
    }
    _addFocus?.dispose();
    super.dispose();
  }

  void _sync(List<NsFavGroup> groups) {
    final want = {for (final g in groups) g.id};
    for (final id in _byId.keys.toList()) {
      if (!want.contains(id)) {
        _byId.remove(id)?.dispose();
      }
    }
    for (var k = 0; k < groups.length; k++) {
      if (k == 0 && widget.firstGroupFocus != null) {
        continue;
      }
      final g = groups[k];
      _byId.putIfAbsent(
        g.id,
        () => FocusNode(debugLabel: 'ns:fav:card:${g.id}'),
      );
    }
  }

  FocusNode _nodeForIndex(int i, NsFavGroup g) {
    if (i == 0 && widget.firstGroupFocus != null) {
      return widget.firstGroupFocus!;
    }
    return _byId[g.id]!;
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    _sync(groups);
    _addFocus ??= FocusNode(debugLabel: 'ns:fav:add');
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTile = 240.0;
        const gap = 8.0;
        final cols = ((constraints.maxWidth + gap) / (minTile + gap))
            .floor()
            .clamp(1, 4);
        final tileW =
            (constraints.maxWidth - gap * (cols - 1)) / cols;
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < groups.length; i++)
                SizedBox(
                  width: tileW,
                  child: _FavCard(
                    group: groups[i],
                    resolver: widget.resolver,
                    onPressed: () => widget.onOpen(groups[i]),
                    focusNode: _nodeForIndex(i, groups[i]),
                    focusLeftNeighbor: i > 0
                        ? _nodeForIndex(i - 1, groups[i - 1])
                        : null,
                    focusRightNeighbor: i + 1 < groups.length
                        ? _nodeForIndex(i + 1, groups[i + 1])
                        : _addFocus,
                  ),
                ),
              SizedBox(
                width: tileW,
                child: _AddCard(
                  onPressed: widget.onNew,
                  focusNode: _addFocus!,
                  focusLeftNeighbor: groups.isEmpty
                      ? null
                      : _nodeForIndex(
                          groups.length - 1,
                          groups.last,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  `.fav-card` — grid 64 / 1fr / auto, 14 padding. TV compact: 56 /
//  1fr / auto, 10 padding.
// ═══════════════════════════════════════════════════════════════════════

class _FavCard extends StatelessWidget {
  const _FavCard({
    required this.group,
    required this.resolver,
    required this.onPressed,
    required this.focusNode,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
  });
  final NsFavGroup group;
  final NsFavResolved? Function(NsFavRef ref) resolver;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;

  @override
  Widget build(BuildContext context) {
    final count = group.refs.length;
    final previews = <NsFavResolved>[];
    for (final r in group.refs.take(3)) {
      final res = resolver(r);
      if (res != null) previews.add(res);
    }

    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: group.name,
      focusAccentRadius: NsRadius.card,
      focusLeftNeighbor: focusLeftNeighbor,
      focusRightNeighbor: focusRightNeighbor,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.accentLine : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(NsRadius.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Cover(
              color: _hex(group.color),
              initials: nsFavInitials(group.name),
              sortOrder: group.sortOrder,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: NsColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.13, // -0.01em
                      height: 1.15,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count channel${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: NsColors.text3,
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Preview(previews: previews, overflow: count - previews.length),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _EditChip(focused: focused),
          ],
        ),
      ),
    );
  }
}

/// 56×56 gradient cover (mix of the user-picked color and a 50%
/// darker shade) with initials + a `#N` sash pill in the bottom-right.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.color,
    required this.initials,
    required this.sortOrder,
  });
  final Color color;
  final String initials;
  final int sortOrder;

  @override
  Widget build(BuildContext context) {
    // HTML mix: `color-mix(in srgb, var(--fav-color) 50%, #000 50%)`
    final dark = Color.fromRGBO(
      (color.r * 255 * 0.5).round(),
      (color.g * 255 * 0.5).round(),
      (color.b * 255 * 0.5).round(),
      1,
    );
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.643, -0.766), // ≈ 140deg
          end: const Alignment(0.643, 0.766),
          colors: [color, dark],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(
              (color.r * 255).round(),
              (color.g * 255).round(),
              (color.b * 255).round(),
              0.35,
            ),
            offset: const Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.36,
                height: 1,
                decoration: TextDecoration.none,
                shadows: [
                  Shadow(
                    color: Color(0x59000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0x73000000), // rgba(0,0,0,.45)
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '#$sortOrder',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 0.3,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.previews, required this.overflow});
  final List<NsFavResolved> previews;
  final int overflow;

  @override
  Widget build(BuildContext context) {
    if (previews.isEmpty) {
      return const Text(
        'No channels yet',
        style: TextStyle(
          color: NsColors.text4,
          fontSize: 10.5,
          fontStyle: FontStyle.italic,
          height: 1.2,
          decoration: TextDecoration.none,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final spans = <InlineSpan>[];
    for (var i = 0; i < previews.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(
          text: '  ·  ',
          style: TextStyle(color: NsColors.text4),
        ));
      }
      spans.add(TextSpan(text: previews[i].channel.alias ?? previews[i].channel.name));
    }
    if (overflow > 0) {
      spans.add(TextSpan(
        text: '  +$overflow',
        style: const TextStyle(
          color: NsColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: NsColors.text3,
          fontSize: 10.5,
          height: 1.25,
          decoration: TextDecoration.none,
        ),
        children: spans,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// `.fav-card-edit` — upper-case 10.5 px chip. Switches to accent
/// palette when the parent card is focused.
class _EditChip extends StatelessWidget {
  const _EditChip({required this.focused});
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: focused ? NsColors.accentSoft : NsColors.bg2,
        border: Border.all(
          color: focused ? NsColors.accentLine : NsColors.line,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_rounded,
            size: 11,
            color: focused ? NsColors.accent : NsColors.text3,
          ),
          const SizedBox(width: 4),
          Text(
            'EDIT',
            style: TextStyle(
              color: focused ? NsColors.accent : NsColors.text3,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.fav-card.add` — dashed-border card with a `+` cover + "New
/// favorite" body text.
class _AddCard extends StatelessWidget {
  const _AddCard({
    required this.onPressed,
    required this.focusNode,
    this.focusLeftNeighbor,
  });
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final FocusNode? focusLeftNeighbor;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      onActivate: onPressed,
      semanticLabel: 'New favorite',
      focusLeftNeighbor: focusLeftNeighbor,
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: focused ? NsColors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(NsRadius.card),
          border: Border.all(
            color: focused ? NsColors.accentLine : NsColors.line,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: NsColors.accentSoft,
                border: Border.all(color: NsColors.accentLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: NsColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New favorite',
                    style: TextStyle(
                      color: NsColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.13,
                      height: 1.15,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Cross-playlist list',
                    style: TextStyle(
                      color: NsColors.text3,
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      height: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew, this.firstContentFocus});
  final VoidCallback onNew;
  final FocusNode? firstContentFocus;

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
              Icons.star_rounded,
              size: 22,
              color: NsColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No favorites yet',
            style: TextStyle(
              color: NsColors.text2,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Click "New favorite" to start a list. You can pick '
              'channels from any playlist — Sports HD, Family Pack, '
              'UK Free-to-Air, anything.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NsColors.text3,
                fontSize: 11.5,
                height: 1.45,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          NsButton(
            focusNode: firstContentFocus,
            label: 'New favorite',
            icon: Icons.add_rounded,
            variant: NsButtonVariant.primary,
            onPressed: onNew,
          ),
        ],
      ),
    );
  }
}

Color _hex(String hex) {
  final s = hex.replaceFirst('#', '');
  final v = int.parse(s, radix: 16);
  if (s.length == 6) return Color(0xFF000000 | v);
  return Color(v);
}
