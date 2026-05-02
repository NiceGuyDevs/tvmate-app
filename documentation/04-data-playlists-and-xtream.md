# Data: playlists, demo mode, and Xtream

## LibraryController

**File:** `lib/data/library_controller.dart`  
**Global instance:** `libraryController`

### Persisted keys (SharedPreferences)

- `iptvil_playlists_v1` — JSON list of `StoredPlaylist`
- `iptvil_active_playlist_id` — which playlist is selected
- `iptvil_demo_mode` — user preference for demo catalog when playlists exist

**Clock overlay** (`lib/data/clock_overlay_settings_store.dart`): `iptvil_clock_enabled_v1`, `iptvil_clock_24h_v1`, `iptvil_clock_corner_v1` (`tl`/`tr`/`bl`/`br`), `iptvil_clock_size_v1` (`s`/`m`/`l`), `iptvil_clock_opacity_v1`, `iptvil_clock_color_idx_v1` (**0–7**: five standard + **three neon** red/green/yellow), `iptvil_clock_framed_v1` (optional HUD: border + gradient backdrop + **`DD/MM MON`** under the time, weekday **uppercase** via **DSEG** + **Roboto** split in `ClockOverlayLayer`). **Neon indices** select **DSEG7 Classic** for segment glyphs where applicable.

**Legacy My space data** (`lib/data/my_space_store.dart`): **`iptvil_my_space_sections_v1`** — JSON array of sections (id, title, sortOrder, channelIds). **No longer used by UI** (shell **My space** removed); key may remain in **`SharedPreferences`** for existing installs.

**Live TV favorite groups** (`lib/data/live_favorite_groups_store.dart`): **`iptvil_live_favorite_groups_v1`** — named groups (id, name, sortOrder, channelIds); drives **Live TV** pills and **Settings → Favorite setup**.

### `useDemoData` (critical flag)

```text
useDemoData == true  when:
  • no playlists are configured, OR
  • user enabled Demo mode in Settings

useDemoData == false when:
  • at least one playlist exists AND demo mode is off
```

Browse screens branch on this:

- **Demo** — static lists from `mock_*_data.dart` files.
- **Live Xtream** — `XtreamCatalogRepository.syncFromLibrary(libraryController)` then read cached categories/rows from the repository.

### Active playlist

- `activePlaylist` returns the `StoredPlaylist` matching `activePlaylistId`.
- If type is **Xtream**, server URL + username + password are used by `XtreamApiClient`.
- If type is **M3U**, UI may show unsupported messaging on browse (see screen-specific code).

## StoredPlaylist

**File:** `lib/data/stored_playlist.dart`

Fields include: `id`, `name`, `type`, `liveCount`, `moviesCount`, `seriesCount`, and optional `serverUrl`, `username`, `password`, `m3uUrl`. Counts are stored after a successful Xtream load in `PlaylistLoadingScreen`.

## Xtream pipeline

### Client

**File:** `lib/xtream/xtream_api_client.dart`

Typical actions (names may vary slightly in code): auth probe, `get_live_categories`, `get_live_streams`, `get_vod_categories`, `get_vod_streams`, `get_series_categories`, `get_series`, `get_series_info`, **`get_short_epg`**, **`get_simple_data_table`** (EPG tables for a single `stream_id`).

### Mapper

**File:** `lib/xtream/xtream_mapper.dart`

Maps API JSON into the same **UI model types** the mocks use:

- `MockLiveCategory`, `MockLiveChannel` (Xtream: **`streamUrl`**, **`iconUrl`**, optional **`epgChannelId`** from API `epg_channel_id`; placeholder **`programTitle` / `description`** until EPG loads). When **`iconUrl`** is missing or not loadable, **`TvCatalogImage`** shows **`TvUniversalMediaPlaceholder`** (see **`05`**).
- `MockMovieCategory`, `MockMovie`
- `MockSeriesCategory`, `MockSeries`
- For series detail: `MockSeason`, `MockEpisode` with **`streamUrl`** built via `XtreamStreamLinkBuilder`

**Series browse** rows often have **empty `seasons`** until the user opens **series details**, which triggers **`fetchSeriesDetail` / `get_series_info`** and merges episodes into seasons.

### Repository

**File:** `lib/data/xtream_catalog_repository.dart`

