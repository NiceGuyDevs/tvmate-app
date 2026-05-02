# Recording / EPG / Catch-up System

## Overview

The Recording system lets users browse past TV programs (catch-up / timeshift) and play them using the existing VOD player. It consists of two main areas:

1. **Settings side** -- a three-step approval flow where the user selects which playlists, categories, and channels appear in the Recording screen. Includes a catch-up filter toggle that hides channels without catch-up support, and an optional **TV frame on EPG** toggle (per playlist) that draws a bezel image behind channel logos on Recording EPG programme rows only.
2. **Front-facing side** -- a "Recording" top-menu entry that shows approved categories, a date column (max 10 days back), a channel grid, and an EPG timeline for selecting and playing past programs. Uses the same **shell cosmic backdrop** as other tabs (transparent body over `CosmicSpaceBackdrop`); horizontal inset and softer TV focus animation reduce clipping on real TVs.

The system does not record or store video locally. It builds Xtream timeshift URLs for past programs and hands them to the same player used for Movies and Series.

### EPG time (per playlist)

Each playlist has its own **EPG time** mode for how programme **start/end** times are **shown** (not catch-up URL construction — that still uses the server UTC offset from `server_info`).

**UI:** **Settings → My playlists** → **EPG** chip on a playlist card opens **`PlaylistEpgTimeScreen`** (`lib/ui/settings/playlist_epg_time_screen.dart`): centered column (~**640** logical px max width, same pattern as **Manage groups →** category list). **Local** is the first row (device timezone). Below that, a scrollable list includes **Original (server)** (raw wall times from provider strings when available) and a **curated set of IANA zones** (e.g. Israel, Pakistan, New York — see `kEpgTimezoneCatalog` in `lib/data/epg_timezone_catalog.dart`). Choosing a row saves immediately and closes the screen. The playlist card chip shows **EPG: Local**, **EPG: Original**, or **EPG:** plus a short zone label (for example NY, IL).

**Storage:** `PlaylistEpgTimezoneStore` — `SharedPreferences` key **`iptvil_epg_display_mode_<playlistId>`** with values **`local`** (default), **`original`**, or a full **IANA** id (e.g. `America/New_York`). Legacy installs may still have **`iptvil_epg_tz_local_<playlistId>`** (bool); on load, `true` → `local`, `false` → `original`, then the new mode key is used going forward.

**Implementation:** `lib/data/epg_time_display.dart` centralizes formatting (`formatEpgTimeRangeForPlaylist`, `formatEpgProgramTime`). The **`timezone`** package is initialized in **`main.dart`** (`initializeTimeZones()`). Live TV hero / player bottom bar / fullscreen EPG overlay and Recording EPG list all respect the **active** playlist’s mode when showing ranges.

### TV frame on EPG (optional)

- Per-playlist boolean **`tvFrameEpg`** in `RecordingApprovalStore` (default **off**), toggled from **Settings → Recording → [playlist] → Categories** (full-width row under Select All / Clear All / catch-up filter).
- When **on**, each programme row in **Recording → EPG mode** shows the channel logo inside **`assets/images/recording_tv_frame.png`** (`BoxFit.contain` for bezel + logo). When **off**, the same larger logo slot is used without the bezel asset (flat `ClipRRect` + network logo).
- Does **not** affect Live TV or other tabs — only the Recording EPG timeline list.

---

## Architecture

