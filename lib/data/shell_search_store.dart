import 'package:flutter/foundation.dart';

import '../shell/shell_destination.dart';

/// Per-destination top-bar search query (e.g. Live TV, Movies, Series).
/// Movies and Series share one merged VOD string so both tabs show the same filter.
class ShellSearchStore extends ChangeNotifier {
  final Map<ShellDestination, String> _queries = {};
  String? _vodMerged;

  String queryFor(ShellDestination destination) {
    if (destination == ShellDestination.movies ||
        destination == ShellDestination.series) {
      return (_vodMerged ?? '').trim();
    }
    return _queries[destination]?.trim() ?? '';
  }

  bool hasQuery(ShellDestination destination) =>
      queryFor(destination).isNotEmpty;

  void setQuery(ShellDestination destination, String query) {
    final normalized = query.trim();
    if (destination == ShellDestination.movies ||
        destination == ShellDestination.series) {
      if ((_vodMerged ?? '') == normalized) return;
      if (normalized.isEmpty) {
        _vodMerged = null;
      } else {
        _vodMerged = normalized;
      }
      notifyListeners();
      return;
    }
    if ((_queries[destination] ?? '') == normalized) return;
    if (normalized.isEmpty) {
      _queries.remove(destination);
    } else {
      _queries[destination] = normalized;
    }
    notifyListeners();
  }

  void clear(ShellDestination destination) {
    if (destination == ShellDestination.movies ||
        destination == ShellDestination.series) {
      if (_vodMerged != null) {
        _vodMerged = null;
        notifyListeners();
      }
      return;
    }
    if (_queries.remove(destination) != null) {
      notifyListeners();
    }
  }
}

final shellSearchStore = ShellSearchStore();
