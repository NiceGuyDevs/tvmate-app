import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shell/shell_destination.dart';

/// Persists the user's top-menu configuration: item order, which optionals
/// are enabled, and which category loads on app startup.
class TopMenuStore extends ChangeNotifier {
  TopMenuStore._();
  static final TopMenuStore instance = TopMenuStore._();

  static const _kOrderKey = 'top_menu_order';
  static const _kStartupKey = 'top_menu_startup';

  /// Default order (fixed items only, optionals off).
  static const List<ShellDestination> defaultOrder = [
    ShellDestination.liveTv,
    ShellDestination.movies,
    ShellDestination.series,
    ShellDestination.recording,
  ];

  List<ShellDestination> _order = List.of(defaultOrder);
  ShellDestination _startup = ShellDestination.liveTv;

  /// Current ordered menu items (excluding the pinned **Settings** tab, which
  /// is always appended after [order]).
  List<ShellDestination> get order => List.unmodifiable(_order);

  /// The full menu as it should appear: [order] + the main [Settings] tab
  /// ([ShellDestination.newSettings], legacy UI removed from the top bar).
  List<ShellDestination> get fullMenu => [
        ..._order,
        ShellDestination.newSettings,
      ];

  /// Category to focus on app startup.
  ShellDestination get startup => _startup;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getStringList(_kOrderKey);
    if (raw != null && raw.isNotEmpty) {
      final parsed = <ShellDestination>[];
      for (final name in raw) {
        final d = _fromName(name);
        if (d != null &&
            d != ShellDestination.settings &&
            d != ShellDestination.newSettings) {
          parsed.add(d);
        }
      }
      // Ensure all fixed items are present (in case new ones were added).
      for (final f in defaultOrder) {
        if (!parsed.contains(f)) parsed.add(f);
      }
      _order = parsed;
    }

    var migratedStartup = false;
    final startupName = prefs.getString(_kStartupKey);
    if (startupName != null) {
      final d = _fromName(startupName);
      if (d != null) {
        if (d == ShellDestination.settings) {
          _startup = ShellDestination.newSettings;
          migratedStartup = true;
        } else {
          _startup = d;
        }
      }
    }

    notifyListeners();
    if (migratedStartup) {
      await _persist();
    }
  }

  Future<void> setOrder(List<ShellDestination> newOrder) async {
    _order = List.of(newOrder);
    // If startup is no longer in the bar, reset to the first available item.
    if (!fullMenu.contains(_startup)) {
      _startup = _order.isNotEmpty ? _order.first : ShellDestination.liveTv;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> setStartup(ShellDestination d) async {
    _startup = d == ShellDestination.settings
        ? ShellDestination.newSettings
        : d;
    notifyListeners();
    await _persist();
  }

  /// Toggle an optional item on/off in the menu.
  Future<void> toggleOptional(ShellDestination d) async {
    if (!d.isOptional) return;
    if (_order.contains(d)) {
      _order.remove(d);
      if (_startup == d) {
        _startup = _order.isNotEmpty ? _order.first : ShellDestination.liveTv;
      }
    } else {
      // Insert at the end of the reorderable segment (before pinned Settings).
      _order.add(d);
    }
    notifyListeners();
    await _persist();
  }

  /// Move an item in the order list from [oldIndex] to [newIndex].
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _order.length) return;
    if (newIndex < 0 || newIndex >= _order.length) return;
    final item = _order.removeAt(oldIndex);
    _order.insert(newIndex, item);
    notifyListeners();
    _persist();
  }

  Map<String, dynamic> exportForBackup() => {
        'order': _order.map((d) => d.name).toList(),
        'startup': _startup.name,
      };

  Future<void> replaceFromBackup(Map<String, dynamic>? encoded) async {
    if (encoded == null) return;
    final rawOrder = encoded['order'];
    if (rawOrder is List) {
      final parsed = <ShellDestination>[];
      for (final name in rawOrder) {
        if (name is! String) continue;
        final d = _fromName(name);
        if (d != null &&
            d != ShellDestination.settings &&
            d != ShellDestination.newSettings) {
          parsed.add(d);
        }
      }
      for (final f in defaultOrder) {
        if (!parsed.contains(f)) parsed.add(f);
      }
      _order = parsed;
    }
    final startupName = encoded['startup'];
    if (startupName is String) {
      final d = _fromName(startupName);
      if (d != null) {
        _startup = d == ShellDestination.settings
            ? ShellDestination.newSettings
            : d;
      }
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kOrderKey,
      _order.map((d) => d.name).toList(),
    );
    await prefs.setString(_kStartupKey, _startup.name);
  }

  static ShellDestination? _fromName(String name) {
    for (final d in ShellDestination.values) {
      if (d.name == name) return d;
    }
    return null;
  }
}

final topMenuStore = TopMenuStore.instance;
