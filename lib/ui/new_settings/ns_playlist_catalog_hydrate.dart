/// Fills [NsPlaylist.groups] and [NsPlaylist.channelsMap] from
/// [xtreamCatalogRepository] and the visibility / override stores
/// (same sources as the legacy playlist tools).
library;

import '../../data/library_controller.dart';
import '../../data/playlist_channel_override_store.dart';
import '../../data/playlist_group_visibility_store.dart';
import '../../data/stored_playlist.dart';
import '../../data/xtream_catalog_repository.dart';
import 'new_settings_data.dart';

void hydrateNsPlaylistMapsFromCatalog(NsPlaylist target, StoredPlaylist stored) {
  if (!stored.isXtream) return;
  if (libraryController.activePlaylistId != stored.id) return;

  final pid = stored.id;
  final repo = xtreamCatalogRepository;

  final live = target.groups['live'] ??= <NsPlaylistGroup>[];
  live.clear();
  for (final c in repo.liveCategories) {
    live.add(
      NsPlaylistGroup(
        id: c.id,
        name: c.name,
        alias: playlistGroupVisibilityStore.categoryAlias(
          pid,
          PlaylistGroupSection.live,
          c.id,
        ),
        visible: playlistGroupVisibilityStore.isCategoryVisible(
          pid,
          PlaylistGroupSection.live,
          c.id,
        ),
        beforeFav: playlistGroupVisibilityStore.isLiveCategoryBeforeFavorites(
          pid,
          c.id,
        ),
      ),
    );
  }

  final vod = target.groups['vod'] ??= <NsPlaylistGroup>[];
  vod.clear();
  for (final c in repo.vodCategories) {
    vod.add(
      NsPlaylistGroup(
        id: c.id,
        name: c.name,
        alias: playlistGroupVisibilityStore.categoryAlias(
          pid,
          PlaylistGroupSection.vod,
          c.id,
        ),
        visible: playlistGroupVisibilityStore.isCategoryVisible(
          pid,
          PlaylistGroupSection.vod,
          c.id,
        ),
        beforeFav: false,
      ),
    );
  }

  final series = target.groups['series'] ??= <NsPlaylistGroup>[];
  series.clear();
  for (final c in repo.seriesCategories) {
    series.add(
      NsPlaylistGroup(
        id: c.id,
        name: c.name,
        alias: playlistGroupVisibilityStore.categoryAlias(
          pid,
          PlaylistGroupSection.series,
          c.id,
        ),
        visible: playlistGroupVisibilityStore.isCategoryVisible(
          pid,
          PlaylistGroupSection.series,
          c.id,
        ),
        beforeFav: false,
      ),
    );
  }

  final liveIds = repo.liveCategories.map((e) => e.id).toSet();
  target.channelsMap.removeWhere((k, _) => !liveIds.contains(k));

  for (final cat in repo.liveCategories) {
    final out = <NsPlaylistChannel>[];
    for (final ch in repo.liveChannelsAll) {
      if (ch.categoryId != cat.id) continue;
      out.add(
        NsPlaylistChannel(
          id: ch.id,
          name: ch.name,
          alias: playlistChannelOverrideStore.displayNameOverride(pid, ch.id),
          logo: playlistChannelOverrideStore.logoUrlOverride(pid, ch.id) ??
              ch.iconUrl,
          hidden: playlistChannelOverrideStore.isHidden(pid, ch.id),
          catchup: ch.hasCatchup,
        ),
      );
    }
    target.channelsMap[cat.id] = out;
  }
}