```
Settings Side                          Top Menu Side
--------------                         --------------
RecordingEditScreen (Step A)           RecordingScreen
  |                                      |
  v                                      +-- Category capsules (approved only)
RecordingCategoryApprovalScreen (B)      +-- Date column (today .. 10 days back)
  |                                      +-- Browse state: channel grid
  v                                      +-- EPG mode: compact channel row + timeline
RecordingChannelApprovalScreen (C)       |
  |                                      v
  v                                    openIptvilPlayer (VOD mode)
RecordingApprovalStore
  |
  +-- SharedPreferences (iptvil_recording_approval_v1)
  +-- Backup/restore via IptvilBackupService

Data Layer
----------
MockLiveChannel         -- tvArchive, tvArchiveDuration, hasCatchup, catchupDays
XtreamStreamLinkBuilder -- catchupUrlWithDuration()
XtreamApiClient         -- getAllEpg(), getFullDayEpg(), getShortEpg()
RecordingEpgLoader      -- fetchDay(), preloadXmltv(), per-(channel,date) cache
XmltvEpgCache           -- SQLite-backed XMLTV EPG store (persistent across sessions)
PlaylistEpgTimezoneStore -- per-playlist EPG display mode (`local` / `original` / IANA) + server UTC offset for catch-up URLs
```

### Data flow: EPG fetch to playback

```
1. User enters Recording screen
2. initState triggers:
   a. refreshServerTimezone() — fetches server_info, stores UTC offset
   b. RecordingEpgLoader.preloadXmltv() — downloads xmltv.php in background,
      parses all <programme> elements, persists to SQLite DB
3. User selects a channel in browse state
4. RecordingScreen calls RecordingEpgLoader.fetchDay(streamId, date, epgChannelId)
5. RecordingEpgLoader (3-strategy approach):
   a. Checks in-memory cache (keyed by "streamId|YYYY-MM-DD", 10-min TTL)
   b. If stale or missing: reads active playlist credentials
   c. Builds candidate IDs: [epgChannelId, streamId]
   d. Strategy 1 — get_simple_data_table with ONLY stream_id (no limit/date params):
      Returns ALL EPG data (past + future) for the stream. This is the primary
      source for both today and past days.
   e. Strategy 2 — get_short_epg / getFullDayEpg():
      Near-now window fallback if Strategy 1 returned too few results.
   f. Strategy 3 — XMLTV SQLite DB:
      Queries locally persisted XMLTV data. Accumulates over time — each
      download captures today+3 days forward, which becomes historical data
      for future sessions.
   g. Filters to only programs whose start falls on the requested calendar day
      AND whose start is not in the future (past or currently airing)
   h. Sorts oldest-first, caches result, notifies listeners
6. _EpgTimeline widget rebuilds, shows program cards
7. User activates a program card
8. _playProgram() builds a catch-up URL:
   - Reads active playlist credentials (serverUrl, username, password)
   - Calls XtreamStreamLinkBuilder.catchupUrlWithDuration(streamId, startRaw, durationMin)
   - URL format: {origin}/streaming/timeshift.php?username=...&password=...
     &stream=...&start=YYYY-MM-DD:HH-MM&duration={minutes}
   - startRaw comes directly from the server's EPG data (no timezone conversion)
   - durationMin is calculated from listing.end - listing.start
9. Calls openIptvilPlayer(context, title, streamUrl, isLive: false, contentDescription)
10. Existing VOD player opens with full seek/pause/resume controls
```

---

## EPG Data Sources (3-Strategy Approach)

The system uses three complementary data sources to maximize EPG coverage:

### Strategy 1: `get_simple_data_table` (Primary)

- Endpoint: `player_api.php?action=get_simple_data_table&stream_id=X`
- Called with **only** `stream_id` — no `limit`, no `start`/`end` parameters
- According to Xtream API docs, returns ALL EPG data (past + future) for the stream
- This is the most reliable source for historical EPG on most providers
- Titles and descriptions are base64-encoded; the parser auto-detects and decodes them

### Strategy 2: `get_short_epg` / `getFullDayEpg` (Fallback)

- Endpoint: `player_api.php?action=get_short_epg&stream_id=X&limit=2000`
- Returns a sliding window of programs around "now"
- Used as supplement when Strategy 1 returns very few results
- Also tries `get_simple_data_table` with date range parameters as part of `getFullDayEpg()`

### Strategy 3: XMLTV SQLite Database (Accumulated History)

