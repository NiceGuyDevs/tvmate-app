# Repository structure

High-level map of the IpTvIl workspace. Paths are relative to the repo root.

## Top level

| Path | Role |
|------|------|
| `lib/` | All Dart application code |
| `android/` | Android embedding, Kotlin native player, manifests, resources |
| `assets/images/` | Flutter-declared images (logos, splash). May include `.gitkeep`; PNGs may exist locally |
| `assets/fonts/` | **DSEG7Classic-Regular.ttf** — 7-segment font for neon clock colors (`pubspec.yaml` `fonts:`) |
| `pubspec.yaml` | Package name, SDK, dependencies, asset bundle |
| `ARCHITECTURE.md` | Short architecture note (player + Xtream); see **`documentation/`** for full write-up |
| `documentation/` | This documentation set (all `*.md` handoff files) |

## `lib/` — application code

### Entry & shell

| File / folder | Role |
|---------------|------|
| `main.dart` | App bootstrap, `libraryController.initialize()`, persisted stores incl. **`teamVisualStore.ensureLoaded()`**, **`LiveFavoriteGroupsStore.instance.ensureLoaded()`**, `clockOverlaySettingsStore.ensureLoaded()`, etc. |
| `app.dart` | `MaterialApp` (base theme **`TeamPalette.cyan`**), **`home`:** `SplashScreen`; **`builder`:** **`ListenableBuilder(teamVisualStore)`** + **`Theme(AppTheme.themeForPalette(palette))`** + `Stack` with **`ClockOverlayLayer`** |
| `shell/main_shell_screen.dart` | **Main TV shell**: **`CosmicSpaceBackdrop`** + **`Column`** — **`AppTopBar`** (destinations) + expanded content; **`PopScope`** back; **double Back** from menu-open-from-Back exits with **`LivePreviewChannel.dispose()`** |
| `shell/app_top_bar.dart` | Top navigation: **`ShellDestination`** tabs + focus nodes for TV |
| `shell/shell_destination.dart` | `enum` Live TV, Movies, Series, **Theme**, Settings + labels/icons (**Theme** → **`TeamScreen`**) |
| `shell/shell_navigation_hub.dart` | **`ShellNavigationHub.instance.goTo(ShellDestination)`** — bound from **`MainShellScreen`** for programmatic tab switches (e.g. **Add Playlist** success → Live TV; **Theme** choice → Live TV) |
| `shell/shell_back_coordinator.dart` | Browse screens register **first Back** consumption (e.g. focus to chips) before the shell handles Back (top bar / exit flow) |

### Theme & focus

| File / folder | Role |
|---------------|------|
| `theme/app_theme.dart` | Colors, radii, shadows, `ThemeData.dark` customization |
| `ui/focus/tv_focusable.dart` | TV-focused wrapper: scale, parallax slide, focus ring, elevation shadow; optional **`focusedBorderWidth`** (default 2.2), optional **`canRequestFocus`**; **`scheduleSteadyChannelTileFocus`** helper for post-route tile refocus |

### Player

| File / folder | Role |
|---------------|------|
| `player/player_service.dart` | Abstract `PlayerService`, factory, `UnavailablePlayerService` |
| `player/native_android_player_service.dart` | MethodChannel / EventChannel to Android |
| `player/player_screen.dart` | Fullscreen playback UI + `Texture`; **VOD:** contain-sized **`Texture`** from **`videoWidth`/`videoHeight`** (progress); **live:** full-bleed |
| `player/player_navigation.dart` | `openIptvilPlayer` — preview pause/resume around **`PlayerScreen`**; optional **`contentDescription`** (VOD Up banner); **VOD** vs **live** ordering for **`onPlayerClosed`** and focus restore |
| `player/player_browse_restore.dart` | Result when **`PlayerScreen`** pops: **`liveChannelId`**, **`movieId`**, **`seriesId`** |
| `player/player_events.dart` | Native event payload parsing |
| `player/playback_resume_store.dart` | SharedPreferences-backed VOD position |
| `player/mock_stream_urls.dart` | Demo HLS when item has no `streamUrl`; **`kIptvilSingleDemoHls`** used for all live/VOD mock resolvers in empty-library mode |
| `player/live_lineup_item.dart` | Live lineup entry: title, URL, **`channelId`**, optional **`epgChannelId`** for EPG refresh in player |
| `player/player_track.dart` | Track snapshot types (future audio/subs UI) |

