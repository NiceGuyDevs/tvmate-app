import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/live_tv/mock_live_tv_data.dart';
import 'live_favorite_groups_store.dart';

/// Parental control: numeric PIN (4–8 digits), section locks, and per-item blocklists.
///
/// Playback checks use [playlistId] from the active playlist; demo mode uses [kDemoPlaylistId].
class ParentalControlStore extends ChangeNotifier {
  ParentalControlStore._();
  static final ParentalControlStore instance = ParentalControlStore._();

  static const _kPrefsKey = 'tvmatepro_parental_control_v1';
  static const String kDemoPlaylistId = '__demo__';

  bool _loaded = false;
  bool _enabled = false;
  String? _pinSaltB64;
  String? _pinHashHex;
  bool _lockAllLive = false;
  bool _lockAllMovies = false;
  bool _lockAllSeries = false;

  /// When [hideRestrictedFromBrowseActive], browse omits items that match lock rules.
  bool _hideRestrictedFromBrowse = false;

  final Map<String, Set<String>> _lockedLiveChannels = {};
  final Map<String, Set<String>> _lockedLiveCategories = {};
  final Set<String> _lockedFavoriteGroups = {};
  final Map<String, Set<String>> _lockedMovieIds = {};
  final Map<String, Set<String>> _lockedVodCategories = {};
  final Map<String, Set<String>> _lockedSeriesIds = {};
  final Map<String, Set<String>> _lockedSeriesCategories = {};

  /// Per-item: hide from Live TV browse lists (in addition to global hide-all-restricted).
  final Map<String, Set<String>> _browseHideLiveChannels = {};
  final Map<String, Set<String>> _browseHideLiveCategories = {};
  final Set<String> _browseHideFavoriteGroups = {};

  bool get isLoaded => _loaded;
  bool get enabled => _enabled;
  bool get isPinConfigured => _pinHashHex != null && _pinHashHex!.isNotEmpty;
  bool get lockAllLive => _lockAllLive;
  bool get lockAllMovies => _lockAllMovies;
  bool get lockAllSeries => _lockAllSeries;

  bool get hideRestrictedFromBrowse => _hideRestrictedFromBrowse;

  /// Hide-from-browse applies when parental is on, PIN exists, and hide is enabled.
  bool get hideRestrictedFromBrowseActive =>
      _enabled && isPinConfigured && _hideRestrictedFromBrowse;

  /// Live TV grid should filter channels/categories when global hide is on **or**
  /// any per-item “lock and hide” rule exists.
  bool get shouldFilterLiveBrowseForParental =>
      _enabled &&
      isPinConfigured &&
      (hideRestrictedFromBrowseActive || _hasAnyLiveBrowseHideRule);

  bool get _hasAnyLiveBrowseHideRule =>
      _browseHideFavoriteGroups.isNotEmpty ||
      _browseHideLiveChannels.values.any((s) => s.isNotEmpty) ||
      _browseHideLiveCategories.values.any((s) => s.isNotEmpty);

  /// Count of per-item lock rows shown on "Restricted rules".
  int get granularLockRuleCount {
    var n = _lockedFavoriteGroups.length;
    for (final s in _lockedLiveChannels.values) {
      n += s.length;
    }
    for (final s in _lockedLiveCategories.values) {
      n += s.length;
    }
    for (final s in _lockedMovieIds.values) {
      n += s.length;
    }
    for (final s in _lockedVodCategories.values) {
      n += s.length;
    }
    for (final s in _lockedSeriesIds.values) {
      n += s.length;
    }
    for (final s in _lockedSeriesCategories.values) {
      n += s.length;
    }
    return n;
  }

  static bool isValidPinFormat(String pin) {
    final t = pin.trim();
    return RegExp(r'^\d{4,8}$').hasMatch(t);
  }