- Endpoint: `xmltv.php?username=X&password=Y`
- Downloads the full XMLTV XML feed (~5MB for ~12,000 programmes)
- Parsed via regex (fast, tolerant of malformed XML)
- **Persisted to a local SQLite database** (`iptvil_xmltv_epg.db`)
- Each download is merged (upserted) with existing data
- Over time, today's "future" data becomes tomorrow's "historical" data
- Old data (>12 days) is automatically pruned
- Pre-loaded in background when the Recording screen opens

### XMLTV Channel ID Matching

XMLTV `<programme channel="...">` attributes are matched against our channel data:

1. **Exact match**: `epgChannelId` (e.g., `"88033"`) matches XMLTV channel `"88033"`
2. **Exact match**: `streamId` (e.g., `"27421"`) matches XMLTV channel `"27421"`
3. **Fuzzy match**: Numeric extraction — if the numeric part of our ID matches the numeric part of an XMLTV channel ID (minimum 3 digits)
4. **Fuzzy match**: Contains check — one ID contains the other, or after stripping common suffixes like `.il`, `.uk`, `.us`

### XMLTV Timestamp Parsing

XMLTV uses the format `"20260331201500 +0300"`:
- First 14 digits: `YYYYMMDDHHmmss`
- Optional timezone offset: `+HHMM` or `-HHMM`
- Parsed to UTC by subtracting the offset
- Stored in SQLite as UTC milliseconds for correct cross-timezone queries

---

## Timezone Handling

### Server UTC Offset

- On Recording screen entry, `refreshServerTimezone()` fetches `player_api.php` (no action) to get `server_info`
- Extracts `timezone`, `time_now`, and `timestamp_now` fields
- Calculates the server's UTC offset by comparing `time_now` (string) with `timestamp_now` (epoch)
- Stores the offset via `PlaylistEpgTimezoneStore.setServerUtcOffset(playlistId, offset)`

### EPG String Parsing

- Xtream servers send date strings (e.g., `"2026-03-31 20:25:00"`) in their own timezone (often UTC)
- The parser (`xtream_short_epg_parser.dart`) treats timezone-less strings as **UTC** by appending `'Z'` before parsing
- This ensures correct conversion to device-local `DateTime` objects regardless of device timezone
- Numeric `start_timestamp`/`stop_timestamp` fields (Unix epoch) are always UTC and used preferentially

### EPG Time Display

The `_formatTime()` function in the Recording screen:
- **Local time mode**: Uses the parsed `DateTime` object (already converted to device-local)
- **Original EPG time mode**: Extracts `HH:MM` directly from the raw server string (`startRaw`/`endRaw`)

---

## New Components and Services

### Data layer

| File | Type | Purpose |
|------|------|---------|
| `lib/data/recording_approval_store.dart` | ChangeNotifier + SharedPreferences | Persists which playlists/categories/channels are approved for Recording |
| `lib/data/recording_epg_loader.dart` | ChangeNotifier (singleton) | Fetches, filters, and caches full-day EPG listings per (channel, date). 3-strategy approach with XMLTV preloading. |
| `lib/data/xmltv_epg_cache.dart` | SQLite-backed singleton | Downloads, parses, and persists XMLTV EPG data. Accumulates history across sessions. |
| `lib/data/playlist_epg_timezone_store.dart` | SharedPreferences | Per-playlist EPG time display preference (local vs. original) and server UTC offset |

### Xtream extensions

| File | Change | Purpose |
|------|--------|---------|
| `lib/ui/live_tv/mock_live_tv_data.dart` | Added fields to MockLiveChannel | `tvArchive`, `tvArchiveDuration`, `hasCatchup`, `catchupDays`, `epgChannelId`, `hasPanelEpg` |
| `lib/xtream/xtream_mapper.dart` | Parse new fields | Reads `tv_archive`, `tv_archive_duration`, `epg_channel_id` from Xtream API response |
| `lib/xtream/xtream_stream_urls.dart` | New methods | `catchupUrlWithDuration()` for timeshift.php URLs |
| `lib/xtream/xtream_api_client.dart` | New methods | `getAllEpg()` (no params), `getFullDayEpg()` (multi-strategy), `getServerInfo()` |
| `lib/data/xtream_catalog_snapshot_codec.dart` | Persist new fields | `tvArchive` and `tvArchiveDuration` in cached JSON (version bumped to 2, backward-compatible with v1) |
| `lib/data/xtream_catalog_repository.dart` | New method | `refreshServerTimezone()` — fetches server_info and stores UTC offset |

