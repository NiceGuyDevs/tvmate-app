# IPTVIL — App features (full catalog)

**Purpose:** One place to see **what the app does**, feature by feature. For implementation detail, follow links to the other `.md` files in **`documentation/`** (same folder as this file).

**Platform:** Android TV / Google TV (remote-first). Flutter UI + native **ExoPlayer (Media3)** for video.

---

## 1. Shell & navigation

| Feature | What you get |
|--------|----------------|
| **Top menu bar** | Live TV, Movies, Series, Recording, Settings — plus optional items (playlist switcher, Theme, Clock, Appearance, Backup, Favorite setup) via **Top Menu Manager**. |
| **Top Menu Manager** | Reorder core tabs, toggle optional entries, set **startup screen** (which tab opens first). Settings stays last and locked. |
| **Cosmic backdrop** | Layered space background (gradients, nebula, starfield, light leaks) on all main routes. |
| **Playlist quick switch** | Change active playlist from the bar without opening Settings. |
| **RTL / locale** | App language persistence; Live TV hero flips preview vs logo side for RTL. |

---

## 2. Visual themes

| Theme | Character |
|-------|-----------|
| **Cosmic** | Cyan / deep blue, violet nebula. |
| **Aurora** | Purple, pink, magenta. |
| **Solar** | Yellow, gold, amber neon. |
| **Heritage** | Champagne gold, wine, midnight blue. |

**Behavior:** Choosing a theme in **Theme** returns you to **Live TV**; accents and focus rings update app-wide (`TeamVisualStore`).

---

## 3. Live TV

| Feature | What you get |
|--------|----------------|
| **Session restore (cold start)** | Default tab **Live TV**. **Live TV** restores **last category + channel** when browsing the grid; if the app was closed during **live fullscreen**, reopens that channel in the player. If closed during **VOD** playback (movie/episode with resume id), restores that tab + player. Other cases (e.g. only Settings) still open **Live TV** (`AppSessionRestoreStore`). See **`14-live-tv-appearance-channel-grid.md`**. |
| **Category pills** | **Named favorite groups** first by default; optional **Live TV** categories can be pinned **before** favorites (**Manage groups → TV** — order panel). Then remaining visible playlist live categories (respects **group visibility**). |
| **Hero row** | Large preview area: **live video + audio** in a TV-style frame, channel logo + name, EPG block (Xtream), clocks / “ends in” strip. |
| **Channel grid** | Browse channels; open fullscreen player with optional **lineup** (Up/Down to change channel while watching). |
| **Favorite groups** | **Settings → Favorite setup**: create/edit named groups, pick channels (`LiveFavoriteGroupsStore`). |
| **Card styles** | Four layouts (name-only, logo+name+programme, logo+name, logo-only). |
| **Appearance** | **Hero height** (30–100%), **channels per row**, **four card layouts** (2×2 grid: move focus with D-pad, **OK** to apply), **global channel name** nudge. Details: **`14-live-tv-appearance-channel-grid.md`**. |
| **Hero preview audio** | Mute preference for preview (`LiveHeroPreviewAudioStore`). |
| **Missing artwork** | Universal placeholder for broken logos (same family as Movies/Series). |
| **EPG** | Short/simple table + XMLTV where configured; programme text on tiles and hero. |
| **Parental (Live TV)** | Lock channels, categories, or favorite groups; optional **hide from browse** per item (not a single global hide). Focused blocked channel: **hero blackout** (no preview video). **Restricted rules** lists locks with **readable names**. If the current category pill becomes empty after a rule change, focus moves to a pill that still has channels. See **`17-parental-control.md`**. |

---

## 4. Movies & Series (VOD browse)

