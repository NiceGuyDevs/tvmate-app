# IpTvIl

Premium-style IPTV client for **Android TV** (Leanback), built with Flutter and native **Media3 / ExoPlayer** playback.

## Features

- Leanback + phone launcher entries; **D-pad–first** TV UI; leanback software feature is **not required** so Android sideload works more broadly (see [documentation/07-android-build-and-branding.md](documentation/07-android-build-and-branding.md)).
- **Live TV** — horizontal **category pills**: **named favorite groups** (you define in **Settings → Favorite setup**) **then** visible playlist categories; **hero banner** with:
  - **Live in-frame preview** (second native ExoPlayer, TV-style bezel + **`Texture`**) of the focused channel’s stream, with **audio** on Android.
  - **Compact** strip under the preview (times, thin progress bar, “Ends in…”).
  - **Center** **EPG** (larger title/description, status line, category) from Xtream when available.
  - **Trailing logo** column (channel art + name); **RTL** mirrors column order.
  - **Two-tone gray** hero surface (no full-bleed channel “watermark” image behind the text).
- **Live EPG (Xtream)** — `get_short_epg` + **`get_simple_data_table` fallback**; **`epg_channel_id`** when present; flexible JSON parsing ([documentation/04-data-playlists-and-xtream.md](documentation/04-data-playlists-and-xtream.md)).
- **EPG time (per playlist)** — **Settings → My playlists → EPG** chooses how programme times are **shown** (device local, server original, or a world time zone). See **[documentation/10-recording-epg-system.md](documentation/10-recording-epg-system.md)**.
- **Fullscreen player handoff** — opening **`PlayerScreen`** calls **`LivePreviewChannel.pauseForFullscreen`** so preview **stops competing for audio**; when the route **pops**, **`resumeAfterFullscreen`** restores preview playback ([ARCHITECTURE.md](ARCHITECTURE.md)).
- **Shell** — **top navigation bar** (**Live TV**, **Movies**, **Series**, **Theme**, **Settings**) over a **cosmic backdrop**; default tab **Live TV**.
- **Theme** (shell label) — choose **Cosmic** (cyan), **Aurora** (violet / purple–pink), **Solar** (yellow / gold neon), or **Heritage** (elegant gold, wine, midnight): persisted accent + backdrop + focus chrome via **`TeamVisualStore`** / **`TeamPalette`**; **`TeamScreen`** implementation. After a choice, the shell switches to **Live TV** (**`ShellNavigationHub.goTo`**) so you land on the main grid immediately. Same playback and data regardless of palette.
- **Live favorites** — **named groups** (**`LiveFavoriteGroupsStore`**): **Settings → Favorite setup** (**`LiveTvFavoritesScreen`**, **`LiveFavoriteGroupEditorScreen`**, channel picker with order). Pills appear on **Live TV** even if **all playlist categories are hidden**. **Movies / Series**, **My List** (movies, series, legacy live ids where applicable), **Xtream** playlists; **M3U** catalog browse not implemented in this path.
- **Native HLS / TS / VOD** via platform channels (not `video_player`); live **lineup** (UP/DOWN) + EPG ids on **`LiveLineupItem`**. **VOD** tier-B strip: **A/V sync** (popup, ms offset, saved per title id) and **speed** (**0.5×–3×** including **1.5×** / **2.5×**, session-only) — see **`documentation/06-playback-and-native-player.md`**.
- **VOD fullscreen picture** — correct **aspect ratio** (no stretch): native **`SCALE_TO_FIT`** + **display** **`videoWidth` / `videoHeight`** (PAR + rotation) in **`player_events`**; **`PlayerScreen`** centers **`Texture`** in a **contain**-sized box; black bars fill the rest ([documentation/06-playback-and-native-player.md](documentation/06-playback-and-native-player.md)). **D-pad seek** uses **larger steps + faster hold** (see **`player_screen.dart`** constants in **`documentation/06-playback-and-native-player.md`**).
- **Missing posters / channel logos** — one shared **`TvUniversalMediaPlaceholder`** (gradient + TV icon) when URLs are absent or fail; **`tv_media_urls`** + **`TvCatalogImage`** ([documentation/05-ui-shell-and-tv-patterns.md](documentation/05-ui-shell-and-tv-patterns.md)).
- **Parental control** — numeric PIN (**4–8** digits), lock-all by section, **per-item** Live TV locks with optional **hide from browse** (four scope actions + unlock), **restricted rules** with readable names, compact PIN entry with **inline numpad** from Settings and the live player; backup key **`parentalControl`**. See **[documentation/17-parental-control.md](documentation/17-parental-control.md)**.
- **Settings (TV)** — compact **icon grid** for library and appearance; **global on-screen clock** (optional): **Settings → Clock** includes an **info banner** plus grid for on/off, 12/24h, corner, size, opacity, **eight color presets** (including **three neon**: red / green / yellow), optional **frame** (digital-HUD pill: gradient, border, **`DD/MM MON`** under the time). **Weekday is always uppercase (`MON`–`SUN`)**: with neon/segment digits, **DSEG7** renders **`DD/MM`** only and **Roboto** renders the weekday so letters never fall back to lowercase glyphs. **Neon** presets use the bundled **DSEG7 Classic** 7-segment font + soft glow for numerals; other colors use standard UI numerals. Clock is drawn in **`MaterialApp.builder`** so it appears above shell, browse, player, and menus; **`IgnorePointer`** so it never steals focus.
- **Add Playlist / My Playlists** — **narrow centered column** (max width) and **dense** `ShieldTvTextField` rows with proper **`TextInputType`** so the **TV on-screen keyboard** appears; source type is two **side-by-side icon tiles** (Xtream / M3U) with **auto-focus on Xtream**, then after a choice **auto-focus on the first field**; **scroll + insets + `ensureVisible`** keep lower fields visible when the IME is open; no **Change type** row (use **Back** and re-open **Add Playlist** to switch Xtream/M3U). **My Playlists** uses a **responsive grid** (up to **three cards per row** on wide TV) with compact action chips.
- **Trailers (movies / series)** — **`InAppYoutubeTrailerScreen`** searches YouTube-style metadata in-app; **Play** opens the watch URL in the **YouTube app** (or browser) via **`url_launcher`**, not an in-app WebView.
- **Manage groups / categories** — **PlaylistGroupSectionScreen**: centered column (**max width ~640**), dense category rows; **`TvFocusable`** uses **no scale / parallax / elevation** on list rows so focus rings stay **inside** the layout (optional **`focusedBorderWidth`** for thinner rings).

