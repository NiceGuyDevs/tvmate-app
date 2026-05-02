import 'package:flutter/foundation.dart';

/// Identifies a live channel within a specific saved Xtream playlist.
///
/// [playlistId] empty means **legacy**: the channel id was saved before
/// cross-playlist refs existed and is resolved against the **active** catalog only.
@immutable
class LiveFavoriteChannelRef {
  const LiveFavoriteChannelRef({
    required this.playlistId,
    required this.channelId,
  });

  final String playlistId;
  final String channelId;

  bool get isLegacy => playlistId.isEmpty;

  Map<String, dynamic> toJson() => {
        'playlistId': playlistId,
        'channelId': channelId,
      };

  factory LiveFavoriteChannelRef.fromJson(Map<String, dynamic> m) {
    return LiveFavoriteChannelRef(
      playlistId: m['playlistId'] as String? ?? '',
      channelId: m['channelId'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LiveFavoriteChannelRef &&
        other.playlistId == playlistId &&
        other.channelId == channelId;
  }

  @override
  int get hashCode => Object.hash(playlistId, channelId);
}