### Settings UI

| File | Type | Purpose |
|------|------|---------|
| `lib/ui/settings/recording_edit_screen.dart` | StatelessWidget | Step A: lists Xtream playlists, shows approval status |
| `lib/ui/settings/recording_category_approval_screen.dart` | StatelessWidget | Step B: toggle categories, Select All / Clear All, catch-up filter, TV frame on EPG |
| `lib/ui/settings/recording_channel_approval_screen.dart` | StatelessWidget | Step C: toggle channels, catch-up indicator icons |

### Recording front page

| File | Type | Purpose |
|------|------|---------|
| `lib/ui/recording/recording_screen.dart` | StatefulWidget | Main Recording screen with browse state and EPG mode |

### Shell integration

| File | Change |
|------|--------|
| `lib/shell/shell_destination.dart` | Added `ShellDestination.recording` between `series` and `team` |
| `lib/shell/main_shell_screen.dart` | Wired `RecordingScreen` into `_buildDestinationBody` switch |
| `lib/ui/demo/demo_placeholder_pages.dart` | Added `recording` case to exhaustive switch |

### Startup and backup

| File | Change |
|------|--------|
| `lib/main.dart` | Added `recordingApprovalStore.ensureLoaded()` at startup |
| `lib/data/backup/iptvil_backup_service.dart` | Added `recordingApproval` to snapshot export and restore |

---

## RecordingApprovalStore Behavior

### Persistence

- **SharedPreferences key:** `iptvil_recording_approval_v1`
- **Structure:** JSON map keyed by playlist ID. Each value contains:
  - `approvedCategories`: list of category ID strings
  - `approvedChannels`: map of category ID to list of channel ID strings
  - `filterCatchupOnly`: boolean (default false)
  - `tvFrameEpg`: boolean (default false) — optional TV bezel behind channel logos on Recording EPG rows only
- **Loaded once** at app startup via `ensureLoaded()`. All mutation methods call `ensureLoaded()` defensively.
- Every mutation persists immediately via `_persist()` and calls `notifyListeners()`.

### Approval hierarchy

- A playlist is considered "approved" if it has at least one approved category.
- Removing a category also removes all its approved channels.
- The catch-up filter is per-playlist. When enabled:
  - The Recording screen shows **only** channels that have catch-up support (`hasCatchup == true`)
  - Channels without catch-up are completely hidden (not just dimmed)

### Backup integration

- `exportForBackup()` returns the full map (same shape as SharedPreferences).
- `replaceFromBackup(Map?)` clears and replaces all data, then persists.
- The backup JSON key is `recordingApproval` in the top-level backup object.

---

## Settings Flow

### Step A: Playlist Selection (`RecordingEditScreen`)

- Shows all Xtream playlists from `libraryController.playlists.where((p) => p.isXtream)`.
- Each tile shows the playlist name and approval status ("N categories approved" or "Not configured").
- Approved playlists have an accent-colored border.
- Activating a playlist navigates to Step B.
- If no Xtream playlists exist, shows an empty state message.

### Step B: Category Approval (`RecordingCategoryApprovalScreen`)

- Shows all live categories from `xtreamCatalogRepository.liveCategories`.
- Each category has a toggle switch (approved / not approved).
- Top actions: **Select All** and **Clear All** (bulk toggle all categories).
- Third action: **Catch-up filter** toggle (ON/OFF). When ON, the Recording screen hides channels without catch-up support.
- Fourth control: **TV frame on EPG** (ON/OFF). When ON, Recording EPG programme rows show the optional bezel asset behind channel logos (see above).
- Activating an **approved** category navigates to Step C (channel approval).
- Activating a **non-approved** category approves it (toggles it on).
- Header shows: playlist name, approved count / total count.

