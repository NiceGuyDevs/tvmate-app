import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// Windows-only “mini player”: small **always-on-top** window, default **bottom-right**,
/// **16:9** aspect, slightly under **¼** screen width. Same app window — no second video.
class WindowsPipController extends ChangeNotifier {
  WindowsPipController._();
  static final WindowsPipController instance = WindowsPipController._();

  bool _active = false;
  Rect? _restoredBounds;
  var _savedMaximized = false;

  bool get isPipActive => _active;

  Future<void> enterPip() async {
    if (!Platform.isWindows || _active) return;
    try {
      await windowManager.ensureInitialized();
      if (await windowManager.isFullScreen()) {
        await windowManager.setFullScreen(false);
      }
      _savedMaximized = await windowManager.isMaximized();
      if (_savedMaximized) {
        await windowManager.unmaximize();
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      _restoredBounds = await windowManager.getBounds();

      final d = await screenRetriever.getPrimaryDisplay();
      final origin = d.visiblePosition ?? Offset.zero;
      final sz = d.visibleSize ?? d.size;
      const margin = 16.0;
      // Slightly under ¼ of the screen: ~22% of work-area width.
      final winW = sz.width * 0.22;
      final winH = winW * 9 / 16;
      final left = origin.dx + sz.width - winW - margin;
      final top = origin.dy + sz.height - winH - margin;

      await windowManager.setAlwaysOnTop(true);
      await windowManager.setBounds(Rect.fromLTWH(left, top, winW, winH));
      await windowManager.setAspectRatio(16 / 9);

      _active = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('WindowsPipController.enterPip: $e\n$st');
    }
  }

  Future<void> exitPip() async {
    if (!Platform.isWindows || !_active) return;
    try {
      await windowManager.setAspectRatio(0);
      await windowManager.setAlwaysOnTop(false);
      final r = _restoredBounds;
      if (r != null) {
        await windowManager.setBounds(r);
      }
      if (_savedMaximized) {
        await windowManager.maximize();
      }
      _active = false;
      _restoredBounds = null;
      _savedMaximized = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('WindowsPipController.exitPip: $e\n$st');
    }
  }

  /// Call when leaving [PlayerScreen] while PIP is on so the shell is not stuck small/on-top.
  Future<void> exitPipIfActive() async {
    if (_active) await exitPip();
  }
}
