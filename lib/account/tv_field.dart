import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/focus/tv_focusable.dart';
import '../ui/settings/tv_remote_char_pad_overlay.dart';

/// TextField for Android TV: D-pad Up/Down move between fields via
/// [HardwareKeyboard] (before [TextField] consumes arrows). IME next uses [nextFocus].
///
/// On Chromecast / Google TV where the system keyboard may not appear,
/// a small keyboard icon is shown so the user can manually open the in-app
/// character pad overlay.
class TvField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// If null, an internal node is created and disposed by this widget.
  final FocusNode? focusNode;

  /// Focus moves here when IME "next" / editing completes (chain fields + buttons).
  final FocusNode? nextFocus;

  const TvField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.nextFocus,
  });

  @override
  State<TvField> createState() => _TvFieldState();
}

class _TvFieldState extends State<TvField> with WidgetsBindingObserver {
  late final FocusNode _focusNode;
  bool _hasFocus = false;
  double _lastBottomInset = 0;
  late final bool Function(KeyEvent) _hardwareKeyHandler;

  bool _showCharPadButton = false;
  Timer? _keyboardTimer;
  bool _keyboardAppeared = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
    _hardwareKeyHandler = _onHardwareKey;
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
  }

  void _onFocusChange() {
    setState(() { _hasFocus = _focusNode.hasFocus; });
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_focusNode.hasFocus) {
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
      // On Android TV, wait to see if the system keyboard appears.
      // If it doesn't within 600ms, show the fallback char pad button.
      if (Platform.isAndroid) {
        _keyboardAppeared = false;
        _keyboardTimer?.cancel();
        _keyboardTimer = Timer(const Duration(milliseconds: 600), () {
          if (!mounted || !_focusNode.hasFocus) return;
          if (!_keyboardAppeared && !_showCharPadButton) {
            setState(() { _showCharPadButton = true; });
          }
        });
      }
    }
  }

  /// Runs early in dispatch: steal Up/Down so focus can leave the text field.
  bool _onHardwareKey(KeyEvent event) {
    if (!_focusNode.hasFocus) return false;
    if (event is! KeyDownEvent) return false;
    if (isDpadKeyRepeat(event)) {
      return true;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _focusNode.nextFocus();
      return true;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _focusNode.previousFocus();
      return true;
    }
    return false;
  }

  @override
  void didChangeMetrics() {
    final bottomInset =
        WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset > 0 && _lastBottomInset == 0) {
      _keyboardAppeared = true;
    }
    if (_lastBottomInset > 0 && bottomInset == 0 && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _lastBottomInset = bottomInset;
  }

  void _onEditingComplete() {
    if (widget.nextFocus != null) {
      widget.nextFocus!.requestFocus();
    }
  }

  void _openCharPad() {
    showTvRemoteCharPad(
      context,
      controller: widget.controller,
      fieldLabel: widget.hint,
      obscure: widget.obscure,
    );
  }

  @override
  void dispose() {
    _keyboardTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: _hasFocus
            ? [BoxShadow(color: const Color(0xFF6366F1).withAlpha(100), blurRadius: 8, spreadRadius: 1)]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscure,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: _onEditingComplete,
        enableInteractiveSelection: true,
        showCursor: true,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.white.withAlpha(100), fontSize: 13),
          filled: true,
          fillColor: _hasFocus ? Colors.white.withAlpha(25) : Colors.white.withAlpha(13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withAlpha(25))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
          suffixIcon: _showCharPadButton
              ? IconButton(
                  icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white54, size: 20),
                  onPressed: _openCharPad,
                  tooltip: 'Open keyboard',
                )
              : null,
        ),
      ),
    );
  }
}
