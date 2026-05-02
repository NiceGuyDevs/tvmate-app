# Playback and native player

## Dart API

**Abstract:** `PlayerService` — `lib/player/player_service.dart`

| Method | Purpose |
|--------|---------|
| `ensureTexture()` | Create (or reuse) Flutter **`Texture`** id; on **Android** the backing is **`SurfaceProducer`** (not legacy **`SurfaceTexture`**) |
| `load({url, isLive, audioDelayMs?, playbackSpeed?})` | Load media; ExoPlayer infers HLS, etc. Optional VOD **A/V sync ms** and **session speed** (see VOD section below) |
| `setPlaybackSpeed` / `setAudioDelayMs` | VOD: session speed and live A/V offset (native) |
| `play` / `pause` | Transport |
| `seekTo` | VOD |
| `releaseTexture()` | Detach surface, stop playback; native player object may remain for reuse |
| `getTracksSnapshot()` | Future audio/subs metadata |
| `events` | `Stream<PlayerNativeEvent>` |
| `dispose()` | Dart-side cleanup |

**Android implementation:** `NativeAndroidPlayerService` — channels `com.iptvil/player` and `com.iptvil/player_events`.

**Other platforms:** `UnavailablePlayerService` throws or no-ops so the project still analyzes.

## Live TV hero preview (second player)

**Dart:** `lib/ui/live_tv/live_preview_channel.dart` — thin wrapper on **`com.iptvil/live_preview`**.

| Call | Purpose |
|------|---------|
| `ensureTexture()` | Allocate preview surface; returns texture id for **`Texture`** |
| `load({url, isLive})` | Load the focused channel's stream (same URL shape as main player) |
| `pauseForFullscreen` | Before **`PlayerScreen`** — preview **stops** competing for **audio** / focus |
| `resumeAfterFullscreen` | After route **pop** — restore preview if still on Live TV |
| `dispose` | Tear down when leaving **`LiveTvScreen`** |

**Android:** `NativeLivePreviewSession.kt` — separate **ExoPlayer**, **`TextureRegistry.SurfaceProducer`** (not legacy **`SurfaceTexture`**), volume **1f**, audio focus **on**. **`MainActivity`** registers this channel next to **`NativeExoPlayerSession`**. **`MainActivity.onPause()`** invokes **`stopForActivityPause()`** (same cleanup as the **`dispose`** channel) so preview **audio does not continue** when the activity is not in the foreground.

**Flutter resume:** **`HeroLivePreview`** observes **`AppLifecycleState`**: after **`paused`** then **`resumed`**, it clears the stale **`Texture`** id and **`_bootstrap()`** again so the widget matches native teardown.

## PlayerScreen

**File:** `lib/player/player_screen.dart`

- Renders **`Texture(textureId: …)`** when initialized; black + spinner until texture id exists.
- Subscribes to **`events`**: buffering, progress, duration, retry banner, fatal error overlay.
- **VOD resume:** when **`resumeContentId`** is set, last position is restored once after **ready** (**`PlaybackResumeStore`**).
- **Live:** optional **`liveLineup`** for **UP/DOWN** channel change in-place. Items should include **`channelId`** (and optional **`epgChannelId`**) so **`LiveEpgController.refreshForStream`** can load short EPG for the current channel.

### VOD display aspect ratio (no stretch)

Fullscreen **movies / episodes** use **`isLive: false`**. Unlike a **`PlayerView`** app, output goes to **`SurfaceProducer` → `Surface` → Flutter `Texture`**, so **letterboxing** is implemented in two layers:

1. **Kotlin (`NativeExoPlayerSession.kt`)**  
   - **`ExoPlayer.setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)`** — uniform scale inside the surface.  
   - Progress events include **`videoWidth` / `videoHeight`** derived from **`player.videoFormat`**: apply **`Format.pixelWidthHeightRatio`** (anamorphic / non-square pixels), then **swap** width/height for **`rotationDegrees`** **90** or **270** so the numbers match **on-screen** aspect.