### Step C: Channel Approval (`RecordingChannelApprovalScreen`)

- Shows all channels in the selected category from `xtreamCatalogRepository.liveChannelsForCategory()`.
- Each channel has a toggle switch.
- Channels with catch-up support show a small clock icon (Icons.history_rounded) in accent color.
- When the catch-up filter is ON, channels without `hasCatchup` are dimmed to 35% opacity (still focusable and toggleable, but visually de-emphasized).
- Top actions: **Select All** and **Clear All**.
- Header shows: category name, approved count / total count.

---

## Recording Screen Behavior

### Initial state

- On first visit, if no categories are approved, shows an empty state: "Set up Recording in Settings" with instructions.
- If categories are approved, the first approved category is auto-selected and today's date is auto-focused.
- Focus lands on the **first channel card** in the grid (not the top menu).
- XMLTV preload starts in the background immediately.

### Layout

- **Backdrop:** `ColoredBox(color: Colors.transparent)` so **`CosmicSpaceBackdrop`** (same as Live TV / Movies / Series) is visible behind the whole screen.
- **Horizontal inset:** `LayoutBuilder` applies **at least 16px** and **~3.5% of width per side** so focused tiles have margin from the physical bezel (TV overscan).
- **Date column width:** **20% of the content row** (computed inside a `LayoutBuilder` around the sidebar + main area), not 20% of full screen width — keeps proportions correct after inset.

```
+--------------------------------------------------+
| [Category 1] [Category 2] [Category 3] ...       |  <- category capsules
+----------+---------------------------------------+
| Today    |                                        |
| Mon 28/3 |   Channel grid (browse state)          |
| Sun 27/3 |   -- or --                             |
| Sat 26/3 |   Compact channel row + EPG timeline   |
| Fri 25/3 |   (EPG mode)                           |
| ...      |                                        |
+----------+---------------------------------------+
  ~20% of row              remainder
```

### Date column

- Shows dates from today going back **maximum 10 days**.
- Today is labeled "Today"; other dates show "Day DD/MM" format.
- Selected date has accent highlight.
- Changing the date reloads the EPG timeline for the new day.

### Browse state

- Right side shows a grid of channel cards for the selected category.
- Each card shows: channel icon (or fallback icon), channel name, and a small catch-up indicator for channels with `hasCatchup`.
- Channel filtering: if the user approved specific channels in settings, only those are shown. If no channels were explicitly approved for a category, all channels in that category are shown.
- When catch-up filter is ON in settings, only channels with `hasCatchup` are displayed.
- Activating a channel transitions to EPG mode with a fade+slide animation (250ms).

### EPG mode

- Right side transforms (same screen, no navigation push) into two sections:
  1. **Compact channel row** (top, 52px height): horizontal scrollable list of 80px-wide channel cards. Selected channel has accent highlight. D-pad left/right switches channels and reloads the timeline.
  2. **EPG timeline** (below): vertical list of program cards for the selected channel and date.

### EPG timeline details

- Each program card shows: start time (accent color), end time (muted), title (bold), description (1-2 lines, muted), and a **tall channel logo slot** on the trailing edge (e.g. **72×56** logical px). If **`tvFrameEpg`** is enabled for the playlist, the logo is composited inside **`recording_tv_frame.png`** with inner padding so the network logo uses **`BoxFit.contain`** in the “screen” area; if disabled, the same slot shows only the logo in a rounded rect.
- Programs are sorted oldest-first (chronological order).
- Initial focus lands on the **last item** (most recent program) so the user sees the latest content first.
- When data loads, the list auto-scrolls to the bottom (latest program).
- Activating a program card triggers catch-up playback.

### Focus behavior

