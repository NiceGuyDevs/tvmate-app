/// Shared chrome widgets for the new settings surface.
///
/// All focus handling uses [NsFocusable] — the HTML-faithful primitive that
/// imposes zero visual treatment of its own. Every element paints its own
/// HTML-accurate focus / hover / selected styling directly, so the result
/// is a 1:1 port of the `settings.html` reference (no team tinting, no
/// parallax slide, no focus scale, no accidental extra borders).
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

/// True when the new-settings header should render the Android variant:
/// no search field, no Ctrl+K palette button, and a HTML-style user chip
/// (avatar + name · role) on the right that opens the Account sub-page.
///
/// Windows / macOS / Linux / web keep the original search header exactly
/// as it was, including the Ctrl+K palette button.
bool get nsUseAndroidHeader => !kIsWeb && Platform.isAndroid;

/// The `.card` surface from settings.html (lines ~200 in the CSS block).
/// Rounded 14 px, subtle 1 px border, surface fill. Used for row groups
/// and the "Coming next" placeholder.
class NsCard extends StatelessWidget {
  const NsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NsColors.surface,
        border: Border.all(color: NsColors.line),
        borderRadius: BorderRadius.circular(NsRadius.card),
        boxShadow: NsShadow.s1,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Group heading — the small uppercase label above a [NsCard] in the right
/// pane. Mirrors the `.group > label` pattern in the HTML.
class NsGroupHeader extends StatelessWidget {
  const NsGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: d.groupLabelBottomGap),
      child: Text(
        label.toUpperCase(),
        style: NsType.groupLabel.copyWith(fontSize: d.groupLabelSize),
      ),
    );
  }
}

/// Eyebrow + title + description header at the top of every right-pane
/// view. Direct port of the HTML's `.pane-head` block (line 4946 of the
/// reference file).
class NsPaneHead extends StatelessWidget {
  const NsPaneHead({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.desc,
  });

  final String eyebrow;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: NsColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: NsColors.accentGlow,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            Text(
              eyebrow.toUpperCase(),
              style: NsType.eyebrow.copyWith(fontSize: d.eyebrowSize),
            ),
          ],
        ),
        SizedBox(height: d.eyebrowTitleGap),
        Text(
          title,
          style: NsType.paneTitle.copyWith(
            fontSize: d.paneTitleSize,
            height: d.paneTitleLh,
          ),
        ),
        SizedBox(height: d.titleDescGap),
        Text(
          desc,
          style: NsType.paneDesc.copyWith(
            fontSize: d.paneDescSize,
            height: d.paneDescLh,
          ),
        ),
      ],
    );
  }
}

/// Single button in the left rail — an icon, a label, and an optional meta
/// count on the right (used by "Playlists · 5" and "Favorites · 3").
///
/// Ports the HTML `.cat[role=tab]` rule (color / background / border on
/// hover, focus, selected). No scale, no slide, no extra chrome.
class NsRailTile extends StatelessWidget {
  const NsRailTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onActivate,
    this.meta,
    this.focusNode,
    this.autofocus = false,
    this.onKeyIntercept,
    this.canRequestFocus = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onActivate;
  final String? meta;
  final FocusNode? focusNode;
  final bool autofocus;

  /// When **false** (sub-page stack or expanded choice sheet), the rail does
  /// not participate in focus traversal so Left / directional moves cannot
  /// jump to categories from deeper UI.
  final bool canRequestFocus;
  final KeyEventResult? Function(FocusNode node, KeyEvent event)?
      onKeyIntercept;

  @override
  Widget build(BuildContext context) {
    return NsFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      canRequestFocus: canRequestFocus,
      onActivate: onActivate,
      onKeyIntercept: onKeyIntercept,
      semanticLabel: label,
      // Rail tiles opt IN to the focus accent bar (cyan, matches the
      // "Rail 1b" look in the approved focus_fix_preview.html). The
      // accent bar sits on the INSIDE left edge of the tile; the
      // selected tile's own cyan gradient bar is outside the tile
      // (::before at left: -12px), so they don't fight each other.
      focusAccentRadius: NsRadius.row, // matches the tile's 10 px radius
      builder: (context, focused) => _RailTileBody(
        icon: icon,
        label: label,
        meta: meta,
        selected: selected,
        focused: focused,
      ),
    );
  }
}