2. **Flutter (`player_screen.dart`)**  
   - **`_buildVideoSurface`**: for **VOD**, when dimensions are **> 0**, **`LayoutBuilder`** computes the largest axis-aligned rectangle that **fits** the screen with the same aspect ratio as **`videoWidth` : `videoHeight`** (helper **`_vodContainVideoSize`** — equivalent to **`BoxFit.contain`**), **`Center`** + **`SizedBox`** + **`Texture`**. The **Scaffold** stays **`Colors.black`** — unused areas are **bars**.  
   - **Live** fullscreen keeps **`SizedBox.expand`** around **`Texture`** (full bleed).  
   - Until the first progress tick with valid sizes, VOD may briefly use full-screen **`Texture`** like before.

**Hero preview** (`NativeLivePreviewSession.kt`): also **`SCALE_TO_FIT`**; hero **`HeroLivePreview`** uses **`SizedBox.expand`** + **`Texture`** inside the bezel (small surface; fit mode avoids odd stretch).

### Live TV fullscreen overlay (`player_tv_overlay.dart`)

- **No full-screen scrim.** **`PlayerTvBottomSheetChrome`**: bottom band (~**32%** height, **max ~340px**, **scrollable** column) so EPG + meta do not overflow.
- **Top bar:** Back + title + **LIVE** badge on a **dark rounded panel**.
- **EPG row:** **`PlayerTvLiveIdentityRow`** (channel + now/next line); **`PlayerTvEpgStrip`** — **NOW** (**red**), **NEXT** (**blue**), neutral cards. Data comes from **`LiveEpgController.lookupDisplay` / `lookupListings`** for the **current lineup channel id** so hero vs player focus does not blank the strip (see **EPG cache reads** below).
- **Buffering:** centered **`_BufferingSpinnerOverlay`** (**`CircularProgressIndicator`**, accent) — for **live** streams, the spinner is **delayed by 1.5 seconds** so fast channel switches never show it (see **Fast channel switching** below). **VOD** shows the spinner immediately.
- **Play/Pause** focus button; **UP/DOWN** switch channel when **`liveLineup.length > 1`**.
- **Auto-hide:** **`PlayerTvOverlayTheme.autoHideDuration`** (**5s**) restarts on **`_pokeControls()`**; timer cancelled when overlay is dismissed manually.
- **Back / PopScope:** **`PopScope(canPop: false)`** + root **`Focus.onKeyEvent`** + **`HardwareKeyboard`**. While **chrome is interactive** (**`_controlsVisible`** or **`_liveOverlayFadingOut`** during **`fadeDuration`** after hide), **Back** runs **`_hideControlsOverlay()`** only — avoids exiting mid **AnimatedOpacity** fade. After chrome fully dismissed, **Back** → **`_exit()`** → **`Navigator.pop`**. **OK** while overlay hidden → show chrome + focus play.

### VOD fullscreen overlay (`player_tv_overlay.dart`)

