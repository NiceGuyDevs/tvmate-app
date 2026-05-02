import '../../data/library_controller.dart';
import '../../data/recording_approval_store.dart';
import '../../data/xtream_catalog_repository.dart';
import '../live_tv/mock_live_tv_data.dart';

/// Same channel set as [RecordingScreen]’s cross-category list: approved
/// categories/channels, optional catch-up-only filter. Used by the live player
/// Catch-up affordance (no new Recording UI).
List<MockLiveChannel> recordingApprovedChannelsFlattened(String playlistId) {
  final approvedCategories =
      recordingApprovalStore.approvedCategoryIds(playlistId);
  final out = <MockLiveChannel>[];
  final seen = <String>{};
  for (final catId in approvedCategories) {
    final approvedChannels =
        recordingApprovalStore.approvedChannelIds(playlistId, catId);
    final categoryAll = xtreamCatalogRepository.liveChannelsForCategory(catId);
    Iterable<MockLiveChannel> base = categoryAll;
    if (approvedChannels.isNotEmpty) {
      base = categoryAll.where((c) => approvedChannels.contains(c.id));
    }
    if (recordingApprovalStore.filterCatchupOnly(playlistId)) {
      base = base.where((c) => c.hasCatchup);
    }
    for (final ch in base) {
      if (seen.add(ch.id)) out.add(ch);
    }
  }
  return out;
}

/// Whether this stream id can open the same EPG path as Recording → channel.
bool recordingCatchUpAvailableForChannelId(String channelId) {
  final playlistId = libraryController.activePlaylistId;
  if (playlistId == null) return false;
  if (!recordingApprovalStore.isPlaylistApproved(playlistId)) return false;
  return recordingApprovedChannelsFlattened(playlistId)
      .any((c) => c.id == channelId);
}