All Recording `TvFocusable` widgets (category strip, date column, browse grid, EPG channel row, EPG programme rows) share **softer** focus motion than the global default: **`_kRecordingFocusScale`** (**1.011**) and **`_kRecordingParallaxSlide`** (**0.002**), with **`focusedBorderWidth: 1.4`** and tight **`focusPadding`**, so highlights stay visible but **do not scale as aggressively** as `AppTheme.focusScale` (~1.075) — reducing overlap with the date column and edge clipping on TVs.

| Scenario | Focus target |
|----------|-------------|
| Entering Recording screen | First channel card in grid (`scheduleRequestFocusWhenReady`) |
| Selecting a channel (entering EPG mode) | Last (most recent) EPG item, with multi-frame retry after `jumpTo` |
| After player closes | Returns to the exact EPG item that was played (`scheduleSteadyChannelTileFocus`) |
| D-pad Left from EPG timeline | Jumps to the currently selected date in the date column |
| D-pad navigation in date column | Standard vertical navigation |

### Mode transitions

- **Browse to EPG:** `AnimatedSwitcher` with fade (opacity) + slide from bottom (4% offset), 250ms ease-out.
- **EPG to Browse:** Back button (registered with `ShellBackCoordinator`) reverses the transition.
- **Channel switch in EPG mode:** timeline rebuilds with new data; auto-scrolls to bottom.
- **Category switch:** always returns to browse mode, clears selected channel.

---

## Player Integration

The Recording system reuses the exact same VOD player used for Movies and Series. No new player code was written.

### How it works

1. `_EpgTimelineState._playProgram()` receives an `XtreamEpgListing` and its index.
2. It reads the active playlist credentials from `libraryController.activePlaylist`.
3. It builds an `XtreamStreamLinkBuilder` and calls `catchupUrlWithDuration()` with:
   - `streamId`: the channel's stream ID
   - `startRaw`: the program's raw start time string from the server (no timezone conversion)
   - `durationMin`: calculated from `listing.end - listing.start` (in minutes)
4. It calls `openIptvilPlayer()` with:
   - `title`: program title
   - `streamUrl`: the timeshift URL
   - `isLive: false` (VOD mode -- enables seek, pause, resume, timeline)
   - `contentDescription`: program description
5. After the player closes, focus is restored to the played EPG item.

### Catch-up URL format

```
{origin}/streaming/timeshift.php?username={user}&password={pass}&stream={streamId}&start={YYYY-MM-DD:HH-MM}&duration={minutes}
```

- `start` uses the raw server time string (from `startRaw`), reformatted as `YYYY-MM-DD:HH-MM`
- `duration` is the program length in minutes
- No timezone conversion is applied to the start time — it's passed as-is from the server's EPG data

---

## XmltvEpgCache (SQLite Persistence)

### Database

- **File:** `iptvil_xmltv_epg.db` (separate from the main catalog DB)
- **Table:** `programmes`
  - `channel TEXT` — XMLTV channel ID
  - `start_utc INTEGER` — UTC milliseconds
  - `stop_utc INTEGER` — UTC milliseconds
  - `start_raw TEXT` — formatted string for timeshift URLs
  - `stop_raw TEXT` — formatted string
  - `title TEXT`
  - `description TEXT`
  - `playlist_sig TEXT` — identifies which playlist this data belongs to
  - **Primary key:** `(channel, start_utc, playlist_sig)`
- **Indexes:** `(channel, start_utc)` and `(playlist_sig)`

### Download & Parse Flow

1. `ensureLoaded()` checks if data was fetched within the last 30 minutes
2. If stale, downloads `xmltv.php?username=X&password=Y` (up to 180s timeout)
3. Parses `<programme>` elements via regex (handles ~12,000 programmes in ~600ms)
4. Batch-inserts into SQLite with `INSERT OR REPLACE` (upsert)
5. Prunes programmes older than 12 days
6. Logs: download size, parse count, channel count, date range, sample channel IDs

### Accumulation Model

The XMLTV feed from most providers only contains **future** EPG data (today + 2-3 days forward). Historical EPG is built up over time:

- Day 1: Download captures today + 3 days forward → stored in DB
- Day 2: Download captures today + 3 days forward → merged with existing data. Yesterday's programmes (which were "today" in yesterday's download) are now historical.
- Day 3: Three days of history available.
- ...continues accumulating up to the 12-day pruning limit.

This is the same approach used by TiviMate, IPTV Smarters, and other professional IPTV apps.

---

## Edge Cases and Fallback Logic

### Missing tvArchiveDuration

When `tvArchiveDuration` is null, zero, or not provided by the Xtream API:
- `MockLiveChannel.catchupDays` returns `kDefaultCatchupDays` (7).
- The date column shows up to 10 days of history (hard max).
- The channel is still considered to have catch-up if `tvArchive == 1`.

### Missing tvArchive flag

When `tvArchive` is null or zero but `tvArchiveDuration > 0`:
- `hasCatchup` returns true (duration alone is sufficient).
- This handles providers that set duration but not the flag.

### EPG fetch reliability (3-strategy cascade)

1. `getAllEpg()` — `get_simple_data_table` with only `stream_id`, no limit or date range. Returns all past+future EPG.
2. `getFullDayEpg()` — `get_short_epg` with limit=2000 and optional date range, plus `get_simple_data_table` with date range. Picks the response with the most listings.
3. XMLTV SQLite DB — queries locally persisted data from previous `xmltv.php` downloads.

Results from all strategies are merged (deduplicated by `startUnix|title`), then filtered for the requested day.

### EPG ID candidates

- `RecordingEpgLoader` tries `epgChannelId` first (XMLTV ID), then falls back to `streamId`.
- This matches the same logic used by `LiveEpgController` for the hero EPG.
- If both fail, the timeline shows "No program data available".

### No approved channels for a category

- If the user approved a category but did not explicitly approve any channels within it, all channels in that category are shown in the browse grid.
- This provides a reasonable default without requiring channel-level setup for every category.

### Empty states

| Condition | Display |
|-----------|---------|
| No active playlist or no approved categories | "Set up Recording in Settings" with instructions |
| No channels in selected category | "No approved channels for this category." |
| EPG loading | CircularProgressIndicator |
| No EPG data for channel/date | "No program data available" |
| No Xtream playlists (settings) | "No Xtream playlists found. Add an Xtream playlist first." |
| No live categories (settings) | "No live categories found. Sync this playlist first." |

### Cache behavior

- `RecordingEpgLoader` caches per `(streamId, date)` with a 10-minute TTL.
- Stale entries are re-fetched on next access.
- `clearCache()` is available for manual invalidation.
- Inflight deduplication prevents duplicate network requests for the same key.
- XMLTV data is persisted to SQLite and survives app restarts.

### Catalog snapshot backward compatibility

- The codec version was bumped from 1 to 2.
- The `fromJson` decoder accepts versions 1 through `kXtreamCatalogPayloadVersion` (currently 2).
- Version 1 snapshots are loaded successfully; `tvArchive` and `tvArchiveDuration` default to null.
- New snapshots are written as version 2 with the catch-up fields included.

---

## All Files Created and Modified

### New files

| File | Purpose |
|------|---------|
| `lib/data/recording_approval_store.dart` | Persistence for playlist/category/channel approvals |
| `lib/data/recording_epg_loader.dart` | Full-day EPG fetch with 3-strategy cascade, filter, and cache |
| `lib/data/xmltv_epg_cache.dart` | SQLite-backed XMLTV EPG download, parse, persist, and query |
| `lib/data/playlist_epg_timezone_store.dart` | Per-playlist EPG time display preference and server UTC offset |
| `lib/ui/recording/recording_screen.dart` | Main Recording screen (browse + EPG + playback + focus management) |
| `lib/ui/settings/recording_edit_screen.dart` | Step A: playlist selection |
| `lib/ui/settings/recording_category_approval_screen.dart` | Step B: category approval, catch-up filter, TV frame on EPG |
| `lib/ui/settings/recording_channel_approval_screen.dart` | Step C: channel approval with catch-up indicators |
| `10-recording-epg-system.md` | This documentation file |