  String _playlistKey(String? playlistId) =>
      (playlistId == null || playlistId.isEmpty) ? kDemoPlaylistId : playlistId;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final m = jsonDecode(raw);
        if (m is Map<String, dynamic>) {
          _enabled = m['enabled'] == true;
          _pinSaltB64 = m['pinSalt'] as String?;
          _pinHashHex = m['pinHash'] as String?;
          _lockAllLive = m['lockAllLive'] == true;
          _lockAllMovies = m['lockAllMovies'] == true;
          _lockAllSeries = m['lockAllSeries'] == true;
          _hideRestrictedFromBrowse = m['hideRestrictedFromBrowse'] == true;
          _readStringSetMap(m['liveChannels'], _lockedLiveChannels);
          _readStringSetMap(m['liveCategories'], _lockedLiveCategories);
          _lockedFavoriteGroups
            ..clear()
            ..addAll(_readStringList(m['favoriteGroups']));
          _readStringSetMap(m['movieIds'], _lockedMovieIds);
          _readStringSetMap(m['vodCategories'], _lockedVodCategories);
          _readStringSetMap(m['seriesIds'], _lockedSeriesIds);
          _readStringSetMap(m['seriesCategories'], _lockedSeriesCategories);
          _readStringSetMap(m['browseHideLiveChannels'], _browseHideLiveChannels);
          _readStringSetMap(
            m['browseHideLiveCategories'],
            _browseHideLiveCategories,
          );
          _browseHideFavoriteGroups
            ..clear()
            ..addAll(_readStringList(m['browseHideFavoriteGroups']));
        }
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  void _readStringSetMap(dynamic raw, Map<String, Set<String>> out) {
    out.clear();
    if (raw is! Map) return;
    raw.forEach((k, v) {
      if (k is! String) return;
      final set = <String>{};
      if (v is List) {
        for (final e in v) {
          if (e is String && e.isNotEmpty) set.add(e);
        }
      }
      out[k] = set;
    });
  }