- **Start:** clean video (no chrome) once duration is known for seek UI.
- **Down (first press):** bottom **`PlayerTvVodBottomChrome`** with **`PlayerTvVodTimelineStrip`** (fat bar: elapsed left, **time remaining** countdown right, optional resolution chip) **plus** **`PlayerTvVodJumpStrip`** — jump chips (**−15s**, **−1 / −2 / −3 min**, **play/pause** center, **+3 / +2 / +1 min**, **+15s**), then trailing **A/V sync**, **Speed**, and **Settings** (gear). Icons: **~36px** jump chips, **~40px** center play, **~40px** trailing controls.
- **Tier A (timeline + jump row visible, jump strip not focused):** **Left / Right** **scrub** — **±30 s** per tap; **hold** uses the **~75 ms** ramp (**30 s → 60 s → 120 s** per tick); **Center / OK** **toggles play/pause** globally. Jump / A/V / Speed / Settings are **visible only** until tier B.
- **Down (second press):** **tier B** — focus in the jump strip, default **center play** (**`_vodJumpStripFocused`**, **`_vodJumpFocusIndex`**). **Left / Right** move focus across **twelve** slots (**0–8** = jumps left→right, **9** = A/V, **10** = Speed, **11** = Settings). **OK** runs the focused action (**`_activateVodJumpButton`**): seeks, play/pause, **A/V** opens a small **A/V sync** popup (**`PlayerTvVodAudioOffsetPopup`**) — **Left/Right** in the popup adjusts **±50 ms** (persisted per **`resumeContentId`** via **`VodAudioOffsetStore`** when set); **Back/OK** closes the popup. **Speed** opens **`PlayerTvVodSpeedPicker`** — presets **0.25×, 0.5×, 1×, 1.5×, 2×, 2.5×, 3×** (session-only; native resets on **`releaseTexture`**); picker UI scaled ~**85%** for a smaller on-screen footprint. **Settings** opens **`openPlayerSettingsOverlay`**. **Up** leaves tier B. **Down** in tier B refreshes the auto-hide timer.
- **Native A/V:** **`IptvilLeadingSilenceAudioProcessor`** + **`IptvilTrimmingAudioProcessor`** in **`IptvilRenderersFactory`** / **`DefaultAudioSink`**; **`NativeExoPlayerSession`** applies delay and forces a short seek flush so ExoPlayer picks up processor changes.
- **Left / Right (tier A):** **`_startSeekHold`** / **`_vodSeekTapMs`**, **`_flashVodTimeline`**, **4s** auto-hide (**`PlayerTvOverlayTheme.autoHideDuration`**).
- **Up:** **`PlayerTvVodInfoBanner`** — title + optional **full description** + resolution/bitrate. **`PlayerScreen.contentDescription`** / **`openIptvilPlayer`**.
- **Back / Escape:** while **any** VOD overlay is up (timeline, info banner, tier-B focus, **speed picker**, or **A/V popup**), **Back** dismisses those first (**`_hideControlsOverlay()`** / **`PopScope`**) — **without** exiting the player.
- **VOD key routing:** Handled in **`HardwareKeyboard.instance.addHandler`** (**`_onPlayerHardwareKey`**). **`_activateVodJumpButton`** uses a **~280 ms** debounce against duplicate **OK** activations.
- **VOD offline download (file copy):** **`VodDownloadController`** streams the VOD URL to a temp file, rejects HLS playlists, then copies to the final location. **Windows:** user **Downloads** folder. **Android:** app-private **`TVMatePro/vod_offline/`** + **Account → Offline downloads** (list, play **`file://`**, delete). Jump strip **Download** = index **14**. See **`19-android-offline-vod-downloads.md`**.

### EPG cache reads (hero, grid, player)

**File:** `lib/data/live_epg_controller.dart`

- **`refreshForStream`** still sets global **`focusedStreamId`** and fills **`_cache[streamId]`**.
- **`lookupDisplay(streamId)`**, **`lookupListings(streamId)`**, **`isLoadingFor(streamId)`** read **per-channel** data so UI stays correct when another surface (e.g. hero) triggers a refresh for a different id. Used by **`LiveTvHeroPanel`**, **`PlayerScreen`** EPG strip, and **`LiveChannelBrowseTile`** (programme line on tiles when cached).

### Debug

- **`kPlayerTvOverlayBuild`** in **`player_tv_overlay.dart`** — log label **`overlay vN`** in debug (currently **26**).

### Stability measures (teardown and navigation)

These reduce **black screen / crash** symptoms when backing out quickly or pressing Back repeatedly:

1. **`_released` flag** — After teardown starts, **`_onEvent`** and control timers ignore updates (no `setState` after dispose paths).
2. **Subscription order** — **`releasePlayerSurface`** cancels the event **subscription** early, then clears **`_textureId`** via **`setState`** so the `Texture` widget is removed **before** native `releaseTexture()` runs (avoids rendering with a dead texture id).
3. **`_exitInProgress`** — Prevents overlapping **double exit** from rapid Back.
4. **`_bootstrap` guards** — After each `await`, checks `mounted` and **`!_released`**; `load()` wrapped so errors during concurrent teardown do not surface as fatal init errors.
5. **`openIptvilPlayer` focus restore** — After pop, **`requestFocus()`** only if **`canRequestFocus`**, inside **try/catch** (`player_navigation.dart`) to avoid crashes from stale `FocusNode`s.

**Native side:** If issues persist, inspect **`NativeExoPlayerSession.kt`** for threading and surface release ordering.

## Opening the player

**File:** `lib/player/player_navigation.dart`

```dart
openIptvilPlayer(
  context,
  title:,
  streamUrl:,
  isLive:,
  contentDescription:, // optional; VOD synopsis for Up banner (movies / episodes)
  …
)
```

**Order (always):** `LivePreviewChannel.pauseForFullscreen()` (if supported) → capture **`FocusManager.instance.primaryFocus`** → **`await navigator.push`** **`PlayerScreen`**.

**After the route pops — branch on `isLive`:**

| | **Live** | **VOD** |
|---|----------|---------|
| Preview resume | **`await`** `resumeAfterFullscreen` + mute prefs | Same, **after** the step below |
| **`onPlayerClosed`** | Deferred to **post-frame** (after resume + layout) | Runs **synchronously first** with **`PlayerBrowseRestore?`** so **details** can arm duplicate-back suppression **before** async preview work |
| Previous-focus restore | Post-frame **`requestFocus`** unless **`suppressPreviousFocusRestore`** | Same (after resume) |

**`PlayerBrowseRestore`** (`player_browse_restore.dart`) is popped from **`PlayerScreen`**: **`liveChannelId`** (live, after UP/DOWN), **`movieId` / `seriesId`** when **`browseRestoreMovieId` / `browseRestoreSeriesId`** were passed into **`PlayerScreen`**.

**VOD watch labels** (automatic **watched** / **continue watching** on exit from fullscreen, **`resumeContentId`**, and **`browseMovieId` / `browseSeriesId`**): full rules and prefs are in **`13-vod-labels-imdb-posters.md`** (§8).

**Callers:** **Live TV** uses **`suppressPreviousFocusRestore: true`** and refocuses by **`liveChannelId`**; movies/series details rely on default focus restore + **`PopScope`** on the details route (see **`05-ui-shell-and-tv-patterns.md`**).

## Fast channel switching

Goal: channel switching should feel near-instant (~200–400 ms), with no visible loading indicator during normal live-stream loads. Applies to the main screen hero preview, in-player UP/DOWN channel switching, and all other live stream loads.

### ExoPlayer — buffer settings (`DefaultLoadControl`)

Configured in `NativeExoPlayerSession.ensurePlayer()`. A single `DefaultLoadControl` is shared (ExoPlayer is built once), using the VOD-friendly larger max buffer. The 250 ms playback threshold benefits both live and VOD equally.

| Parameter | Value | ExoPlayer default | Purpose |
|-----------|-------|-------------------|---------|
| `bufferForPlaybackMs` | **250 ms** | 2 500 ms | Start decoding after only 250 ms of buffered data — cuts perceived startup time dramatically |
| `bufferForPlaybackAfterRebufferMs` | **1 000 ms** | 5 000 ms | Resume quickly after a mid-stream rebuffer |
| `minBufferMs` | **5 000 ms** | 50 000 ms | Keep a 5 s rolling buffer |
| `maxBufferMs` | **30 000 ms** | 50 000 ms | Buffer up to 30 s ahead — forward seeks within this window are instant (no network round-trip) |
| `prioritizeTimeOverSizeThresholds` | **true** | true | Prefer time-based buffer limits |

