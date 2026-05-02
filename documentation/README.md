# IpTvIl — documentation index

**All project markdown lives in this folder (`documentation/`).** The former separate `docs/` and `doc/` trees were merged here so there is a single place to edit and link from.

Handoff docs: structure, **dual native players** (fullscreen + hero preview, **`SurfaceProducer`** + manifest **Impeller** toggle), **four visual themes** (Cosmic / Aurora / Solar / Heritage), **live EPG**, TV patterns, Android packaging, and **feature history**.

Root **[`ARCHITECTURE.md`](../ARCHITECTURE.md)** — channels, Xtream, preview + main player. **[`CHANGELOG.md`](../CHANGELOG.md)** — user-visible changes (Keep a Changelog style).

## Read order

| # | Document | Contents |
|---|----------|----------|
| 1 | [01-product-overview.md](01-product-overview.md) | Product, stack |
| 2 | [02-repository-structure.md](02-repository-structure.md) | Paths; **NativeLivePreviewSession**, **hero_live_preview** |
| 3 | [03-system-architecture.md](03-system-architecture.md) | Layers, singletons |
| 4 | [04-data-playlists-and-xtream.md](04-data-playlists-and-xtream.md) | Library, **EPG APIs** |
| 5 | [05-ui-shell-and-tv-patterns.md](05-ui-shell-and-tv-patterns.md) | Shell, **Live TV hero** (layout, preview, gray panel), **Appearance** editors (**Movie Grid Settings** card, Hide/Show, TV focus) |
| 14 | [14-live-tv-appearance-channel-grid.md](14-live-tv-appearance-channel-grid.md) | **Live TV · Appearance** — Channel Grid Settings (2×2 focus vs OK, Hide/Show layout, rail), cold-start pointer |
| 15 | [15-hero-background-appearance-editor.md](15-hero-background-appearance-editor.md) | **Hero background** editor — gradient + wash + TV frame, D-pad steppers, bottom-right panel, persistence |
| 16 | [16-performance-tier-and-tv-input.md](16-performance-tier-and-tv-input.md) | **Performance** — Full / Optimized / Automatic (RAM threshold), what changes, Settings copy, **TV IME + D-pad** (Shield / Chromecast) |
| 6 | [06-playback-and-native-player.md](06-playback-and-native-player.md) | **PlayerService**, **hero preview**, **`openIptvilPlayer`**, **VOD aspect ratio** (native + Flutter), **live vs VOD** chrome + remotes |
| 7 | [07-android-build-and-branding.md](07-android-build-and-branding.md) | Manifest, sideload |
| 8 | [08-feature-history-and-decisions.md](08-feature-history-and-decisions.md) | Chronology |
| 9 | [09-backup-system.md](09-backup-system.md) | Export / import / share / delete backups |
| 10 | [10-recording-epg-system.md](10-recording-epg-system.md) | Recording, catch-up EPG, approval store, optional TV frame on EPG rows |
| 11 | [11-feature-showcase.md](11-feature-showcase.md) | Marketing-style feature list |
| — | [APP-FEATURES-OVERVIEW.md](APP-FEATURES-OVERVIEW.md) | **Single consolidated feature catalog** (all areas, one file) |
| — | [PERFORMANCE_TIER_SYSTEM.md](PERFORMANCE_TIER_SYSTEM.md) | **Performance tier** — Full / Optimized / Auto, Chromecast, native buffers, leapfrog (full technical record) |
| — | [subtitle-system.md](subtitle-system.md) | OpenSubtitles, VOD subtitles, look editor, backup keys |
| 12 | [12-player-pool-system.md](12-player-pool-system.md) | Player pool (if referenced from index) |
| 13 | [13-vod-labels-imdb-posters.md](13-vod-labels-imdb-posters.md) | **VOD labels**, My List pills, episode marks, backup, **IMDb chips** on posters |
| 17 | [17-parental-control.md](17-parental-control.md) | **Parental control** — PIN (4–8 digits), lock-all, **Live TV four scope actions** (lock / lock+hide from browse), browse-hide maps, restricted rules names, backup `parentalControl` |
| 18 | [18-manage-live-channels.md](18-manage-live-channels.md) | **Manage channels** — per-playlist rename / hide / custom logo; `PlaylistChannelOverrideStore`; playlist order in category list |
| 19 | [19-android-offline-vod-downloads.md](19-android-offline-vod-downloads.md) | **VOD offline download** — Windows → user Downloads; Android → app-private `vod_offline/` + Account list; pipeline, filenames, `VodOfflineLibrary` |