  List<String> _readStringList(dynamic raw) {
    if (raw is! List) return [];
    return [for (final e in raw) if (e is String && e.isNotEmpty) e];
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'enabled': _enabled,
      'pinSalt': _pinSaltB64,
      'pinHash': _pinHashHex,
      'lockAllLive': _lockAllLive,
      'lockAllMovies': _lockAllMovies,
      'lockAllSeries': _lockAllSeries,
      'hideRestrictedFromBrowse': _hideRestrictedFromBrowse,
      'liveChannels': {
        for (final e in _lockedLiveChannels.entries)
          e.key: e.value.toList(growable: false),
      },
      'liveCategories': {
        for (final e in _lockedLiveCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'favoriteGroups': _lockedFavoriteGroups.toList(growable: false),
      'movieIds': {
        for (final e in _lockedMovieIds.entries)
          e.key: e.value.toList(growable: false),
      },
      'vodCategories': {
        for (final e in _lockedVodCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'seriesIds': {
        for (final e in _lockedSeriesIds.entries)
          e.key: e.value.toList(growable: false),
      },
      'seriesCategories': {
        for (final e in _lockedSeriesCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'browseHideLiveChannels': {
        for (final e in _browseHideLiveChannels.entries)
          e.key: e.value.toList(growable: false),
      },
      'browseHideLiveCategories': {
        for (final e in _browseHideLiveCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'browseHideFavoriteGroups': _browseHideFavoriteGroups.toList(growable: false),
    };
    await prefs.setString(_kPrefsKey, jsonEncode(map));
  }

  String _hashPin(String saltB64, String pin) {
    final combined = utf8.encode(saltB64 + pin.trim());
    return sha256.convert(combined).toString();
  }

  bool verifyPin(String pin) {
    if (!isValidPinFormat(pin) || _pinSaltB64 == null || _pinHashHex == null) {
      return false;
    }
    return _hashPin(_pinSaltB64!, pin) == _pinHashHex;
  }

  Future<bool> setPin(String pin) async {
    await ensureLoaded();
    if (!isValidPinFormat(pin)) return false;
    final rnd = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    _pinSaltB64 = base64Encode(saltBytes);
    _pinHashHex = _hashPin(_pinSaltB64!, pin);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> clearPinAndRules() async {
    await ensureLoaded();
    _enabled = false;
    _pinSaltB64 = null;
    _pinHashHex = null;
    _lockAllLive = false;
    _lockAllMovies = false;
    _lockAllSeries = false;
    _hideRestrictedFromBrowse = false;
    _lockedLiveChannels.clear();
    _lockedLiveCategories.clear();
    _lockedFavoriteGroups.clear();
    _lockedMovieIds.clear();
    _lockedVodCategories.clear();
    _lockedSeriesIds.clear();
    _lockedSeriesCategories.clear();
    _browseHideLiveChannels.clear();
    _browseHideLiveCategories.clear();
    _browseHideFavoriteGroups.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> setEnabled(bool v) async {
    await ensureLoaded();
    _enabled = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setLockAllLive(bool v) async {
    await ensureLoaded();
    _lockAllLive = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setLockAllMovies(bool v) async {
    await ensureLoaded();
    _lockAllMovies = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setLockAllSeries(bool v) async {
    await ensureLoaded();
    _lockAllSeries = v;
    await _persist();
    notifyListeners();
  }

  Future<void> setHideRestrictedFromBrowse(bool v) async {
    await ensureLoaded();
    _hideRestrictedFromBrowse = v;
    await _persist();
    notifyListeners();
  }

  Set<String> _setFor(Map<String, Set<String>> map, String? playlistId) {
    final k = _playlistKey(playlistId);
    return map.putIfAbsent(k, () => <String>{});
  }

  Future<void> addLockedLiveChannel(String? playlistId, String channelId) async {
    await ensureLoaded();
    if (channelId.isEmpty) return;
    _setFor(_lockedLiveChannels, playlistId).add(channelId);
    await _persist();
    notifyListeners();
  }

  Future<void> addLockedLiveCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    if (categoryId.isEmpty) return;
    _setFor(_lockedLiveCategories, playlistId).add(categoryId);
    await _persist();
    notifyListeners();
  }

  Future<void> addLockedFavoriteGroup(String groupId) async {
    await ensureLoaded();
    if (groupId.isEmpty) return;
    _lockedFavoriteGroups.add(groupId);
    await _persist();
    notifyListeners();
  }

  Future<void> addBrowseHideLiveChannel(String? playlistId, String channelId) async {
    await ensureLoaded();
    if (channelId.isEmpty) return;
    _setFor(_browseHideLiveChannels, playlistId).add(channelId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeBrowseHideLiveChannel(String? playlistId, String channelId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _browseHideLiveChannels[pid]?.remove(channelId);
    await _persist();
    notifyListeners();
  }

  Future<void> addBrowseHideLiveCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    if (categoryId.isEmpty) return;
    _setFor(_browseHideLiveCategories, playlistId).add(categoryId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeBrowseHideLiveCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _browseHideLiveCategories[pid]?.remove(categoryId);
    await _persist();
    notifyListeners();
  }

  Future<void> addBrowseHideFavoriteGroup(String groupId) async {
    await ensureLoaded();
    if (groupId.isEmpty) return;
    _browseHideFavoriteGroups.add(groupId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeBrowseHideFavoriteGroup(String groupId) async {
    await ensureLoaded();
    _browseHideFavoriteGroups.remove(groupId);
    await _persist();
    notifyListeners();
  }

  Future<void> addLockedMovie(String? playlistId, String movieId) async {
    await ensureLoaded();
    if (movieId.isEmpty) return;
    _setFor(_lockedMovieIds, playlistId).add(movieId);
    await _persist();
    notifyListeners();
  }

  Future<void> addLockedVodCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    if (categoryId.isEmpty) return;
    _setFor(_lockedVodCategories, playlistId).add(categoryId);
    await _persist();
    notifyListeners();
  }

  Future<void> addLockedSeries(String? playlistId, String seriesId) async {
    await ensureLoaded();
    if (seriesId.isEmpty) return;
    _setFor(_lockedSeriesIds, playlistId).add(seriesId);
    await _persist();
    notifyListeners();
  }

  Future<void> addLockedSeriesCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    if (categoryId.isEmpty) return;
    _setFor(_lockedSeriesCategories, playlistId).add(categoryId);
    await _persist();
    notifyListeners();
  }

  /// This channel id is explicitly in the per-channel blocklist (not only via category).
  bool isLiveChannelDirectlyLocked(String? playlistId, String channelId) {
    if (channelId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    return _lockedLiveChannels[pid]?.contains(channelId) ?? false;
  }

  bool isLiveChannelBrowseHidden(String? playlistId, String channelId) {
    if (channelId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    return _browseHideLiveChannels[pid]?.contains(channelId) ?? false;
  }

  /// Current browse pill (playlist category or favorite / umbrella) has its own block rule.
  bool isLiveViewCategoryOrFavoriteLocked(String? playlistId, String viewCategoryId) {
    if (viewCategoryId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    final fav = LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
    if (viewCategoryId == kLiveTvFavoritesCategoryId || fav != null) {
      return _lockedFavoriteGroups.contains(viewCategoryId);
    }
    return _lockedLiveCategories[pid]?.contains(viewCategoryId) ?? false;
  }

  bool isLiveViewCategoryBrowseHidden(String? playlistId, String viewCategoryId) {
    if (viewCategoryId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    final fav = LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
    if (viewCategoryId == kLiveTvFavoritesCategoryId || fav != null) {
      return _browseHideFavoriteGroups.contains(viewCategoryId);
    }
    return _browseHideLiveCategories[pid]?.contains(viewCategoryId) ?? false;
  }

  bool isMovieDirectlyLocked(String? playlistId, String movieId) {
    if (movieId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    return _lockedMovieIds[pid]?.contains(movieId) ?? false;
  }

  bool isVodCategoryLocked(String? playlistId, String categoryId) {
    if (categoryId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    return _lockedVodCategories[pid]?.contains(categoryId) ?? false;
  }

  bool isSeriesDirectlyLocked(String? playlistId, String seriesId) {
    if (seriesId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    return _lockedSeriesIds[pid]?.contains(seriesId) ?? false;
  }

  bool isSeriesCategoryLocked(String? playlistId, String categoryId) {
    if (categoryId.isEmpty) return false;
    final pid = _playlistKey(playlistId);
    return _lockedSeriesCategories[pid]?.contains(categoryId) ?? false;
  }

  Future<void> removeLockedLiveChannel(String? playlistId, String channelId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _lockedLiveChannels[pid]?.remove(channelId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeLockedLiveCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    if (categoryId.isEmpty) return;
    final pid = _playlistKey(playlistId);
    _lockedLiveCategories[pid]?.remove(categoryId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeLockedFavoriteGroup(String groupId) async {
    await ensureLoaded();
    _lockedFavoriteGroups.remove(groupId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeLockedMovie(String? playlistId, String movieId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _lockedMovieIds[pid]?.remove(movieId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeLockedVodCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _lockedVodCategories[pid]?.remove(categoryId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeLockedSeries(String? playlistId, String seriesId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _lockedSeriesIds[pid]?.remove(seriesId);
    await _persist();
    notifyListeners();
  }

  Future<void> removeLockedSeriesCategory(String? playlistId, String categoryId) async {
    await ensureLoaded();
    final pid = _playlistKey(playlistId);
    _lockedSeriesCategories[pid]?.remove(categoryId);
    await _persist();
    notifyListeners();
  }

  /// When true, opening this live channel requires PIN (parental on + rules match).
  bool isLivePlaybackBlocked({
    required String? playlistId,
    required String viewCategoryId,
    required String channelId,
    required String channelCategoryId,
  }) {
    if (!_enabled || !isPinConfigured) return false;
    if (_lockAllLive) return true;
    final pid = _playlistKey(playlistId);
    if (_lockedLiveChannels[pid]?.contains(channelId) ?? false) return true;

    final favGroup =
        LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
    final isFavoritesPill = viewCategoryId == kLiveTvFavoritesCategoryId ||
        favGroup != null;
    if (isFavoritesPill) {
      if (viewCategoryId == kLiveTvFavoritesCategoryId) {
        if (_lockedFavoriteGroups.contains(kLiveTvFavoritesCategoryId)) {
          return true;
        }
      } else if (favGroup != null) {
        if (_lockedFavoriteGroups.contains(viewCategoryId)) return true;
      }
    }

    if (_lockedLiveCategories[pid]?.contains(viewCategoryId) ?? false) {
      return true;
    }
    if (_lockedLiveCategories[pid]?.contains(channelCategoryId) ?? false) {
      return true;
    }
    return false;
  }

  bool isLiveHiddenFromBrowse({
    required String? playlistId,
    required String viewCategoryId,
    required String channelId,
    required String channelCategoryId,
  }) {
    if (!_enabled || !isPinConfigured) return false;
    final pid = _playlistKey(playlistId);
    if (_browseHideLiveChannels[pid]?.contains(channelId) ?? false) {
      return true;
    }
    if (viewCategoryId.isNotEmpty) {
      final fav = LiveFavoriteGroupsStore.instance.groupById(viewCategoryId);
      if (viewCategoryId == kLiveTvFavoritesCategoryId || fav != null) {
        if (_browseHideFavoriteGroups.contains(viewCategoryId)) return true;
      } else {
        if (_browseHideLiveCategories[pid]?.contains(viewCategoryId) ?? false) {
          return true;
        }
      }
    }
    // Do not hide by [channelCategoryId] alone here — it matched too many rows when
    // the same backend category id appears across views and emptied unrelated grids.
    if (!hideRestrictedFromBrowseActive) return false;
    return isLivePlaybackBlocked(
      playlistId: playlistId,
      viewCategoryId: viewCategoryId,
      channelId: channelId,
      channelCategoryId: channelCategoryId,
    );
  }

  bool isMovieHiddenFromBrowse({
    required String? playlistId,
    required String movieId,
    required String categoryId,
  }) {
    if (!hideRestrictedFromBrowseActive) return false;
    return isMoviePlaybackBlocked(
      playlistId: playlistId,
      movieId: movieId,
      categoryId: categoryId,
    );
  }

  bool isSeriesHiddenFromBrowse({
    required String? playlistId,
    required String seriesId,
    required String categoryId,
  }) {
    if (!hideRestrictedFromBrowseActive) return false;
    return isSeriesPlaybackBlocked(
      playlistId: playlistId,
      seriesId: seriesId,
      categoryId: categoryId,
    );
  }

  bool isMoviePlaybackBlocked({
    required String? playlistId,
    required String movieId,
    required String categoryId,
  }) {
    if (!_enabled || !isPinConfigured) return false;
    if (_lockAllMovies) return true;
    final pid = _playlistKey(playlistId);
    if (_lockedMovieIds[pid]?.contains(movieId) ?? false) return true;
    if (_lockedVodCategories[pid]?.contains(categoryId) ?? false) return true;
    return false;
  }

  bool isSeriesPlaybackBlocked({
    required String? playlistId,
    required String seriesId,
    required String categoryId,
  }) {
    if (!_enabled || !isPinConfigured) return false;
    if (_lockAllSeries) return true;
    final pid = _playlistKey(playlistId);
    if (_lockedSeriesIds[pid]?.contains(seriesId) ?? false) return true;
    if (_lockedSeriesCategories[pid]?.contains(categoryId) ?? false) {
      return true;
    }
    return false;
  }

  Map<String, dynamic> exportForBackup() {
    return {
      'enabled': _enabled,
      'pinSalt': _pinSaltB64,
      'pinHash': _pinHashHex,
      'lockAllLive': _lockAllLive,
      'lockAllMovies': _lockAllMovies,
      'lockAllSeries': _lockAllSeries,
      'hideRestrictedFromBrowse': _hideRestrictedFromBrowse,
      'liveChannels': {
        for (final e in _lockedLiveChannels.entries)
          e.key: e.value.toList(growable: false),
      },
      'liveCategories': {
        for (final e in _lockedLiveCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'favoriteGroups': _lockedFavoriteGroups.toList(growable: false),
      'movieIds': {
        for (final e in _lockedMovieIds.entries)
          e.key: e.value.toList(growable: false),
      },
      'vodCategories': {
        for (final e in _lockedVodCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'seriesIds': {
        for (final e in _lockedSeriesIds.entries)
          e.key: e.value.toList(growable: false),
      },
      'seriesCategories': {
        for (final e in _lockedSeriesCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'browseHideLiveChannels': {
        for (final e in _browseHideLiveChannels.entries)
          e.key: e.value.toList(growable: false),
      },
      'browseHideLiveCategories': {
        for (final e in _browseHideLiveCategories.entries)
          e.key: e.value.toList(growable: false),
      },
      'browseHideFavoriteGroups': _browseHideFavoriteGroups.toList(growable: false),
    };
  }

  /// Read-only snapshots for the restricted-rules settings screen.
  Map<String, List<String>> get lockedLiveChannelsByPlaylist {
    return {
      for (final e in _lockedLiveChannels.entries)
        e.key: e.value.toList()..sort(),
    };
  }

  Map<String, List<String>> get lockedLiveCategoriesByPlaylist {
    return {
      for (final e in _lockedLiveCategories.entries)
        e.key: e.value.toList()..sort(),
    };
  }

  List<String> get lockedFavoriteGroupIdsSorted =>
      _lockedFavoriteGroups.toList()..sort();

  Map<String, List<String>> get lockedMovieIdsByPlaylist {
    return {
      for (final e in _lockedMovieIds.entries)
        e.key: e.value.toList()..sort(),
    };
  }

  Map<String, List<String>> get lockedVodCategoriesByPlaylist {
    return {
      for (final e in _lockedVodCategories.entries)
        e.key: e.value.toList()..sort(),
    };
  }

  Map<String, List<String>> get lockedSeriesIdsByPlaylist {
    return {
      for (final e in _lockedSeriesIds.entries)
        e.key: e.value.toList()..sort(),
    };
  }

  Map<String, List<String>> get lockedSeriesCategoriesByPlaylist {
    return {
      for (final e in _lockedSeriesCategories.entries)
        e.key: e.value.toList()..sort(),
    };
  }

  Future<void> replaceFromBackup(Map<String, dynamic>? m) async {
    await ensureLoaded();
    if (m == null) {
      await clearPinAndRules();
      return;
    }
    _enabled = m['enabled'] == true;
    _pinSaltB64 = m['pinSalt'] as String?;
    _pinHashHex = m['pinHash'] as String?;
    _lockAllLive = m['lockAllLive'] == true;
    _lockAllMovies = m['lockAllMovies'] == true;
    _lockAllSeries = m['lockAllSeries'] == true;
    _hideRestrictedFromBrowse = m['hideRestrictedFromBrowse'] == true;
    _readStringSetMap(m['liveChannels'], _lockedLiveChannels);
    _readStringSetMap(m['liveCategories'], _lockedLiveCategories);
    _lockedFavoriteGroups
      ..clear()
      ..addAll(_readStringList(m['favoriteGroups']));
    _readStringSetMap(m['movieIds'], _lockedMovieIds);
    _readStringSetMap(m['vodCategories'], _lockedVodCategories);
    _readStringSetMap(m['seriesIds'], _lockedSeriesIds);
    _readStringSetMap(m['seriesCategories'], _lockedSeriesCategories);
    _readStringSetMap(m['browseHideLiveChannels'], _browseHideLiveChannels);
    _readStringSetMap(m['browseHideLiveCategories'], _browseHideLiveCategories);
    _browseHideFavoriteGroups
      ..clear()
      ..addAll(_readStringList(m['browseHideFavoriteGroups']));
    await _persist();
    notifyListeners();
  }
}

final ParentalControlStore parentalControlStore = ParentalControlStore.instance;
