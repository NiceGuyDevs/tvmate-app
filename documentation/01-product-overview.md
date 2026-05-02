# Product overview

## What IpTvIl is

**IpTvIl** is a **premium-style IPTV client** aimed at **Android TV** (e.g. NVIDIA Shield, Fire TV with Leanback, Google TV, Chromecast with Google TV, ONN and other **Google TV** / **Android TV** boxes). The UI is **remote-first**: large touch targets, focus rings, a **top navigation bar**, cosmic backdrop, and horizontal rails typical of TV apps. **Animation and scroll smoothness** depend on device **CPU / GPU / RAM**; budget HDMI sticks often feel **less fluid** than a Shield while running the **same** build — see **[TESTING_GUIDE.md](../TESTING_GUIDE.md)** (*Device matrix*).

Functional areas:

- **Live TV** (default shell tab) — horizontal **category pills**: **named favorite groups** first (from **`LiveFavoriteGroupsStore`**), then **visible** playlist live categories (respecting **group visibility**). A **tall hero** (~232 logical px) with **two-tone gray** styling (no full-bleed channel poster behind EPG): **live video preview** in a TV-style frame (native **second ExoPlayer**, **with audio** on Android under the focused channel), a **compact** row under the frame (clocks, thin bar, “ends in…”), **center EPG** (larger title/body, status, category) from the panel when Xtream is active, and **channel logo + name** on the **outer** side (**RTL**: preview leading, logo trailing). **Missing/broken channel logos** use **`TvUniversalMediaPlaceholder`** (same as Movies/Series art — **`05`**). Fullscreen play **pauses** hero preview audio to avoid overlap, then **resumes** when returning. A **channel grid** opens the player with optional **lineup** (UP/DOWN). If **all** playlist categories are hidden but **favorite groups** exist, Live TV still shows those pills.
- **Theme** — shell tab (label **Theme**; screen **`TeamScreen`**) to pick **Cosmic** (cyan), **Aurora** (violet / purple–pink), **Solar** (yellow / gold neon), or **Heritage** (gold, wine, midnight — refined multi-tone): backdrop, accents, and focus chrome update app-wide via **`TeamVisualStore`** + **`TeamPalette`**. After a choice, **`ShellNavigationHub`** switches the shell to **Live TV** (playback and library behavior unchanged).
- **Favorites (Live)** — **Settings → Favorite setup** opens **`LiveTvFavoritesScreen`**: **New favorite** / edit **name pills**, **`LiveFavoriteGroupEditorScreen`**, **Choose channels** picker (`LiveFavoritePickerScreen`). Persisted in **`LiveFavoriteGroupsStore`** (`iptvil_live_favorite_groups_v1`); legacy single-list migration may create a **“My favorites”** group. See **`05-ui-shell-and-tv-patterns.md`** (Favorite setup + Choose channels).
- **Movies** — category rails, detail screen, play / external / trailer / My List style actions. **Trailer** opens **`InAppYoutubeTrailerScreen`** (search in-app) then the **YouTube** watch URL via **`url_launcher`** (external app). Fullscreen **VOD** playback preserves **video aspect ratio** (centered **`Texture`**, black bars when needed; native **display** size + Flutter **contain** layout — see **`06-playback-and-native-player.md`**). **D-pad** seek while playing VOD uses **larger steps + faster hold** (see **`06`**). **Back** from fullscreen returns to **details** (not browse-only) via **`PopScope`** + **`openIptvilPlayer`** VOD ordering; browse hero/rail can sync without stealing focus from details. **Missing/broken posters** use **`TvUniversalMediaPlaceholder`** (see **`05-ui-shell-and-tv-patterns.md`**).
- **Series** — category rails, series detail with seasons and **episode tiles**; episode play uses VOD URLs from mock or Xtream mapping; same **back-to-details** and **VOD seek** behavior as movies. **Missing/broken art** uses the same **universal placeholder** as movies and Live TV.
- **Settings** — compact **icon grid**: add playlist, **my playlists** (responsive **grid** of cards; **EPG** per playlist opens **Local / Original / time zone** picker), channel/movie/series **card styles**, optional **global on-screen clock** (**Settings → Clock**: info **banner** + grid for 12/24h, position, size, opacity, **eight colors** including **three neon** with 7-segment **DSEG** for numerals, **Roboto** for **uppercase weekday** on the framed date line, optional **framed** HUD), **Edit** (**Live TV** hero height **30–100%**, Movies/Series placeholders for now), demo mode, **manage groups** (TV / Movies / Shows) with icon-style section tiles; per-section **category visibility** list is centered, dense, and TV-safe focus (no scale-on-focus overflow).

## Technical stack

| Layer | Choice |
|-------|--------|
| UI framework | Flutter 3.x (Dart SDK `>=3.5.0 <4.0.0`) |
| State | `ChangeNotifier` + `ListenableBuilder` / `AnimatedBuilder` patterns; some `ValueNotifier` on detail screens |
| Persistence | `shared_preferences` (playlists, demo flag, My List ids, VOD resume positions) |
| HTTP | `package:http` for Xtream JSON |
| External links | `url_launcher` |
| Video | **Platform channels** to Kotlin **ExoPlayer (Media3)**; Flutter displays **`Texture`** backed on Android by **`SurfaceProducer`**; manifest **disables Impeller** (**`<application>`** **`meta-data`**) so TV GPUs composite **decoder output** with **correct colors** — see **`06`**, **`07`** |

## What this app is not (current scope)

- **Not** a generic mobile phone–first layout (though sideload on phone is supported from an install perspective; UI remains TV-oriented).
- **M3U** as a playlist type may be stored and shown in UI flows; **full M3U parsing** and catalog browse from M3U are **out of scope** for the documented Xtream integration path.
- **iOS / desktop** players are stubs (`UnavailablePlayerService`) so the project analyzes without native video.

## Dependencies (pubspec)

Declared in `pubspec.yaml`:

- `http`, `url_launcher`, `shared_preferences`
- `flutter_lints` (dev)

Assets: `assets/images/` (brand logos, splash art); **`assets/fonts/DSEG7Classic-Regular.ttf`** (clock 7-segment face, SIL OFL — upstream [DSEG](https://github.com/keshikan/DSEG)). Android launcher/TV banner use **`drawable-nodpi/`** (**`app_icon.jpg`**, **`branding_logo.png`**, **`tv_banner_logo.png`**, etc.) — see [07-android-build-and-branding.md](07-android-build-and-branding.md).

## Entry point

- `lib/main.dart` — `WidgetsFlutterBinding`, immersive system UI, `libraryController.initialize()`, persisted stores (**`teamVisualStore.ensureLoaded()`**, **`LiveFavoriteGroupsStore.instance.ensureLoaded()`**, **`clockOverlaySettingsStore.ensureLoaded()`**, **`liveTvHeroLayoutStore.ensureLoaded()`**, card styles, groups, etc.), `runApp(IptvilApp)`.
- `lib/app.dart` — `MaterialApp` with base **`AppTheme.themeForPalette(TeamPalette.cyan)`**, `home: SplashScreen`, **`builder`:** **`ListenableBuilder(teamVisualStore)`** applies **`Theme(AppTheme.themeForPalette(…))`** then **`Stack`** with **`ClockOverlayLayer`** so the clock and team palette apply on every route without recreating **`MaterialApp`**.
