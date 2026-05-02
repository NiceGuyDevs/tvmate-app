# Subtitle system (VOD): OpenSubtitles, settings, and on-screen edit

This document describes everything the app implements around **external subtitles** (OpenSubtitles), **default language**, **subtitle appearance** (colors, size, transparency, position), **player UI** (jump strip), and **backup**. Use it while testing or when maintaining the code.

---

## 1. High-level architecture

| Layer | Role |
|-------|------|
| **OpenSubtitles REST** | Search by query, download subtitle file bytes (`lib/subtitles/opensubtitles_client.dart`). |
| **Built-in API key** | Single constant in source; no in-app field (`lib/data/opensubtitles_config.dart`). |
| **Subtitle settings** | Default **language code** for sorting OpenSubtitles results (`SubtitleSettingsStore`). |
| **Player (VOD)** | Search UI, apply file path to native player, optional **overlay preview** for styling (`PlayerScreen`, `VodSubtitlePickerPanel`, `VodSubtitleStylePanel`). |
| **Subtitle appearance** | Global prefs: on/off, bg/text colors, bg opacity, font size, **position** (`SubtitleAppearanceStore`). |
| **Native Android** | External subtitle path passed into ExoPlayer (`setExternalSubtitle` on `PlayerService` / native). |
| **Backup** | `subtitles` + `subtitleAppearance` blocks in IPTVIL settings backup JSON (`IptvilBackupService`). |

---

## 2. OpenSubtitles

### 2.1 API key (manual change)

- **File:** `lib/data/opensubtitles_config.dart`
- **Symbol:** `kOpenSubtitlesBuiltInApiKey` — edit the **quoted string** only, then rebuild the app.
- There is **no** Settings screen field for the key; `SubtitleSettingsStore.openSubtitlesApiKey` always returns this constant.
- `setOpenSubtitlesApiKey` exists as a **no-op** for older call sites.

### 2.2 HTTP client

- **File:** `lib/subtitles/opensubtitles_client.dart`
- **Base URL:** `https://api.opensubtitles.com/api/v1`
- **Headers:** `Api-Key`, `User-Agent` (`IPTVIL/1.0`), `Accept` / `Content-Type` JSON.
- **Operations:**
  - `searchSubtitles` — GET `/subtitles?query=...`; groups by language; **preferred language** from `SubtitleSettingsStore.defaultLanguageCode`.
  - `downloadBytes` — download file for a chosen file id / link from API response.
- Errors surface as `OpenSubtitlesException` (e.g. 401/403 invalid key).

### 2.3 Where search is triggered

- **File:** `lib/player/player_screen.dart`
- Methods such as `_loadVodSubtitleSearch` use `OpenSubtitlesClient` with `SubtitleSettingsStore.instance.openSubtitlesApiKey` and an **effective query** from title / URL / `subtitleSearchQuery` (see `_effectiveSubtitleQuery` / `widget.subtitleSearchQuery`).
- **Navigation:** `openIptvilPlayer(..., subtitleSearchQuery: ...)` in `lib/player/player_navigation.dart` passes an optional query from movie/episode/catch-up flows.

### 2.4 Applying a downloaded subtitle

- Downloaded bytes are written to a temp file; `PlayerService.setExternalSubtitle(path)` is called.
- Clearing uses `setExternalSubtitle(null)` (e.g. CC “clear” action).
- Native: `lib/player/native_android_player_service.dart` — method channel `setExternalSubtitle` with `subtitlePath`.

---

## 3. Settings UI: “Subtitles”

- **Screen:** `lib/ui/settings/subtitle_settings_screen.dart`
- **Entry:** Settings hub lists **Subtitles** (`settings_screen.dart`); subtitle line explains **default language** only.
- **Behavior:** User picks **default subtitle language** (list of ISO-style codes). This affects **OpenSubtitles result ordering / preference**, not system locale.
- **Store:** `lib/data/subtitle_settings_store.dart`
  - Pref key: `iptvil_subtitle_default_lang`
  - **Backup:** `exportForBackup` / `applyFromBackup` only carry `defaultLanguageCode` (API key is not exported).