### Modified files

| File | Change |
|------|--------|
| `lib/ui/live_tv/mock_live_tv_data.dart` | Added `tvArchive`, `tvArchiveDuration`, `hasCatchup`, `catchupDays`, `epgChannelId`, `hasPanelEpg`, `kDefaultCatchupDays` to `MockLiveChannel` |
| `lib/xtream/xtream_mapper.dart` | Parse `tv_archive`, `tv_archive_duration`, `epg_channel_id` from Xtream API; pass to `MockLiveChannel` constructor |
| `lib/xtream/xtream_stream_urls.dart` | Added `catchupUrlWithDuration()` method to `XtreamStreamLinkBuilder` |
| `lib/xtream/xtream_api_client.dart` | Added `getAllEpg()`, `getFullDayEpg()`, `getServerInfo()` methods; switched logging from `developer.log` to `debugPrint` for logcat visibility |
| `lib/xtream/xtream_short_epg_parser.dart` | Fixed timezone-less string parsing (force UTC interpretation); separate handling of epoch vs. string fields for start/end times |
| `lib/data/xtream_catalog_snapshot_codec.dart` | Version bumped to 2 (backward-compatible); serialize `tvArchive`/`tvArchiveDuration` |
| `lib/data/xtream_catalog_repository.dart` | Added `refreshServerTimezone()` — fetches server_info and stores UTC offset |
| `lib/main.dart` | Added `recordingApprovalStore.ensureLoaded()` at startup |
| `lib/data/backup/iptvil_backup_service.dart` | Added `recordingApproval` to snapshot export and restore |
| `lib/shell/shell_destination.dart` | Added `ShellDestination.recording` with label "Recording" and icon `fiber_smart_record_rounded` |
| `lib/shell/main_shell_screen.dart` | Added `RecordingScreen` to `_buildDestinationBody` switch |
| `lib/ui/demo/demo_placeholder_pages.dart` | Added `recording` case to exhaustive `_blurbFor` switch |

---

## Known Limitations

1. **XMLTV history requires accumulation time.** If the provider's XMLTV feed only contains future EPG, historical data builds up over days as the app downloads and persists new data each session. A fresh install will only have today's data until it accumulates.

2. **No day-boundary auto-scroll.** When the user scrolls past the top of the current day's timeline, the system does not automatically load the previous day. The user must manually select a different date in the date column.

3. **No EPG thumbnail/preview images.** Program cards show the channel icon as a fallback thumbnail. Xtream EPG responses rarely include per-program images.

4. **No resume position for catch-up.** The VOD player supports resume via `resumeContentId`, but catch-up programs are not assigned a stable resume ID. Reopening the same program starts from the beginning.

5. **No live/future program distinction in timeline.** The filter excludes future programs, but currently-airing programs (start in the past, end in the future) are included. The catch-up URL for a currently-airing program may not work on all providers.

6. **Single catch-up URL format.** The system uses `timeshift.php` query-style URLs. Some providers may require path-style format (`/timeshift/{user}/{pass}/...`).

---

## Future Improvements

1. **Catch-up URL format selector.** Add a per-playlist setting to choose between query-style and path-style timeshift URLs, or auto-detect by probing both.

2. **Day-boundary auto-switching.** When scrolling past the top of the timeline, automatically load the previous day and position focus on its latest item.

3. **Resume support for catch-up.** Assign a stable `resumeContentId` (e.g., `catchup_{streamId}_{startTimestamp}`) so the VOD player can resume from where the user left off.

4. **Program search/filter.** Add a search bar or filter within the EPG timeline to find specific programs by title.

5. **Favorite programs.** Allow users to bookmark specific programs or set up notifications for recurring shows.

6. **EPG grid view.** An alternative multi-channel grid view (like traditional EPG guides) showing multiple channels side-by-side with time slots.

7. **Background XMLTV sync.** Periodically download XMLTV data even when the Recording screen is not open, to ensure historical data accumulates faster.
