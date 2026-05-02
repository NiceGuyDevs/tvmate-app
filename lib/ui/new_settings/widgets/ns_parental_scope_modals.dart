/// New Settings–styled parental “scope” actions (lock / unlock rows) for
/// [showDialog] with [nsIslandThemeData] + [NsFocusAccentScope] (see
/// [parental_scope_dialogs]).
library;

import 'package:flutter/material.dart';

import '../new_settings_theme.dart';
import 'ns_focusable.dart';
import 'ns_parental_pin_modals.dart' show NsParentalDialogShell;

/// One tappable action row: New Settings card row + TV orange focus (via
/// [NsFocusable]), matching `documentation/ns-live-tv-lock-scope-preview.html`.
class NsParentalScopeActionRow extends StatelessWidget {
  const NsParentalScopeActionRow({
    super.key,
    required this.label,
    required this.isAvailable,
    this.danger = false,
    required this.onPressed,
    this.autofocus = false,
  });

  final String label;
  final bool isAvailable;
  final bool danger;
  final VoidCallback onPressed;
  final bool autofocus;

  static const Color _idleDangerText = Color(0xFFFCA5A5);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: NsFocusable(
        autofocus: autofocus,
        onActivate: onPressed,
        semanticLabel: label,
        builder: (context, focused) {
          if (!isAvailable) {
            return Opacity(
              opacity: 0.45,
              child: _ScopeRowBody(
                background: NsColors.bg2,
                border: NsColors.line,
                textColor: NsColors.text3,
                label: label,
              ),
            );
          }
          if (danger) {
            if (focused) {
              return _ScopeRowBody(
                background: NsColors.surface2,
                border: NsColors.line2,
                textColor: NsColors.text,
                label: label,
              );
            }
            return _ScopeRowBody(
              background: NsColors.dangerSoft,
              border: NsColors.danger.withValues(alpha: 0.35),
              textColor: _idleDangerText,
              label: label,
            );
          }
          return _ScopeRowBody(
            background: focused ? NsColors.surface2 : NsColors.bg2,
            border: focused ? NsColors.line2 : NsColors.line,
            textColor: NsColors.text,
            label: label,
          );
        },
      ),
    );
  }
}

class _ScopeRowBody extends StatelessWidget {
  const _ScopeRowBody({
    required this.background,
    required this.border,
    required this.textColor,
    required this.label,
  });

  final Color background;
  final Color border;
  final Color textColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(NsRadius.row),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: NsType.rowTitle.copyWith(
          color: textColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Bottom “Cancel” line — [NsType] text-2, accent-2 when focused.
class NsParentalScopeCancelRow extends StatelessWidget {
  const NsParentalScopeCancelRow({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: NsFocusable(
        onActivate: onPressed,
        semanticLabel: label,
        builder: (context, focused) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                style: NsType.rowTitle.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: focused ? NsColors.accent2 : NsColors.text2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Card shell for scope pickers: title + [NsShadow.s2] + [child] column.
class NsParentalScopeDialogCard extends StatelessWidget {
  const NsParentalScopeDialogCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return NsParentalDialogShell(
      title: title,
      subtitle: subtitle,
      boxShadow: NsShadow.s2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
