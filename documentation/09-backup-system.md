# Backup system

Full export / import of app settings so they survive uninstall, device migration, or sharing a layout with another person.

## What gets backed up

| Category | Detail |
|----------|--------|
| **Playlists** | Every `StoredPlaylist` (name, URL, type, credentials, stats) + active playlist ID + demo-mode flag |
| **Live TV favorites** | All favorite groups and their channel references (`LiveFavoriteGroupsStore`) |
| **My List** | Saved movie, series, and live-channel IDs (`MyListStore`) |
| **VOD labels** | **Watching**, **continue watching**, and **watched** for every title: **`vodMovieLabels`** (movies), **`vodSeriesLabels`** (shows), **`vodEpisodeLabels`** (series episodes). Each map is `{ "id": labelIndex }` where **1** = watching, **2** = continue watching, **3** = watched. **`watchedMovieIds`** is also written for backward compatibility (watched-only movie ids, derived from the same store). Legacy restores with only `watchedMovieIds` and no `vodMovieLabels` still work. Import clears series/episode VOD maps when those keys are absent so state matches the file. See **`13-vod-labels-imdb-posters.md`** §11. |
| **Clock overlay** | Enabled, 24h format, corner, size, opacity, color index, framed (`ClockOverlaySettingsStore`) |
| **Channel card style** | Four modes (`LiveTvCardStyleStore`): name only; logo + name + programme; logo + name; logo only — **Settings → Edit → Live TV · Appearance** (Tiles row) |
| **Live TV channel name position** | Vertical step **−5…+5** (`LiveTvNameVerticalBiasStore`, prefs `iptvil_live_tv_name_vertical_step_v1`) — **Live TV · Appearance** → Tiles → **Name** row |
| **Movie card style** | Poster + title / poster only / title only (`MediaCardStyleStore.movieStyle`) |
| **Series card style** | Same options (`MediaCardStyleStore.seriesStyle`) |
| **Live TV hero height** | Percentage 30–100 (`LiveTvHeroLayoutStore`) — **Live TV · Appearance** |
| **Live TV grid columns** | Channels per row (`LiveTvGridColumnsStore`) — **Live TV · Appearance** |
| **Movies rail page size** | Posters visible per row (`MovieRailPageSizeStore`) — **Movies · Appearance** |
| **Series rail page size** | Posters visible per row (`SeriesRailPageSizeStore`) — **Series · Appearance** |
| **Visual team** | Cosmic / Aurora / Solar / Heritage (`TeamVisualStore`) |
| **Hero preview audio** | Muted flag (`LiveHeroPreviewAudioStore`) |
| **Group visibility** | Per-playlist **hidden** categories (Live / Movies / Series), **aliases**, and **Live TV** **`liveBeforeFavorites`** order (category ids shown **before** favorite-group pills). Same JSON as prefs: each playlist id maps to rules; optional **`liveBeforeFavorites`** array inside each rules object (`PlaylistGroupVisibilityStore`) |
| **Recording approval** | Per-playlist approved categories, channels, catch-up filter, TV frame EPG flag (`RecordingApprovalStore`) |
| **Top Menu Manager** | Menu item order, enabled optionals, startup category (`TopMenuStore`) |
| **My Space sections** | Custom home sections (`MySpaceStore`) |
| **Subtitles (settings)** | Default OpenSubtitles language (`SubtitleSettingsStore`) — `subtitles` in JSON |
| **Subtitle appearance** | On/off, colors, size, opacity, **position** (`SubtitleAppearanceStore`) — `subtitleAppearance` |
| **VOD resume positions** | Last playback ms per content id (`movie_*`, `episode_*`, …) — `playbackResume` |
| **VOD A/V offsets** | Per-title audio delay ms (`VodAudioOffsetStore`) — `vodAudioOffsets` |
| **EPG time per playlist** | Per-playlist display mode (`local` / `original` / IANA zone) + server UTC offset for catch-up URLs (`PlaylistEpgTimezoneStore`) — `epgTimezone` |
| **Channel overrides** | Per-playlist per-channel custom display name, hide from Live TV, custom logo URL (`PlaylistChannelOverrideStore`) — `channelOverrides` |
| **TV keyboard languages** | Ordered list of enabled on-screen keyboard languages (`TvKeyboardLanguageStore`) — `tvKeyboardLanguages` |

**Not** included: Xtream **catalog cache** files, large **EPG** caches — these are rebuilt when a playlist loads. (Resume and A/V maps **are** included in backup JSON as of the current `IptvilBackupService` snapshot.)

### Appearance editors (all covered above)

The **Edit** hub (**Settings → Appearance** / **Edit settings**) adjusts layout using the same persisted stores as the table:

