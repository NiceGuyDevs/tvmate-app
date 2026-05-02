/// Text prompt — same card + button + TV focus family as
/// [showNsConfirmDialog] and the HTML `prompt()`.
///
/// [Dialog] routes do not inherit [NsFocusAccentScope] from the main
/// new-settings body, so this wraps the content in
/// [NsFocusAccentScope] and uses [NsButton] with D-pad neighbors.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../new_settings_theme.dart';
import 'ns_button.dart';
import 'ns_focusable.dart' show NsFocusAccentScope;

/// Returns the trimmed [TextField] value, or `null` if cancelled.
Future<String?> showNsTextPromptDialog(
  BuildContext context, {
  required String title,
  required String initial,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  String? help,
  TextInputType? keyboardType,
}) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NsTextPromptDialog(
      title: title,
      initial: initial,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      help: help,
      keyboardType: keyboardType,
    ),
  );
}

class _NsTextPromptDialog extends StatefulWidget {
  const _NsTextPromptDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    required this.cancelLabel,
    this.help,
    this.keyboardType,
  });

  final String title;
  final String initial;
  final String confirmLabel;
  final String cancelLabel;
  final String? help;
  final TextInputType? keyboardType;

  @override
  State<_NsTextPromptDialog> createState() => _NsTextPromptDialogState();
}

class _NsTextPromptDialogState extends State<_NsTextPromptDialog> {
  late final TextEditingController _ctrl;
  late final FocusNode _field;
  late final FocusNode _cancel;
  late final FocusNode _confirm;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _field = FocusNode();
    _cancel = FocusNode(debugLabel: 'ns:prompt:cancel');
    _confirm = FocusNode(debugLabel: 'ns:prompt:confirm');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_field.canRequestFocus) _field.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _field.dispose();
    _cancel.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NsFocusAccentScope(
      enabled: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.goBack) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Dialog(
            backgroundColor: NsColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: NsColors.line),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: NsType.paneTitle.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctrl,
                      focusNode: _field,
                      keyboardType: widget.keyboardType,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (v) =>
                          Navigator.of(context).pop(_ctrl.text),
                      cursorColor: NsColors.accent,
                      style: NsType.rowValue.copyWith(
                        fontSize: 12.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: NsColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: NsColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: NsColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: NsColors.accentLine,
                          ),
                        ),
                      ),
                    ),
                    if (widget.help != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.help!,
                        style: NsType.optionSub.copyWith(
                          color: NsColors.text4,
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        NsButton(
                          label: widget.cancelLabel,
                          variant: NsButtonVariant.ghost,
                          focusNode: _cancel,
                          focusRightNeighbor: _confirm,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 6),
                        NsButton(
                          label: widget.confirmLabel,
                          variant: NsButtonVariant.primary,
                          icon: Icons.check_rounded,
                          focusNode: _confirm,
                          focusLeftNeighbor: _cancel,
                          onPressed: () => Navigator.of(context).pop(
                            _ctrl.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
