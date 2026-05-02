# Feature history and engineering decisions

This section records **what was built and why**, so future developers understand intent without digging through chat logs. Dates are approximate unless tied to version control.

### VOD offline download — Windows Downloads + Android app-private library (2026)

- **Goal:** Save single-file VOD streams to disk; **HLS playlists** rejected by sniffing `#EXTM3U` on the downloaded bytes.
- **Windows:** Copy completed file to **user Downloads** (`VodDownloadController`); global **`VodDownloadStripLayer`**; no native save dialog (stability). Snackbar shows full path.
- **Android:** Same HTTP → temp → validate → copy pipeline; destination **`getApplicationSupportDirectory()/TVMatePro/vod_offline/`**; metadata in **`index.json`** via **`VodOfflineLibrary`** (title, path, size, date, optional poster URL from **`openTvMatePlayer(vodPosterUrl:)`**). **Account → Offline downloads** lists items with play (**`file://`**) and delete. Jump strip **Download** (index 14); Android shows VOD chrome even when duration is still unknown so the control remains reachable.
- **Filenames:** **`vodDownloadSuggestedFileName`** — prefer HTTP **`Content-Type`**, ignore bogus URL extensions (e.g. `.php`), default **`.mp4`** when needed.
- Full write-up: **`documentation/19-android-offline-vod-downloads.md`**.

### Parental control — Live TV scope, browse-hide, PIN UX (2026)

- **Settings hub:** **Parental control** uses a compact grid (**main** + **utilities** rows). There is **no** global **“hide from Live TV browse”** toggle; **hide** is chosen **per** channel, category, or favorite group in the **scope dialog** (alongside lock-only options).
- **Live TV scope dialog** exposes **four** actions where applicable: **lock channel**, **lock channel & hide from browse**, **lock category or favorite group**, **lock category/group & hide from browse**; **unlock** rows appear only when the current target has matching lock and/or hide rules.
- **Data:** `browseHideLiveChannels`, `browseHideLiveCategories`, `browseHideFavoriteGroups` in **`ParentalControlStore`**; backup JSON **`parentalControl`** includes these maps. Browse filtering uses **`shouldFilterLiveBrowseForParental`** — hide applies only to **explicitly** listed ids (avoiding over-broad category matching that emptied unrelated grids).
- **Live TV grid:** When the **selected pill** has **no visible channels** after rules change, selection moves to the **first pill with channels** (search off) so the UI does not stick on an empty grid.
- **PIN:** **Compact** dialogs with **inline numpad** (`ParentalPinNumpadGrid`, **`parental_pin_dialog.dart`**). The live **player** uses a **quick create-PIN** flow when no PIN exists; no full-screen parental setup overlay on that path.
- **Restricted rules** screen resolves **display names** for channels, categories, movies, and series via **`parental_rule_labels.dart`** + catalog listenables.
- **Player:** **Back** with fullscreen **Live EPG** open pops the **root** route first so EPG dismisses reliably. Details: **`documentation/17-parental-control.md`**.

### Manage live channels (per playlist) (2026)

- **Settings → My playlists → Manage channels:** Per **Xtream stream id**, users can **rename** display name, **hide** from Live TV, or set **custom logo URL**. State in **`PlaylistChannelOverrideStore`** (`iptvil_channel_overrides_v1`); Live TV applies via **`apply`** + filters **`isHidden`** in **`live_tv_screen.dart`**. Category channel list order matches **catalog / playlist order** (`liveChannelsForCategory` → `liveChannelsAll` sequence), not A–Z. **Now included in full backup** as **`channelOverrides`** — see **`09-backup-system.md`**, **`18-manage-live-channels.md`**.

### Performance tier + TV text input (2026)

- **Settings → Performance:** **Full quality**, **Optimized**, **Automatic** (RAM ≤ **2560 MiB** → optimized; unknown RAM → full). UI shows detected RAM and, when **Automatic** is selected, the **effective** tier. Behavior: lighter backdrop / image cache / deferred catalog sync / splash when optimized — see **`16-performance-tier-and-tv-input.md`**.
- **TV IME / D-pad:** `ShieldTvTextField` and shell **search** skip D-pad interception when the IME is likely open — **`MediaQuery.viewInsets`** plus **native** `WindowInsetsCompat.Type.ime()` via **`MainActivity`** + **`DeviceInfoChannel`** (Shield often reports **no** Flutter `viewInsets` while the keyboard is visible).

### Hero background appearance editor (2026)

- **Route:** **Settings → Appearance → Hero background** — **`HeroAppearanceEditScreen`** over **`LiveTvScreen(previewMode: true)`**. **D-pad safe** color editing via **`HeroColorTvSteppers`** (− / + only); **`LiveTvHeroAppearanceStore`** persists gradient, wash (brush/solid), intensity, brush style, **TV bezel** on/style/finish, gradient depth. Panel chrome aligned with **VOD subtitle** / **Movie grid** inset panels (**`#1A1A2E`** blocks + brushed shell). **Position:** bottom-right with **~2%** margin from safe edges; optional **scale** for footprint. **On open:** TV frame forced **on** (user can turn off). Details: **`15-hero-background-appearance-editor.md`**.

### Live TV · Appearance — Channel Grid Settings (2026)

- **Channel display 2×2:** D-pad moves **`_channelDisplayFocusIndex`** only; **OK** commits **`liveTvCardStyleStore`**. UI: **neon ring** = focus, **gold pill + check** = applied style (see **`14-live-tv-appearance-channel-grid.md`**).
- **Panel chrome (2026):** **Channel Grid Settings** shell aligned with **Movie / Series Grid Settings** — **`VodBrushedPanelFill`**, accent-blended outer border, **`#1A1A2E`-style** inset sections (`channelGridInsetDecoration`), gold segment chips, inset footer row. **No behavior change** to rail indices or focus/commit rules.
- **Hide:** Collapsed layout uses **`Positioned(top, right)`** without **`bottom`** so the rail focus region does not fill the right third of the screen; **Show** chip stays **`SizedBox(width: targetW)`** bounded.
- **Cold start:** Default shell tab **Live TV**; **VOD** / **live fullscreen** exceptions persist via **`AppSessionRestoreStore`** + **`PlayerSessionRestoreMarker`** (details in doc 14 + store comments).

## Product direction

- **TV-first IPTV client** with a **premium dark** visual language (**team-selectable** Cosmic / Aurora / Solar neon + **Heritage** elegance, image-forward rails).
- **Dual catalog mode:** polished **demo data** for empty / demo setting, and **Xtream Codes** when a playlist is active and demo is off.
- **Native playback** chosen over `video_player` for **HLS / live** reliability and control on Android TV.

## Major feature areas (historical)

### Shell and navigation