### Direct media swap — no `stop()` before `setMediaItem()`

When a new URL is loaded while a stream is already playing (`applyLoadRunnable` in `NativeExoPlayerSession.kt`), the code calls `setMediaItem()` + `prepare()` **without** calling `stop()` first. ExoPlayer handles the transition internally, which:

- Avoids the full teardown/rebuild cycle of decoders.
- **Keeps the last decoded video frame visible** on the `SurfaceProducer` until the new stream renders its first frame — no black flash between channels.

### Extension renderer preference

`DefaultRenderersFactory` is set to `EXTENSION_RENDERER_MODE_PREFER`, so hardware-accelerated decoders are used when available for faster decode startup.

### `channelSwitch` native event

When a live stream is swapped (URL changes while `isLive` is true and a previous stream was already playing), native emits a **`channelSwitch`** event to Flutter before the buffering state begins. This lets the Flutter side know a rapid channel change is in progress.

### Buffering spinner — 1.5-second delay for live streams

**`player_screen.dart`** suppresses the `_BufferingSpinnerOverlay` for live streams:

- When `STATE_BUFFERING` arrives and `widget.isLive` is true, a **1 500 ms** timer starts. The spinner only becomes visible if the player is **still buffering** after 1.5 seconds.
- If `STATE_READY` arrives before the timer fires, it is cancelled — the spinner never appeared.

On any normal connection (stream starts in < 1.5 s), the user sees the previous frame → new stream pops in, with **zero** loading indicator. If a server is genuinely slow (> 1.5 s), the spinner appears to provide feedback that loading is in progress.

### Buffering spinner — 800 ms seek grace for VOD/catch-up

For VOD/catch-up streams, the spinner is suppressed for **800 ms** after each seek operation (`_vodSeekSpinnerGrace`). This prevents spinner flashes during rapid seeking and during the scrub-on-release commit. Outside of seeking, the spinner shows immediately for VOD/catch-up.

### State fields (`player_screen.dart`)

| Field | Type | Purpose |
|-------|------|---------|
| `_showLiveSpinner` | `bool` | Whether the delayed live spinner is currently visible |
| `_liveSpinnerDelayTimer` | `Timer?` | The 1.5 s delay timer; cancelled on `STATE_READY` or dispose |
| `_vodSeekSpinnerGrace` | `bool` | Whether the VOD seek grace is active (suppresses spinner) |
| `_vodSeekGraceTimer` | `Timer?` | The 800 ms grace timer; cancelled on `STATE_READY` or dispose |

All are cleaned up in `_releasePlayerSurface()` and `dispose()`.

### Why these are permanent, not patches

- **250 ms buffer threshold:** A standard `DefaultLoadControl` configuration parameter. IPTV, live broadcast, and video conferencing apps routinely use low values. ExoPlayer's 2 500 ms default targets on-demand video (YouTube, Netflix) where smooth uninterrupted playback matters more than startup speed.
- **1.5 s spinner delay:** An established UX pattern — showing a spinner for < 1 s actually makes the experience feel *slower* than showing nothing (it draws attention to the wait). Apps like YouTube, Twitch, and premium IPTV players intentionally delay loading indicators.

## Catch-up / VOD playback optimization

Goal: catch-up (recorded) content should start fast and seeking should feel responsive and smooth. These optimizations are gated on `isLive: false` — live TV behavior is completely unaffected.

### `SeekParameters.CLOSEST_SYNC` for VOD/catch-up

Set in `applyLoadRunnable` (`NativeExoPlayerSession.kt`) when `isLive` is false. Instead of seeking to the exact requested position (which requires decoding extra frames from the previous keyframe), ExoPlayer snaps to the **nearest keyframe**. This lets the decoder start immediately, making each seek resolve noticeably faster. Precision loss is ±1 second — unnoticeable for catch-up content. Live streams use `SeekParameters.DEFAULT`.