class _RailTileBody extends StatelessWidget {
  const _RailTileBody({
    required this.icon,
    required this.label,
    required this.meta,
    required this.selected,
    required this.focused,
  });

  final IconData icon;
  final String label;
  final String? meta;
  final bool selected;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    // Ports `.cat` (settings.html lines 254–283):
    //   base:        background: transparent;   color: var(--text-2);
    //   :hover:      background: var(--surface); color: var(--text);
    //   [aria-selected=true]: background: var(--surface-2); color: var(--text);
    //                         .ico { color: var(--accent); }
    //                         .meta { color: --accent; border: --accent-line;
    //                                 background: --accent-soft; }
    //
    // HTML also specifies `.cat:focus-visible { box-shadow: 0 0 0 2px
    // var(--accent-soft) inset }` but rendered in the browser the 14%-alpha
    // cyan band on top of a surface-2 fill is so subtle the user perceives
    // only the background change. Flutter's `Border` paints that same band
    // with a hard edge that reads as a visible frame — especially at
    // compact TV sizes. So we intentionally skip the inset and rely on the
    // bg change alone, which matches the HTML's actual visual feel.
    final d = NsDensity.of(context);
    final Color fill;
    final Color iconColor;
    final TextStyle labelStyle;
    // Ported `.cat` state rules (settings.html lines 254–283):
    //
    //   base     → bg: transparent,   text: text-2, ico: text-3
    //   :hover   → bg: surface,       text: text,   ico: text-2
    //   :focus   → (same as :hover on TV — no mouse to distinguish)
    //   selected → bg: surface-2,     text: text,   ico: accent
    //
    // The icon color on selected is base [NsColors.accent] — not
    // [NsColors.accent2] — to stay exactly on the HTML token. The
    // accent2 version was an earlier experiment that drifted off-spec.
    if (selected) {
      fill = NsColors.surface2;
      iconColor = NsColors.accent;
      labelStyle = NsType.railItemLabel.copyWith(
        color: NsColors.text,
        fontSize: d.railTileLabelSize,
      );
    } else if (focused) {
      fill = NsColors.surface;
      iconColor = NsColors.text2;
      labelStyle = NsType.railItemLabel.copyWith(
        color: NsColors.text,
        fontSize: d.railTileLabelSize,
      );
    } else {
      fill = Colors.transparent;
      iconColor = NsColors.text3;
      labelStyle = NsType.railItemLabelDim.copyWith(
        fontSize: d.railTileLabelSize,
      );
    }

    // Layout uses `mainAxisAlignment: spaceBetween` with two groups (left:
    // icon + label, right: meta pill) — this pushes the meta pill to the
    // right edge of the shared rail width WITHOUT using `Expanded`, which
    // doesn't compose with the outer [IntrinsicWidth] that sizes the whole
    // rail to its widest tile's natural width. The label is `Flexible` so
    // it still ellipsizes if the rail hits its max-width clamp.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          height: d.railTileHeight,
          margin: EdgeInsets.symmetric(
            horizontal: d.railTileHorizontalMargin,
            vertical: d.railTileVerticalMargin,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: d.railTileHorizontalPadding,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(NsRadius.row),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left group — icon + label, hugged to the left edge.
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: d.railTileIconSize,
                      color: iconColor,
                    ),
                    SizedBox(width: d.isCompact ? 10 : 12),
                    Flexible(
                      child: Text(
                        label,
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Right group — meta pill, hugged to the right edge.
              if (meta != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    // HTML `.cat .meta { background: surface; border: 1px
                    // solid line; }` on the base state; accent-soft +
                    // accent-line on selected. Previous code used bg2
                    // which read darker than the HTML intended.
                    color: selected
                        ? NsColors.accentSoft
                        : NsColors.surface,
                    border: Border.all(
                      color: selected
                          ? NsColors.accentLine
                          : NsColors.line,
                    ),
                    borderRadius: BorderRadius.circular(NsRadius.pill),
                  ),
                  child: Text(
                    meta!,
                    style: NsType.railItemMeta.copyWith(
                      // Selected → accent (HTML). Base → text-4 (from
                      // `railItemMeta`). No more accent2 override.
                      color: selected ? NsColors.accent : NsColors.text4,
                      fontSize: d.isCompact ? 10 : 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Selected left-side indicator — ports
        // `.cat[aria-selected=true]::before` (settings.html lines 284–290):
        //
        //   position: absolute; left: -12px; top: 8px; bottom: 8px; width: 4px;
        //   border-radius: 0 4px 4px 0;
        //   background: linear-gradient(180deg, var(--accent),
        //                               color-mix(var(--accent), white 25%));
        //   box-shadow: 0 0 16px var(--accent-glow);
        //
        // This is what makes the selected state read as "neon cyan" rather
        // than a flat baby-blue fill — the gradient bar plus its accent-glow
        // halo draw the eye immediately.
        if (selected) _SelectedRailIndicator(density: d),
      ],
    );
  }
}

/// The 4 px gradient bar + glow that marks the currently selected rail
/// category. Positioned off the left edge of the tile, vertically inset by
/// a density-proportional amount.
class _SelectedRailIndicator extends StatelessWidget {
  const _SelectedRailIndicator({required this.density});

