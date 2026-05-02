/// Shared sub-page header used across every sub-page in the new settings
/// surface (Top menu items, PIN, Appearance, Clock, etc.).
///
/// Ports `.subpage-head` from `settings.html` (lines 356–381):
///
///   .subpage-head {
///     display: grid;
///     grid-template-columns: auto 1fr auto;
///     align-items: center;
///     gap: 14px;
///     max-width: 880px;
///     margin-bottom: 22px;
///   }
///   .subpage-head.no-back { grid-template-columns: 1fr auto; }
///
/// The three slots are: back button | title column | head-actions row.
/// `noBack = true` drops the back button (used for landing-style sub-pages
/// that are the first screen their category renders).
library;

import 'package:flutter/material.dart';

import '../new_settings_density.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

class NsSubPageHead extends StatelessWidget {
  const NsSubPageHead({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.autofocusBack = false,
  });

  final String title;
  final String? subtitle;

  /// Tap / Select handler for the back button. When null, the back button
  /// is not rendered (landing-style "no-back" sub-pages).
  final VoidCallback? onBack;

  /// Buttons rendered at the end of the head row (e.g. "+ New rule").
  final List<Widget> actions;

  /// Whether the back button grabs initial focus. Defaults to **false**
  /// so each sub-page can autofocus its first meaningful content item
  /// instead (per the new-settings navigation rulebook: "never land on
  /// Back / header — always on the first actionable item").
  final bool autofocusBack;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    final hasBack = onBack != null;
    return Padding(
      padding: EdgeInsets.only(bottom: d.subPageHeadBottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasBack) ...[
            _BackButton(onPressed: onBack!, autofocus: autofocusBack),
            SizedBox(width: d.sp(12)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: NsType.paneTitle.copyWith(
                    fontSize: d.subPageTitleSize,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: d.sp(3)),
                  Text(
                    subtitle!,
                    style: NsType.paneDesc.copyWith(
                      fontSize: d.subPageSubtitleSize,
                      color: NsColors.text2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(width: d.sp(12)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) SizedBox(width: d.sp(8)),
                  actions[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Auto-focus the first focusable descendant of [child] after the first
/// frame. Intended for sub-page bodies so the user lands on the first
/// actionable item (card / row / tab / button) instead of the back
/// button — matches rule 6 of the new-settings navigation rulebook.
///
/// Usage: wrap the sub-page's main content (anything below
/// [NsSubPageHead]) so traversal starts from the first focusable node
/// inside, not from the back button.
class NsAutoFocusFirst extends StatefulWidget {
  const NsAutoFocusFirst({
    super.key,
    required this.child,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 1),
  });

  final Widget child;

  /// When false, the helper becomes a pass-through. Sub-pages that own
  /// their focus logic (e.g. Account's Profile-tab autofocus) use this.
  final bool enabled;

  /// Millisecond delay before the focus request. One extra frame is
  /// enough for nested scrollers to settle, but pages with heavy first
  /// builds can override with a larger value.
  final Duration delay;

  @override
  State<NsAutoFocusFirst> createState() => _NsAutoFocusFirstState();
}

class _NsAutoFocusFirstState extends State<NsAutoFocusFirst> {
  bool _focused = false;

  /// Our own scope node — limits the first-focusable walk to this
  /// widget's subtree (e.g. the sub-page body, excluding the header
  /// back button that lives above it in the widget tree).
  late final FocusScopeNode _scopeNode;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(
      canRequestFocus: false,
      debugLabel: 'NsAutoFocusFirst',
    );
    if (!widget.enabled) return;
    // Defer so the widget tree is mounted and traversal has candidates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focused) return;
      Future.delayed(widget.delay, _tryFocusFirst);
    });
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  /// Walk the [FocusNode] tree rooted at our owned [_scopeNode] and
  /// request focus on the first node that can take it.
  void _tryFocusFirst() {
    if (!mounted || _focused) return;
    // Bail out if any descendant already has focus.
    final current = FocusManager.instance.primaryFocus;
    if (current != null && _isDescendantOf(current, _scopeNode)) {
      _focused = true;
      return;
    }
    final first = _findFirstFocusable(_scopeNode);
    if (first != null && first.canRequestFocus) {
      first.requestFocus();
      _focused = true;
    }
  }

  bool _isDescendantOf(FocusNode node, FocusNode ancestor) {
    FocusNode? n = node;
    while (n != null) {
      if (n == ancestor) return true;
      n = n.parent;
    }
    return false;
  }

  FocusNode? _findFirstFocusable(FocusNode root) {
    for (final c in root.traversalChildren) {
      if (c.skipTraversal) continue;
      if (c.canRequestFocus && c is! FocusScopeNode) return c;
      final deeper = _findFirstFocusable(c);
      if (deeper != null) return deeper;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FocusScope(node: _scopeNode, child: widget.child);
  }
}

/// Ports `.back-btn` (settings.html lines 367–378):
///   padding: 7px 11px 7px 8px;
///   background: var(--surface); border: 1px solid var(--line);
///   color: var(--text-2); border-radius: 8px; font: 600 12.5px/1;
///   :hover { background: surface-2; color: text; border-color: line-2; }
///
/// Hardware **Back** / **Escape** are **not** handled here — the shell
/// [PopScope] runs [ShellBackCoordinator] once per key so the internal
/// stack does not double-[pop]. Use **Select/Enter** on this control to
/// go back, same as the HTML.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed, required this.autofocus});

  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final d = NsDensity.of(context);
    return NsFocusable(
      autofocus: autofocus,
      // When this button isn't the autofocus target, exclude it from
      // traversal so `nextFocus()` / `FocusScope.focusInDirection`
      // advance straight into the page content. D-pad spatial movement
      // still reaches the back button — [skipTraversal] only affects
      // the tab / auto-advance ring, not direction-based focus.
      skipTraversal: !autofocus,
      onActivate: onPressed,
      semanticLabel: 'Back',
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: NsEase.ease,
          padding: EdgeInsets.symmetric(
            horizontal: d.buttonPadH * 0.8,
            vertical: d.buttonPadV,
          ),
          decoration: BoxDecoration(
            color: focused ? NsColors.surface2 : NsColors.surface,
            border: Border.all(
              color: focused ? NsColors.line2 : NsColors.line,
            ),
            borderRadius: BorderRadius.circular(d.sp(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: d.iconSmall,
                color: focused ? NsColors.text : NsColors.text2,
              ),
              SizedBox(width: d.sp(4)),
              Text(
                'Back',
                style: TextStyle(
                  color: focused ? NsColors.text : NsColors.text2,
                  fontSize: d.buttonFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