- Singleton pattern with `ChangeNotifier`.
- Holds cached lists and last error message.
- `syncFromLibrary(LibraryController)` loads from **disk cache** when valid (see below), otherwise performs the **network** sync and notifies listeners.

### Xtream catalog disk cache (`xtream_catalog_cache`)

**Files:** `lib/data/xtream_catalog_cache_db.dart`, same SQLite file as **`iptvil_xtream_catalog.db`** (under `getDatabasesPath()`).

Large Xtream snapshots (**tens of thousands** of streams) serialize to **many megabytes** of JSON. On **Android**, reading a single huge **`TEXT`** cell through **sqflite** pulls the row into a **`CursorWindow`** with a **~2 MB per-row limit**. Storing **`full_catalog_json`** / **`live_catalog_json`** in SQLite caused **`Row too big to fit into CursorWindow`**, so the catalog **failed to load** after restart (empty Live TV / “demo-like” UI even when playlists still existed).

**Current design (DB v5+):**

- SQLite table **`xtream_catalog_cache`** keeps **metadata only** per playlist: **`playlist_id`**, **`fingerprint`** (credentials hash), **`schema_version`**, **`updated_at_ms`**. The **`full_catalog_json`** / **`live_catalog_json`** columns are **unused** (kept **NULL**); payloads are **not** stored in those cells.
- Payloads are written as **files** next to the DB directory:
  - **`iptvil_cat_full_<playlistId>.json`** — full **`XtreamCatalogSnapshot`** (live + VOD + series lists).
  - **`iptvil_cat_live_<playlistId>.json`** — live-only **`XtreamLiveCatalogPersistV1`** when saved without a full snapshot.
- **`readFullCatalog` / `readLiveCatalog`** query **only small columns**, then **`dart:io` `File.readAsString`** for JSON decode.
- **Migration:** upgrading from DB v4 clears legacy blob columns with **`UPDATE … SET … = NULL`** (one-time; users may **refetch** once after upgrade if the cache was only in SQLite).
- **`deleteForPlaylist`** removes the row and deletes both catalog files if present.

Related: **`app_library`** in the same DB mirrors library JSON for resilience; that payload stays small (credentials + playlist list), not the full catalog.

### Episode model

**File:** `lib/ui/series/mock_series_data.dart` — `MockEpisode`

- `season`, `episode` (ints) — source of truth for **`codename`** getter → `S02E01` style string.
- `title`, `description` from API or mocks.
- `streamUrl` when Xtream mapping provides it.

## Live EPG (Xtream)

**Files:** `lib/data/live_epg_controller.dart`, `lib/xtream/xtream_short_epg_parser.dart`

- **`LiveEpgController`** is a **`ChangeNotifier`** singleton. Call **`refreshForStream(streamId, { epgChannelId })`** when the user focuses a channel (Live TV grid/hero) or switches channels inside the player.
- **Per-channel reads (do not rely on `focusedStreamId` alone):** **`lookupDisplay(streamId)`**, **`lookupListings(streamId)`**, **`isLoadingFor(streamId)`** — return cached / in-flight data for that id so **hero**, **grid tiles**, and **fullscreen player** stay in sync when another widget refreshes EPG for a different stream.
- **Not used in demo mode** (`useDemoData`): overlay display is cleared.
- **Fetch strategy**
  1. Build candidate ids: **`epgChannelId`** first (if non-empty), then **`streamId`** (deduped). Many panels key EPG on XMLTV id, not the live stream id.
  2. For each candidate, call **`get_short_epg`**; if parsed listings are empty, call **`get_simple_data_table`** with the same id.
  3. Pick **current or next** listing (`pickCurrentOrNextXtreamListing`): prefers **`now_playing`**, then time window `[start, end)`, then next future start. Falls back to **first listing** if needed.
- **Parser** accepts varied JSON: root **`epg_listings`** or alternate keys (`listings`, `data`, `programs`), **Unix or string** `start`/`end`, **`now_playing`**, base64 titles, **localized title maps** (object of language → string).
- **Cache:** in-memory per `streamId` (~2 minutes, or until program end when sooner). **`focusedStreamId`** tracks the last **refresh** target; UI should use **`lookupDisplay` / `lookupListings`** with the **channel id being rendered** so hero/player/tiles do not blank when focus diverges.
- **UI model:** `LiveNowEpgDisplay` — title, description, `progress01`, `isOnAir`, optional `programStart` / `programEnd` for clocks and “ends in …”.