| Feature | What you get |
|--------|----------------|
| **Category rails** | Horizontal scrolling by playlist category. |
| **Detail screens** | Backdrop, metadata, description, actions. |
| **Play** | Fullscreen VOD with resume when a stable content id is used. |
| **External player** | Open stream URL in external app. |
| **Trailer** | In-app YouTube search → opens YouTube app (`InAppYoutubeTrailerScreen`). |
| **My List** | Save movies, series, live channels (`MyListStore`). |
| **My List filters** | Pills: all / watched / continue watching (VOD labels). |
| **VOD labels** | **Watching**, **continue watching**, **watched** — manual toggles + automatic updates from playback (`MovieVodLabelStore`, `SeriesVodLabelStore`, `EpisodeVodLabelStore`). |
| **Continue watching off** | Turning **continue watching** off clears **saved resume position** for that title (movies: per movie; series: all listed episodes on that series screen). |
| **IMDb chip** | When playlist provides a rating, compact IMDb badge on posters/hero (tinted to active team). |
| **Rail / card appearance** | Posters per row, movie vs series card style (poster+title, etc.). |

---

## 5. Player (fullscreen)

### Live

| Feature | What you get |
|--------|----------------|
| **Lineup** | Up/Down switches channels when `liveLineup` is passed. |
| **Overlay** | Play/pause, channel info, EPG where available. |
| **Preview pause** | Hero preview pauses while fullscreen; resumes after exit. |
| **Multiview** | Optional multi-channel mode where implemented. |
| **Right panel** | Options / settings entry as per live overlay. |
| **Parental** | From the strip: **scope** dialog (lock / lock+hide / unlock per channel or category); **compact PIN** create or verify with **inline numpad**. Fullscreen **EPG:** **Back** dismisses the EPG layer via the **root** navigator. |

### VOD (movies & episodes)

| Feature | What you get |
|--------|----------------|
| **Aspect ratio** | Centered video, letterbox/pillarbox — no stretch (`Texture` + native sizing). |
| **Resume** | Restores last position when `resumeContentId` is set (`PlaybackResumeStore`). |
| **Start from beginning** | Navigation API can clear resume before open (`startFromBeginning`). |
| **Seek** | D-pad: step seek, hold-to-accelerate scrub, timeline feedback. |
| **Jump strip (tier B)** | After opening timeline, second **Down**: ±15s jumps, ±1/2/3 min, **play/pause**, **CC**, **Style**, **A/V**, **Speed**, **Settings**. |
| **Offline download (VOD)** | **Windows:** saves a single-file stream to the user **Downloads** folder (no Save-As dialog). **Android:** saves under **app-private** storage and lists items under **Account → Offline downloads** (poster, play, delete). **HLS** master playlists are not supported. Details: **`19-android-offline-vod-downloads.md`**. |
| **Speed** | Session presets (e.g. 0.5×–3×); resets when player releases. |
| **A/V sync** | Small popup; ±ms adjustment, **persisted per `resumeContentId`** (`VodAudioOffsetStore`). |
| **Back stack** | PopScope closes overlays before exiting player; details screen stays under player. |

---

## 6. Subtitles (VOD)

| Feature | What you get |
|--------|----------------|
| **OpenSubtitles** | Search by query, download file, apply to ExoPlayer (`setExternalSubtitle`). Built-in API key in source (`opensubtitles_config.dart`). |
| **Default language** | **Settings → Subtitles** picks preferred language for sorting results (`SubtitleSettingsStore`). |
| **CC picker** | From jump strip: choose language + file, load, or clear. |
| **Subtitle look** | Global: on/off, background + text colors, background opacity, font size, **position** (persisted). |
| **Style panel** | Top-right card: D-pad rows for all options; position “move” mode; **hardware Back** closes panel without exiting player. |
| **Exit / Reset** | **Exit** closes panel; **Reset defaults** restores factory look + centered position (`resetToDefaults`). |
| **On-screen preview** | Overlay shows cues or “Subtitle preview” while editing. |
| **Backup** | `subtitles` + `subtitleAppearance` in settings backup JSON. |

---

## 7. Recording & catch-up (EPG)

| Feature | What you get |
|--------|----------------|
| **EPG sources** | Xtream simple/short EPG + XMLTV where configured. |
| **Past programmes** | Browse archive; catch-up playback when provider supports it. |
| **Recording UI** | Category/channel filters, approval store, optional TV-frame mode on EPG rows. |
| **EPG time** | Per playlist: **Settings → My playlists → EPG** opens a centered picker (**Local** first, then **Original (server)** and world time zones). Chip on the card shows the active mode. Does not change catch-up URL math (server offset still from Xtream). |