### Data & Xtream

| File / folder | Role |
|---------------|------|
| `data/library_controller.dart` | Playlists, active playlist, demo mode; global `libraryController` |
| `data/stored_playlist.dart` | Persisted playlist model |
| `data/playlist_type.dart` | Xtream vs M3U enum |
| `data/my_list_store.dart` | Persisted **movie**, **series**, and **live channel** id lists |
| `data/my_space_store.dart` | Legacy **`MySpaceStore`** (JSON **`iptvil_my_space_sections_v1`**); **no UI** — shell **My space** removed |
| `data/live_favorite_groups_store.dart` | **`LiveFavoriteGroupsStore`**: named Live TV **favorite groups** (channels per group, sort order); prefs **`iptvil_live_favorite_groups_v1`** |
| `data/clock_overlay_settings_store.dart` | **Singleton** `clockOverlaySettingsStore`: clock on/off, 12/24h, corner, size, opacity, color index, **framed**; **neon color indices** drive **DSEG7** segment font in overlay |
| `data/live_tv_hero_layout_store.dart` | **Singleton** `liveTvHeroLayoutStore`: Live TV hero **height** **30–100%** (step **10**), default **60**; prefs **`iptvil_live_tv_hero_height_pct_v1`** |
| `data/live_epg_controller.dart` | **Singleton** `LiveEpgController`: Xtream short/simple EPG per focused channel, cache, `notifyListeners` |
| `data/playlist_epg_timezone_store.dart` | **Singleton** `playlistEpgTimezoneStore`: per-playlist EPG **display** mode (`local` / `original` / IANA) + server UTC offset for catch-up URLs |
| `data/epg_time_display.dart` | Shared EPG time range / single-time formatting using **`PlaylistEpgTimezoneStore`** + **`timezone`** |
| `data/epg_timezone_catalog.dart` | Curated IANA zones for **EPG time** picker (labels + short chip text) |
| `data/xtream_catalog_repository.dart` | Cache + sync from library; `ChangeNotifier` |
| `data/xtream_catalog_cache_db.dart` | SQLite **`iptvil_xtream_catalog.db`** (metadata) + **`iptvil_cat_full_*.json`** / **`iptvil_cat_live_*.json`** files for large snapshots (**Android `CursorWindow`**) — see **`04`** |
| `xtream/xtream_api_client.dart` | HTTP calls to panel `player_api.php` (incl. **`get_short_epg`**, **`get_simple_data_table`**) |
| `xtream/xtream_mapper.dart` | JSON → `Mock*` UI models + episode/season mapping; live streams include **`epgChannelId`** when panel sends `epg_channel_id` |
| `xtream/xtream_short_epg_parser.dart` | Parses EPG listing JSON (multiple keys, timestamps, `now_playing`, localized titles) |
| `xtream/xtream_stream_urls.dart` | URL builder for live/movie/series episode |
| `xtream/xtream_url.dart` | URL normalization |
| `xtream/xtream_exceptions.dart` | Typed errors |

### UI — screens

