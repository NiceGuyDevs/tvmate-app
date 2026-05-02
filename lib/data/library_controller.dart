import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_api.dart';
import '../account/account_store.dart';
import 'library_disk_store.dart';
import 'library_store_db.dart';
import 'playlist_epg_timezone_store.dart';
import 'playlist_group_visibility_store.dart';
import 'playlist_type.dart';
import 'stored_playlist.dart';
import 'xtream_catalog_cache_db.dart';

class LibraryController extends ChangeNotifier {
  LibraryController();

  static const _kPlaylists = 'tvmatepro_playlists_v1';
  static const _kActiveId = 'tvmatepro_active_playlist_id';
  static const _kDemo = 'tvmatepro_demo_mode';
  static const _kDemoPlaylistFix = 'tvmatepro_demo_off_when_playlists_fix_v1';
  static const _kLegacyTagApplied = 'tvmatepro_legacy_owner_tag_applied_v1';

  /// Master list including every playlist persisted on this device for
  /// every account that ever signed in here. The visible [playlists] list
  /// is rebuilt from this whenever the active user changes.
  final List<StoredPlaylist> _allPlaylists = [];

  /// Visible playlists for the current user (or guest fallback).
  /// External callers continue to read this; we rebuild it via
  /// [_applyVisibility] whenever the master list or active user changes.
  final List<StoredPlaylist> playlists = [];

  String? activePlaylistId;
  bool demoModeUserPreference = true;
  var _demoPlaylistFixApplied = false;
  var _ready = false;
  bool get isReady => _ready;

  /// Legacy server-id map kept for migrating existing installs. New entries
  /// store the server id on [StoredPlaylist.serverPlaylistId] directly.
  static const _kServerIdMap = 'tvmatepro_server_id_map';
  final Map<String, String> _serverIdMap = {}; // localId → serverId

  Timer? _syncTimer;

  /// Simple async mutex: serialises pullAdminPlaylists, deletePlaylist, and
  /// updatePlaylistDetails so they never race on _allPlaylists.
  Completer<void>? _syncLock;

  Future<void> _acquireLock() async {
    while (_syncLock != null) {
      await _syncLock!.future;
    }
    _syncLock = Completer<void>();
  }

  void _releaseLock() {
    final c = _syncLock;
    _syncLock = null;
    c?.complete();
  }

  /// Called after a cloud pull that changed local playlists.
  /// Wired from [main] to refresh [XtreamCatalogRepository] without a circular import.
  void Function()? onAfterCloudSyncChanged;

  bool get useDemoData => playlists.isEmpty;

  StoredPlaylist? get activePlaylist {
    if (activePlaylistId == null) return null;
    for (final p in playlists) {
      if (p.id == activePlaylistId) return p;
    }
    return null;
  }

  String? get _currentUserId {
    final id = accountStore.user?['id'];
    return id is String ? id : null;
  }

  bool _isVisible(StoredPlaylist p, String? currentUserId) {
    if (p.locallyRemoved) return false;
    final owner = p.ownerUserId;
    if (owner == null) return true; // legacy / guest
    return owner == currentUserId;
  }

  void _applyVisibility() {
    final uid = _currentUserId;
    playlists
      ..clear()
      ..addAll(_allPlaylists.where((p) => _isVisible(p, uid)));
    if (activePlaylistId == null ||
        !playlists.any((p) => p.id == activePlaylistId)) {
      activePlaylistId = playlists.isEmpty ? null : playlists.first.id;
    }
  }

  /// Rebuilds the visible [playlists] list from disk-backed master list
  /// based on the currently signed-in user. Call after sign-in / sign-out.
  Future<void> refreshVisibility() async {
    _applyVisibility();
    await _persist();
    notifyListeners();
  }