---

## 4. Player: download picker (CC)

- **Panel:** `lib/player/vod_subtitle_picker.dart` — `VodSubtitlePickerPanel`
- **Opened from:** VOD jump strip index **0** (CC chip) — see section 6.
- **State in `PlayerScreen`:** loading, error, language/file indices, OpenSubtitles groups, focus columns.
- User selects language + file; app downloads and calls `setExternalSubtitle`.

---

## 5. Player: subtitle “look” editor (palette)

- **Widget:** `lib/player/vod_subtitle_style_panel.dart` — `VodSubtitleStylePanel`
- **Opened from:** Jump strip index **1** (Style / palette chip), or equivalent focus path.
- **Layout:** Top-**right** card (~28% width), does not use the bottom timeline while open (bottom chrome hidden in `PlayerScreen`).
- **Rows (keyboard / D-pad):**
  0. Subtitles on/off  
  1. Background color (palette)  
  2. Background **transparency** (slider + D-pad steps)  
  3. Text color  
  4. Font size  
  5. **Position:** first **Select (OK)** enters **move mode** (amber border); **↑↓←→** nudge the on-screen subtitle; second **Select** exits move mode so **↑↓** navigate rows again. **Back** exits move mode first, then closes the panel if pressed again.  
  6. **Exit** — closes the panel and returns to the movie (same as **Back** after move mode).  
  7. **Reset defaults** — `SubtitleAppearanceStore.resetToDefaults()` (on, default palette indices, size, opacity, position **0,0**); panel stays open.

  Focus **Down** from row 5 reaches **Exit**, then **Reset**. **Left/Right** switches between Exit and Reset. **OK** on **Reset** applies factory defaults.

### 5.1 Appearance store (global)

- **File:** `lib/data/subtitle_appearance_store.dart` — `SubtitleAppearanceStore.instance`
- **SharedPreferences keys:**
  - `iptvil_subtitle_appearance_enabled`
  - `iptvil_subtitle_appearance_bg` / `iptvil_subtitle_appearance_fg`
  - `iptvil_subtitle_appearance_size_sp`
  - `iptvil_subtitle_appearance_bg_opacity`
- **Palette:** `paletteColors` (8 colors, shared by bg and text pickers).
- **Backup:** `exportForBackup` / `applyFromBackup` include enabled flag, indices, size, `backgroundOpacity`, `positionDx` / `positionDy`. **`resetToDefaults()`** matches the same factory values as first install for these fields.
- **Bootstrap:** `ensureLoaded()` should run before player uses appearance (already wired from player init path).

### 5.2 On-screen preview overlay

- **File:** `lib/player/player_screen.dart` — `_buildVodSubtitleOverlay`
- Renders cue text (or “Subtitle preview”) with `Transform.translate` using **`SubtitleAppearanceStore.positionOffset`** (persisted).
- **Bottom inset:** uses a smaller `Positioned.bottom` while the style panel is open vs closed (`_kVodSubtitleBottomInsetStylePanelOpen` / `_kVodSubtitleBottomInsetNormal`). The anchor changes by `_kVodSubtitleBottomInsetDelta` px; the overlay adds that delta to the translate **only while the style panel is open** so the caption does not jump.
- **Hardware Back** while the style panel is open is handled in `_onPlayerHardwareKey` (closes the panel) so Back does not exit the player when focus is not on the jump strip.

### 5.3 Closing the style panel

- **Method:** `_closeVodSubtitleStylePanelAndRestoreJumpFocus()` in `PlayerScreen`
- Hides subtitle style panel, clears bottom dock visibility so the bar does not stay stuck, restores jump focus index for the Style chip, reschedules hide timer.

---

## 6. VOD jump strip layout and focus indices

