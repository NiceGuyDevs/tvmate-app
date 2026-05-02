import 'playlist_type.dart';

/// Locally persisted playlist entry (no live parsing yet — stats are stored as given).
class StoredPlaylist {
  const StoredPlaylist({
    required this.id,
    required this.name,
    required this.type,
    required this.liveCount,
    required this.moviesCount,
    required this.seriesCount,
    this.serverUrl,
    this.username,
    this.password,
    this.m3uUrl,
    /// Xtream `user_info.exp_date` (Unix seconds). Null if unknown / M3U / unlimited.
    this.subscriptionExpiresAtSec,
    this.serverPlaylistId,
    this.ownerUserId,
    this.lastModifiedBy,
    this.locallyRemoved = false,
  });

  final String id;
  final String name;
  final PlaylistType type;
  final int liveCount;
  final int moviesCount;
  final int seriesCount;

  final String? serverUrl;
  final String? username;
  final String? password;
  final String? m3uUrl;

  final int? subscriptionExpiresAtSec;

  /// If non-null, the playlist mirrors a server-side row (admin-pushed).
  /// User edits/deletes on this row propagate back to the server.
  final String? serverPlaylistId;

  /// If non-null, the playlist is scoped to that User id. Other accounts
  /// signed in on the same device must not see it.
  final String? ownerUserId;

  /// 'admin' | 'user' — last actor that mutated this entry.
  final String? lastModifiedBy;

  /// When true the user deleted this server-backed playlist locally but the
  /// server DELETE hasn't confirmed yet. Hidden from the UI; retried on sync.
  final bool locallyRemoved;

  bool get isXtream => type == PlaylistType.xtream;

  /// True for entries pushed by an admin (server-backed).
  bool get isAdminPushed => serverPlaylistId != null;

  StoredPlaylist copyWith({
    String? name,
    int? liveCount,
    int? moviesCount,
    int? seriesCount,
    String? serverUrl,
    String? username,
    String? password,
    String? m3uUrl,
    int? subscriptionExpiresAtSec,
    bool clearSubscriptionExpiresAtSec = false,
    String? serverPlaylistId,
    bool clearServerPlaylistId = false,
    String? ownerUserId,
    bool clearOwnerUserId = false,
    String? lastModifiedBy,
    bool? locallyRemoved,
  }) {
    return StoredPlaylist(
      id: id,
      name: name ?? this.name,
      type: type,
      liveCount: liveCount ?? this.liveCount,
      moviesCount: moviesCount ?? this.moviesCount,
      seriesCount: seriesCount ?? this.seriesCount,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      subscriptionExpiresAtSec: clearSubscriptionExpiresAtSec
          ? null
          : (subscriptionExpiresAtSec ?? this.subscriptionExpiresAtSec),
      serverPlaylistId: clearServerPlaylistId
          ? null
          : (serverPlaylistId ?? this.serverPlaylistId),
      ownerUserId: clearOwnerUserId ? null : (ownerUserId ?? this.ownerUserId),
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      locallyRemoved: locallyRemoved ?? this.locallyRemoved,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.storageValue,
        'liveCount': liveCount,
        'moviesCount': moviesCount,
        'seriesCount': seriesCount,
        'serverUrl': serverUrl,
        'username': username,
        'password': password,
        'm3uUrl': m3uUrl,
        'subscriptionExpiresAtSec': subscriptionExpiresAtSec,
        'serverPlaylistId': serverPlaylistId,
        'ownerUserId': ownerUserId,
        'lastModifiedBy': lastModifiedBy,
        if (locallyRemoved) 'locallyRemoved': true,
      };

  factory StoredPlaylist.fromJson(Map<String, dynamic> j) {
    final rawExp = j['subscriptionExpiresAtSec'];
    int? exp;
    if (rawExp is int) {
      exp = rawExp;
    } else if (rawExp is num) {
      exp = rawExp.toInt();
    }
    return StoredPlaylist(
      id: j['id'] as String,
      name: j['name'] as String,
      type: PlaylistTypeCodec.fromStorage(j['type'] as String?),
      liveCount: (j['liveCount'] as num).toInt(),
      moviesCount: (j['moviesCount'] as num).toInt(),
      seriesCount: (j['seriesCount'] as num).toInt(),
      serverUrl: j['serverUrl'] as String?,
      username: j['username'] as String?,
      password: j['password'] as String?,
      m3uUrl: j['m3uUrl'] as String?,
      subscriptionExpiresAtSec: exp,
      serverPlaylistId: j['serverPlaylistId'] as String?,
      ownerUserId: j['ownerUserId'] as String?,
      lastModifiedBy: j['lastModifiedBy'] as String?,
      locallyRemoved: j['locallyRemoved'] == true,
    );
  }
}

/// Submitted from Add Playlist form before fake ingest runs.
class PlaylistDraft {
  PlaylistDraft.xtream({
    required this.name,
    required this.username,
    required this.password,
    required this.serverUrl,
  })  : type = PlaylistType.xtream,
        m3uUrl = null;

  PlaylistDraft.m3u({
    required this.name,
    required this.m3uUrl,
  })  : type = PlaylistType.m3u,
        username = null,
        password = null,
        serverUrl = null;

  final PlaylistType type;
  final String name;
  final String? username;
  final String? password;
  final String? serverUrl;
  final String? m3uUrl;
}
