/// Transient feedback matching [documentation/ns-messaging-toast-preview.html]:
/// dark surface, `--line-2` border, left status rail, soft icon tile, title +
/// body, optional Dismiss. Use [showNsMessage] from new settings (island theme).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../new_settings_theme.dart';
import 'ns_focusable.dart';

/// Visual variant (success / error / neutral) — sets rail, glyph, and icon.
enum NsMessageVariant { success, error, neutral }

/// Ns-styled message card (not a [SnackBar] by itself — wrap in [SnackBar]).
class NsMessageBar extends StatelessWidget {
  const NsMessageBar({
    super.key,
    this.title,
    this.message,
    this.variant = NsMessageVariant.neutral,
    this.showDismiss = true,
  });

  /// Primary line (e.g. "Backup applied"). Optional if [message] is non-empty.
  final String? title;

  /// Secondary line or full text when [title] is null.
  final String? message;

  final NsMessageVariant variant;

  final bool showDismiss;

  @override
  Widget build(BuildContext context) {
    final t = title?.trim();
    final m = message?.trim();
    final hasTitle = t != null && t.isNotEmpty;
    final hasMsg = m != null && m.isNotEmpty;
    if (!hasTitle && !hasMsg) return const SizedBox.shrink();

    final rail = _railGradient();
    final iconData = _icon();
    final glyphBorder = _glyphBorder();
    final glyphBg = _glyphBg();
    final iconColor = _iconColor();

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            color: NsColors.surface,
            borderRadius: BorderRadius.circular(NsRadius.row),
            border: Border.all(color: NsColors.line2),
            boxShadow: NsShadow.s1,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Rail(gradient: rail),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: glyphBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: glyphBorder),
                ),
                child: Icon(iconData, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitle)
                        Text(
                          t,
                          style: const TextStyle(
                            color: NsColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.01 * 13.5,
                          ),
                        ),
                      if (hasTitle && hasMsg) const SizedBox(height: 4),
                      if (hasMsg)
                        Text(
                          m,
                          style: const TextStyle(
                            color: NsColors.text2,
                            fontSize: 12.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (showDismiss) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: NsFocusable(
                    onActivate: () {
                      ScaffoldMessenger.of(context)
                          .removeCurrentSnackBar();
                    },
                    semanticLabel:
                        AppLocalizations.of(context).nsMessageDismiss,
                    builder: (context, focused) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: focused
                              ? NsColors.surface2
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            AppLocalizations.of(context).nsMessageDismiss,
                            style: TextStyle(
                              color: focused
                                  ? NsColors.text2
                                  : NsColors.text3,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _railGradient() {
    switch (variant) {
      case NsMessageVariant.success:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
        );
      case NsMessageVariant.error:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF87171), Color(0xFFEF4444)],
        );
      case NsMessageVariant.neutral:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4DD0E1), Color(0xFF22D3EE)],
        );
    }
  }

  IconData _icon() {
    switch (variant) {
      case NsMessageVariant.success:
        return Icons.check_rounded;
      case NsMessageVariant.error:
        return Icons.error_outline_rounded;
      case NsMessageVariant.neutral:
        return Icons.info_outline_rounded;
    }
  }

  Color _glyphBg() {
    switch (variant) {
      case NsMessageVariant.success:
        return NsColors.successSoft;
      case NsMessageVariant.error:
        return NsColors.dangerSoft;
      case NsMessageVariant.neutral:
        return NsColors.accentSoft;
    }
  }

  Color _glyphBorder() {
    switch (variant) {
      case NsMessageVariant.success:
        return const Color.fromRGBO(74, 222, 128, 0.28);
      case NsMessageVariant.error:
        return const Color(0x4DF87171);
      case NsMessageVariant.neutral:
        return NsColors.accentLine;
    }
  }

  Color _iconColor() {
    switch (variant) {
      case NsMessageVariant.success:
        return NsColors.success;
      case NsMessageVariant.error:
        return NsColors.danger;
      case NsMessageVariant.neutral:
        return NsColors.accent;
    }
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.gradient});

  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        width: 3,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(2),
          ),
          gradient: gradient,
        ),
      ),
    );
  }
}

/// Shows an Ns-styled floating message (replaces default [SnackBar] styling
/// inside the new settings surface).
void showNsMessage(
  BuildContext context, {
  String? title,
  String? message,
  NsMessageVariant variant = NsMessageVariant.neutral,
  Duration duration = const Duration(seconds: 4),
  bool showDismiss = true,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      padding: EdgeInsets.zero,
      duration: duration,
      content: NsMessageBar(
        title: title,
        message: message,
        variant: variant,
        showDismiss: showDismiss,
      ),
    ),
  );
}