- **File:** `lib/player/player_tv_overlay.dart` — `PlayerTvVodJumpStrip`, `kPlayerTvOverlayBuild` (bump when strip semantics change).
- **Visual layout (left → center → right):**
  - **Left:** CC (subtitle download), Style (look editor)
  - **Center:** −15s … +15s and **play/pause** (same cluster as before)
  - **Right:** A/V delay, Speed, Settings

### 6.1 Focus index map (0–13)

| Index | Control |
|------:|---------|
| 0 | CC (OpenSubtitles picker) |
| 1 | Style (subtitle appearance panel) |
| 2–10 | Seek / play cluster (−15s … +15s, play at 6) |
| 11 | A/V offset popup |
| 12 | Speed picker |
| 13 | Player settings |

- **Activation:** `PlayerScreen._activateVodJumpButton` — must use `index.clamp(0, 13)` so index **13** (settings) is reachable.
- **Default focus** when focusing the strip: **6** (play).

---

## 7. Player overlay behavior (VOD)

- **Opacity / interaction:** `_vodWantsOpaqueOverlay`, `_overlayInteractive`, `_playerOverlayOpacity` in `PlayerScreen`.
- **Auto-hide:** After `PlayerTvOverlayTheme.autoHideDuration` (e.g. 4s), timer can hide **timeline** and related chrome so the dock does not stay forever.
- **Progress events:** The `progress` handler must **not** set `_vodTimelineVisible = true` on every tick — only when duration **first** becomes known (`prevDur <= 0` and `d > 0`). Otherwise the dock fights the hide timer and **flickers** while staying visible.
- **Back / PopScope:** Closes modals and overlay layers before exiting the player; order is documented in code (subtitle picker, style panel, then generic hide).

---

## 8. Backup (`IptvilBackupService`)

- Snapshot includes (among other app settings):
  - **`subtitles`:** from `SubtitleSettingsStore.exportForBackup` (default language; API key is not stored).
  - **`subtitleAppearance`:** from `SubtitleAppearanceStore.exportForBackup` (look + position).
  - **`playbackResume`:** per-content VOD resume positions (`PlaybackResumeStore`).
  - **`vodAudioOffsets`:** per-content A/V sync ms (`VodAudioOffsetStore`).
- Restore merges these maps when present. See also **`09-backup-system.md`** for the full backup table.

---

## 9. Localization

- Strings live under `lib/l10n/app_*.arb` with prefixes such as `subtitleVod*`, `subtitleAppearance*`, `subtitleSettings*`, `settingsSubtitles*`.
- After ARB edits, run **`flutter gen-l10n`**.

---

## 10. File checklist (quick reference)

| Topic | Path |
|-------|------|
| API key | `lib/data/opensubtitles_config.dart` |
| Subtitle language store | `lib/data/subtitle_settings_store.dart` |
| Subtitle look store | `lib/data/subtitle_appearance_store.dart` |
| OpenSubtitles HTTP | `lib/subtitles/opensubtitles_client.dart` |
| Settings UI (language) | `lib/ui/settings/subtitle_settings_screen.dart` |
| Player: picker + style + overlay | `lib/player/player_screen.dart` |
| Style panel UI | `lib/player/vod_subtitle_style_panel.dart` |
| Picker UI | `lib/player/vod_subtitle_picker.dart` |
| Jump strip | `lib/player/player_tv_overlay.dart` |
| Open player + query | `lib/player/player_navigation.dart` |
| Backup | `lib/data/backup/iptvil_backup_service.dart` |
| Native subtitle path | `lib/player/native_android_player_service.dart`, `player_service.dart` |

---

## 11. Security note

The OpenSubtitles API key is **compiled into the app**. Anyone can extract it from a release build. Rotate the key in the OpenSubtitles consumer dashboard if it is leaked, then update `opensubtitles_config.dart` and ship a new build.

---

*Document generated to match the IPTVIL codebase feature set; adjust this file when behavior or file paths change.*