  final NsDensity density;

  @override
  Widget build(BuildContext context) {
    // HTML positions at `left: -12px` relative to the .cat box. The .cat
    // has `.rail-scroll` padding of ~14 px at the outer left, so the bar
    // sits ~2 px inside the rail's edge. We reproduce by placing the bar
    // at the LEFT edge of our tile margin, painting outward to the left
    // to catch the same visual position.
    final verticalInset = density.isCompact ? 5.0 : 8.0;
    return Positioned(
      left: 0,
      top: density.railTileVerticalMargin + verticalInset,
      bottom: density.railTileVerticalMargin + verticalInset,
      child: IgnorePointer(
        child: Container(
          width: 4,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            // Gradient ported from HTML:
            //   background: linear-gradient(180deg, var(--accent),
            //                color-mix(in oklab, var(--accent), white 25%));
            // Top stop is the base accent (#4DD0E1); bottom stop is
            // accent lightened ~25 % toward white. Keeps the HTML's
            // softer cyan feel (no over-saturated accent2 shift).
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                NsColors.accent, // #4DD0E1 — base HTML accent, top stop
                Color(0xFF98E2EA), // accent lightened ~25 % (bottom stop)
              ],
            ),
            // Multi-layer glow for the neon bloom — the HTML specifies
            // a single 16 px blur at ~22 % alpha, but Flutter's flat
            // painting loses some of that bloom vs a browser so we
            // stack two accent-tinted shadows.
            boxShadow: const [
              BoxShadow(
                color: Color(0x664DD0E1), // accent at 40%
                blurRadius: 10,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Color(0x384DD0E1), // accent at ~22% (HTML value)
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header row inside the new settings surface. The shell's top menu sits
/// ABOVE this header (painted by [MainShellScreen]); this header stays
/// visually identical to the HTML's `.header` row.
///
/// Two layouts, selected by platform at call-site:
///
///   * **Desktop / Windows (default)** — `[brand + crumb]  [search input]
///     [palette btn · help · notif]`. [searchController] + [searchFocusNode]
///     are required; the Ctrl+K palette button routes focus into the search
///     field.
///   * **Android** — search and palette button are gone. The HTML's header
///     right-side action cluster is rendered instead: `[help · notif ·
///     user-chip]`. The user chip shows the account avatar + name/role pill
///     and opens the Account sub-page when activated.
class NsHeaderRow extends StatelessWidget {
  /// Desktop layout — header with search field + Ctrl+K palette button.
  const NsHeaderRow({
    super.key,
    required TextEditingController this.searchController,
    required FocusNode this.searchFocusNode,
    required this.crumb,
  })  : showSearch = true,
        onOpenAccount = null,
        accountInitials = null,
        accountName = null,
        accountRole = null;

  /// Android layout — no search, no palette button. HTML-faithful user chip
  /// on the right that opens the Account sub-page.
  const NsHeaderRow.android({
    super.key,
    required this.crumb,
    required this.onOpenAccount,
    required this.accountInitials,
    required this.accountName,
    required this.accountRole,
  })  : showSearch = false,
        searchController = null,
        searchFocusNode = null;

  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final String crumb;
  final bool showSearch;

  /// Android-only — tap callback for the user chip. When this is non-null
  /// the chip is rendered focusable and activated; when null the chip is
  /// painted as a read-only display.
  final VoidCallback? onOpenAccount;

  /// Android-only — avatar text (typically 2 uppercase initials from the
  /// account display name, or `'G'` for guest).
  final String? accountInitials;

  /// Android-only — main label text for the user chip (e.g. `John D.`).
  final String? accountName;

  /// Android-only — short role text appended after `·` (e.g. `Pro`,
  /// `Trial`, `Guest`). Pass `null` to omit.
  final String? accountRole;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return Container(
      height: d.headerHeight,
      padding: EdgeInsets.symmetric(horizontal: d.isCompact ? 14 : 20),
      decoration: const BoxDecoration(
        color: NsColors.bg2,
        border: Border(bottom: BorderSide(color: NsColors.line)),
      ),
      child: Row(
        children: [
          // LEFT group — brand + crumb — grabs ALL leftover width so the
          // action cluster on the right is pinned flush against the
          // header's right padding, exactly like the HTML's 3-column
          // grid (`brand | search | head-actions`).
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                const _BrandLogo(),
                const SizedBox(width: 10),
                Text(
                  'TVMate',
                  style: NsType.brandName.copyWith(
                    fontSize: d.isCompact ? 13 : 14.5,
                  ),
                ),
                if (crumb.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    '›',
                    style: NsType.crumbStep.copyWith(color: NsColors.text4),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      crumb,
                      style: NsType.crumbCurrent.copyWith(
                        fontSize: d.isCompact ? 12 : 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
                // On the desktop search variant we want the search field
                // to flex into this space; on Android we just want the
                // brand/crumb left-aligned and the remaining width to be
                // a visual gap between them and the right cluster.
                if (showSearch) ...[
                  SizedBox(width: d.isCompact ? 10 : 18),
                  Expanded(
                    child: _SearchField(
                      controller: searchController!,
                      node: searchFocusNode!,
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
            ),
          ),
          // RIGHT group — head actions. Pinned to the right edge.
          SizedBox(width: d.isCompact ? 8 : 12),
          if (showSearch) ...[
            _PaletteButton(
              onPressed: () {
                final n = searchFocusNode!;
                if (n.canRequestFocus) n.requestFocus();
              },
            ),
            const SizedBox(width: 6),
            const _HeaderIconButton(icon: NsIconSpec.help),
            const SizedBox(width: 2),
            const _HeaderIconButton(icon: NsIconSpec.notifications),
          ] else ...[
            const _HeaderIconButton(icon: NsIconSpec.help),
            const SizedBox(width: 6),
            const _HeaderIconButton(
              icon: NsIconSpec.notifications,
              showBadge: true,
            ),
            const SizedBox(width: 6),
            _UserChip(
              initials: accountInitials ?? 'G',
              name: accountName ?? 'Guest',
              role: accountRole,
              onPressed: onOpenAccount,
            ),
          ],
        ],
      ),
    );
  }
}

enum NsIconSpec { help, notifications }

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    this.showBadge = false,
    this.onPressed,
  });

  final NsIconSpec icon;

  /// HTML's `.badge-dot` — tiny cyan accent pip at top-right of the bell,
  /// ringed with a 2 px band in the header's `--bg` to separate it from
  /// the icon glyph. Only the notifications button uses this in the
  /// reference.
  final bool showBadge;

  /// Optional tap callback. Kept `null` while the real help / notifications
  /// surfaces ship later — the button still focuses and activates visually
  /// so D-pad exploration feels alive.
  final VoidCallback? onPressed;

  IconData get _iconData => switch (icon) {
        NsIconSpec.help => Icons.help_outline_rounded,
        NsIconSpec.notifications => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context) {
    // Ports `.icon-btn` (settings.html lines 178–196):
    //   base:           background: transparent;    border: 1px solid transparent;
    //                   color: var(--text-2);
    //   :hover:         background: var(--surface); border-color: var(--line);
    //                   color: var(--text);
    //   :focus-visible: box-shadow: 0 0 0 3px var(--accent-soft);
    //                   border-color: var(--accent-line);
    //
    // On TV the states merge: focused == hover + focus-visible combined —
    // surface fill, accent-line border, AND the 3 px outer accent-soft ring.
    return NsFocusable(
      onActivate: onPressed ?? () {},
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? NsColors.surface : Colors.transparent,
            border: Border.all(
              color: focused ? NsColors.accentLine : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: focused
                ? const [
                    BoxShadow(
                      color: NsColors.accentSoft,
                      spreadRadius: 3,
                      blurRadius: 0,
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  _iconData,
                  size: 16,
                  color: focused ? NsColors.text : NsColors.text2,
                ),
              ),
              if (showBadge)
                // HTML `.icon-btn .badge-dot`:
                //   top: 7px; right: 7px; width: 7px; height: 7px;
                //   background: var(--accent);
                //   box-shadow: 0 0 0 2px var(--bg);
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NsColors.accent,
                      border: Border.all(color: NsColors.bg, width: 2),
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

/// HTML `.user-chip` port (settings.html lines ~197–219):
///
///   display: inline-flex; align-items: center; gap: 8px;
///   padding: 4px 10px 4px 4px;
///   background: var(--surface); border: 1px solid var(--line);
///   border-radius: 999px;
///
///   .avatar { width/height: 26px; border-radius: 50%;
///             background: linear-gradient(135deg, #FBBF24, #F472B6);
///             color: #0B1220; font: 700 11px; }
///
/// Tap opens the Account sub-page — same entry point as the rail Account
/// tile — so the HTML's "click the avatar to see your account" flow is
/// preserved 1:1.
class _UserChip extends StatelessWidget {
  const _UserChip({
    required this.initials,
    required this.name,
    required this.role,
    required this.onPressed,
  });

  final String initials;
  final String name;
  final String? role;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = (role == null || role!.isEmpty) ? name : '$name · $role';
    return NsFocusable(
      onActivate: onPressed ?? () {},
      semanticLabel: 'Account: $label',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar — HTML uses a yellow→pink gradient here (distinct from
            // the Account hero card's cyan ring), so ports that gradient
            // literally. The inner 1 px white-25 ring the CSS uses
            // (`inset 0 0 0 1px rgba(255,255,255,.25)`) is reproduced with
            // a 1 px white-alpha border — visually identical at this size.
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFBBF24), // amber
                    Color(0xFFF472B6), // pink
                  ],
                ),
                border: Border.all(
                  color: const Color(0x40FFFFFF),
                  width: 1,
                ),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF0B1220),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: focused ? NsColors.text : NsColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NsColors.accent, Color(0xFF6366F1)],
        ),
        boxShadow: const [
          BoxShadow(
            color: NsColors.accentGlow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.node});
  final TextEditingController controller;
  final FocusNode node;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.node.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.node.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    final now = widget.node.hasFocus;
    if (_focused != now) setState(() => _focused = now);
  }

  @override
  Widget build(BuildContext context) {
    // Ports `.search input` (settings.html lines 141–156):
    //   base:    background: var(--surface);  border: 1px solid var(--line);
    //   :focus:  outline: none;
    //            border-color: var(--accent-line);
    //            background: var(--surface-2);
    //            box-shadow: 0 0 0 4px var(--accent-soft);
    // Transition .15s var(--ease) on border, background and box-shadow.
    //
    // Width flexes with the header row (Expanded ancestor) — same behaviour
    // as the HTML's middle grid column which expands to fill available
    // space between the brand on the left and the actions on the right.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: NsEase.ease,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _focused ? NsColors.surface2 : NsColors.surface,
        border: Border.all(
          color: _focused ? NsColors.accentLine : NsColors.line,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: _focused
            ? const [
                // 4 px outer accent-soft ring, solid band, no blur.
                BoxShadow(
                  color: NsColors.accentSoft,
                  spreadRadius: 4,
                  blurRadius: 0,
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: NsColors.text3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.node,
              style: NsType.rowValue.copyWith(color: NsColors.text),
              cursorColor: NsColors.accent,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search settings, playlists, channels…',
                hintStyle: TextStyle(color: NsColors.text3, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Styled as `.btn` (settings.html lines 384–394):
    //   base:    background: var(--surface);  border: 1px solid var(--line);
    //   :hover:  background: var(--surface-2); border-color: var(--line-2);
    //
    // No outer ring and no accent-colored border — on TV, focus merges with
    // hover and the only visual shift is bg + border darkening.
    return NsFocusable(
      onActivate: onPressed,
      semanticLabel: 'Open command palette',
      builder: (context, focused) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: NsEase.ease,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: focused ? NsColors.surface2 : NsColors.surface,
          border: Border.all(
            color: focused ? NsColors.line2 : NsColors.line,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 14,
              color: focused ? NsColors.text : NsColors.text2,
            ),
            const SizedBox(width: 8),
            Text(
              'Ctrl+K',
              style: NsType.rowValue.copyWith(
                color: focused ? NsColors.text : NsColors.text2,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
