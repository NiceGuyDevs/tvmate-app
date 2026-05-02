import 'package:flutter/services.dart';

/// Android TV / Shield — stable logical keys only (Flutter stable).
bool tvRemoteIsDpadDown(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final k = event.logicalKey;
  return identical(k, LogicalKeyboardKey.arrowDown) ||
      identical(k, LogicalKeyboardKey.numpad2);
}

bool tvRemoteIsDpadUp(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final k = event.logicalKey;
  return identical(k, LogicalKeyboardKey.arrowUp) ||
      identical(k, LogicalKeyboardKey.numpad8);
}

bool tvRemoteIsDpadLeft(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final k = event.logicalKey;
  return identical(k, LogicalKeyboardKey.arrowLeft) ||
      identical(k, LogicalKeyboardKey.numpad4);
}

bool tvRemoteIsDpadRight(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final k = event.logicalKey;
  return identical(k, LogicalKeyboardKey.arrowRight) ||
      identical(k, LogicalKeyboardKey.numpad6);
}

/// Center / OK — let [TextField] handle when we return ignored from wrappers.
bool tvRemoteIsActivate(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final k = event.logicalKey;
  return identical(k, LogicalKeyboardKey.select) ||
      identical(k, LogicalKeyboardKey.enter);
}

/// Android TV back / ESC — not the on-screen back affordance.
bool tvRemoteIsBack(KeyEvent event) {
  if (event is! KeyDownEvent) return false;
  final k = event.logicalKey;
  return identical(k, LogicalKeyboardKey.goBack) ||
      identical(k, LogicalKeyboardKey.escape);
}
