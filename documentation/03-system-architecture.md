# System architecture

## Layered view

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter UI (Material, TV layouts, TvFocusable, rails)      │
├─────────────────────────────────────────────────────────────┤
│  Domain-ish LibraryController, XtreamCatalogRepository        │
│  MyListStore, LiveFavoriteGroupsStore, PlaybackResumeStore, │
│  LiveEpgController                                           │
├─────────────────────────────────────────────────────────────┤
│  PlayerService + LivePreviewChannel ◄──► Method + Event     │
│  `com.iptvil/player` (main)  `com.iptvil/live_preview` (hero)│
├─────────────────────────────────────────────────────────────┤
│  Android: NativeExoPlayerSession + NativeLivePreviewSession │
│  (ExoPlayer → TextureRegistry.SurfaceProducer → Flutter Texture) │
└─────────────────────────────────────────────────────────────┘
```

## Application flow

1. **Startup** — `main()` initializes **`libraryController`** (loads `SharedPreferences`: playlists, active id, demo preference) and **`await`s** other persisted stores (`playlistGroupVisibilityStore`, live/movie/series **card style** stores, **`LiveFavoriteGroupsStore.instance.ensureLoaded()`**, **`clockOverlaySettingsStore`**, etc.).
2. **Splash** — `SplashScreen` shows brand assets, then **`Navigator.pushReplacement`** → `MainShellScreen`.
3. **Shell** — `MainShellScreen` shows one of: `LiveTvScreen`, `MoviesScreen`, `SeriesScreen`, **`TeamScreen`** (shell label **Theme**), `SettingsScreen` (top bar + **`CosmicSpaceBackdrop`**). **`LiveTvFavoritesScreen`** is reached from **Settings → Favorite setup**, not as a root shell tab.
4. **Details** — Movies/Series push their own `MaterialPageRoute`s (details are not inside the shell’s single-child swap; they stack on the navigator).
5. **Player** — `openIptvilPlayer()` calls **`LivePreviewChannel.pauseForFullscreen`**, pushes **`PlayerScreen`**, then on pop: for **live**, **`resumeAfterFullscreen`** then deferred **`onPlayerClosed`** + focus restore; for **VOD**, **`onPlayerClosed`** runs **first** (sync), then **`resumeAfterFullscreen`** and focus restore — see **`06-playback-and-native-player.md`**. **`suppressPreviousFocusRestore`** skips restoring the pre-push focus node (**Live TV** uses this and refocuses by channel id).

## Global singletons (important for onboarding)

| Symbol | Location | Responsibility |
|--------|----------|------------------|
| `libraryController` | `lib/data/library_controller.dart` | Playlists, `useDemoData`, `activePlaylist` |
| `xtreamCatalogRepository` | `lib/data/xtream_catalog_repository.dart` | In-memory catalog after sync |
| `MyListStore.instance` | `lib/data/my_list_store.dart` | Favorites-style lists: **movies**, **series**, **live channel** ids (persisted separately) |
| `LiveFavoriteGroupsStore.instance` | `lib/data/live_favorite_groups_store.dart` | Named **Live TV favorite groups** (id, name, sort order, ordered channel ids); prefs **`iptvil_live_favorite_groups_v1`** |
| `LiveEpgController.instance` | `lib/data/live_epg_controller.dart` | Xtream **short/simple EPG** for the currently focused live channel; UI listens via `ListenableBuilder` |
| `ShellNavigationHub.instance` | `lib/shell/shell_navigation_hub.dart` | Programmatic shell tab changes (**`goTo`**) — bound in **`MainShellScreen`**; used after successful **Add Playlist** ingest and after **Theme** selection (**Live TV**) |
| `clockOverlaySettingsStore` | `lib/data/clock_overlay_settings_store.dart` | Global **on-screen clock** prefs (enabled, format, corner, size, opacity, color index **0–7**, **framed**); **`useSegmentDigitFont`** when color is one of three **neon** presets; `ListenableBuilder` in `SettingsScreen` for subtitle |
| `teamVisualStore` | `lib/data/team_visual_store.dart` | Persisted **Cosmic / Aurora / Solar / Heritage** visual team → **`TeamPalette`**; `ListenableBuilder` in **`IptvilApp`** drives **`Theme`** |

Listen to `libraryController` when switching demo ↔ Xtream or changing active playlist so browse screens refetch.

## Global overlay (clock)

- **`MaterialApp.builder`** in `app.dart` wraps the navigator child and **`ClockOverlayLayer`** in a `Stack` (`fit: StackFit.expand`). The clock is wrapped in **`IgnorePointer`** so **remote / touch** events reach the shell and routes underneath (the clock is **visual-only** for input).
- **Typography:** Non-neon colors use the theme’s sans + tabular figures. **Neon** presets (indices **5–7**) use bundled **`DSEG7Classic`** for 7-segment **time** and for **`DD/MM`** on the framed line; **`MON`–`SUN`** use explicit **`Roboto`** so the weekday stays **uppercase**. **Framed** mode adds a **HUD** (gradient fill, border, shadow). **Unframed** — **time only**.

## TV focus (`TvFocusable`)

- Default focus uses **`AppTheme.focusScale`** (~1.075), **`focusParallaxSlide`**, **`context.teamPalette`** for the focus ring / shadows, and optional **elevation shadow** — ideal for rails; can **overflow** parents if the row is full-bleed.
- **Dense lists** (e.g. **Manage groups → category toggles**): pass **`focusScale: 1.0`**, **`parallaxSlide: 0`**, **`showFocusElevation: false`**, and optionally **`focusedBorderWidth: 1.4`** so the ring stays **inside** the padded column.

## Navigation model

- **Shell** uses local state `_destination` (`ShellDestination`) + **`AppTopBar.onSelect`**.
- **Android Back** on shell root (`PopScope(canPop: false)`): **`ShellBackCoordinator.tryConsumeBack()`** runs **only when** the shell is **not** in “menu opened from Back” mode. **First Back** in the normal state arms top-nav focus; while **`_menuOpenedFromBack`**, the coordinator is **not** invoked; **first Back** arms exit, **second Back** calls **`_stopPreviewAndExit()`** (**`await LivePreviewChannel.dispose()`** then **`SystemNavigator.pop()`**). Choosing a destination clears **menu-from-Back** state.
- **Pushed routes** (details, player): normal `Navigator.pop` / system back handled by the route.

## Theming

- **Dark theme** is built per **`TeamPalette`**: `AppTheme.themeForPalette` in `lib/theme/app_theme.dart` (see **`TeamPalette.cyan`**, **`violet`**, **`solar`**, **`heritage`**).
- **`TeamPaletteTheme`** (`lib/theme/team_palette_theme.dart`) exposes **`context.teamPalette`** for widgets (focus rings, surfaces, **`CosmicSpaceBackdrop`**-aligned colors).
- **Legacy static accents** on `AppTheme` remain for code paths not yet migrated; new chrome should prefer **`context.teamPalette`**.

## Image pipeline

- Catalog posters/backdrops/channel icons: **`TvCatalogImage`** + **`tv_media_urls.dart`**. Helpers return **only** plausible **`http://` / `https://`** URLs from Xtream (and mocks); otherwise **`''`**. Empty or failed loads show **`TvUniversalMediaPlaceholder`** (**`tv_catalog_image.dart`**) — same **team-palette** gradient + **`Icons.live_tv_rounded`** for **Live TV** and **VOD**. Movies/Series rails use **`TvUniversalMediaPlaceholder`** in **`_MoviesHiResImage` / `_SeriesHiResImage`** for empty/error. **`tv_tmdb_placeholders.dart`** is **legacy** (unused by **`tv_media_urls`**).

## Error handling (catalog)

- `catalog_status_widgets.dart` and per-screen logic show loading, empty, and retry when `XtreamCatalogRepository` reports errors or M3U-only active playlist.

## Android host app (Gradle)

TV behavior also depends on **native** dependency alignment: Flutter’s **`TextInputPlugin`** must see a **new enough** **`androidx.core`** (see **`07-android-build-and-branding.md`**). A too-old forced **`core`** / **`core-ktx`** can crash when the **IME** opens, unrelated to Dart layer architecture above.