| Editor screen | Keys in backup JSON |
|---------------|---------------------|
| **Live TV · Appearance** | `liveTvCardStyle`, `liveTvNameVerticalStep`, `heroHeightPercent`, `liveTvGridColumns` |
| **Movies · Appearance** | `movieRailPageSize`, `movieCardStyle` — same stores whether edited on the hub or in the full-screen **Movie Grid Settings** card (`movie_grid_settings_panel.dart`) |
| **Series · Appearance** | `seriesRailPageSize` (and series poster card style is `seriesCardStyle`) |

Implementation: `IptvilBackupService.buildSnapshot` / `applyFromMap` in `lib/data/backup/iptvil_backup_service.dart` — no separate backup fields are required.

## Personal vs share

Two export modes:

- **Personal** — complete copy including Xtream `username` and `password` on every playlist. Keep this private; it's for your own reinstall or device transfer.
- **Share** — identical structure, but `username` and `password` are set to `null` on all playlists. Safe to send to someone else; they add their own credentials in My Playlists after import.

The `kind` field in the JSON records which mode was used (`"personal"` or `"share"`).

## File format

```
iptvil-backup-YYYYMMDD-HHmmss-ms.json
```

Example: `iptvil-backup-20260330-132923-811.json`

Top-level JSON object:

```json
{
  "backupFormat": 1,
  "kind": "personal",
  "exportedAt": "2026-03-30T10:29:23.811Z",
  "library": { ... },
  "liveFavoriteGroups": [ ... ],
  "myList": { "movieIds": [], "seriesIds": [], "liveChannelIds": [] },
  "clock": { ... },
  "liveTvCardStyle": "logo_text",
  "liveTvNameVerticalStep": 0,
  "movieCardStyle": "poster_title",
  "seriesCardStyle": "poster_title",
  "heroHeightPercent": 60,
  "liveTvGridColumns": 6,
  "movieRailPageSize": 7,
  "seriesRailPageSize": 7,
  "visualTeam": "cosmic",
  "heroPreviewAudioMuted": false,
  "groupVisibility": {
    "<playlistId>": {
      "live": ["hiddenCategoryId1"],
      "vod": [],
      "series": [],
      "aliases": { "live": { "42": "Sports" } },
      "liveBeforeFavorites": ["12", "42"]
    }
  },
  "recordingApproval": { ... },
  "topMenu": { "order": ["liveTv","movies","series","recording"], "startup": "liveTv" },
  "mySpace": { "sections": [] },
  "epgTimezone": {
    "<playlistId>": { "mode": "Asia/Jerusalem", "serverUtcOffset": 2.0 }
  },
  "channelOverrides": {
    "<playlistId>": {
      "<streamId>": { "name": "My ESPN", "hidden": false, "logo": "https://..." }
    }
  },
  "tvKeyboardLanguages": ["en", "he"]
}
```

Version field: `backupFormat: 1`. Import rejects any file where this doesn't match `kIptvilBackupFormatVersion`.

## Storage location

Backups are saved to **public external storage** so they survive app uninstall:

```
/storage/emulated/0/Download/IPTVIL/
```

This is the real Android public Downloads folder, NOT app-private storage. When the user uninstalls and reinstalls the app, the files are still there.

### How the path is resolved

1. **Platform channel** (`com.iptvil.iptvil/backup_storage` → `BackupStorageChannel.kt`) calls `Environment.getExternalStoragePublicDirectory(DIRECTORY_DOWNLOADS)` and appends `/IPTVIL`. This is the authoritative path.
2. **Fallback** (if platform channel fails): try hard-coded `/storage/emulated/0/Download/IPTVIL`, then `/sdcard/Download/IPTVIL`, then bare `/storage/emulated/0/Download`.
3. **Last resort**: `Directory.systemTemp` (should never happen on a real device).

### Storage permissions

Writing to public external storage requires Android permissions:

| Android version | Permission |
|-----------------|------------|
| 10 and below | `WRITE_EXTERNAL_STORAGE` + `requestLegacyExternalStorage="true"` in manifest |
| 11+ (API 30+) | `MANAGE_EXTERNAL_STORAGE` → system "All files access" toggle |

The app requests permission automatically when the user taps Export. The Kotlin `BackupStorageChannel` handles both flows:
- API < 30: `ActivityCompat.requestPermissions(WRITE_EXTERNAL_STORAGE)`
- API 30+: `Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION` intent

### File discovery (import / delete)

When listing files for import or delete, the app does **not** only look in `Download/IPTVIL/`. Files might exist in `Download/`, `Download/Downloader/`, or other subfolders (from older exports, file manager moves, etc.).

`discoverAllBackupFiles()` walks the **entire** `Download/` tree recursively and collects every file matching `iptvil-backup-*.json`, sorted newest first. This guarantees files are found regardless of which subfolder they're in.

## Architecture

### Dart side

```
lib/data/backup/
├── iptvil_backup_constants.dart   — format version (1), file prefix
├── iptvil_backup_paths.dart       — path resolution, permission request,
│                                    file discovery (recursive), file listing
└── iptvil_backup_service.dart     — snapshot builder, export writer,
                                     import parser + applier, secret stripping
```