## Xtream Codes

- **Credentials** in **Settings → Add Playlist → Xtream Codes**; load step verifies server and stores **live / VOD / series** counts.
- **Demo mode** forces mock catalogs; **off** + active Xtream loads from `player_api.php`. **M3U-only** shows unsupported on browse tabs.
- **Catalog cache** — Large Xtream snapshots are stored as **JSON files** next to the local DB (not multi‑MB SQLite TEXT), so **Android** does not hit **`CursorWindow`** row limits after restart. Details: **[documentation/04-data-playlists-and-xtream.md](documentation/04-data-playlists-and-xtream.md)**.
- Code: `lib/xtream/`, `lib/data/xtream_catalog_repository.dart`, `lib/data/xtream_catalog_cache_db.dart`, `lib/data/live_epg_controller.dart`; models carry **`streamUrl`**, **`epgChannelId`**, **`iconUrl`** where mapped.

See [ARCHITECTURE.md](ARCHITECTURE.md), [TESTING_GUIDE.md](TESTING_GUIDE.md), **[CHANGELOG.md](CHANGELOG.md)** (release-style notes), **[documentation/](documentation/README.md)** — handoff docs include **Android TV video (`SurfaceProducer`, Impeller flag placement)**, **TV keyboard / Add Playlist focus**, **theme → Live TV**, and **trailer → external YouTube**.

## Playback

- **Main player:** `com.iptvil/player` + `com.iptvil/player_events` — one reused **`NativeExoPlayerSession`** for **`PlayerScreen`**.
- **Hero preview:** `com.iptvil/live_preview` — separate **`NativeLivePreviewSession`** (muted only while fullscreen player is on top).

**Android TV video stack (one APK, all devices):** Both Kotlin sessions use **`TextureRegistry.createSurfaceProducer()`** (lifecycle **`Callback`**, **`setSize`**, re-attach **`ExoPlayer`** after resize). **`AndroidManifest.xml`** disables **Impeller** (**`io.flutter.embedding.android.EnableImpeller` = false**) as a **child of `<application>`** — not `<activity>` — so **Skia + OpenGL** composites **MediaCodec** output correctly; **Impeller/Vulkan** alone caused **black** or **rainbow** video on some **Shield**-class devices while the UI stayed fine. Details: **[documentation/06-playback-and-native-player.md](documentation/06-playback-and-native-player.md)**, **[documentation/07-android-build-and-branding.md](documentation/07-android-build-and-branding.md)**, **[documentation/08-feature-history-and-decisions.md](documentation/08-feature-history-and-decisions.md)**.

**Live TV:** lineup passes **`channelId`** / **`epgChannelId`**; **VOD resume** via **`PlaybackResumeStore`**.

**VOD aspect layout:** [documentation/06-playback-and-native-player.md](documentation/06-playback-and-native-player.md) — native **`SCALE_TO_FIT`**, **display** **`videoWidth`/`videoHeight`**, Flutter **`_vodContainVideoSize`** + centered **`Texture`** for movies/episodes.

**Shell / TV behavior**

