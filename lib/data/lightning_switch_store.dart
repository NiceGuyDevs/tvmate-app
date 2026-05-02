import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// Optional dual-decoder leapfrog pool on **Full-quality** devices only.
/// Default **off** — live player then matches [PerformanceTierStore.isOptimizedEffective]
/// (single decoder, fast live buffers, 2s buffering spinner delay).
final lightningSwitchStore = LightningSwitchStore();

class LightningSwitchStore extends ChangeNotifier {
  static const _prefsKey = 'tvmatepro_lightning_switch_v1';

  /// Persisted default: **off** (same live path as Optimized until user enables).
  static const bool defaultEnabled = false;

  var _enabled = defaultEnabled;
  var _loaded = false;

  bool get enabled => _enabled;
  bool get loaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_prefsKey)) {
      await prefs.setBool(_prefsKey, defaultEnabled);
    }
    _enabled = prefs.getBool(_prefsKey) ?? defaultEnabled;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Map<String, dynamic> exportForBackup() => {'enabled': _enabled};

  Future<void> applyFromBackup(Map<String, dynamic>? m) async {
    if (m == null) return;
    final e = m['enabled'];
    if (e is bool) {
      await setEnabled(e);
    }
  }
}