### Seek increment hints

`setSeekBackIncrementMs(30_000)` and `setSeekForwardIncrementMs(30_000)` are set on the `ExoPlayer.Builder` so ExoPlayer knows the app's seek step size and can optimize internal buffering strategy around it.

### Larger buffer (30 s max)

The `DefaultLoadControl` uses a 30 s max buffer. When catch-up content is playing, ExoPlayer buffers ahead up to 30 seconds. Forward seeks within that already-buffered window are **instant** — no network request, no server round-trip.

### Scrub-on-hold / seek-on-release

**Problem:** During hold-to-seek (Left/Right held down), the previous implementation sent a `seekTo` to ExoPlayer every 75 ms. Each seek cancelled the previous one's buffer loading, triggered a new HTTP request to the server, and completed none of them until the last. This caused heavy server thrashing and slow playback resume after releasing.

**Solution (`player_screen.dart`):**

1. **Single tap** (Left/Right quick press): sends `seekTo` immediately — no change from before.
2. **Hold starts scrubbing:** `_startSeekHold` sets `_isScrubbing = true` and initializes `_scrubPositionMs` to current position. Each 75 ms tick updates `_scrubPositionMs` locally without touching ExoPlayer.
3. **Timeline shows scrub position:** `PlayerTvVodTimelineStrip` receives `_isScrubbing ? _scrubPositionMs : _positionMs` — the progress bar and elapsed/remaining times update in real-time during the hold.
4. **Release commits:** When the key is released (timer detects key not pressed, or `_cancelSeekHold` is called), `_commitScrub()` sends **one single** `seekTo` to ExoPlayer at the final scrubbed position. One HTTP request, ~250 ms buffer, playback resumes.

### Scrub state fields (`player_screen.dart`)

| Field | Type | Purpose |
|-------|------|---------|
| `_isScrubbing` | `bool` | True while hold-to-seek is active |
| `_scrubPositionMs` | `int` | UI-only position during scrub; not sent to player until commit |

### How it all works together

1. User presses Right once → `_seekBy(+30s)` → immediate `seekTo` to ExoPlayer → 800 ms spinner grace → playback resumes in ~500 ms.
2. User holds Right for 3 seconds → timeline scrubs forward visually (30s/60s/120s ticks) → user releases → `_commitScrub()` sends one seek → playback resumes from new position in ~500 ms.
3. Forward seeks within the 30 s buffer window → instant (data already downloaded).
4. `CLOSEST_SYNC` → decoder starts at nearest keyframe → faster than exact-position decode.

### VOD minute jump strip (`PlayerTvVodJumpStrip`)

**File:** `player_tv_overlay.dart` — **`PlayerTvVodJumpStrip`** (build **`kPlayerTvOverlayBuild`**).

**Layout:** **`Row`** with **`Expanded`** + centered horizontal scroll of jump chips, then **`_VodSettingsChip`** (gear, team accent when focused) — Settings is **not** in the same centered cluster as the minute jumps.

| Tier-B index | Control | Action |
|--------------|---------|--------|
| 0 | −15s | **`_seekBy(-15_000)`** |
| 1–3 | −1, −2, −3 min | **`_seekBy(-60_000)`**, **`_seekBy(-120_000)`**, **`_seekBy(-180_000)`** |
| 4 | Center | **`_togglePlayPause()`** (same as tier-A center when activated in tier B) |
| 5–7 | +3, +2, +1 min | **`_seekBy(+180_000)`**, **`_seekBy(+120_000)`**, **`_seekBy(+60_000)`** |
| 8 | +15s | **`_seekBy(+15_000)`** |
| 9 | Settings (far right) | **`openPlayerSettingsOverlay(context)`** via **`_openPlayerSettingsFromVodJump`** in **`player_screen.dart`**; root focus restored after pop |