- **Back** from a root browse screen **focuses** the **top bar** for the current tab (`ShellBackCoordinator` runs only when the shell is not in that “menu from Back” mode). While that mode is active, **two more Back presses** call **`SystemNavigator.pop()`** (exit). Before exit, Flutter **`await`s `LivePreviewChannel.dispose()`**; **`MainActivity.onPause()`** also releases the hero preview native player so audio does not continue in the background on devices that keep the process alive.
- **VOD (Movies / Series) — back from fullscreen player:** One **Back** must return to the **detail** screen (where **Play** lives), not to the **browse** poster grid. Android TV can deliver a **second** system-back in the same gesture after the player route pops, which previously popped **details** too. **Mitigation:** **`openIptvilPlayer`** invokes **`onPlayerClosed`** **synchronously** for **`isLive: false`** (before live-preview resume) so details can arm a short window; **`MovieDetailsScreen` / `SeriesDetailsScreen`** use **`PopScope(canPop: false)`** and only call **`Navigator.pop`** from **`onPopInvokedWithResult`** when **not** inside that window. The on-screen **back** control still calls **`Navigator.pop`** directly to leave details. **`MoviesScreen._syncMovieBrowseToId`** / **`SeriesScreen._syncSeriesBrowseToId`** update hero/rail index when the player closes but **do not** `requestFocus` on posters while details is still on top (that used to steal focus from the details page).
- **Live TV — channel grid after player:** **`PlayerBrowseRestore`** carries **`liveChannelId`**; **`LiveTvScreen`** scrolls to the tile and refocuses it. **`scheduleSteadyChannelTileFocus`** (`tv_focusable.dart`) re-applies tile focus across frames/delays. Category **pills** temporarily use **`TvFocusable(canRequestFocus: false)`** during restore (~420 ms) so focus does not flash on chips first.
- **Live TV channel tiles (`LiveChannelBrowseTile`):** **`TvFocusable`** uses **`parallaxSlide: 0`**, **`focusScale: 1.0`** (ring-only focus — no grow past cell bounds), tight padding, and a **`ClipRRect`** **`Clip.hardEdge`** around the card. Logo+text style uses **`BoxFit.contain`** for channel art so logos are not cropped at the sides.
- **Focus / clipping:** Browse grids and rails use **`clipBehavior: Clip.none`** or **`Clip.hardEdge`** where noted; **Movies / Series** dropped an outer **`ClipRect`** around the main column so poster **focus rings** are not cut off; **`Row.clipBehavior`** is omitted for compatibility with older Flutter SDKs (see `pubspec` / local engine).
- **Nav chrome:** A **brief flash** on some transitions may still appear on certain hardware (e.g. Shield) — **known open visual issue** (see **`CHANGELOG.md`**).

### Build / run

```text
flutter pub get
flutter run -d <android-tv-emulator-or-device-id>
```

**AndroidX:** Root **`android/build.gradle`** uses **`resolutionStrategy`** to force **`androidx.core:core`** / **`core-ktx` 1.15.0** so Flutter’s text-input path matches the packaged **`EditorInfoCompat`** API (avoids **`NoSuchMethodError`** when the TV IME opens on some devices). Details: **[documentation/07-android-build-and-branding.md](documentation/07-android-build-and-branding.md)**.

### Automated checks

```text
flutter analyze
flutter test
```

## Project layout

- `lib/shell/` — **`main_shell_screen.dart`** (top bar + backdrop, double-Back exit + preview dispose), **`app_top_bar.dart`**, destinations, back coordinator  
- `lib/ui/live_tv/` — **live_tv_screen.dart**, **hero_live_preview.dart** (lifecycle resume after `paused`), **live_preview_channel.dart**, **live_tv_favorites_screen.dart**, **live_favorite_group_editor_screen.dart**, **live_favorite_picker_screen.dart**, favorites store, mocks  
- `lib/ui/team/` — **`team_screen.dart`** (Cosmic / Aurora / Solar / Heritage; shell tab label **Theme**)  
- `lib/ui/widgets/` — **`cosmic_space_backdrop.dart`**, catalog images, etc.  
- `lib/player/` — **`player_screen.dart`** (VOD **`Texture`** contain layout), **player_navigation.dart**, **player_browse_restore.dart**, **player_events.dart** (`videoWidth`/`videoHeight`)  
- `lib/data/` — **LiveEpgController**, **MyListStore**, **`live_favorite_groups_store.dart`**, **team_visual_store.dart**, **`my_space_store.dart`** (legacy prefs key; **no shell UI**), **clock_overlay_settings_store**, library, **`xtream_catalog_cache_db.dart`** (SQLite + JSON files for Xtream cache), Xtream repo  
- `lib/theme/` — **`app_theme.dart`**, **`team_palette.dart`**, **`team_palette_theme.dart`**  
- `lib/ui/clock/` — **`clock_overlay.dart`** (global overlay layer)  
- `assets/fonts/` — **DSEG7Classic-Regular.ttf** (7-segment clock digits; SIL OFL), declared in **`pubspec.yaml`**  
- `android/.../NativeExoPlayerSession.kt` (**`SurfaceProducer`**, **`displayVideoWidthHeight`**, **`SCALE_TO_FIT`**), **`NativeLivePreviewSession.kt`** (**`SurfaceProducer`**, **`SCALE_TO_FIT`**; **`stopForActivityPause()`** from **`MainActivity.onPause`**), **`MainActivity.kt`** (registers both); **`AndroidManifest.xml`** (**`EnableImpeller` false** under **`<application>`**)

## Version

**`pubspec.yaml`** `version: x.y.z+build` — the **+build** is Android **`versionCode`**; bump for upgrades over an existing install.