*(Catch-up resume ids may differ from main VOD; see recording doc for details.)*

---

## 8. Clock overlay

| Feature | What you get |
|--------|----------------|
| **Global layer** | Optional clock over all screens (`ClockOverlayLayer` in `MaterialApp` builder). |
| **Settings** | 12/24h, corner, size, opacity, **eight colors** (including neon + **DSEG** digits), optional **frame** + date line. |

---

## 9. Playlist & library

| Feature | What you get |
|--------|----------------|
| **Xtream** | Server URL, credentials, catalog fetch, cached snapshots on disk. |
| **M3U** | Stored/shown in flows; full M3U-first browse may be limited vs Xtream path (see product doc). |
| **Group visibility** | Hide/show playlist categories across Live / Movies / Series; per-category aliases; **Live TV** pill order (**before** or **after** favorite groups, with position among “before” pills). |
| **Manage channels** | **Settings → My playlists → Manage channels:** per-playlist **rename**, **hide from Live TV**, **custom logo URL** for live streams (`PlaylistChannelOverrideStore`). Channel order in the editor follows **playlist/catalog** order. See **`18-manage-live-channels.md`**. |
| **Demo mode** | Toggle for safe demos. |
| **Library disk** | Playlists + active id persisted; backup embeds library block. |

---

## 10. Backup & restore

| Feature | What you get |
|--------|----------------|
| **Export** | JSON to public **Download/IPTVIL** (survives uninstall). |
| **Personal vs share** | Share mode strips playlist passwords. |
| **Import** | Scans Downloads recursively for `iptvil-backup-*.json`. |
| **Included data** | Library, favorites, My List, VOD labels, clock, card styles, hero/grid/rail sizes, team, hero preview mute, **group visibility** (including **Live TV** `liveBeforeFavorites` pill order), recording approval, top menu, My Space sections, **subtitles**, **subtitle appearance**, **playback resume map**, **VOD A/V offsets**, app language, etc. |

See **`09-backup-system.md`** for the authoritative table.

---

## 11. Settings hubs

| Area | Contents (typical) |
|------|---------------------|
| **Settings grid** | Playlist management, Appearance (Live/Movies/Series editors), Clock, Subtitles, Backup, Demo, Group management, Favorite setup, **Parental control** (PIN, lock-all sections, restricted rules, change/clear PIN), Edit… |
| **Appearance** | Live TV channel grid editor; **Movies** and **Series** each open the same grid settings pattern (posters per row, poster display, hide/show). |
| **Add playlist** | TV-safe form, keyboard-friendly fields. |

---

## 12. TV / remote UX

| Feature | What you get |
|--------|----------------|
| **D-pad first** | Focus rings, traversal order, no mouse required. |
| **Back key** | Consistent dismiss: overlays → then exit screen/player. |
| **Safe margins** | Content within overscan-friendly layout. |
| **Performance** | Buffering tuned for TV; Impeller disabled on Android for correct video color compositing (see `06`, `07`). |

---

## 13. Where to read more

| Topic | Document |
|-------|----------|
| Product + stack | `01-product-overview.md` |
| Marketing-style blurbs | `11-feature-showcase.md` |
| Playback & native player | `06-playback-and-native-player.md` |
| VOD labels & IMDb | `13-vod-labels-imdb-posters.md` |
| Backup format | `09-backup-system.md` |
| Recording / EPG depth | `10-recording-epg-system.md` |
| Parental control | `17-parental-control.md` |
| UI shell & Live hero | `05-ui-shell-and-tv-patterns.md` |
| Subtitle system (dev) | `subtitle-system.md` |
| Repo / architecture | `ARCHITECTURE.md`, `03-system-architecture.md` |

---

*IPTVIL — consolidated feature list for personal review. Update `subtitle-system.md` and `09-backup-system.md` when backup or subtitle behavior changes.*
