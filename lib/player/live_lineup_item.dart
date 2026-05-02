/// One playable entry in a live channel lineup (same [PlayerScreen], no re-navigation).
class LiveLineupItem {
  const LiveLineupItem({
    required this.title,
    required this.streamUrl,
    this.channelId,
    this.epgChannelId,
    this.iconUrl,
  });

  final String title;
  final String streamUrl;

  /// Xtream / catalog channel id; used for favorites in the player when set.
  final String? channelId;

  /// Panel EPG id when it differs from [channelId]; passed to [LiveEpgController].
  final String? epgChannelId;

  /// Optional channel logo URL (grid / multiview icon strip).
  final String? iconUrl;
}
