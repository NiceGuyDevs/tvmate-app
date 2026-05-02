import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_memory_channel.dart';

/// User-chosen performance profile. [auto] picks optimized vs full from total RAM.
enum PerformanceTierMode {
  auto,
  full,
  optimized;

  static const _auto = 'auto';
  static const _full = 'full';
  static const _optimized = 'optimized';

  String get storageValue => switch (this) {
        PerformanceTierMode.auto => _auto,
        PerformanceTierMode.full => _full,
        PerformanceTierMode.optimized => _optimized,
      };

  static PerformanceTierMode fromStorage(String? raw) {
    switch (raw) {
      case _full:
        return PerformanceTierMode.full;
      case _optimized:
        return PerformanceTierMode.optimized;
      case _auto:
      default:
        return PerformanceTierMode.auto;
    }
  }
}

/// Global performance tier: **full** experience on strong streamers, **optimized** pacing on weak ones.
final performanceTierStore = PerformanceTierStore();

class PerformanceTierStore extends ChangeNotifier {
  static const _prefsKey = 'tvmatepro_performance_tier_mode_v1';

  /// Total RAM (MiB) from Android; `null` until [refreshDeviceRam] succeeds or on non-Android.
  int? _totalRamMb;
  PerformanceTierMode _mode = PerformanceTierMode.auto;
  var _loaded = false;

  int? get totalRamMb => _totalRamMb;
  PerformanceTierMode get mode => _mode;

  bool get loaded => _loaded;

  /// **True** when the app should reduce work (lighter shell, deferred sync, smaller image cache).
  bool get isOptimizedEffective {
    switch (_mode) {
      case PerformanceTierMode.full:
        return false;
      case PerformanceTierMode.optimized:
        return true;
      case PerformanceTierMode.auto:
        final r = _totalRamMb;
        if (r == null) return false;
        return r <= _autoOptimizedRamMbThreshold;
    }
  }

  /// Auto: treat devices with at most this **total** RAM (MiB) as “weak” (typical 2 GB TV sticks).
  static const int _autoOptimizedRamMbThreshold = 2560;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _mode = PerformanceTierMode.fromStorage(prefs.getString(_prefsKey));
    await refreshDeviceRam();
    _loaded = true;
    notifyListeners();
  }

  Future<void> refreshDeviceRam() async {
    _totalRamMb = await DeviceMemoryChannel.getTotalRamMb();
    notifyListeners();
  }

  Future<void> setMode(PerformanceTierMode value) async {
    _mode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.storageValue);
  }

  Map<String, dynamic> exportForBackup() => {
        'mode': _mode.storageValue,
      };

  Future<void> applyFromBackup(Map<String, dynamic>? m) async {
    if (m == null) return;
    final raw = m['mode'];
    if (raw is! String) return;
    await setMode(PerformanceTierMode.fromStorage(raw));
  }
}