  Map<String, dynamic>? _jsonMap(Object? v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  bool _tryLoadFromLibraryMap(Map<String, dynamic>? m) {
    if (m == null) return false;
    if (m['v'] != kLibraryDiskFormatVersion) return false;
    final pl = m['playlists'];
    if (pl is! List || pl.isEmpty) return false;
    final next = <StoredPlaylist>[];
    for (final e in pl) {
      final row = _jsonMap(e);
      if (row == null) continue;
      try {
        next.add(StoredPlaylist.fromJson(row));
      } catch (err, st) {
        debugPrint('LibraryController: skip entry $err\n$st');
      }
    }
    if (next.isEmpty) return false;
    _allPlaylists
      ..clear()
      ..addAll(next);
    activePlaylistId = m['activePlaylistId'] as String?;
    demoModeUserPreference = m['demoMode'] as bool? ?? false;
    _demoPlaylistFixApplied = m['demoFixApplied'] as bool? ?? false;
    return true;
  }

  Map<String, dynamic> _libraryPayloadMap() {
    // Persist the master list (every account / legacy entry) — visibility
    // filtering happens in memory at read time only.
    return {
      'v': kLibraryDiskFormatVersion,
      'playlists': _allPlaylists.map((e) => e.toJson()).toList(),
      'activePlaylistId': activePlaylistId,
      'demoMode': demoModeUserPreference,
      'demoFixApplied': _demoPlaylistFixApplied,
    };
  }

  /// Library section for JSON backup / restore.
  Map<String, dynamic> exportLibraryForBackup() =>
      Map<String, dynamic>.from(_libraryPayloadMap());

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _allPlaylists.clear();
    activePlaylistId = prefs.getString(_kActiveId);
    _demoPlaylistFixApplied = prefs.getBool(_kDemoPlaylistFix) ?? false;

    var loaded = _tryLoadFromLibraryMap(await libraryStoreDb.readPayload());
    if (!loaded) {
      loaded = _tryLoadFromLibraryMap(await xtreamCatalogCacheDb.readLibraryPayload());
    }
    if (!loaded) {
      loaded = _tryLoadFromLibraryMap(await LibraryDiskStore.load());
    }
    if (!loaded) {
      final raw = prefs.getString(_kPlaylists);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List<dynamic>) {
            for (final e in decoded) {
              final row = _jsonMap(e);
              if (row == null) continue;
              try {
                _allPlaylists.add(StoredPlaylist.fromJson(row));
              } catch (err, st) {
                debugPrint('LibraryController: skip bad playlist entry $err\n$st');
              }
            }
          }
        } catch (e, st) {
          debugPrint('LibraryController: failed to load playlists JSON $e\n$st');
        }
      }
    }

    await _loadServerIdMap();
    _applyVisibility();

    if (playlists.isEmpty) {
      activePlaylistId = null;
      demoModeUserPreference = prefs.getBool(_kDemo) ?? true;
      _demoPlaylistFixApplied = prefs.getBool(_kDemoPlaylistFix) ?? false;
    } else {
      demoModeUserPreference = false;
      _demoPlaylistFixApplied = true;
    }

    if (_allPlaylists.isNotEmpty) {
      await _persist();
    }

    _ready = true;
    notifyListeners();

    // Kick off admin-pushed playlist pull in background (non-blocking)
    if (accountStore.isLoggedIn) {
      tagUntaggedPlaylistsForCurrentUser()
          .then((_) => pullAdminPlaylists())
          .then((_) => startPeriodicSync());
    }
  }

  Future<void> _persist() async {
    final listMaps = _allPlaylists.map((e) => e.toJson()).toList();
    final payload = _libraryPayloadMap();
    await libraryStoreDb.savePayload(payload);
    await xtreamCatalogCacheDb.saveLibraryPayload(payload);
    try {
      await LibraryDiskStore.save(
        playlists: listMaps,
        activePlaylistId: activePlaylistId,
        demoMode: demoModeUserPreference,
        demoFixApplied: _demoPlaylistFixApplied,
      );
    } catch (e, st) {
      debugPrint('LibraryDiskStore.save failed: $e\n$st');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlaylists, jsonEncode(listMaps));
    if (activePlaylistId != null) {
      await prefs.setString(_kActiveId, activePlaylistId!);
    } else {
      await prefs.remove(_kActiveId);
    }
    await prefs.setBool(_kDemo, demoModeUserPreference);
    await prefs.setBool(_kDemoPlaylistFix, _demoPlaylistFixApplied);
  }

  // ── Admin-Pushed Playlist Pull (one-way) ───────────────────────

  Future<void> _loadServerIdMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kServerIdMap);
    _serverIdMap.clear();
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          _serverIdMap[e.key] = e.value as String;
        }
      } catch (_) {}
    }
  }

  Future<void> _saveServerIdMap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerIdMap, jsonEncode(_serverIdMap));
  }

  /// Pulls playlists pushed by an admin to this (user, device) pair.
  /// One-way only: the server is authoritative for admin-pushed entries.
  /// User-added local playlists are NEVER uploaded.
  Future<void> pullAdminPlaylists() async {
    if (_syncLock != null || !accountStore.isLoggedIn) return;
    final uid = _currentUserId;
    if (uid == null) return;

    // Skip entirely when the access token lacks a deviceId — the server would
    // return [] which would incorrectly wipe all local server-backed playlists.
    final devId = accountStore.deviceId;
    if (devId == null || devId.isEmpty) {
      debugPrint('[LibrarySync] skipping pull: no deviceId on account store');
      return;
    }

    await _acquireLock();
    try {
      // ── Retry any pending local soft-deletes from previous cycles ──
      await _retryPendingDeletes(uid);

      final serverList = await accountApi.getPlaylists();
      final serverById = <String, Map<String, dynamic>>{
        for (final raw in serverList)
          ((raw as Map<String, dynamic>)['id'] as String): raw,
      };

      var changed = false;

      // Index existing server-backed rows for this user (by serverPlaylistId).
      final ownedServerIdToIdx = <String, int>{};
      for (var i = 0; i < _allPlaylists.length; i++) {
        final p = _allPlaylists[i];
        if (p.ownerUserId == uid && p.serverPlaylistId != null) {
          ownedServerIdToIdx[p.serverPlaylistId!] = i;
        }
      }

      // Upsert server entries.
      for (final raw in serverList) {
        final sp = raw as Map<String, dynamic>;
        final serverId = sp['id'] as String;
        final isHidden = sp['hidden'] == true;
        final typeStr = sp['type'] as String? ?? 'xtream';
        final lastModifiedBy = sp['lastModifiedBy'] as String? ?? 'admin';

        final existingIdx = ownedServerIdToIdx[serverId];
        if (existingIdx != null) {
          final local = _allPlaylists[existingIdx];

          // Never resurrect a playlist the user deleted locally but the server
          // hasn't acknowledged yet.
          if (local.locallyRemoved) continue;

          // Don't clobber a row the user just edited locally — but admin re-pushes
          // (lastModifiedBy='admin') always win.
          if (lastModifiedBy == 'admin') {
            final merged = local.copyWith(
              name: (sp['name'] as String?)?.trim().isNotEmpty == true
                  ? (sp['name'] as String).trim()
                  : local.name,
              serverUrl: isHidden ? local.serverUrl : (sp['serverUrl'] as String?) ?? local.serverUrl,
              username: isHidden ? local.username : (sp['username'] as String?) ?? local.username,
              password: isHidden ? local.password : (sp['password'] as String?) ?? local.password,
              m3uUrl: isHidden ? local.m3uUrl : (sp['m3uUrl'] as String?) ?? local.m3uUrl,
              lastModifiedBy: 'admin',
            );
            if (merged.name != local.name ||
                merged.serverUrl != local.serverUrl ||
                merged.username != local.username ||
                merged.password != local.password ||
                merged.m3uUrl != local.m3uUrl ||
                merged.lastModifiedBy != local.lastModifiedBy) {
              _allPlaylists[existingIdx] = merged;
              changed = true;
            }
          }
          continue;
        }

        // If this server id belongs to a locallyRemoved entry, don't re-add it.
        final isLocallyRemoved = _allPlaylists.any((p) =>
            p.ownerUserId == uid &&
            p.serverPlaylistId == serverId &&
            p.locallyRemoved);
        if (isLocallyRemoved) continue;

        // New server-pushed playlist — insert into local store tagged for this user.
        final localId = 'pl_${DateTime.now().microsecondsSinceEpoch}_${serverId.hashCode.abs()}';
        final added = StoredPlaylist(
          id: localId,
          name: (sp['name'] as String?)?.trim().isNotEmpty == true
              ? (sp['name'] as String).trim()
              : 'Untitled',
          type: PlaylistTypeCodec.fromStorage(typeStr),
          liveCount: 0,
          moviesCount: 0,
          seriesCount: 0,
          serverUrl: sp['serverUrl'] as String?,
          username: sp['username'] as String?,
          password: sp['password'] as String?,
          m3uUrl: sp['m3uUrl'] as String?,
          serverPlaylistId: serverId,
          ownerUserId: uid,
          lastModifiedBy: lastModifiedBy,
        );
        _allPlaylists.add(added);
        changed = true;
      }

      // Remove local server-backed rows that the admin hard-deleted on the
      // server. Guard: only run this removal when the server returned a
      // non-empty list, OR when we have zero local server-backed playlists
      // (nothing to lose). An empty response from a degraded/tokenless call
      // must never wipe the local library.
      final localServerCount = _allPlaylists.where((p) =>
          p.ownerUserId == uid &&
          p.serverPlaylistId != null &&
          !p.locallyRemoved).length;
      final allowRemoval = serverList.isNotEmpty || localServerCount == 0;

      if (allowRemoval) {
        final toRemoveLocalIds = <String>[];
        for (final p in _allPlaylists) {
          if (p.ownerUserId != uid) continue;
          if (p.locallyRemoved) continue;
          final sid = p.serverPlaylistId;
          if (sid == null) continue;
          if (!serverById.containsKey(sid)) {
            toRemoveLocalIds.add(p.id);
          }
        }
        for (final id in toRemoveLocalIds) {
          _allPlaylists.removeWhere((p) => p.id == id);
          await xtreamCatalogCacheDb.deleteForPlaylist(id);
          await playlistGroupVisibilityStore.removePlaylist(id);
          await playlistEpgTimezoneStore.removePlaylist(id);
          if (activePlaylistId == id) {
            activePlaylistId = null;
          }
          changed = true;
        }
      } else if (localServerCount > 0) {
        debugPrint('[LibrarySync] server returned empty list — skipping '
            'removal of $localServerCount local server-backed playlists');
      }

      if (changed) {
        _applyVisibility();
        if (playlists.isNotEmpty) {
          demoModeUserPreference = false;
          _demoPlaylistFixApplied = true;
        }
        await _persist();
        notifyListeners();
        try {
          onAfterCloudSyncChanged?.call();
        } catch (e, st) {
          debugPrint('[LibrarySync] onAfterCloudSyncChanged failed: $e\n$st');
        }
      }
    } catch (e) {
      debugPrint('[LibrarySync] pull failed: $e');
    } finally {
      _releaseLock();
    }
  }

  /// Retries server DELETE for entries the user removed locally but whose
  /// server soft-delete hasn't been confirmed. Fully removes from
  /// [_allPlaylists] on success or 404.
  Future<void> _retryPendingDeletes(String uid) async {
    final pending = _allPlaylists
        .where((p) =>
            p.ownerUserId == uid &&
            p.locallyRemoved &&
            p.serverPlaylistId != null)
        .toList();
    if (pending.isEmpty) return;

    for (final p in pending) {
      try {
        await accountApi.deletePlaylist(p.serverPlaylistId!);
        _fullyRemovePlaylist(p.id);
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          _fullyRemovePlaylist(p.id);
        } else {
          debugPrint('[LibrarySync] retry delete failed for ${p.serverPlaylistId}: $e');
        }
      } catch (e) {
        debugPrint('[LibrarySync] retry delete failed for ${p.serverPlaylistId}: $e');
      }
    }
  }

  /// Removes a playlist from [_allPlaylists] and cleans up related caches.
  void _fullyRemovePlaylist(String localId) {
    _allPlaylists.removeWhere((p) => p.id == localId);
    unawaited(xtreamCatalogCacheDb.deleteForPlaylist(localId));
    unawaited(playlistGroupVisibilityStore.removePlaylist(localId));
    unawaited(playlistEpgTimezoneStore.removePlaylist(localId));
    if (activePlaylistId == localId) {
      activePlaylistId = null;
    }
  }

  /// Backwards-compat shim. Older call sites still invoke this name; the new
  /// behaviour is one-way pull only.
  Future<void> syncWithCloud() => pullAdminPlaylists();

  /// Start periodic admin-pushed playlist pull (call after login / app startup).
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => pullAdminPlaylists());
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// First-launch-after-update migration: any legacy playlist that was on this
  /// device before the per-user-scoping update is treated as belonging to the
  /// currently signed-in user. Runs once per install.
  Future<void> tagUntaggedPlaylistsForCurrentUser() async {
    final uid = _currentUserId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kLegacyTagApplied) == true) return;

    var changed = false;
    for (var i = 0; i < _allPlaylists.length; i++) {
      final p = _allPlaylists[i];
      if (p.ownerUserId == null && p.serverPlaylistId == null) {
        _allPlaylists[i] = p.copyWith(ownerUserId: uid);
        changed = true;
      }
    }
    await prefs.setBool(_kLegacyTagApplied, true);
    if (changed) {
      _applyVisibility();
      await _persist();
      notifyListeners();
    }
  }

  Future<void> setDemoMode(bool enabled) async {
    if (playlists.isNotEmpty) return;
    demoModeUserPreference = enabled;
    await _persist();
    notifyListeners();
  }

  int _indexInAllById(String id) =>
      _allPlaylists.indexWhere((p) => p.id == id);

  Future<void> addPlaylist({
    required PlaylistDraft draft,
    required int liveCount,
    required int moviesCount,
    required int seriesCount,
    int? subscriptionExpiresAtSec,
  }) async {
    final id = 'pl_${DateTime.now().microsecondsSinceEpoch}';
    final ownerUserId = _currentUserId;
    final p = switch (draft.type) {
      PlaylistType.xtream => StoredPlaylist(
          id: id,
          name: draft.name.trim(),
          type: PlaylistType.xtream,
          liveCount: liveCount,
          moviesCount: moviesCount,
          seriesCount: seriesCount,
          serverUrl: draft.serverUrl?.trim(),
          username: draft.username?.trim(),
          password: draft.password,
          subscriptionExpiresAtSec: subscriptionExpiresAtSec,
          ownerUserId: ownerUserId,
          lastModifiedBy: 'user',
        ),
      PlaylistType.m3u => StoredPlaylist(
          id: id,
          name: draft.name.trim(),
          type: PlaylistType.m3u,
          liveCount: liveCount,
          moviesCount: moviesCount,
          seriesCount: seriesCount,
          m3uUrl: draft.m3uUrl?.trim(),
          subscriptionExpiresAtSec: null,
          ownerUserId: ownerUserId,
          lastModifiedBy: 'user',
        ),
    };
    _allPlaylists.add(p);
    activePlaylistId = id;
    demoModeUserPreference = false;
    _demoPlaylistFixApplied = true;
    _applyVisibility();
    await _persist();
    notifyListeners();

    // User-added playlists are local-only now. We still trigger a pull so any
    // newly admin-pushed entries show up alongside the new local one.
    if (accountStore.isLoggedIn) {
      pullAdminPlaylists().catchError((_) {});
    }
  }

  Future<void> setActivePlaylist(String id) async {
    if (!playlists.any((p) => p.id == id)) return;
    activePlaylistId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    final i = _indexInAllById(id);
    if (i < 0) return;
    _allPlaylists[i] = _allPlaylists[i].copyWith(
      name: name,
      lastModifiedBy: 'user',
    );
    _applyVisibility();
    await _persist();
    notifyListeners();
  }

  /// Updates display name and connection fields (Xtream: server, user, pass; M3U: URL).
  /// Caller should evict [xtreamCatalogCacheDb] / [playlistLiveCatalogCache] and run
  /// [XtreamCatalogRepository.syncFromLibrary] when credentials change.
  Future<void> updatePlaylistDetails({
    required String id,
    required String name,
    String? serverUrl,
    String? username,
    String? password,
    String? m3uUrl,
  }) async {
    await _acquireLock();
    try {
      await _updatePlaylistDetailsLocked(
        id: id,
        name: name,
        serverUrl: serverUrl,
        username: username,
        password: password,
        m3uUrl: m3uUrl,
      );
    } finally {
      _releaseLock();
    }
  }

  Future<void> _updatePlaylistDetailsLocked({
    required String id,
    required String name,
    String? serverUrl,
    String? username,
    String? password,
    String? m3uUrl,
  }) async {
    final i = _indexInAllById(id);
    if (i < 0) return;
    final p = _allPlaylists[i];
    final n = name.trim();
    if (n.isEmpty) return;

    if (p.isXtream) {
      final su = (serverUrl ?? p.serverUrl ?? '').trim();
      final u = (username ?? p.username ?? '').trim();
      if (su.isEmpty || u.isEmpty) return;
      _allPlaylists[i] = p.copyWith(
        name: n,
        serverUrl: su,
        username: u,
        password: password ?? p.password,
        lastModifiedBy: 'user',
      );
    } else {
      final m = (m3uUrl ?? p.m3uUrl ?? '').trim();
      if (m.isEmpty) return;
      _allPlaylists[i] = p.copyWith(
        name: n,
        m3uUrl: m,
        lastModifiedBy: 'user',
      );
    }

    _applyVisibility();
    await _persist();
    notifyListeners();

    // Propagate user edits back ONLY for admin-pushed rows (so the admin can
    // see the change). Pure local rows stay on the device.
    final serverId = p.serverPlaylistId ?? _serverIdMap[id];
    if (serverId != null && accountStore.isLoggedIn) {
      try {
        await accountApi.updatePlaylist(serverId,
          name: n,
          serverUrl: serverUrl,
          username: username,
          password: password,
          m3uUrl: m3uUrl,
        );
      } catch (e) {
        debugPrint('[LibrarySync] update server failed: $e');
      }
    }
  }

  /// Updates Xtream subscription expiry from `user_info.exp_date` after auth/sync.
  Future<void> updatePlaylistSubscriptionExpiry(
    String id,
    int? subscriptionExpiresAtSec,
  ) async {
    final i = _indexInAllById(id);
    if (i < 0) return;
    _allPlaylists[i] = _allPlaylists[i].copyWith(
      subscriptionExpiresAtSec: subscriptionExpiresAtSec,
    );
    _applyVisibility();
    await _persist();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _acquireLock();
    try {
      await _deletePlaylistLocked(id);
    } finally {
      _releaseLock();
    }
  }

  Future<void> _deletePlaylistLocked(String id) async {
    final wasLoggedIn = accountStore.isLoggedIn;
    final i = _indexInAllById(id);
    if (i < 0) return;
    final entry = _allPlaylists[i];

    final serverId = entry.serverPlaylistId ?? _serverIdMap[id];
    final isServerBacked = serverId != null && wasLoggedIn;

    if (isServerBacked) {
      // Mark as locally removed first so it vanishes from the UI immediately.
      _allPlaylists[i] = entry.copyWith(locallyRemoved: true);
      _applyVisibility();
      if (playlists.isEmpty) demoModeUserPreference = true;
      await _persist();
      notifyListeners();

      // Attempt server soft-delete.
      var serverOk = false;
      try {
        await accountApi.deletePlaylist(serverId);
        serverOk = true;
      } on ApiException catch (e) {
        if (e.statusCode == 404) serverOk = true;
        debugPrint('[LibrarySync] delete from server: $e');
      } catch (e) {
        debugPrint('[LibrarySync] delete from server failed: $e');
      }

      if (serverOk) {
        _fullyRemovePlaylist(id);
        _serverIdMap.remove(id);
        await _saveServerIdMap();
        _applyVisibility();
        if (playlists.isEmpty) demoModeUserPreference = true;
        await _persist();
        notifyListeners();
      }
      // If !serverOk, the entry stays with locallyRemoved=true. The next
      // pullAdminPlaylists cycle will retry the server DELETE.
    } else {
      // Pure local playlist — remove immediately.
      _allPlaylists.removeWhere((p) => p.id == id);
      await xtreamCatalogCacheDb.deleteForPlaylist(id);
      await playlistGroupVisibilityStore.removePlaylist(id);
      await playlistEpgTimezoneStore.removePlaylist(id);
      if (activePlaylistId == id) activePlaylistId = null;
      _applyVisibility();
      if (playlists.isEmpty) demoModeUserPreference = true;
      await _persist();
      notifyListeners();
    }
  }

  /// Replaces playlists from backup (clears catalog rows + visibility per old id).
  /// Restored entries replace the master list entirely; admin-pushed entries
  /// will be re-pulled on the next sync.
  Future<void> replaceFromBackup({
    required List<StoredPlaylist> newPlaylists,
    String? newActiveId,
    required bool demoModePref,
    bool demoFixApplied = false,
  }) async {
    final oldIds = [for (final p in _allPlaylists) p.id];
    for (final id in oldIds) {
      await xtreamCatalogCacheDb.deleteForPlaylist(id);
      await playlistGroupVisibilityStore.removePlaylist(id);
      await playlistEpgTimezoneStore.removePlaylist(id);
    }
    _allPlaylists
      ..clear()
      ..addAll(newPlaylists);
    _demoPlaylistFixApplied = demoFixApplied;
    if (newPlaylists.isEmpty) {
      activePlaylistId = null;
      demoModeUserPreference = demoModePref;
    } else {
      activePlaylistId = newActiveId;
      if (activePlaylistId == null ||
          !newPlaylists.any((p) => p.id == activePlaylistId)) {
        activePlaylistId = newPlaylists.first.id;
      }
      demoModeUserPreference = false;
      _demoPlaylistFixApplied = true;
    }
    _applyVisibility();
    await _persist();
    notifyListeners();
  }
}

final LibraryController libraryController = LibraryController();