- **Main shell (current):** **top navigation bar** (`AppTopBar`) + full-width content over **`CosmicSpaceBackdrop`**; default tab **Live TV**.
- **Earlier iteration:** right-hand sidebar rail — replaced by top bar for clearer TV hierarchy and more vertical space for grids.
- **Back key (updated):** first Back from root browse **opens** top-nav focus mode (unless **`ShellBackCoordinator`** consumes Back). While **menu-from-Back** is active, **two** Back presses **exit** (**`LivePreviewChannel.dispose()`** + **`SystemNavigator.pop()`**); **`MainActivity.onPause`** also stops native preview.
- **Focus:** **`FocusNode` per `ShellDestination`** in **`MainShellScreen`** for predictable TV behavior when Back focuses the bar.
- **Shell navigation hub** for programmatic tab switches when needed.

### Home, movies, series, live TV

- **Home browse** with **paged rails** (e.g. seven tiles per page) and chip-to-rail focus improvements.
- **Movies / series** screens aligned with **category chips** and **horizontal rails**.
- **Live TV** layout tuned for TV: **tall hero** (two-tone gray, **live preview** in bezel + larger **center EPG** + outer **logo**), **named favorite-group** pills **then** playlist categories, denser grid with cover-style channel tiles.
- **Detail screens:** **compact action row** — Play, external player, trailer (where applicable), **My List** toggle.

### My List

- **Separate lists** for **movies** and **series** (`MyListStore`), persisted, surfaced from detail actions.

### VOD labels, episode marks, My List pills, IMDb on posters (2026)

- **Stores:** `MovieVodLabelStore`, `SeriesVodLabelStore`, `EpisodeVodLabelStore` share the same `MovieVodLabel` enum; player exit applies auto labels for movies and series episodes; backup JSON includes `vodMovieLabels`, `vodSeriesLabels`, `vodEpisodeLabels`.
- **My List rail:** **Watched** / **Continue watching** pills list **all catalog** titles with that label; **All** still lists only My List favorites (see **`13-vod-labels-imdb-posters.md`**).
- **Posters:** VOD state badges bottom-left; **IMDb** rating top-right via `VodImdbRatingBadge` (gold star + white score + soft blurred black scrim; not team-colored chip).

### Xtream integration

- **API client** for standard `player_api.php` style endpoints, including **`get_short_epg`** and **`get_simple_data_table`** for live EPG.
- **Mapper** outputs the same **`Mock*`** models as demos so **one UI code path**; live streams include **`epgChannelId`** when the panel provides **`epg_channel_id`**.
- **Series list** without full episode trees until **series detail** fetches **`get_series_info`**.
- **Stream URLs** built per panel conventions (`/live`, `/movie`, `/series` paths) via **`XtreamStreamLinkBuilder`**.

### Xtream catalog cache — file-backed JSON on Android (March 2026)

- **Symptom:** After killing the app or clearing it from recents, **Live TV** looked empty or “demo” while **My Playlists** still listed the Xtream playlist.
- **Root cause (logcat):** **`DatabaseException(Row too big to fit into CursorWindow)`** on **`SELECT … full_catalog_json …`** — Android’s SQLite cursor path limits **~2 MB per row**; full-catalog JSON for large panels was **~15 MB**.
- **Fix:** **`XtreamCatalogCacheDb`** stores **metadata in SQLite** and writes **`iptvil_cat_full_*.json`** / **`iptvil_cat_live_*.json`** under **`getDatabasesPath()`**; reads use **`File.readAsString`**, not giant TEXT columns. **DB version 5** migration **`UPDATE`s** legacy blob columns to **NULL** (cannot be migrated row-by-row through the Dart API without hitting the same limit).
- **Trade-off:** One **refetch** after upgrade is acceptable if the only copy lived in SQLite blobs; thereafter persistence survives process death.

### Live TV EPG and hero (2025–2026)

- **`LiveEpgController`** fetches and caches programme data for the **focused** channel; **`xtream_short_epg_parser`** tolerates multiple panel JSON shapes, Unix/string timestamps, **`now_playing`**, and localized title objects.
- **ID strategy:** try **`epg_channel_id`** before **`stream_id`** when both exist; **short EPG** then **simple data table** if listings are empty.
- **Live TV hero** redesigned in stages: three columns (**preview / EPG / logo**), RTL-aware order, **`LayoutBuilder`** + reserved meta width so the hero does not **vertically overflow**; synthetic timing fallback when EPG has no end time; **larger** EPG typography; **compact** time/progress row **under** the preview frame only.
- **Live hero preview (video + audio):** second native **`ExoPlayer`** via **`NativeLivePreviewSession`** and **`com.iptvil/live_preview`**; Flutter **`HeroLivePreview`** + **`LivePreviewChannel`**. Preview plays **with sound** on Android; **no** full-bleed channel “watermark” behind EPG (gray gradient hero instead).
- **Fullscreen handoff:** **`openIptvilPlayer`** calls **`pauseForFullscreen`** before push and **`resumeAfterFullscreen`** after pop so preview and main player never **double** the same audio.
- **Player** passes **`epgChannelId`** through **`LiveLineupItem`** so EPG updates match the channel when switching with UP/DOWN.

### Live channel favorites (evolved)

- **Current:** **`LiveFavoriteGroupsStore`** — multiple **named** groups (sort order, ordered channel ids); **`LiveTvFavoritesScreen`** (**Favorite setup**) + editor + picker; **Live TV** pills include groups **even if** all playlist categories are hidden. Legacy migration may map old single-list prefs into one **“My favorites”** group.
- **Earlier:** single **`MyListStore`** live id list and one synthetic **My favorites** pill — superseded by groups where implemented.

### Android install / manifest

- **`android.software.leanback`** set to **`required="false"`** to fix generic **“App not installed”** on many non-TV devices while retaining **`LEANBACK_LAUNCHER`**.
- **`pubspec` version** bumped (e.g. **`1.0.1+2`**) to raise **`versionCode`** for upgrades.

### Playback

- **ExoPlayer** on Kotlin side with **texture** output to Flutter (**main** player + **optional** hero **preview** player on Live TV).

### Android TV video pipeline — `SurfaceProducer`, Impeller flag, release assets (2026)

