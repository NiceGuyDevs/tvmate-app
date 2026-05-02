# VOD offline download (Windows + Android)

## Purpose

Let users **save a single-file VOD stream** (movie or episode) to disk while it plays in fullscreen. **HLS master playlists** (`.m3u8` / adaptive streams) are **not** supported — the downloader expects one progressive file (e.g. MP4, MPEG-TS).

This document describes **where files go**, **how the pipeline works**, and **how the Android library UI fits in**.

---

## User-facing behavior

### Windows (desktop)

- From the VOD player, use the jump strip (**Download** chip, index **14** after focusing tier B).
- A **global progress strip** shows download + save progress (`VodDownloadStripLayer` in `app.dart`).
- The completed file is copied to the user’s **Downloads** folder (resolved via `getDownloadsDirectory()` / `%USERPROFILE%\Downloads`). No native “Save As” dialog (avoids UI freezes with **media_kit** on this stack).
- Success snackbar shows the **full path** on disk.

### Android (TV / phone)

- Same **Download** control in the VOD jump strip once the bottom chrome is available.
- **Android** also shows the **progress strip** during an active download.
- The file is stored in **app-private storage** (not the public Downloads app). Path shape:

  `{applicationSupportDirectory}/TVMatePro/vod_offline/`

  alongside a JSON index: **`index.json`**.
- After copy, a short snackbar confirms save (**title-based**, not a long filesystem path).
- **Account** (overlay): sidebar entry **Offline downloads** opens a list screen:
  - **Poster / thumbnail** when a catalog URL was passed at download time; otherwise a placeholder icon.
  - **Title**, **size**, **saved date/time**.
  - **Play** — opens the same fullscreen player with a **`file://`** URI (`openTvMatePlayer` → `NativeExoPlayerSession` / `MediaItem.fromUri`).
  - **Delete** — removes the file and the index row (with confirmation).

Uninstalling the app **removes** app-private offline files (unlike backups under public Download — see **`09-backup-system.md`**).

---

## Download pipeline (both platforms)

**Controller:** `lib/data/vod_download_controller.dart` — singleton **`VodDownloadController`**.

1. **Single active job** — starting a second download is ignored (snackbar: already in progress).
2. **HTTP GET** the `streamUrl` with a browser-like **User-Agent**.
3. **Stream body** to a **temp file** under `getTemporaryDirectory()` (`tvmate_vod_*.tmp`).
4. **Throttle** progress notifications (`notifyListeners`) to avoid janking the UI.
5. **Cancel** — only while bytes are still streaming; closes the `HttpClient` forcefully.
6. **Validation**
   - Reject **empty** files.
   - Read the first bytes; if they look like **`#EXTM3U`** (HLS playlist), delete temp and surface **playlist not supported** (not a single media file).
7. **Copy** temp → final path with a **unique filename** if the target name already exists.
8. **Android only:** register metadata in **`VodOfflineLibrary`** (`lib/data/vod_offline_library.dart`): title, absolute path, size, timestamp, optional **poster URL**.

**Entry points:**

- `lib/player/vod_download.dart` — **`startVodDownload`** (Windows + Android). Optional **`posterUrl`** is only persisted on Android.
- `PlayerScreen` calls this from **`_startVodDownloadFromJumpStrip`** with **`widget.vodPosterUrl`** when provided.

**Poster URL wiring:**

- `openTvMatePlayer` accepts optional **`vodPosterUrl`** (`lib/player/player_navigation.dart`).
- Movie / series detail screens pass **`catalogBackdropHiResUrl(movieBackdropUrl(…))`** or **`seriesBackdropUrl`** so the offline list can show network art.

---

## Filename and extension

**Helper:** `lib/player/vod_download_helpers.dart` — **`vodDownloadSuggestedFileName`**.

- Prefer **`Content-Type`** from the HTTP response when it maps to a known video type (e.g. `video/mp4` → `.mp4`, `video/mp2t` → `.ts`).
- Otherwise derive from the **last URL path segment**. **Script-style extensions** (`php`, `html`, `asp`, …) are treated as **invalid** and fall back to **`.mp4`**, because many IPTV gateways use `.php` for real video bytes.
- The display **title** is sanitized for the filesystem (forbidden characters → `_`, length cap).

---

## UI and localization

| Piece | Location |
|-------|----------|
| Progress strip | `lib/ui/vod/vod_download_strip.dart` — shown on **Windows and Android**; copying phase text: Windows **“Saving to Downloads…”**, Android **“Saving offline…”** (`playerVodDownloadSavingOffline`). |
| Jump strip download chip | `lib/player/player_tv_overlay.dart` — **`PlayerTvVodJumpStrip`**, index **14** |
| Player wiring | `lib/player/player_screen.dart` — **`showSeek`** on Android includes VOD chrome even if duration is not reported yet, so download can be reached; download action does **not** require `_vodSeekable` |
| Account list | `lib/account/android_offline_downloads_screen.dart` — styling aligned with **`AccountOverlay`** (`_AccColors`-style palette) |
| Account sidebar | `lib/account/account_overlay.dart` — **Offline downloads** row, **`Platform.isAndroid` only** |

ARB keys include **`playerVodDownloadSavedShort`**, **`accountOfflineDownloads*`** — see `lib/l10n/app_en.arb`.

---

## Key files (quick reference)

| File | Role |
|------|------|
| `lib/data/vod_download_controller.dart` | HTTP download, temp file, validation, copy, snackbars |
| `lib/data/vod_offline_library.dart` | JSON index + `ChangeNotifier` for Android list |
| `lib/player/vod_download_helpers.dart` | Suggested filename, byte formatting, HLS sniff |
| `lib/player/vod_download.dart` | `startVodDownload` |
| `lib/ui/vod/vod_download_strip.dart` | Floating progress UI |
| `lib/account/android_offline_downloads_screen.dart` | List / play / delete |

---

## Platform notes

- **Windows** continues to use **user Downloads** only; no `VodOfflineLibrary` entry.
- **Android** does not use the backup platform channel or **MANAGE_EXTERNAL_STORAGE** for this feature — everything stays under **`getApplicationSupportDirectory()`**, which is normal for private app content and avoids extra permission flows.

For native playback of local files, **`NativeExoPlayerSession.buildMediaItem`** uses **`MediaItem.fromUri(url)`**; the Dart side passes a **`file://`** URL string from `Uri.file(path).toString()`.
