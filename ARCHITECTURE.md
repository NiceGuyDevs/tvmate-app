# Architecture

## High level

IpTvIl is a Flutter app with an Android-first, TV-first UI. Heavy lifting for **streaming** is done on Android with **Media3 ExoPlayer**, while Flutter owns **navigation, focus, and playback chrome** (overlays, progress, retry messaging).

### AndroidX Core vs Flutter text input

Gradle **`resolutionStrategy`** in **`android/build.gradle`** forces **`androidx.core:core`** and **`androidx.core:core-ktx`** to **1.15.0**. Flutter’s Android embedding calls **`EditorInfoCompat.setStylusHandwritingEnabled`** when building an **`InputConnection`** for **`TextField`**s; that API exists only in **newer** AndroidX Core than **1.12.0**. Pinning an older Core caused **`NoSuchMethodError`** and an instant crash when opening the on-screen keyboard (e.g. **Settings → Add Playlist** on some **Google TV / ONN**-class devices). See **[documentation/07-android-build-and-branding.md](documentation/07-android-build-and-branding.md)**.

## Player architecture

### Goals

- **HLS (.m3u8)** and live-style streams without relying on Flutter’s `video_player` plugin for decoding.
- **One native player instance** reused across `load()` calls to avoid teardown stalls when switching channels or titles.
- **Smooth handoff:** new URL → `stop()` → `setMediaItem(uri, resetPosition)` → `prepare()` (retries on failure).

### Layers

1. **Flutter — `PlayerService` (`lib/player/player_service.dart`)**  
   Abstract API: `ensureTexture()`, `load`, `play`, `pause`, `seekTo`, `releaseTexture`, `events`.  
   Android uses `NativeAndroidPlayerService` (`native_android_player_service.dart`). Other platforms use `UnavailablePlayerService` so `flutter analyze` / widget tests can run without a native stack.

2. **Flutter — `PlayerScreen` (`lib/player/player_screen.dart`)**  
   - Embeds video with `Texture` using the id from `ensureTexture()`.  
   - **VOD (`isLive: false`):** once **`videoWidth` / `videoHeight`** arrive from progress events, **`LayoutBuilder`** + **`_vodContainVideoSize`** (same math as **`BoxFit.contain`**) **`Center`** a **`SizedBox`** around **`Texture`** so the picture is **not stretched** on Android TV (letterboxing / pillarboxing on the **Scaffold** black background). **Live:** **`Texture`** remains **full-screen** (`SizedBox.expand`).  
   - **VOD D-pad seek (TV):** constants **`_vodSeekTapMs`**, **`_vodSeekHoldTier*Ms`**, **`_vodSeekHoldTickMs`** — tap **±30 s**, hold repeat **~75 ms**, ramp **30 / 60 / 120 s** per step (see **`documentation/06-playback-and-native-player.md`**).  
   - **VOD tier-B jump row** (`PlayerTvVodJumpStrip`): minute jumps + **far-right Settings** → **`openPlayerSettingsOverlay`** (same in-player settings route as Live TV).  
   - Subscribes to `events` for buffering, progress, retries, and fatal errors.  
   - Overlay: title, LIVE badge, buffering text, progress (and seek slider for VOD when duration is known), play/pause, auto-hiding controls, back handling with focus restoration via `openIptvilPlayer` (`player_navigation.dart`).