| Folder | Role |
|--------|------|
| `ui/splash/splash_screen.dart` | Branded splash → `MainShellScreen` |
| `ui/live_tv/` | **Live TV** screen, **hero** (`live_tv_screen.dart`, **`live_tv_hero_panel.dart`** — **`viewCategoryId`**, parental **blackout** when `isLivePlaybackBlocked`, **`hero_epg_script.dart`**, **`hero_live_preview.dart`** — framed **`Texture`** or **`parentalBlackout`** black fill, optional **inside-bezel** timeline, debounced load), **`live_preview_channel.dart`**, **`live_tv_channel_browse_tile.dart`** (grid tiles), grid, **`live_tv_favorites_screen.dart`**, **`live_favorite_group_editor_screen.dart`**, **`live_favorite_picker_screen.dart`**, mock data (**`mock_live_tv_data.dart`** — large demo channel list + **`iconUrl`**) |
| `ui/team/team_screen.dart` | **Theme** tab (shell label): pick **Cosmic / Aurora / Solar / Heritage** (`teamVisualStore.setTeam`) |
| `ui/widgets/cosmic_space_backdrop.dart` | Animated deep-space background; driven by palette-aware gradients |
| `ui/movies/` | Movies browse, details, mocks |
| `ui/series/` | Series browse, details, mocks |
| `ui/settings/` | Settings grid, **`edit_settings_screen.dart`** (**Edit** hub → **Live TV** / Movies / Series), **`live_tv_edit_screen.dart`**, **`media_rail_edit_screen.dart`** (Movies/Series appearance previews), **`movie_grid_settings_panel.dart`** (Movie Grid Settings card: Hide/Show, brushed fill, TV focus), **`clock_settings_screen.dart`** (info banner + clock grid), **`add_playlist_screen.dart`** (TV focus + scroll + keyboard insets), loading, **`my_playlists_screen.dart`**, **`playlist_epg_time_screen.dart`** (EPG time picker), **playlist group manager**, **`shield_tv_text_field.dart`** (**`dense`**, **`keyboardType`** for TV IME), `tv_remote_keys.dart` |
| `ui/clock/` | **`clock_overlay.dart`** — `ClockOverlayLayer` (global time, `IgnorePointer`) |
| `ui/demo/` | Placeholder pages for unused shell destinations |
| `ui/catalog/catalog_status_widgets.dart` | Loading / error / retry for catalog |

### UI — widgets

| File | Role |
|------|------|
| `ui/widgets/tv_catalog_image.dart` | **`TvCatalogImage`**, **`TvUniversalMediaPlaceholder`**, shimmer, legacy **`TvImagePlaceholder`** |
| `ui/widgets/tv_media_urls.dart` | Poster/backdrop/icon/still URL helpers; **`''`** when not loadable → universal art |
| `ui/widgets/tv_tmdb_placeholders.dart` | Legacy TMDb path list (unused by **`tv_media_urls`**; kept for reference) |
| `ui/widgets/detail_actions.dart` | Shared detail action row (play, external, trailer, my list) |
| `ui/widgets/episode_season_caption_bar.dart` | Bottom **SxxExx** strip on episode tiles |

> **Note:** Older docs referred to a right-hand **`AppSidebar`** and a **Home** shell tab; the current shell uses a **top bar** (`app_top_bar.dart`) and defaults to **Live TV**.

## `android/` — native

| Path | Role |
|------|------|
| `build.gradle` (project root) | **`allprojects`** repos + **`resolutionStrategy`** **`force`** for **`androidx.core:core`** / **`core-ktx`** (**1.15.0**) so Flutter text input matches **`EditorInfoCompat`** APIs (see **`07-android-build-and-branding.md`**) |
| `app/src/main/AndroidManifest.xml` | `LEANBACK_LAUNCHER`, `android:banner`, `android:icon`, cleartext |
| `app/src/main/kotlin/.../MainActivity.kt` | Flutter activity; registers **`NativeExoPlayerSession`** + **`NativeLivePreviewSession`**; **`onPause`** → **`livePreview.stopForActivityPause()`** |
| `app/src/main/kotlin/.../NativeExoPlayerSession.kt` | Main ExoPlayer, **`SurfaceProducer` → `Texture`**, `com.iptvil/player` |
| `app/src/main/kotlin/.../NativeLivePreviewSession.kt` | Hero preview ExoPlayer, **`SurfaceProducer`**, **`com.iptvil/live_preview`**, audio + fullscreen pause/resume; **`SCALE_TO_FIT`** |
| `app/src/main/AndroidManifest.xml` | **`EnableImpeller` false** under **`<application>`** (TV video color / compositor path) |
| `app/src/main/res/` | Themes, launcher adaptive icon XML, TV banner, launch background |

## Tests

`test/` may exist for widget/unit tests; primary app is integration-tested on device/TV.