Seeks clamp to **`[0, duration]`** via **`_seekBy`**. Visual focus ring is shown only in **tier B** (**`stripFocused`**). Activating Settings does not call **`_flashVodTimeline()`**.

## Native Android

**Main player —** `NativeExoPlayerSession.kt`

- Creates **`TextureRegistry.SurfaceProducer`** (**`createSurfaceProducer()`**), registers **`SurfaceProducer.Callback`** (**`onSurfaceAvailable`** / **`onSurfaceCleanup`**), **`setSize`** (default then from format in **`emitProgress`**), **`ExoPlayer.setVideoSurface(producer.surface)`** — same Kotlin path on all Android TV devices. **`AndroidManifest.xml`:** **`EnableImpeller`** **`false`** under **`<application>`** (not **`activity`** — otherwise **ignored**, Impeller stays on, **rainbow video**). Flutter then composites with **OpenGL** where Vulkan mis-samples YUV.
- **`setVideoScalingMode(SCALE_TO_FIT)`** on **`ExoPlayer`** after build.
- **`DefaultLoadControl`** with aggressive buffer settings (see **Fast channel switching** above).
- **`DefaultRenderersFactory`** with **`EXTENSION_RENDERER_MODE_PREFER`** for hardware-accelerated decoders.
- **`emitProgress` (~250 ms):** sends **`videoWidth` / `videoHeight`** (display-oriented) for Flutter VOD layout; **`bitrate`** when present; updates producer size when dimensions are known (re-attaches surface after resize).
- **`releaseTextureInternal`:** stops player, **`clearVideoSurface`**, **`setCallback(null)`**, **`producer.release()`** (do not **`Surface.release()`** the producer's surface).
- Retries on **`PlaybackException`** (emits `retrying` then `error` after cap).

**Hero preview —** `NativeLivePreviewSession.kt` (channel **`com.iptvil/live_preview`**) — same general streaming stack, **separate** instance, used **only** on Live TV hero; **`setVideoScalingMode(SCALE_TO_FIT)`**; see **`ARCHITECTURE.md`** for preview pause/resume semantics.

See root **`ARCHITECTURE.md`** for **`com.iptvil/player`** event payload shapes (`state`, `isPlaying`, `progress`, etc.).

### Android TV — production stack (same APK, multi-generation Shield)

| Concern | What we ship |
|--------|----------------|
| **Surface API** | **`createSurfaceProducer()`** + **`Callback`** + **`setSize`** + fresh **`getSurface()`** after resize on **both** **`NativeExoPlayerSession`** and **`NativeLivePreviewSession`**. |
| **Flutter renderer** | **`io.flutter.embedding.android.EnableImpeller` = false** on **`<application>`** so **Skia + OpenGL** composite video; avoids **Vulkan YUV** mis-sampling (**rainbow** video) on some TV GPUs. **Do not** put this flag only under **`activity`** ([flutter/flutter#154252](https://github.com/flutter/flutter/issues/154252)). |
| **Verification** | **Fullscreen + hero preview:** correct **motion and colors** reported on **updated** and **older** **NVIDIA Shield** with the same build; keep **ONN / Chromecast with Google TV** in the routine matrix (**`TESTING_GUIDE.md`**). |
| **Release builds** | Launcher **`app_icon`** is **`drawable-nodpi/app_icon.jpg`** (valid JPEG). A **JPEG named `.png`** breaks **AAPT2** — see **`07-android-build-and-branding.md`**. |

## Integration points (who passes URLs)

- **Live TV** — channel `streamUrl` or mock helper; **hero** uses the same URL via **`LivePreviewChannel`**; **EPG** from `LiveEpgController` when Xtream lineup items expose ids (see `player_screen.dart` + `live_lineup_item.dart`).
- **Movies** — detail play → movie `streamUrl` or mock.
- **Series** — episode play → `MockEpisode.streamUrl` from Xtream mapper or mock.

Always prefer **real `streamUrl`** from catalog when present.
