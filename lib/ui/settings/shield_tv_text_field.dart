import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/device_memory_channel.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/team_palette_theme.dart';
import '../focus/tv_focusable.dart';
import 'tv_remote_char_pad_overlay.dart';
import 'tv_remote_keys.dart';

/// TV [TextField]: one [FocusNode] on the [TextField] only. D-pad is handled via
/// [HardwareKeyboard] so we never attach the same node to both [Focus] and [TextField].
class ShieldTvTextField extends StatefulWidget {
  const ShieldTvTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.nextFieldFocus,
    this.previousFieldFocus,
    this.obscure = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.dense = false,
    this.hint,
    this.inputFormatters,
    this.keyboardType = TextInputType.text,
    this.showTvRemotePad = false,
    this.autofocus = false,
    this.dpadMovesFocusWhenImeOpen = false,
  });

  /// URL/server fields use [TextInputType.url] on Shield / most TVs so the system IME works.
  /// When [showTvRemotePad] is true, **Chromecast-like devices** use [TextInputType.none],
  /// [readOnly], and the in-app char pad (see [DeviceMemoryChannel.tvTextInputProfile]);
  /// **Shield** keeps the normal IME.
  final TextInputType keyboardType;

  /// Tighter vertical layout for dense forms (e.g. Add Playlist on TV).
  final bool dense;

  /// Shown inside the field when empty (Material [InputDecoration.hintText]).
  final String? hint;

  /// Optional filters (e.g. digits-only for numeric fields).
  final List<TextInputFormatter>? inputFormatters;

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFieldFocus;
  final FocusNode? previousFieldFocus;
  final bool obscure;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Google TV / Chromecast: opens an in-app character pad (no system IME / phone keyboard).
  final bool showTvRemotePad;

  /// When true, D-pad Up/Down still move focus to [previousFieldFocus]/[nextFieldFocus] even if
  /// the system IME is open ([DeviceMemoryChannel.imeLikelyOpenForTvTextInput]). Use for short
  /// numeric fields where the user must reach a Save row below the keyboard (e.g. pill order).
  final bool dpadMovesFocusWhenImeOpen;

  /// Focus this field when shown (e.g. PIN dialogs).
  final bool autofocus;

  @override
  State<ShieldTvTextField> createState() => _ShieldTvTextFieldState();
}

class _ShieldTvTextFieldState extends State<ShieldTvTextField>
    with WidgetsBindingObserver {
  void _onFocusChange() {
    final inAppOnly =
        widget.showTvRemotePad && DeviceMemoryChannel.useInAppTextPadOnly;
    if (widget.focusNode.hasFocus && !inAppOnly) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.focusNode.hasFocus) return;
        final stillInAppOnly =
            widget.showTvRemotePad && DeviceMemoryChannel.useInAppTextPadOnly;
        if (stillInAppOnly) return;
        DeviceMemoryChannel.requestShowSoftInput();
      });
    }
    setState(() {});
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Chromecast / some TVs update [viewInsets] a frame after the IME opens — rebuild so
    // [DeviceMemoryChannel.imeLikelyOpenForTvTextInput] re-reads [MediaQuery].
    if (mounted) setState(() {});
  }

  /// Intercepts D-pad Up/Down so focus moves between fields without inserting newlines.
  /// When the on-screen keyboard (IME) is open, we must **not** consume those keys —
  /// the IME needs them to move the caret / highlight keys (e.g. Chromecast with Google TV).
  bool _hardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (!widget.focusNode.hasFocus) return false;
    final inAppOnly =
        widget.showTvRemotePad && DeviceMemoryChannel.useInAppTextPadOnly;
    // D-pad Center / Enter: open in-app pad (onTap does not fire on TV remotes).
    if (inAppOnly && tvRemoteIsActivate(event)) {
      unawaited(
        showTvRemoteCharPad(
          context,
          controller: widget.controller,
          fieldLabel: widget.label,
          obscure: widget.obscure,
        ),
      );
      return true;
    }
    if (!inAppOnly &&
        DeviceMemoryChannel.imeLikelyOpenForTvTextInput(context) &&
        !widget.dpadMovesFocusWhenImeOpen) {
      return false;
    }
    if (tvRemoteIsDpadDown(event)) {
      widget.nextFieldFocus.requestFocus();
      return true;
    }
    if (tvRemoteIsDpadUp(event)) {
      final prev = widget.previousFieldFocus;
      if (prev != null) {
        prev.requestFocus();
      } else {
        widget.focusNode.previousFocus();
      }
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_onFocusChange);
    HardwareKeyboard.instance.addHandler(_hardwareKey);
  }

  @override
  void didUpdateWidget(covariant ShieldTvTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_hardwareKey);
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final focused = widget.focusNode.hasFocus;
    final dense = widget.dense;
    final inAppOnly =
        widget.showTvRemotePad && DeviceMemoryChannel.useInAppTextPadOnly;
    final effectiveKeyboardType =
        inAppOnly ? TextInputType.none : widget.keyboardType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: (dense ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
              ?.copyWith(
            color: Colors.white.withOpacity(0.75),
            fontSize: dense ? 12 : null,
          ),
        ),
        SizedBox(height: dense ? 4 : 6),
        if (inAppOnly) ...[
          TvFocusable(
            onActivate: () {
              unawaited(
                showTvRemoteCharPad(
                  context,
                  controller: widget.controller,
                  fieldLabel: widget.label,
                  obscure: widget.obscure,
                ),
              );
            },
            focusPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                l10n.tvRemoteTypingButton,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.teamPalette.accent.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor:
                      context.teamPalette.accent.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.tvRemoteGoogleTvKeyboardHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.55),
                height: 1.35,
              ),
            ),
          ),
        ],
        AnimatedContainer(
          duration: AppTheme.focusAnimationDuration,
          curve: AppTheme.focusAnimationCurve,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: focused ? 2.5 : 1,
              color: focused
                  ? context.teamPalette.brandCyan
                  : Colors.white.withOpacity(0.12),
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: context.teamPalette.brandCyan.withOpacity(0.38),
                      blurRadius: 14,
                      spreadRadius: 0.5,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            controller: widget.controller,
            readOnly: inAppOnly,
            obscureText: widget.obscure,
            style: dense
                ? theme.textTheme.bodyMedium?.copyWith(fontSize: 14.5)
                : theme.textTheme.bodyLarge,
            keyboardType: effectiveKeyboardType,
            textInputAction: widget.textInputAction,
            enableSuggestions: false,
            autocorrect: false,
            inputFormatters: widget.inputFormatters,
            onTap: inAppOnly
                ? () {
                    unawaited(
                      showTvRemoteCharPad(
                        context,
                        controller: widget.controller,
                        fieldLabel: widget.label,
                        obscure: widget.obscure,
                      ),
                    );
                  }
                : null,
            onSubmitted: (value) {
              widget.onSubmitted?.call(value);
              widget.nextFieldFocus.requestFocus();
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.45),
                fontSize: dense ? 13 : null,
              ),
              filled: true,
              fillColor: context.teamPalette.surfaceElevated,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: dense ? 12 : 14,
                vertical: dense ? 9 : 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
