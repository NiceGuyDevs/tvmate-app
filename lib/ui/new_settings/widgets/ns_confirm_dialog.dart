/// Port of the HTML confirm-modal pattern used for danger actions ("Reset
/// all settings", "Clear PIN & rules", etc.). The reference `#modal` /
/// `.modal-backdrop` blocks live around lines 3992 and ~4820 of
/// `settings.html`. This is a minimal Flutter equivalent sized for TV use —
/// big title, dark surface, cancel + confirm buttons with D-pad focus.
///
/// Shown via [showNsConfirmDialog]. The dialog closes itself before calling
/// [NsConfirmResult.confirmed] so the caller can mutate state without
/// timing issues.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_theme.dart';
import 'ns_focusable.dart';

enum NsConfirmResult { confirmed, cancelled }

/// Show a dark modal with a title, message, cancel and confirm buttons.
/// The confirm button uses danger colors when [isDanger] is true.
Future<NsConfirmResult> showNsConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDanger = false,
}) async {
  final result = await showGeneralDialog<NsConfirmResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.op(0.6),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) => _NsConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDanger: isDanger,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: NsEase.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? NsConfirmResult.cancelled;
}

class _NsConfirmDialog extends StatefulWidget {
  const _NsConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDanger,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDanger;

  @override
  State<_NsConfirmDialog> createState() => _NsConfirmDialogState();
}

class _NsConfirmDialogState extends State<_NsConfirmDialog> {
  late final FocusNode _cancelNode;
  late final FocusNode _confirmNode;

  @override
  void initState() {
    super.initState();
    _cancelNode = FocusNode(debugLabel: 'ns:confirm:cancel');
    _confirmNode = FocusNode(debugLabel: 'ns:confirm:confirm');
    // Autofocus Cancel on danger, Confirm otherwise — prevents accidental
    // destructive actions from an over-eager D-pad Select.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (widget.isDanger ? _cancelNode : _confirmNode).requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelNode.dispose();
    _confirmNode.dispose();
    super.dispose();
  }

  void _close(NsConfirmResult r) => Navigator.of(context).pop(r);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NsFocusAccentScope(
        enabled: true,
        child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.goBack)) {
            _close(NsConfirmResult.cancelled);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: NsColors.surface,
              border: Border.all(color: NsColors.line2),
              borderRadius: BorderRadius.circular(NsRadius.card),
              boxShadow: NsShadow.s3,
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.isDanger
                            ? NsColors.dangerSoft
                            : NsColors.accentSoft,
                        border: Border.all(
                          color: widget.isDanger
                              ? NsColors.danger
                              : NsColors.accentLine,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.isDanger
                            ? Icons.warning_amber_rounded
                            : Icons.help_outline_rounded,
                        color: widget.isDanger
                            ? NsColors.danger
                            : NsColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: NsType.paneTitle.copyWith(fontSize: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.message,
                  style: NsType.rowSub.copyWith(
                    color: NsColors.text2,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      focusNode: _cancelNode,
                      focusRightNeighbor: _confirmNode,
                      label: widget.cancelLabel,
                      onPressed: () => _close(NsConfirmResult.cancelled),
                    ),
                    const SizedBox(width: 10),
                    _DialogButton(
                      focusNode: _confirmNode,
                      focusLeftNeighbor: _cancelNode,
                      label: widget.confirmLabel,
                      onPressed: () => _close(NsConfirmResult.confirmed),
                      isPrimary: true,
                      isDanger: widget.isDanger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.focusNode,
    this.focusLeftNeighbor,
    this.focusRightNeighbor,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final FocusNode focusNode;
  final FocusNode? focusLeftNeighbor;
  final FocusNode? focusRightNeighbor;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    // Styled as `.btn` / `.btn.primary` / `.btn.danger`
    // (settings.html lines 384–406):
    //
    //   .btn         { background: var(--surface); border: 1px solid var(--line);
    //                  color: var(--text); }
    //   .btn:hover   { background: var(--surface-2); border-color: var(--line-2); }
    //   .btn.primary { background: linear-gradient(var(--accent) ... ) }
    //   .btn.primary:hover { filter: brightness(1.05); }
    //   .btn.danger  { color: var(--danger); border-color: rgba(248,113,113,.25);
    //                  background: var(--danger-soft); }
    //   .btn.danger:hover  { background: rgba(248,113,113,.18); }
    //
    // Orange Hugging-L focus (same as [NsFocusAccentScope] on the main
    // new-settings body) — dialog route is outside that scope, so we opt
    // in here. Radius matches [BorderRadius.circular(8)] on the container.
    return NsFocusable(
      focusNode: focusNode,
      focusLeftNeighbor: focusLeftNeighbor,
      focusRightNeighbor: focusRightNeighbor,
      focusAccentRadius: 8,
      onActivate: onPressed,
      semanticLabel: label,
      builder: (context, focused) {
        final Color fill;
        final Color border;
        final Color textColor;
        if (isPrimary && isDanger) {
          // `.btn.danger` on dialog confirm — danger-soft at rest, brighter
          // danger tint on focus (HTML uses rgba(248,113,113,.18) = 46/255).
          fill = focused ? const Color(0x2EF87171) : NsColors.dangerSoft;
          border = const Color(0x40F87171); // rgba(248,113,113,.25)
          textColor = NsColors.danger;
        } else if (isPrimary) {
          // `.btn.primary` — accent fill; hover applies brightness(1.05).
          // We bump to accent2 (slightly brighter cyan) on focus to match.
          fill = focused ? NsColors.accent2 : NsColors.accent;
          border = NsColors.accentLine;
          textColor = NsColors.bg; // HTML uses #001317 on primary.
        } else {
          // `.btn` — bg surface → surface-2, border line → line-2.
          fill = focused ? NsColors.surface2 : NsColors.surface;
          border = focused ? NsColors.line2 : NsColors.line;
          textColor = NsColors.text;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120), // .12s var(--ease)
          curve: NsEase.ease,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8), // .btn uses 8px
          ),
          child: Text(
            label,
            style: NsType.rowValue.copyWith(
              color: textColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
