import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android [ActivityManager] total RAM via [MainActivity] — used for performance Auto tier.
/// Also receives **IME visibility** from [MainActivity] window insets (see [imeLikelyOpenForTvTextInput]).
/// On desktop (Windows/macOS), most native channel calls are no-ops.
class DeviceMemoryChannel {
  DeviceMemoryChannel._();

  static const _channel = MethodChannel('com.tvmate.app/device');

  static const String fullIme = 'fullIme';
  static const String inAppPad = 'inAppPad';

  /// Resolved before [runApp]; safe to read synchronously from widgets.
  static String tvTextInputProfile = fullIme;

  static bool get useInAppTextPadOnly => tvTextInputProfile == inAppPad;

  static Future<void> ensureTvTextInputProfileLoaded() async {
    if (!Platform.isAndroid) {
      tvTextInputProfile = fullIme;
      return;
    }
    try {
      final v = await _channel.invokeMethod<String>('getTvTextInputProfile');
      if (v != null && (v == inAppPad || v == fullIme)) {
        tvTextInputProfile = v;
      }
    } catch (_) {
      tvTextInputProfile = fullIme;
    }
  }

  /// Google TV Streamer 4K — detected once at startup and read synchronously
  /// thereafter. Used to route VOD through a native [SurfaceView] platform view
  /// instead of the Flutter texture path, because that device's MediaTek decoder
  /// emits a vendor-private YUV format that Flutter cannot sample (green-screen).
  /// Every other device (Shield, FireTV, Chromecast, desktop, …) keeps the
  /// original texture path.
  static bool isGoogleTvStreamer = false;

  static Future<void> ensureIsGoogleTvStreamerLoaded() async {
    if (!Platform.isAndroid) {
      isGoogleTvStreamer = false;
      return;
    }
    try {
      final v = await _channel.invokeMethod<bool>('isGoogleTvStreamer');
      isGoogleTvStreamer = v == true;
    } catch (_) {
      isGoogleTvStreamer = false;
    }
  }

  /// Set from Android [DeviceInfoChannel.onImeVisibilityChanged]; `null` until first event.
  static bool? platformReportsImeOpen;

  /// Call once from [main] so TVs (e.g. Chromecast) can type when the soft keyboard is open.
  static void registerImeVisibilityListener() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'imeVisibility') {
        platformReportsImeOpen = call.arguments == true;
      }
    });
  }

  static bool imeLikelyOpenForTvTextInput(BuildContext context) {
    if (!context.mounted) return false;
    if (MediaQuery.viewInsetsOf(context).bottom > 0.5) return true;
    if (platformReportsImeOpen == true) return true;
    return false;
  }

  static Future<void> prepareForTextInput() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('prepareForTextInput');
    } catch (_) {}
  }

  static Future<void> requestShowSoftInput() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestShowSoftInput');
    } catch (_) {}
  }

  static Future<void> setKeepScreenOn(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', on);
    } catch (_) {}
  }

  /// Total device RAM in **mebibytes** (MiB), or `null` if unavailable.
  static Future<int?> getTotalRamMb() async {
    if (!Platform.isAndroid) return null;
    try {
      final v = await _channel.invokeMethod<Object>('getTotalRamMb');
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