## Quick facts

- **Android native video:** **`NativeExoPlayerSession`** + **`NativeLivePreviewSession`** use **`createSurfaceProducer()`** (not **`createSurfaceTexture()`**). **`EnableImpeller` false** in **`AndroidManifest.xml`** under **`<application>`** (required placement — [flutter/flutter#154252](https://github.com/flutter/flutter/issues/154252)) for **correct video colors** on TV (**OpenGL** compositing). Same APK for **Shield / ONN / Chromecast**; see **`06-playback-and-native-player.md`**, **`07-android-build-and-branding.md`**, **`08-feature-history-and-decisions.md`**.
- **Launcher foreground bitmap:** **`drawable-nodpi/app_icon.jpg`** (resource name **`app_icon`**). File format must match extension (**AAPT2** fails if JPEG is named **`.png`**).
- **Android `applicationId`:** `com.iptvil.iptvil` — `android/app/build.gradle`
- **AndroidX Core:** Root **`android/build.gradle`** forces **`androidx.core:core`** and **`androidx.core:core-ktx`** to **1.15.0** so Flutter **`TextInputPlugin`** / **`EditorInfoCompat.setStylusHandwritingEnabled`** match the packaged library (fixes **Add Playlist** IME crash on some Google TV / ONN devices when Core was pinned to **1.12.0**). See **`07-android-build-and-branding.md`**.
- **Two Kotlin sessions:** **`NativeExoPlayerSession`** (fullscreen) + **`NativeLivePreviewSession`** (hero **`com.iptvil/live_preview`**).
- **Leanback:** **`required="false"`** for broader install (07-android-build-and-branding.md).
- **EPG:** **`LiveEpgController`** + short/simple table APIs; **`epgChannelId`** on channels when present; **`lookupDisplay` / `lookupListings`** for per-tile / hero / player consistency. **Per-playlist EPG time** (how start/end are **labeled**): **`Settings → My playlists → EPG`** → **`PlaylistEpgTimeScreen`**; **`PlaylistEpgTimezoneStore`** + **`epg_time_display.dart`**; **`timezone`** package. See **`10-recording-epg-system.md`**, **`04-data-playlists-and-xtream.md`**.
- **Xtream catalog cache:** Large snapshots are **files** (`iptvil_cat_full_*.json`, `iptvil_cat_live_*.json` next to **`iptvil_xtream_catalog.db`**), not multi‑MB SQLite **TEXT** rows — avoids **Android `CursorWindow`** **~2 MB** row limit (**`Row too big`**). See **`04-data-playlists-and-xtream.md`**, **`08-feature-history-and-decisions.md`**.
- **Clock:** `clock_overlay_settings_store` + `ClockOverlayLayer` in **`app.dart`** `MaterialApp.builder`; **Settings → Clock** — **`clock_settings_screen.dart`** (info **banner** + option grid); **8** color presets (**3 neon** → **DSEG7Classic** for time + date **digits**; **Roboto** for **`MON`–`SUN`**); font file under **`assets/fonts/`**.
- **Visual team:** **`TeamVisualStore`** (`iptvil_visual_team_v1`) — **Cosmic** (cyan), **Aurora** (violet / purple–pink), **Solar** (yellow / gold neon), **Heritage** (champagne gold, wine, midnight — classic elegance). **`TeamPalette`** + **`TeamPaletteTheme`**; UI reads **`context.teamPalette`**. **`MaterialApp`** keeps a stable home; **`builder`** wraps the subtree in **`ListenableBuilder(teamVisualStore)`** + **`Theme(AppTheme.themeForPalette(palette))`** so switching teams does not reset navigation. Shell tab **Theme** → **`team_screen.dart`**: after **`setTeam`**, **`ShellNavigationHub.instance.goTo(ShellDestination.liveTv)`** returns to **Live TV**.
- **Add Playlist / TV keyboard:** **`ShieldTvTextField`** uses a real **`keyboardType`** (not **`TextInputType.none`**) so Android TV shows the IME; **Add Playlist** auto-focuses the type picker and first form field; **scroll + viewInsets + metrics** avoid the keyboard covering **Password** / **Name**. **Trailers:** **`in_app_youtube_trailer_screen.dart`** + search; external **YouTube** watch URL. **`piped_trailer_stream.dart`** optional for future direct-stream experiments.
- **Live favorites:** **`live_favorite_groups_store.dart`** (`iptvil_live_favorite_groups_v1`); **Favorite setup** = **`live_tv_favorites_screen.dart`** + editor + picker. Legacy **`my_space_store.dart`** / **`iptvil_my_space_sections_v1`** may remain on disk; **My space** shell UI **removed**.
- **Shell exit / preview:** **Double Back** from menu-open-from-Back state + **`LivePreviewChannel.dispose`**; **`MainActivity.onPause`** → **`stopForActivityPause`** on hero native session.
- **Open issue:** transient **nav chrome flash** on some TVs (documented in **`CHANGELOG.md`** Known issues).
- **Movies / Series (full option reference):** VOD labels, My List pills, rail + card style prefs, detail actions, player auto-label, IMDb badges, backup keys — **`13-vod-labels-imdb-posters.md`**.
- **VOD fullscreen aspect:** **`NativeExoPlayerSession`** — **`displayVideoWidthHeight`**, **`SCALE_TO_FIT`**; **`PlayerScreen`** — **`_vodContainVideoSize`** + centered **`Texture`** for **`!isLive`** (see `06-playback-and-native-player.md`).
- **VOD D-pad seek:** **`player_screen.dart`** — **±30 s** tap, **75 ms** hold repeat, **30 / 60 / 120 s** ramp. **VOD jump row (tier B):** **A/V sync** (OK → small popup, **±50 ms**, persisted per **`resumeContentId`**), **Speed** (**0.25×–3×** including **1.5×** / **2.5×**, session-only), far-right **Settings** → **`openPlayerSettingsOverlay`**. See **`06-playback-and-native-player.md`** (VOD overlay).
- **Missing catalog art:** **`TvUniversalMediaPlaceholder`** + **`tv_media_urls`** **`''`** when URL not loadable — same look for **Live** logos and **VOD** posters (see **`05`**, **`06`**).
- **After `PlayerScreen` pops:** **Live** — restore channel tile + optional pill focus suppression (`scheduleSteadyChannelTileFocus`, **`TvFocusable.canRequestFocus`** on pills). **VOD** — **`onPlayerClosed`** runs **sync** before preview resume; **details** **`PopScope`** swallows duplicate **Back** ~480 ms so browse does not appear under one press.
- **Parental:** **`17-parental-control.md`** — PIN, four Live TV scope modes (lock / lock+hide), browse-hide maps, restricted rules labels, compact PIN UI, Live TV empty-pill recovery, player EPG **Back**.
- **Channel grid tiles:** **`live_tv_channel_browse_tile.dart`** — **`focusScale: 1.0`**, **`parallaxSlide: 0`**, **`ClipRRect`** hard clip; logo+text uses **`BoxFit.contain`**; optional **EPG** line when cached for that channel. **Appearance:** four card styles + global **name vertical** step (**`live_tv_name_vertical_bias_store.dart`**, **Live TV · Appearance** → Tiles → **Name** row); see **`05`**, **`11-feature-showcase.md`**.

## Personal / ops

- **[debug-running.md](debug-running.md)** — Quick **ADB + logcat** steps (your `platform-tools` path, wireless address, save logs). For big debugging sessions, not product spec.

## Updating docs

Change the relevant **0x-*.md** file and add a bullet to **08-feature-history-and-decisions.md**. Recording / catch-up / EPG approval details: **[10-recording-epg-system.md](10-recording-epg-system.md)**.