3. **Android — `NativeExoPlayerSession` (`android/.../NativeExoPlayerSession.kt`)**  
   - `ExoPlayer` from Media3 + HLS module.  
   - **`FlutterEngine.renderer.createSurfaceProducer()`** (not legacy **`createSurfaceTexture`**) → **`SurfaceProducer.getSurface()`** → **`player.setVideoSurface`**, with **`SurfaceProducer.Callback`** for resume/background cleanup and **`setSize`** when video dimensions are known (works with **Skia / OpenGL** and **Impeller**). **`AndroidManifest.xml`** disables **Impeller** (**`EnableImpeller` false** on **`<application>`** — **must not** be nested only under **`activity`** or it is ignored; see flutter/flutter#154252) so **video colors** stay correct where **Vulkan + YUV** mis-samples. See **[documentation/07-android-build-and-branding.md](documentation/07-android-build-and-branding.md)**.  
   - **`setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)`** — uniform scale inside the surface (pairs with Flutter VOD layout).  
   - **`emitProgress`:** **`videoWidth` / `videoHeight`** for Flutter are **display** sizes: **`Format.pixelWidthHeightRatio`** (anamorphic), then **swap** for **`rotationDegrees` 90 / 270**; also drives **`SurfaceProducer.setSize`**.  
   - On `releaseTexture`, the producer is released (callback cleared) and the player clears the surface; the **player object is kept** until process teardown (or future explicit `dispose` if added).

### Platform channels

| Channel | Direction | Purpose |
|--------|-----------|---------|
| `com.iptvil/player` | Flutter → Android (MethodChannel) | `ensureTexture`, `load`, `play`, `pause`, `seekTo`, `releaseTexture`, `dispose` |
| `com.iptvil/player_events` | Android → Flutter (EventChannel) | Maps with `type`: `state`, `isPlaying`, `progress`, `retrying`, `error` |
| `com.iptvil/live_preview` | Flutter → Android (MethodChannel) | **`ensureTexture`**, **`load`**, **`pauseForFullscreen`**, **`resumeAfterFullscreen`**, **`dispose`** — second **`ExoPlayer`** for Live TV **hero** only |

**`load` arguments:** `{ "url": String, "isLive": bool }` — `isLive` is reserved for UI (seek bar); ExoPlayer infers HLS type.

### Activity lifecycle vs hero preview

- **`MainActivity.onPause()`** calls **`NativeLivePreviewSession.stopForActivityPause()`** (same teardown as the **`dispose`** method channel) so **hero preview audio stops** when the user leaves the app (home, recents, or **`SystemNavigator.pop`**) even if the process stays alive on the device.
- Flutter **`MainShellScreen`**: when the user exits via **double Back** from the rail-open-from-Back state, **`_stopPreviewAndExit`** **`await`s `LivePreviewChannel.dispose()`** then **`SystemNavigator.pop()`** so Dart and native stay aligned before the activity finishes.

### Live TV hero preview (native)

- **`NativeLivePreviewSession.kt`** — separate from **`NativeExoPlayerSession`**. Uses the same **`TextureRegistry.SurfaceProducer`** pattern as the main session (not legacy **`SurfaceTexture`**); **`setVolume(1f)`** and **`handleAudioFocus = true`** so the focused channel is **audible** in the hero on real hardware. **`setVideoScalingMode(SCALE_TO_FIT)`** for consistent scaling in the hero bezel.
- **Flutter:** **`HeroLivePreview`** (`lib/ui/live_tv/hero_live_preview.dart`) + **`LivePreviewChannel`** (`live_preview_channel.dart`). Debounced **`load(url)`** when the grid/hero focus channel changes. **`dispose`** when leaving **Live TV** (shell swaps away `LiveTvScreen`). **`HeroLivePreview`** is a **`WidgetsBindingObserver`**: after **`AppLifecycleState.paused`** then **`resumed`**, it clears the texture id and **`_bootstrap()`** again so the UI matches native teardown (**`MainActivity.onPause`** releases the preview session — see below).
- **No double audio:** **`openIptvilPlayer`** (`player_navigation.dart`) calls **`pauseForFullscreen`** before **`Navigator.push`**, and **`resumeAfterFullscreen`** after the route **pops**. **`pauseForFullscreen`** only sets internal “muted for fullscreen” state when a preview **player already exists** (so opening Movies before Live TV cannot break the first preview load). **`context.mounted`** is checked after async **`PlaybackResumeStore.clear`** before **`Navigator.of(context)`**.

**`progress` payload:** `positionMs`, `bufferedMs`, `durationMs` (`-1` when unknown / live), **`videoWidth` / `videoHeight`** (display pixels for aspect layout; **-1** until known), optional **`bitrate`**.

**Retries:** On `PlaybackException`, native code emits `retrying` (attempt 1–3) and reloads the same URI after a short delay. After three failures, `error` is emitted. The overlay shows *“Playback failed. Retrying…”* during retries.

### Integration entry points

- **Live TV:** channel tile activate → **`streamUrl`** from Xtream mapper when set, else `mockLiveStreamUrlForChannel` + `isLive: true`; **`LiveEpgController.refreshForStream`** on focus / lineup change
- **Movies:** Play actions → `mockVodStreamUrlForMovie` + `isLive: false`
- **Series:** episode tile activate → `mockVodStreamUrlForEpisode` + `isLive: false`

Replace mock URL helpers with playlist/Xtream data when those pipelines exist; `PlayerScreen` stays unchanged.

### Navigation and focus after `PlayerScreen` pops

**`openIptvilPlayer`** (`player_navigation.dart`) returns **`PlayerBrowseRestore?`** from the route (`liveChannelId` for live after UP/DOWN; `movieId` / `seriesId` for VOD when `browseRestoreMovieId` / `browseRestoreSeriesId` were passed).

- **Live (`isLive: true`):** After **`await navigator.push`**, the code **awaits** **`resumeAfterFullscreen`** (and mute prefs), then schedules **previous-focus** restore (unless **`suppressPreviousFocusRestore`**), then **`onPlayerClosed`** in a **post-frame** callback so grids can **`Scrollable.ensureVisible`** before **`requestFocus`**.
- **VOD (`isLive: false`):** **`onPlayerClosed(restore)` runs synchronously immediately after the push returns**, **before** live-preview resume and before deferred focus restore. This lets **movie/series details** mark a **short window** where **system Back** must not pop the details route (duplicate back from the same remote press). Then preview resumes and previous focus is restored as usual.

**Movie / series details** use **`PopScope(canPop: false)`** with **`onPopInvokedWithResult`**: programmatic / system back pops details only when not swallowing the post-player window. The **icon back** button still calls **`Navigator.pop`** directly.

**Live TV** uses **`suppressPreviousFocusRestore: true`** and restores the channel tile by id via **`scheduleSteadyChannelTileFocus`** plus optional category **pill** **`canRequestFocus: false`** during restore.

## Data & settings

Library and playlist preferences live under `lib/data/` (e.g. `library_controller.dart`, `stored_playlist.dart`). They are independent of the player bridge.

**Clock overlay:** `clock_overlay_settings_store.dart` persists on/off, 12/24h, corner, size, opacity, color index (**0–7**: five standard + **three neon**), and optional **framed** mode (border + gradient + semi-transparent backdrop; second line **`DD/MM MON`** with **`MON`–`SUN` always uppercase**). **Framed + segment/neon:** **`Text.rich`** uses **`DSEG7Classic`** for **`DD/MM `** and **`Roboto`** for the weekday so letters are not rendered in lowercase by segment font fallback. Loaded at startup in `main.dart`. **`ClockOverlayLayer`** in `lib/ui/clock/clock_overlay.dart` is built in **`IptvilApp`** via `MaterialApp.builder` + `Stack` with **`IgnorePointer`**; unframed mode shows **time only** with no shadows where applicable. **Neon indices (5–7)** apply **DSEG** + glow to **time** and the numeric portion of the date line.

**Legacy `my_space_store`:** `lib/data/my_space_store.dart` — JSON in **`iptvil_my_space_sections_v1`**. **Shell UI removed** — data file may remain unused.

**Live TV favorites:** `lib/data/live_favorite_groups_store.dart` — **`iptvil_live_favorite_groups_v1`**; **Settings → Favorite setup** (**`LiveTvFavoritesScreen`**, editor, picker).

**`TvFocusable`** (`lib/ui/focus/tv_focusable.dart`) supports optional **`canRequestFocus`** (default **true**) so parents can temporarily disable category pills during post-player focus restore.

**Playlist category UI:** `PlaylistGroupSectionScreen` centers content with a **max width** cap; **`TvFocusable`** on dense lists uses **`focusScale: 1.0`**, **`parallaxSlide: 0`**, **`showFocusElevation: false`**, and optional **`focusedBorderWidth`** (~1.4) so focus chrome does not clip off-screen.

**Visual team (Cosmic / Aurora / Solar / Heritage):** `team_visual_store.dart` persists **`AppVisualTeam`** (`iptvil_visual_team_v1`; storage strings **`cyan`**, **`violet`**, **`solar`**, **`heritage`**). **`IptvilApp`** (`app.dart`) keeps **`MaterialApp`** stable and, in **`MaterialApp.builder`**, listens to **`teamVisualStore`** and wraps the subtree in **`Theme(data: AppTheme.themeForPalette(palette))`** (plus the clock **`Stack`**). **`TeamPaletteTheme`** attaches the palette for **`context.teamPalette`**. Shell **Theme** tab (label): **`TeamScreen`** — after the user selects a team, **`ShellNavigationHub.instance.goTo(ShellDestination.liveTv)`** switches the shell to **Live TV**. Backdrop: **`CosmicSpaceBackdrop`** (palette-driven for all four looks).

**Trailers (details screens):** **`InAppYoutubeTrailerScreen`** performs YouTube-style search in-app; **Play** opens a **watch** URL via **`url_launcher`** (external YouTube app / browser). Optional **`piped_trailer_stream.dart`** can resolve direct stream URLs but is not the default UX path on TV.

## Xtream Codes integration (Step 8A)

### When data is demo vs real

- **`LibraryController.useDemoData`** is `true` when there are **no playlists** or when the user enabled **Demo mode** in Settings. Browse screens use the static mock lists in `lib/ui/**/mock_*_data.dart`.
- When **`useDemoData`** is `false` and **`activePlaylist`** is **Xtream**, screens call **`XtreamCatalogRepository.syncFromLibrary`**, which hits `player_api.php` and fills the same UI models the mocks use (categories, channels, movies, series rows).
- When **`useDemoData`** is `false` but the active playlist is **M3U**, browse surfaces show an unsupported error (M3U parsing is out of scope for Step 8A).

### Service and mapping

- **`lib/xtream/xtream_api_client.dart`** — GET JSON: auth probe, `get_live_categories`, `get_live_streams`, `get_vod_categories`, `get_vod_streams`, `get_series_categories`, `get_series`, `get_series_info`, **`get_short_epg`**, **`get_simple_data_table`**.
- **`lib/xtream/xtream_mapper.dart`** — Maps API maps to `MockLiveCategory`, `MockLiveChannel`, `MockMovieCategory`, `MockMovie`, `MockSeriesCategory`, `MockSeries`, and (for series info) `MockSeason` / `MockEpisode`, including **`streamUrl`** via `XtreamStreamLinkBuilder` (`/live`, `/movie`, `/series` paths aligned with the panel URL prefix).
- **`lib/data/xtream_catalog_repository.dart`** — Singleton cache, **`ChangeNotifier`**, loading/error/empty states. **Series browse** uses `series` rows with **empty `seasons`** until **`fetchSeriesDetail`** runs on the details screen (`get_series_info`).
- **`lib/data/xtream_catalog_cache_db.dart`** — Persists Xtream browse snapshots: **SQLite** for **fingerprint / schema / timestamps**, **JSON files** (`iptvil_cat_full_*.json`, `iptvil_cat_live_*.json`) for large payloads so Android never hits **`CursorWindow`** row-size limits on **`SELECT`** (see **`documentation/04-data-playlists-and-xtream.md`**).

### Playlist ingest

- **`PlaylistLoadingScreen`**: Xtream drafts run a **real** API round-trip; persisted **`liveCount` / `moviesCount` / `seriesCount`** match list sizes from the server. M3U drafts still use the **placeholder** animated pipeline (implementation deferred).

### Player

- Unchanged: **`PlayerScreen`** / **`PlayerService`** stay the same. Items with **`streamUrl` set** use that URL; legacy demo paths still fall back to `lib/player/mock_stream_urls.dart`.

### Live EPG (Xtream)

- **`LiveEpgController`** (`lib/data/live_epg_controller.dart`) — singleton **`ChangeNotifier`**. **`refreshForStream(streamId, { epgChannelId })`** loads programme info for the focused live channel when **`useDemoData`** is false and the active playlist is Xtream. Hero **visual design** uses a **gradient panel** for readability; EPG text is **not** drawn over a full-bleed channel poster (that role is served by the **live preview** + logo column).
- **HTTP:** **`XtreamApiClient.getShortEpg`** then, if listings parse empty, **`getSimpleDataTable`** (same `stream_id` query param). Candidate ids: optional **`epgChannelId`** (from `get_live_streams` → `MockLiveChannel.epgChannelId`) first, then **`streamId`**, deduped.
- **Parsing:** **`lib/xtream/xtream_short_epg_parser.dart`** — `epg_listings` and alternate container keys, Unix or string datetimes, **`now_playing`**, base64 titles, localized title maps.
- **UI:** **`LiveTvScreen`** hero and **`PlayerScreen`** (when lineup items carry ids) use **`ListenableBuilder`** / **`ValueListenableBuilder`** with **`focusedStreamId == channel.id`** so cached EPG matches the visible channel.
- **`LiveLineupItem`** — **`channelId`**, **`epgChannelId`** passed from `LiveTvScreen` when opening the player so UP/DOWN channel changes refresh EPG correctly.
- **Per-playlist EPG labels:** Programme times in the hero, player bottom bar, fullscreen EPG overlay, and Recording EPG list are formatted for the **active** playlist’s **`PlaylistEpgTimezoneStore`** mode (`local`, `original`, or a named IANA zone). **`lib/data/epg_time_display.dart`**; **`timezone`** initialized in **`main.dart`**. Does not replace Xtream server offset used for catch-up URL `start=` parameters.