**`IptvilBackupService`** (singleton):
- `buildSnapshot(kind)` — loads all stores, serializes to `Map<String, dynamic>`, strips secrets if `kind == share`
- `exportToDownloads(kind)` — calls `buildSnapshot`, writes JSON to resolved directory, returns file path
- `applyFromJsonString(raw)` — decodes, validates version, calls `applyFromMap`
- `applyFromMap(map)` — restores every store in order: library → group visibility → favorites → my list → clock → card styles → hero height → **live TV grid columns** → **live TV name vertical step** (if present) → **movie/series rail page sizes** → team → audio → my space → catalog sync

**`IptvilBackupException`** — thrown for bad format version, missing library block, invalid playlists.

### Kotlin side

```
android/app/src/main/kotlin/com/iptvil/iptvil/
└── BackupStorageChannel.kt
```

Platform channel `com.iptvil.iptvil/backup_storage` with two methods:

| Method | Returns | Purpose |
|--------|---------|---------|
| `getPublicBackupDir` | `String` (path) | Real public `Download/IPTVIL` via `Environment.getExternalStoragePublicDirectory` |
| `ensureStoragePermission` | `bool` | Checks and requests storage permission (API-appropriate flow) |

Wired in `MainActivity.kt` → `configureFlutterEngine`. Permission callbacks forwarded via `onRequestPermissionsResult` and `onActivityResult`.

### Android manifest entries

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

Plus `android:requestLegacyExternalStorage="true"` on `<application>` for Android 10 compat.

## UI screens

All screens live in `lib/ui/settings/`.

### Backup main screen (`backup_screen.dart`)

Reached from **Settings → Backup**. Shows:

1. **Banner** — one-line explanation of Personal vs Share
2. **3-column grid** of action tiles:
   - Export personal
   - Export to share
   - Share latest (or "Share last export" for 6 seconds after exporting)
   - Import backup → navigates to import screen
   - Delete backups → navigates to manage screen

After export, a SnackBar shows the filename for 4 seconds and auto-dismisses. No `SnackBarAction` is used (Material 3 makes SnackBars with actions indefinite regardless of the `duration` parameter).

### Import screen (`backup_import_screen.dart`)

Lists all discovered backup files (recursive scan of `Download/`). Each row shows:

- Friendly date/time parsed from the filename
- Original filename (small, gray)
- File size and parent folder name

Tap a row to import immediately. Shows a spinner during restore. Pops back on success.

Has a **Refresh** button to re-scan after new exports.

### Delete screen (`backup_manage_screen.dart`)

Multi-select list of all discovered backup files. Header row contains:

- **Select all / Clear all** toggle
- **Delete (N)** button with count

Confirmation dialog before deleting. Files are removed from disk. List refreshes after deletion.

## User flow

### Export and keep safe

1. Settings → Backup → **Export personal**
2. App requests storage permission (first time only)
3. File saved to `Download/IPTVIL/iptvil-backup-20260330-132923-811.json`
4. SnackBar confirms the filename (disappears after 4 seconds)
5. File survives app uninstall, factory reset of the app, clearing data

### Restore after reinstall

1. Install app fresh
2. Settings → Backup → **Import backup**
3. App requests storage permission
4. Scans all of `Download/` recursively — finds the backup file
5. Tap the file → all settings restored, catalogs refresh

### Share with someone else

1. Export to share (passwords stripped)
2. Share latest → Android share sheet → send via WhatsApp, email, Drive, etc.
3. Recipient saves file to their device's Downloads
4. Opens IPTVIL → Settings → Backup → Import → picks the file
5. Everything restores except passwords — they add their own in My Playlists

## Key design decisions

1. **Public storage, not app-private** — the whole point is surviving uninstall. `getApplicationDocumentsDirectory()` is wiped when the app is removed.

2. **Platform channel for path resolution** — `path_provider`'s `getDownloadsDirectory()` returns scoped/private paths on many Android TV devices. The native `Environment.getExternalStoragePublicDirectory()` returns the real public path every time.

3. **Recursive file discovery** — users may move files, file managers may save to different subfolders, older exports may land in different locations. Scanning the whole `Download/` tree guarantees we find them all.

4. **No SnackBarAction** — Material 3 with `useMaterial3: true` makes SnackBars with actions stay on screen indefinitely, ignoring the `duration` parameter. All notifications use plain timed SnackBars instead.

5. **JSON format** — human-readable, easy to inspect, small file size (typically 1–30 KB). Pretty-printed with 2-space indent for readability.

6. **All-or-nothing restore** — import applies all settings atomically. If the format version doesn't match or the library block is invalid, it throws `IptvilBackupException` and nothing is changed.

7. **IPTVIL subfolder** — keeps backup files organized and separate from other Downloads content, easy to find in a file manager.