## EPG time display (`PlaylistEpgTimezoneStore`)

**Files:** `lib/data/playlist_epg_timezone_store.dart`, `lib/data/epg_time_display.dart`, `lib/data/epg_timezone_catalog.dart`, `lib/ui/settings/playlist_epg_time_screen.dart`

- **Prefs:** **`iptvil_epg_display_mode_<playlistId>`** — string: **`local`** (default), **`original`**, or an **IANA** timezone id (e.g. `Asia/Jerusalem`). Legacy **`iptvil_epg_tz_local_<playlistId>`** (bool) is still read on first load and mapped to `local` / `original`.
- **Catch-up URLs (unchanged):** **`iptvil_epg_server_utc_offset_<playlistId>`** — `double` hours from Xtream **`server_info.timezone`**; used for timeshift `start=` construction, **not** for choosing which timezone label to draw on screen.
- **Catalog:** `kEpgTimezoneCatalog` lists user-facing **labels** + **chip shorts** + IANA ids for the picker.
- **Dependency:** **`timezone`** — `initializeTimeZones()` in **`main.dart`** before `runApp`.

## Playlist group visibility (Manage groups)

**File:** `lib/data/playlist_group_visibility_store.dart`  
**Prefs key:** `iptvil_group_visibility_v1` (JSON: playlist id → rules)

Per **active playlist** and **section** (Live / Movies / Series), the store persists:

- **Hidden category ids** — categories the user turned off in **Settings → Manage groups →** TV, Movies, or Shows.
- **Aliases** — optional custom display names per category id (`aliases` in JSON).
- **Live TV only — pill order before favorites** — ordered list of **live** category ids that should appear as **category pills to the left of** (before) the user’s **favorite group** pills. Default behavior remains **favorite groups first**, then remaining visible playlist categories. **`liveBeforeFavorites`** in JSON is this ordered list (1 = leftmost among pinned-before-favorites pills). Setting a category to **after favorites** removes it from that list; hiding a live category removes it from the list.

**UI:** `playlist_group_manager_screen.dart` — Live rows include a **move-up** control opening a small panel (**after** vs **before** favorites, **position** when before). Strings are localized (`playlistGroupPill*` keys in **`app_en.arb`** and all supported locales: **en, he, ar, es, fr**).

**Backup:** Included inside the **`groupVisibility`** object in full settings backup / restore (`PlaylistGroupVisibilityStore.exportForBackup` / `replaceFromBackup`). See **`09-backup-system.md`**.

## My List

**File:** `lib/data/my_list_store.dart`

- Separate persisted id lists for **movies**, **series**, and **live channels**.
- Movies/series: detail compact actions (`detail_actions.dart` pattern).
- Live: **Favorites** picker / Live TV flows; keys include **`my_list_live_channel_ids`** (see source for exact `SharedPreferences` key constants).

## VOD resume

**File:** `lib/player/playback_resume_store.dart`

- Position saved periodically during VOD playback when `resumeContentId` is passed into `PlayerScreen`.
- Series episodes use ids like `episode_${e.id}` from `series_details_screen.dart` (verify in code if refactored).

For **VOD watch labels** (watching / continue / watched), **My List pills**, **Appearance** options for movie/series rails, **IMDb** chips, and **player auto-label** rules, see **`13-vod-labels-imdb-posters.md`**.

## Mock stream fallbacks

**File:** `lib/player/mock_stream_urls.dart`

When a catalog item has **no** `streamUrl`, some flows still call the player with demo HLS URLs — replace with real panel URLs as ingestion matures.

**Empty-library / demo playback:** `kIptvilSingleDemoHls` is the **single** canonical Apple **Bipbop** test HLS URL used for **`mockLiveStreamUrlForChannel`**, **`mockVodStreamUrlForMovie`**, and **`mockVodStreamUrlForEpisode`** so first-run browse always resolves the **same** stream when opening the player from demo data.

**Demo catalog density (no playlists):** `lib/ui/live_tv/mock_live_tv_data.dart` exposes a **large** `kMockLiveChannels` list (dozens of rows) with per-channel **`iconUrl`** (stable **picsum.photos** seeds) for a populated grid; **`mock_movies_data.dart`** / **`mock_series_data.dart`** add **`coverUrl`** / **`backdropUrl`** the same way so Movies/Series rails show **network** posters. **Requires network** for those images; offline-first demo would need bundled assets instead.