- **Black video (audio only)** on some **updated** Android TV devices (e.g. **NVIDIA Shield** with **Impeller + Vulkan**) when using Flutter’s legacy **`createSurfaceTexture()`** path: native code migrated to **`FlutterEngine.renderer.createSurfaceProducer()`**, **`SurfaceProducer.Callback`** (**`onSurfaceAvailable` / `onSurfaceCleanup`**), **`setSize`** (default then from video dimensions), and **re-bind `ExoPlayer.setVideoSurface(producer.getSurface())`** after resize — same **Kotlin** path for **all** devices (**Shield, ONN, Chromecast**, etc.).
- **Rainbow / neon / solarized video** while **UI colors stayed normal:** **Impeller (Vulkan)** can mis-sample **hardware-decoded YUV** into the Flutter layer. **`AndroidManifest.xml`** sets **`io.flutter.embedding.android.EnableImpeller`** to **`false`** so Flutter composites with **Skia + OpenGL**. **Critical:** that **`meta-data` must be a child of `<application>`**, **not** `<activity>` — if placed only on the activity, Flutter **ignores** it ([flutter/flutter#154252](https://github.com/flutter/flutter/issues/154252)) and Impeller stays on, so colors stay wrong.
- **Release build (`mergeReleaseResources`):** **`drawable-nodpi/app_icon.png`** that was actually a **JPEG** (wrong magic bytes) caused **AAPT2** “file failed to compile.” Renamed to **`app_icon.jpg`**; **`@drawable/app_icon`** unchanged.
- **Validation (same APK):** reported **correct** fullscreen + hero preview **picture and colors** on **updated** and **older** **NVIDIA Shield** after the above; re-test **budget Google TV** sticks periodically.

### VOD aspect ratio — native surface + Flutter `Texture` (2026)

- **Problem:** Full-screen **`Texture`** on Android TV (e.g. Shield) showed **stretched** video; **`PlayerView.setResizeMode(FIT)`** does not apply — pipeline is **`ExoPlayer` → `Surface` → Flutter `Texture`** (embedding uses **`SurfaceProducer`**, not legacy **`SurfaceTexture`**), not **`PlayerView`**.
- **Native:** **`VIDEO_SCALING_MODE_SCALE_TO_FIT`** on **`ExoPlayer`**; **`emitProgress`** exposes **`videoWidth` / `videoHeight`** as **display** size: **`pixelWidthHeightRatio`**, then **rotation** swap for **90° / 270°**.
- **Flutter:** **`PlayerScreen`** for **`!isLive`** — **`LayoutBuilder`**, **`_vodContainVideoSize`** (contain), **`Center`** + **`SizedBox`** wrapping **`Texture`**; black **Scaffold** shows **letterbox / pillarbox**. **Live** fullscreen unchanged (full-bleed **`Texture`**). Hero preview session also uses **`SCALE_TO_FIT`**.
- **Retry** UX for transient failures; fatal error overlay with Back.
- **VOD resume** keyed by content id in **SharedPreferences**.
- **Live lineup** optional for in-player channel changes.

### Stability passes (player / navigation)

- **Teardown ordering:** cancel native event subscription, **null `textureId` in UI** before native `releaseTexture`.
- **Guards:** `_released`, `_exitInProgress`, `!_released` in event handlers and timers.
- **Bootstrap** concurrency: do not apply texture / error UI after user has already exited.
- **Focus restore** after player pop: **`canRequestFocus`** + **try/catch**.

### Visual / brand

- **Splash:** single black screen, **large logo**, spinner + loading text; removed separate heavy “glow box” stage so first paint and splash match.
- **Shell chrome:** top bar + cosmic backdrop; older **sidebar + logo header** layout superseded.
- **Android TV banner / icon:** real bitmaps under **`drawable-nodpi`** (**`app_icon.jpg`** for adaptive foreground center, **`branding_logo`**, **`tv_banner_logo`**, etc.), **`ic_launcher_fg`**, **`tv_banner`**, **`launch_background`** — replaced placeholder vector banners where applicable. **`app_icon`** must match its **real** format (JPEG vs PNG); wrong extension breaks **AAPT2** on release.

### Visual teams — Cosmic, Aurora, Solar & Heritage (March 2026)

- **`AppVisualTeam`** (**Cosmic** / **Aurora** / **Solar** / **Heritage**) persisted in **`TeamVisualStore`** (`iptvil_visual_team_v1`; keys **`cyan`**, **`violet`**, **`solar`**, **`heritage`**).
- **Solar:** **`TeamPalette.solar`** — electric **yellow / gold / amber / coral** neon; same **structure** as cyan/violet (deep warm void, rim gradient, nebula blobs, light leaks).
- **Heritage:** **`TeamPalette.heritage`** — **classic elegance**: champagne **gold** accent, **wine** burgundy, **midnight** blue surfaces, pearl/cream rim tones; **lower** light-leak opacities for a calmer, jewel-tone backdrop (layout unchanged).
- **`TeamPalette`** holds surfaces, accents, nebula gradient stops, rail card shadows; **`TeamPaletteTheme`** + **`context.teamPalette`** for widgets.
- **`IptvilApp`:** **`MaterialApp`** stays mounted; **`builder`** uses **`ListenableBuilder(teamVisualStore)`** and wraps children in **`Theme(AppTheme.themeForPalette(palette))`** so switching teams does **not** reset navigation.
- **Shell tab `Theme` (label):** **`TeamScreen`** — two large selectable cards; **`ShellContentFocusRegistry`** restores focus when returning to the tab.
- **Migration:** focus widgets (e.g. **`TvFocusable`**, **`LiveChannelBrowseTile`**) use palette-backed colors; static **`AppTheme.accent`** avoided for new chrome where possible.

### Series episode tiles

- **Posters:** all episodes in a show use **`seriesPosterUrl(series)`** so tiles are **consistent** (not per-episode stills).
- **Labels:** removed redundant **show + episode title** under each tile; **bottom bar** only **`SxxExx`** via **`MockEpisode.codename`** in **`EpisodeSeasonCaptionBar`** (gradient, accent hairline, tabular figures).

### Tooling / repo hygiene

- **`documentation/`** folder (this set) added for **developer handoff** without changing runtime behavior.

## Known limitations (explicit)

- **M3U** full catalog parse/browse not treated as first-class alongside Xtream in the documented path.
- **EPG via player API only** in this build — providers that expose EPG **only** as **XMLTV** (`xmltv.php`) without short/simple table data may need a separate XMLTV client and merge layer.
- **Non-Android** platforms: no real video (by design).
- **Dependency upgrades:** `flutter pub outdated` may report packages blocked by conservative constraints — bump intentionally after testing on TV hardware.

### EPG time per playlist (April 2026)

- **Settings → My playlists → EPG** opens **`PlaylistEpgTimeScreen`** — centered layout (~**640** px max width), same TV pattern as **Manage groups** category list: **Local** (device TZ) as the first row; scrollable **Original (server)** plus curated **IANA** zones from **`kEpgTimezoneCatalog`** (`lib/data/epg_timezone_catalog.dart`). Activating a row saves **`PlaylistEpgTimezoneStore.setEpgDisplayMode`** and pops.
- **Persistence:** **`iptvil_epg_display_mode_<playlistId>`** (`local` | `original` | IANA id). Legacy bool **`iptvil_epg_tz_local_*`** → migrate to `local` / `original`. **Catch-up** still uses **`iptvil_epg_server_utc_offset_*`** for Xtream `timeshift.php` **`start=`** — unchanged.
- **Formatting:** **`lib/data/epg_time_display.dart`**, **`timezone`** package (**`main.dart`**: **`initializeTimeZones()`**). Consumers: **Recording** EPG list, **`LiveEpgController`** programme line, **`LiveTvPlayerBottomBar`**, **`player_live_epg_overlay`**. See **`10-recording-epg-system.md`**, **`04-data-playlists-and-xtream.md`**.

### Backup — EPG time, channel overrides, TV keyboard (April 2026)

- Three new JSON fields in **`IptvilBackupService`** (`lib/data/backup/iptvil_backup_service.dart`):
  - **`epgTimezone`** — per-playlist EPG display mode + server UTC offset (`PlaylistEpgTimezoneStore.exportForBackup` / `replaceFromBackup`). Keyed by **playlist id**; each value has optional `mode` and `serverUtcOffset`.
  - **`channelOverrides`** — per-playlist per-channel rename, hide, custom logo (`PlaylistChannelOverrideStore.exportForBackup` / `replaceFromBackup`). Same nested JSON shape as the prefs key `iptvil_channel_overrides_v1`.
  - **`tvKeyboardLanguages`** — ordered list of enabled on-screen keyboard language codes (`TvKeyboardLanguageStore.exportForBackup` / `replaceFromBackup`).
- **Backward compatible:** Old backup files without these keys import cleanly (keys are optional; stores keep current state when absent). New exports always include all three.
- **Restore order:** Library is applied first, then playlist-scoped stores (EPG, overrides, group visibility, etc.) so playlist ids match.
- Docs: **`09-backup-system.md`** (table + JSON example), **`CHANGELOG.md`**.

### Live TV · Appearance — tile modes + channel name position (April 2026)

- **Four channel card styles** (`LiveTvCardStyle` / `live_tv_card_style_store.dart`): **name only**; **logo + name + programme** (EPG line when available); **logo + name**; **logo only**. Persisted prefs (`logo_text`, `text_only`, `logo_name_only`, `logo_only`).
- **Channel name vertical bias** (`LiveTvNameVerticalBiasStore`, `live_tv_name_vertical_bias_store.dart`, prefs `iptvil_live_tv_name_vertical_step_v1`): global step **−5…+5** applied on the grid — **name-only** tiles use a lower/higher **alignment**; **logo + text** modes translate the **bottom text block** (programme + name together). **Live TV · Appearance** → **Tiles** box: **▼** / **▲** switch between the **tile style** row and the **Name** row; **◀▶** adjusts the active row. Included in **backup** as `liveTvNameVerticalStep` (`IptvilBackupService`).

### Settings UX, clock overlay, playlist screens (March 2026)

- **Global clock:** `ClockOverlaySettingsStore` + `ClockOverlayLayer` — always-on-top, **D-pad safe** (`IgnorePointer`), local time, user preferences in **Settings → Clock** (info **banner** + compact option grid ~**80%** scale; layout aligned with other settings sub-screens). Default **unframed** text (no `Text` shadows; explicit `TextDecoration.none`). Optional **Frame ON** adds a **gentle border** and **dark translucent backing** behind the time only (not full-screen).
- **Main Settings** — `SettingsScreen` uses a **compact icon tile grid** (`maxCrossAxisExtent` ~220) for entries including **Add Playlist**, **My Playlists**, channel/movie/series **card styles**, **Clock**, **Demo mode**.
- **Card style sub-screens** — Channel / movie / series style pickers use the same compact grid + circular back control.
- **Add Playlist** — Content **centered** with **`maxWidth: 520`**; **Xtream** vs **M3U** as two **fixed-size icon tiles** (118×118); **D-pad** left/right between tiles (`tv_remote_keys`: `tvRemoteIsDpadLeft` / `tvRemoteIsDpadRight`). Forms use **`ShieldTvTextField(dense: true)`** with tighter vertical spacing; form + **Add** in one scrollable column for small viewports. *(Same month: TV auto-focus, **`keyboardType`**, scroll/IME behavior, removal of **Change type** — see **TV text input, trailers, Add Playlist focus, theme handoff**.)*
- **My Playlists** — **`GridView`** with **3 / 2 / 1** columns by layout width (~1100 / ~700 / narrow); compact tiles (**Groups**, **EPG** opens per-playlist time picker, **Use/Ren/Del** chips). **EPG time** screen: see **EPG time per playlist (April 2026)** above.
- **Manage groups** (`playlist_group_manager_screen.dart`) — main **TV / Movies / Shows** chooser uses the same **icon grid** pattern as settings. **Category list** (`PlaylistGroupSectionScreen`): **narrow centered column** (~640 logical px max width), **dense** rows, **Show all / Hide all** shortcuts; **`TvFocusable`** on rows uses **`focusScale: 1`**, **`parallaxSlide: 0`**, **`showFocusElevation: false`**, **`focusedBorderWidth: ~1.4`**, plus **horizontal inset** on the list so focus rings stay **inside** the layout (fixes edge clipping on TV). **Live TV rows only:** **pill-order** control + panel — pin a playlist category **before** or **after** **favorite group** pills, with **position** among “before” pills; persisted as **`liveBeforeFavorites`** in **`PlaylistGroupVisibilityStore`**, included in **`groupVisibility`** backup. See **`04-data-playlists-and-xtream.md`**, **`09-backup-system.md`**.
- **Neon clock colors + segment font** — Three additional palette entries (**neon red, green, yellow**). When selected, **`ClockOverlayLayer`** applies **`fontFamily: DSEG7Classic`** (bundled **DSEG7 Classic** `.ttf`, SIL OFL) and **neon-style** text shadows; HUD **shape** unchanged. **`pubspec.yaml`** registers the font under **`fonts:`**.
- **TvFocusable** — Optional **`focusedBorderWidth`** (default **2.2**) for thinner focus rings on dense UIs.
- **Bugfix:** `ClockSettingsScreen` route requires **`import 'clock_settings_screen.dart'`**; avoid **`const ClockSettingsScreen()`** in the route if the analyzer reports a non-const context error.

### TV polish pass — exit, clock, focus (March 2026)

- **My space (removed later):** was **`MySpaceStore`** + shell **`MySpaceScreen`** / **`MySpaceManageScreen`** — superseded by removal from the shell; **`LiveFavoriteGroupsStore`** covers user-curated Live TV lists in **Favorite setup**.
- **Exit + preview:** **`MainShellScreen`** **`await`s `LivePreviewChannel.dispose()`** before **`SystemNavigator.pop()`** on double-Back exit; **`NativeLivePreviewSession.stopForActivityPause()`** from **`MainActivity.onPause`**; **`HeroLivePreview`** lifecycle **re-bootstrap** after **`paused` → `resumed`**.
- **Clock:** Framed date **`DD/MM MON`** with **uppercase weekday** — **`Text.rich`**: **DSEG** for date prefix, **Roboto** for **`MON`–`SUN`**; darker framed gradient.
- **Focus clipping:** Shell content **`ClipRect`** removed; Movies/Series **column `ClipRect`** removed; **`GridView` / `ListView`** **`clipBehavior: Clip.none`** where used; **no `Row.clipBehavior`** on SDKs that lack the parameter (build fix).
- **Sidebar era (superseded):** **`ColoredBox`** + **2px** **`Transform.translate`** overlap — mitigated seam on the old right rail; **known remaining issue:** occasional **white vertical flash** on some hardware (e.g. Shield) may still appear with **top bar** transitions.

### Fullscreen player — live EPG, VOD chrome, Back during fade (March 2026)

- **EPG:** **`LiveEpgController`** exposes **`lookupDisplay` / `lookupListings` / `isLoadingFor`** so **hero**, **channel tiles**, and **`PlayerScreen`** show the right programme data even when **`focusedStreamId`** moves between contexts.
- **Live Back:** **`_liveOverlayFadingOut`** keeps **Back** / **`PopScope`** in “dismiss chrome” mode until **`AnimatedOpacity`** finishes hiding the overlay (avoids **`Navigator.pop`** on the first press while the UI is still fading).
- **VOD:** Separate **Down** (fat timeline strip), **Up** (info banner + optional **`contentDescription`** from **`openIptvilPlayer`**), **Center** (pause/play), **L/R** seek with strip flash; keys duplicated on **`Focus.onKeyEvent`** for TV reliability. **Timeline strip** (**`PlayerTvVodTimelineStrip`**): **elapsed** left, **time remaining** (countdown) right — same bar layout/styles as before (**`player_tv_overlay.dart`**).

### Universal missing art + faster VOD seek + Theme grid (March 2026)

- **Universal placeholder:** **`TvUniversalMediaPlaceholder`** (**`tv_catalog_image.dart`**) — one **team-palette** gradient + **`Icons.live_tv_rounded`** when **`tv_media_urls`** yields **no loadable URL** or **`Image.network`** fails. Replaces per-item **`TvTmdbPlaceholders`** fallbacks in **`liveChannelArtUrl`**, **`moviePosterUrl`**, **`seriesPosterUrl`**, backdrops, **`episodeStillUrl`**. **`TvCatalogImage`** dropped **`placeholderIcon`**; Movies/Series browse **`_MoviesHiResImage` / `_SeriesHiResImage`** match.
- **VOD seek:** **`player_screen.dart`** — tap **±30 s**, hold tick **75 ms**, ramp **30 s / 60 s / 120 s** (**`_vodSeekTapMs`**, **`_vodSeekHoldTier*Ms`**, **`_vodSeekHoldTickMs`**).
- **Theme tab:** **`TeamScreen`** — **two columns** of **compact** theme tiles (half-width cards, smaller swatch).

### TV text input, trailers, Add Playlist focus, theme handoff (March 2026)

- **Problem:** **`ShieldTvTextField`** used **`TextInputType.none`** (intended for Shield D-pad field switching) which **suppresses** the Android TV **soft keyboard**, so users could not type without a mouse-style companion app.
- **Fix:** Default **`keyboardType`** to **`TextInputType.text`** (and **`url`** / **`number`** where appropriate). Documented that **`none`** must not be used for fields that need IME.
- **Add Playlist:** Auto-focus **Xtream** on the source picker; after **Xtream** or **M3U** is chosen, **`scheduleSteadyChannelTileFocus`** on **Server URL** or **M3U Name**. Removed **“Source type”** caption and **“Change type”** row; vertical chain is **Back → fields → Add**; switching source type = **Back** out and open **Add Playlist** again. **`SingleChildScrollView`** + **`ScrollController`**, **`Scaffold.resizeToAvoidBottomInset`**, bottom **`Padding`** from **`viewInsets`**, **`Scrollable.ensureVisible`** on focus, **`WidgetsBindingObserver.didChangeMetrics`** to re-scroll when the keyboard resizes — keeps **Password** / **Name** visible.
- **Favorite setup editor:** Same **`keyboardType`** pattern on name (**text**) and order (**number**).
- **Trailers:** Search stays in-app (**`youtube_trailer_search`** / **`InAppYoutubeTrailerScreen`**); playback uses **`url_launcher`** **`externalApplication`** to **`youtube.com/watch?v=`** so the **YouTube app** handles video (WebView embed and **`webview_flutter`** removed — TV embed errors 153 / 150-class). **`piped_trailer_stream.dart`** (Piped + Invidious URL resolution) remains in the repo for possible reuse but is **not** wired as the default trailer player.
- **Theme tab:** **`TeamScreen`** — after **`teamVisualStore.setTeam`**, **`ShellNavigationHub.instance.goTo(ShellDestination.liveTv)`** so choosing a theme returns to the **Live TV** shell tab immediately.

### AndroidX Core pin for Flutter IME (March 2026)

- **Symptom:** App **force-closes** when opening **Settings → Add Playlist** (or any screen) and focusing a **`TextField`**, as the TV **soft keyboard** attaches. Logcat: **`FATAL EXCEPTION`**, **`NoSuchMethodError`**, missing **`EditorInfoCompat.setStylusHandwritingEnabled`**, stack through **`io.flutter.plugin.editing.TextInputPlugin.createInputConnection`**.
- **Cause:** Root **`android/build.gradle`** **`resolutionStrategy`** had forced **`androidx.core:core`** / **`core-ktx` to 1.12.0**, which **does not** implement the static method Flutter’s embedding calls (API added in **Core 1.13+**). The wrong class version was packaged in **`base.apk`**.
- **Fix:** Raise the forced versions to **`1.15.0`** (both **`core`** and **`core-ktx`**). **NVIDIA Shield** and **ONN / Chromecast**-class devices then share the same correct dependency; no Dart/UI change required for this specific crash.

### TV navigation polish — player pop, focus, channel tiles (March 2026)

- **VOD duplicate Back:** On some Android TV devices, **one** remote **Back** closed **`PlayerScreen`** and then **also** popped **movie/series details**, leaving the user on the **browse** grid. **Mitigation:** **`openIptvilPlayer`** invokes **`onPlayerClosed` synchronously** when **`isLive: false`**, **before** **`resumeAfterFullscreen`**, so details can record a **~480 ms** window; **`PopScope(canPop: false)`** on **`MovieDetailsScreen` / `SeriesDetailsScreen`** swallows **system Back** inside that window. The **UI back** control still calls **`Navigator.pop`** directly.
- **Browse sync without focus steal:** **`_syncMovieBrowseToId`** / **`_syncSeriesBrowseToId`** update **index + hero** when the player closes but **no longer** **`requestFocus`** on poster rails while the details route is still visible.
- **Live TV after player:** **`scheduleSteadyChannelTileFocus`**, **`suppressPreviousFocusRestore: true`**, temporary **`canRequestFocus: false`** on category pills during restore.
- **`LiveChannelBrowseTile`:** **`focusScale: 1.0`**, **`parallaxSlide: 0`**, **`ClipRRect`**, logo+text **`BoxFit.contain`**; tile fill/shadows use **`context.teamPalette`**.

### Backup system (March 2026)

- **Full settings backup** — export/import of playlists, favorites, card styles, clock, team, hero layout, group visibility, My List, My Space. Two modes: **personal** (with passwords) and **share** (passwords stripped).
- **Public external storage** — files saved to `Download/IPTVIL/` via native `Environment.getExternalStoragePublicDirectory()` through platform channel `BackupStorageChannel.kt`. Survives app uninstall.
- **Storage permissions** — `WRITE_EXTERNAL_STORAGE` (Android ≤10) + `MANAGE_EXTERNAL_STORAGE` (Android 11+), requested at export time.
- **Recursive file discovery** — import and delete screens scan the entire `Download/` tree recursively for `iptvil-backup-*.json` files, finding them regardless of subfolder.
- **Material 3 SnackBar fix** — `SnackBarAction` causes indefinite display in M3 regardless of `duration`; replaced with plain timed SnackBars.
- **UI:** Settings → Backup → 3-column grid (Export personal, Export to share, Share latest, Import, Delete). Import screen lists files with friendly dates, size, parent folder. Delete screen with multi-select + Select all.
- Full documentation: **[`09-backup-system.md`](09-backup-system.md)**.

### Settings sub-screen autofocus (March 2026)

- **Problem:** On Android TV, opening Channel cards / Movie cards / Series cards / Clock settings started D-pad focus on the **back arrow** (top-left). The user had to scroll down to reach the first option tile.
- **Fix:** Added **`autofocus: true`** to the **first option tile** in each screen — `index == 0` in `GridView.builder` for card style screens; the **Clock ON/OFF** toggle tile in `ClockSettingsScreen`. Focus now lands directly on the first actionable option.
- **Pattern rule:** Every settings sub-screen with an options grid should **`autofocus`** the first option, not the back button. The back button is reachable via D-pad Up from the grid.

### Playlist quick-switcher in top bar (March 2026)

- **Goal:** Let users switch between playlists without navigating into Settings → My Playlists.
- **Approach:** Added a "Playlist" button to `AppTopBar` as a special `TvFocusable` item (not a `ShellDestination`, since it has no content screen — just a popup).
- **Activation:** Clicking the button opens a `PopupRoute` overlay anchored below it, showing all playlists from `libraryController.playlists`. The active playlist is marked with a filled check circle; others show an empty radio icon.
- **Switching:** Selecting a different playlist calls `libraryController.setActivePlaylist(id)` then `xtreamCatalogRepository.syncFromLibrary(libraryController)`, dismisses the dropdown, and navigates to Live TV via `ShellNavigationHub`.
- **Empty state:** When no playlists exist (demo mode), the dropdown shows "No playlists yet" with a "Go to Settings" button.
- **TV focus:** First item in the list gets `autofocus: true`. D-pad Up/Down navigates the list; Back dismisses the dropdown.
- **Styling:** Dropdown uses `teamPalette.surface` background, accent-tinted border, and the same compact typography as the rest of the shell.

### Recording — shell backdrop, TV-safe layout, softer focus, optional EPG TV frame (March 2026)

- **Backdrop:** `RecordingScreen` previously used an opaque **`palette.surface`** fill, hiding **`CosmicSpaceBackdrop`**. Switched to **`Colors.transparent`** so Recording matches other shell tabs visually.
- **Layout:** Horizontal inset via **`LayoutBuilder`** (~**3.5%** of width per side, minimum **16px**); date column width from **row** constraints (**20%** of the main row) instead of full-screen **`MediaQuery`** width.
- **Focus:** Introduced shared **`_kRecordingFocusScale`** (**1.011**) and **`_kRecordingParallaxSlide`** (**0.002**) (and dense-list border width) on all Recording **`TvFocusable`** widgets so focus growth stays on-screen better than the default **`AppTheme.focusScale`** / parallax.
- **EPG UI:** Per-playlist **`tvFrameEpg`** in **`RecordingApprovalStore`** (JSON **`tvFrameEpg`**, default **false**); **Settings → Recording → Categories** toggles **TV frame on EPG**. When on, programme rows use **`assets/images/recording_tv_frame.png`** behind **`BoxFit.contain`** channel logos; taller rows / logo slot apply with frame on or off. Documented in **[`10-recording-epg-system.md`](10-recording-epg-system.md)**.

### Fast channel switching (March 2026)

- **Goal:** Make live channel switching feel near-instant (~200–400 ms) with no visible loading spinner, similar to premium IPTV apps.
- **Aggressive `DefaultLoadControl`:** `bufferForPlaybackMs` **250 ms** (down from ExoPlayer default 2 500 ms), `bufferForPlaybackAfterRebufferMs` **1 000 ms**, `minBufferMs` **5 000 ms**, `maxBufferMs` **30 000 ms**. Applied globally to the single `ExoPlayer` instance — benefits all stream loads (hero preview, player, VOD, catch-up). The larger 30 s max buffer also serves the catch-up optimization (forward seeks within buffered data are instant).
- **Direct media swap:** Removed `stop()` call before `setMediaItem()` during channel switches. ExoPlayer handles the transition internally, keeping the **last decoded frame visible** until the new stream renders (no black flash).
- **`DefaultRenderersFactory` with `EXTENSION_RENDERER_MODE_PREFER`:** Hardware-accelerated decoders preferred for faster decode startup.
- **`channelSwitch` native event:** Emitted when a live stream is swapped so Flutter can coordinate UI behavior.
- **1.5-second spinner delay for live:** `_BufferingSpinnerOverlay` is suppressed for the first 1 500 ms of any live buffering event. If `STATE_READY` arrives within that window (normal case), the spinner never appears. VOD/catch-up retain immediate spinner. This is a standard UX pattern — brief spinners make perceived performance worse, not better.
- **Files changed:** `NativeExoPlayerSession.kt` (buffer config, media swap, `channelSwitch` event, renderer factory), `player_screen.dart` (`_showLiveSpinner`, `_liveSpinnerDelayTimer`).
- Full documentation: **[`06-playback-and-native-player.md`](06-playback-and-native-player.md)** § *Fast channel switching*.

### Catch-up / VOD playback optimization (March 2026)

- **Goal:** Make catch-up (recorded) playback start faster and improve seeking responsiveness. All changes gated on `isLive: false` — live TV is completely unaffected.
- **`SeekParameters.CLOSEST_SYNC`:** VOD/catch-up seeks snap to nearest keyframe instead of exact position. Faster decoder startup, ±1 s precision loss (unnoticeable). Live keeps `SeekParameters.DEFAULT`.
- **Larger buffer (30 s max):** `DefaultLoadControl` buffers up to 30 s ahead for VOD. Forward seeks within the buffered window are instant (no network request).
- **Seek increment hints:** `setSeekBackIncrementMs(30_000)` / `setSeekForwardIncrementMs(30_000)` on `ExoPlayer.Builder` so ExoPlayer can optimize buffering around the app's seek step size.
- **Scrub-on-hold / seek-on-release:** During hold-to-seek, only the UI scrubs (`_scrubPositionMs` updated locally every 75 ms, timeline strip reflects it). ExoPlayer receives **one single `seekTo`** when the user releases the key — eliminates server thrashing from dozens of overlapping HTTP requests. Single taps still seek immediately.
- **800 ms seek spinner grace:** Spinner suppressed for 800 ms after each seek (`_vodSeekSpinnerGrace`), preventing flashes during rapid seeking.
- **Files changed:** `NativeExoPlayerSession.kt` (`SeekParameters`, buffer profile, seek increments), `player_screen.dart` (scrub state, `_commitScrub`, `_scrubBy`, spinner grace, timeline conditional).
- Full documentation: **[`06-playback-and-native-player.md`](06-playback-and-native-player.md)** § *Catch-up / VOD playback optimization*.

### VOD minute jump strip + A/V sync + speed (April 2026)

- **Goal:** Quick **±1 / ±2 / ±3 minute** jumps without replacing **L/R** scrub; optional **A/V sync** and **playback speed** for VOD; two-step **Down** to focus the jump row.
- **UI:** **`PlayerTvVodJumpStrip`** under **`PlayerTvVodTimelineStrip`**; jump chips + trailing **A/V**, **Speed**, **Settings**. **`kPlayerTvOverlayBuild`** in **`player_tv_overlay.dart`**.
- **Tier A — first Down:** Timeline + jump row; **L/R** scrub (**±30 s** + hold ramp); **Center** play/pause.
- **Tier B — second Down:** Focus on strip (**default** center play); **L/R** across **indices 0–11**: **0–8** jumps (−15s … +15s), **9** A/V (**OK** opens **`PlayerTvVodAudioOffsetPopup`**; **±50 ms** in popup; persisted per **`resumeContentId`** via **`VodAudioOffsetStore`**), **10** Speed (**`PlayerTvVodSpeedPicker`**: **0.25×, 0.5×, 1×, 1.5×, 2×, 2.5×, 3×** — session-only; native reset on texture release), **11** **`openPlayerSettingsOverlay`**. **Up** exits tier B. **Back** dismisses overlays / popups before player exit.
- **Native A/V:** **`IptvilLeadingSilenceAudioProcessor`**, **`IptvilTrimmingAudioProcessor`**, **`IptvilRenderersFactory`** → **`DefaultAudioSink`**; **`NativeExoPlayerSession`** `setAudioDelayMs` / `load` args + short seek flush so processors apply.
- **Accuracy fix:** VOD keys only in **`HardwareKeyboard`** (**`_onPlayerHardwareKey`**); **`_activateVodJumpButton`** ~**280 ms** debounce.
- **Files:** `lib/player/player_tv_overlay.dart`, `lib/player/player_screen.dart`, `lib/player/vod_audio_offset_store.dart`, `android/.../NativeExoPlayerSession.kt`, `Iptvil*AudioProcessor*`, `IptvilRenderersFactory.kt`.
- Full documentation: **[`06-playback-and-native-player.md`](06-playback-and-native-player.md)** § *VOD fullscreen overlay*.

### Top Menu Manager (March 2026)

- **Goal:** Allow full customization of the top navigation bar — item order, optional items, and startup category.
- **Core categories** (Live TV, Movies, Series, Recording) are always present; their **order** is user-configurable. Settings is always last and locked.
- **Optional items** (Playlist, Theme, Clock, Appearance, Backup, Favorite Setup) can be toggled on/off from Settings → Top Menu Manager. When enabled, they appear in the top bar at the user's chosen position; when disabled, they remain accessible via Settings.
- **Startup category:** Any currently visible top menu item can be chosen as the app's startup screen.
- **Persistence:** `TopMenuStore` (singleton) persists order and startup to `SharedPreferences` (`top_menu_order`, `top_menu_startup`).
- **Backup:** `topMenu` key added to backup JSON — `{ "order": [...], "startup": "liveTv" }`. Import via `replaceFromBackup`.
- **UI:** Two-column layout — left: reorderable list (OK to pick up, D-pad Up/Down to move, OK to drop), right: available optionals + startup radio selector.
- **Shell integration:** `AppTopBar` reads from `topMenuStore.fullMenu` dynamically. `MainShellScreen` initializes from `topMenuStore.startup`.
- **Files:** `lib/data/top_menu_store.dart`, `lib/ui/settings/top_menu_manager_screen.dart`, `lib/shell/app_top_bar.dart`, `lib/shell/main_shell_screen.dart`, `lib/ui/settings/settings_screen.dart`.

### CosmicSpaceBackdrop on all settings sub-screens (March 2026)

- **Goal:** Unified deep-space visual experience across the entire app — no flat solid backgrounds on any screen.
- **Change:** All settings sub-screens (`BackupScreen`, `BackupImportScreen`, `BackupManageScreen`, `ClockSettingsScreen`, `EditSettingsScreen`, `LiveTvEditScreen`, `MediaRailEditScreen`, `TopMenuManagerScreen`, `RecordingEditScreen`, `RecordingCategoryApprovalScreen`, `RecordingChannelApprovalScreen`, `AddPlaylistScreen`, `PlaylistGroupManagerScreen`) switched from `Scaffold(backgroundColor: palette.surface)` to `Scaffold(backgroundColor: Colors.transparent)` with `Stack([CosmicSpaceBackdrop(), ...content])`.
- **Main Settings grid:** Changed from `ColoredBox(color: p.surface)` to `Colors.transparent` — the shell's existing backdrop shows through.
- **Pattern:** Import `cosmic_space_backdrop.dart`, set `backgroundColor: Colors.transparent`, wrap body in `Stack` with `const CosmicSpaceBackdrop()` as first child.

### Movies · Appearance — Movie Grid Settings card (April 2026)

- **Goal:** A dedicated left-docked **Movie Grid Settings** panel for movies rail density and poster display modes, with TV-safe focus, a **brushed** slate interior, and **Hide/Show** so users can judge the full browse layout without the card.
- **Files:** `lib/ui/settings/movie_grid_settings_panel.dart` (`MovieGridSettingsPanel`, `MovieGridSettingsPanelHost`, `_MovieGridPanelBrushedFill`, `_CyanFocusShell`), `lib/ui/settings/media_rail_edit_screen.dart` (route `Stack`, `ExcludeFocus` on preview, `FittedBox` scale, `MovieGridSettingsPanelHost`).
- **Behavior:** **Hide** / **Show** (`movieGridHidePanel` / `movieGridShowPanel` in l10n); **OrderedTraversalPolicy** + **NumericFocusOrder** inside the card; outline-only cyan focus rings; card scaled to **65%** of design width with fixed corner position; valid **Positioned** under **LayoutBuilder** + **Stack**.
- **Stores:** `movieRailPageSizeStore`, `mediaCardStyleStore` (movie poster modes); unchanged backup keys.

### Appearance screen consolidation (March 2026)

- **Goal:** Combine card style settings (Channel, Movie, Series) into the Appearance screen as compact inline selectors — no separate sub-screens.
- **Removed:** Three settings tiles ("Channel cards", "Movie cards", "Series cards") and their full-screen `_LiveTvCardStyleScreen` / `_MediaCardStyleScreen` classes from `settings_screen.dart`.
- **Added:** Inline `_CardStyleSection<T>` widget with radio-chip rows in `EditSettingsScreen`. Each card type gets a section label + 3 horizontally arranged `_StyleChip` widgets (selected chip shows accent border + check icon).
- **Layout:** Two-column layout — left: layout editors (Live TV, Movies, Series with chevron navigation to detail screens), right: three card style selectors. Fits on one page without scrolling, with breathing room for future additions.
- **Compact spacing:** Reduced padding and font sizes for a dense but readable single-page fit on TV screens.

### Movie detail screen redesign — cinematic split layout (April 2026)

- **Goal:** Match the premium look of competitor IPTV apps — movie backdrop blending into a dark left text area, no visible app background.
- **Before:** Full-screen backdrop as wallpaper, text overlaid directly on image (hard to read), no Cast/Director/Rating info.
- **After:** Split layout — text left (~52% width), backdrop image right (~65% width, overlapping). Image fades seamlessly into a solid dark base via nested `ShaderMask` widgets (`BlendMode.dstIn`). No `CosmicSpaceBackdrop` — the movie's own art is the background.
- **New info displayed:** Rating badge (blue pill), Cast line, Director line — all sourced from Xtream VOD API (`MockMovie.cast`, `.director`, `.rating`).
- **Image blending:** Two `ShaderMask` layers on the image: horizontal (left-to-right fade to transparent) + vertical (subtle top/bottom fade). This eliminates any visible seam between the image and dark area.
- **Action buttons:** Play, External, Trailer, My list / Remove, Watched / Unwatch — same set, now positioned at bottom of left column.
- **Files changed:** `lib/ui/movies/movie_details_screen.dart` (full rewrite), `05-ui-shell-and-tv-patterns.md`.

### Series detail screen redesign — same cinematic split (April 2026)

- **Goal:** Apply the identical cinematic split layout from Movies to Series details for visual consistency.
- **Data model:** Added `cast`, `director`, `rating` optional fields to `MockSeries` (`mock_series_data.dart`).
- **Xtream integration:** `mapXtreamSeriesList` and `mergeXtreamSeriesDetail` in `xtream_mapper.dart` now extract cast/director/rating from the API. `xtream_catalog_snapshot_codec.dart` serializes/deserializes these fields.
- **Layout:** Same solid dark base + right-aligned backdrop with dual `ShaderMask` fade. Dynamic hero image (switches on episode focus). Two-zone layout: info constrained to left side, episode rails span full screen width (7 tiles per row). Focus ring fully visible via `clipBehavior: Clip.none` + vertical padding on `ListView`.
- **Files changed:** `lib/ui/series/series_details_screen.dart`, `lib/ui/series/mock_series_data.dart`, `lib/xtream/xtream_mapper.dart`, `lib/data/xtream_catalog_snapshot_codec.dart`.

### Browse screen full-bleed cinematic redesign (April 2026)

- **Goal:** Replace the old NeonGradientFrame banner-style hero on Movies and Series browse screens with a full-screen cinematic backdrop covering the entire page — matching the look of competitor IPTV apps where the movie image IS the background.
- **Before:** Backdrop confined inside a small hero card with neon-glow frame border. App cosmic background visible behind/around the card. Text overlaid at the bottom of the card.
- **After:** Full-screen `Stack` at the page level. **Color-matched background** via `backdropPrimary` darkened 72% toward black (`Color.lerp`) — transitions smoothly per focused item. Backdrop image displayed with **`BoxFit.contain`** + **`Alignment.centerRight`** — shows the **full image** at natural aspect ratio (no cropping/stretching), right-aligned, slight top/bottom padding for headroom. Dual `ShaderMask` (`BlendMode.dstIn`) blends the left edge into the matched background — the whole screen looks like one unified visual. Text info (title, rating, cast, director, description) overlaid on left ~46% with drop shadows. Category strip and poster rail sit on top. Backdrop is inside `ValueListenableBuilder` so image always matches focused poster (sync bug fix).
- **Hero cards now text-only:** `MovieBrowseHeroCard` and `SeriesBrowseHeroCard` render only text info — no image, no colored box. The backdrop lives at the parent screen level.
- **Both screens updated:** `MoviesScreen` and `SeriesScreen` both use the identical full-bleed pattern.
- **Files changed:** `lib/ui/movies/movies_screen.dart` (full `build()` rewrite — `Stack` with backdrop layer), `lib/ui/series/series_screen.dart` (same treatment), `lib/ui/movies/movie_browse_hero_card.dart` (text-only rewrite), `lib/ui/series/series_browse_hero_card.dart` (text-only rewrite).

## How to extend next

| Goal | Suggestion |
|------|------------|
| XMLTV-only providers | Fetch `xmltv.php` or external EPG URL, map by channel id, feed same `LiveNowEpgDisplay`-style model |
| Localized EPG strings | `AppLocalizations` for hero labels (“Broadcasting now”, “Ends in …”) |
| Player dispose on Android | Optional explicit native `dispose` if you need process-long player teardown guarantees |
| DRM / widevine | Not in current native stack — would be a large add |

---

*End of handoff documentation. Update this file when you ship meaningful UX or architecture changes.*
