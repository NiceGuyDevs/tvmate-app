# UI: shell, TV patterns, and major screens

## Main shell

**File:** `lib/shell/main_shell_screen.dart`

- **Layout:** Full-screen **`Stack`**: **`CosmicSpaceBackdrop`** (palette-aware animated gradient) under a **`Column`** — **`AppTopBar`** (shell destinations) then **expanded** browse content. **`Scaffold.backgroundColor`** is **transparent** so the backdrop shows through.
- **Focus traversal:** `FocusTraversalOrder` — main content **`NumericFocusOrder(0)`**, top bar **`NumericFocusOrder(1)`** so D-pad flow can move between the bar and the active screen predictably.
- **Destinations:** `ShellDestination` — **Live TV** (default), **Movies**, **Series**, **Recording**, **Theme**, **Settings** (`shell_destination.dart` + `app_top_bar.dart`). Labels: **Theme** for Cosmic / Aurora / Solar / Heritage (**`TeamScreen`**).
- **Back behavior:** First Back from a root browse screen **opens** the top-nav “menu” mode and focuses the **current tab** in **`AppTopBar`** unless **`ShellBackCoordinator`** consumes Back (e.g. in-screen escalation). While **`_menuOpenedFromBack`** is true, the coordinator is **not** invoked; **two** further Back presses **exit** (**`await LivePreviewChannel.dispose()`** then **`SystemNavigator.pop()`**). **Known visual bug (some devices):** brief **chrome seam / flash** at nav edges during transitions may still appear (see **`CHANGELOG.md`**).

## Recording

**Files:** `lib/ui/recording/recording_screen.dart`, `lib/data/recording_approval_store.dart`, `lib/ui/settings/recording_*_approval_screen.dart`

- **Backdrop:** Same as other shell browse tabs — **no opaque fill** on the screen body (**`Colors.transparent`**) so **`CosmicSpaceBackdrop`** from **`MainShellScreen`** stays visible.
- **Layout:** **`LayoutBuilder`** horizontal padding (**minimum 16px**, **~3.5% of width per side**) for TV-safe margins; the **date** column is **20% of the content row** (not full screen width).
- **Focus:** Shared **`_kRecordingFocusScale`** (**~1.011**) and **`_kRecordingParallaxSlide`** (**~0.002**) on all **`TvFocusable`** regions in Recording (categories, dates, grid, EPG ribbon, programme rows), plus **`focusedBorderWidth: ~1.4`**, to limit focus “pop” vs default **`AppTheme.focusScale`** — reduces edge clipping on real TVs.
- **EPG rows:** Optional **TV frame** bezel (`assets/images/recording_tv_frame.png`) behind channel logos when **`tvFrameEpg`** is enabled per playlist in **Settings → Recording → Categories**. Full spec: **[`10-recording-epg-system.md`](10-recording-epg-system.md)**.

## Top navigation bar

**File:** `lib/shell/app_top_bar.dart`

- Horizontal strip of **`ShellDestination`** entries with `TvFocusable`-style focus and icons/labels for TV.
- **`MainShellScreen`** holds a **`FocusNode` per destination** for predictable focus when Back opens the bar.
- **Playlist quick-switcher:** An extra **`TvFocusable`** item (**`Icons.playlist_play_rounded`** + "Playlist") is appended after the destinations. It opens a **popup overlay** anchored below the button listing all playlists from `libraryController.playlists`. The active playlist shows a filled **check circle**; selecting a different one calls `setActivePlaylist` + `syncFromLibrary` and navigates to **Live TV**. When no playlists exist, a "Go to Settings" shortcut is shown. The playlist button is **not** a `ShellDestination` — it has no content screen and does not participate in Back/menu logic.

## Splash

**File:** `lib/ui/splash/splash_screen.dart`

- Full **black** background.
- Large **logo** (same asset family as brand), subtle **opacity + scale** animation.
- **Spinner** + “Loading…” below the logo (single coherent screen, no separate “second stage” glow card).

## TvFocusable

**File:** `lib/ui/focus/tv_focusable.dart`

Central primitive for TV:

- Focus ring uses **`context.teamPalette`** (accent + nebula blend + **`railCardFocusShadow`** when elevation is on); slight **scale** on focus (`AppTheme.focusScale`), optional **parallax** slide, optional **elevation** shadow (`showFocusElevation`).
- **`canRequestFocus`** — when **false**, the widget cannot take focus (e.g. **Live TV** category pills during ~420 ms after closing the fullscreen player so focus stays on the channel tile).
- **`focusedBorderWidth`** — thickness of the accent border when focused (default **2.2**); use **~1.4** on **dense lists** (e.g. category toggles) so the ring stays visually inside the row.
- For **full-width list rows** that must not **grow or clip** at screen edges: set **`focusScale: 1.0`**, **`parallaxSlide: 0`**, **`showFocusElevation: false`** (see **`PlaylistGroupSectionScreen`**).
- **`scheduleSteadyChannelTileFocus`** (same file) — **re-`requestFocus`** on a channel tile across several frames and short delays after a route pop (TV stacks sometimes assign focus elsewhere first).
- `onActivate` for center / enter.
- `onKeyIntercept` for custom arrow / back behavior on dense grids.

## Theme (visual team)

**Files:** `lib/ui/team/team_screen.dart`, `lib/data/team_visual_store.dart`, `lib/theme/team_palette.dart`

- Shell tab **Theme** — choose **Cosmic** (cyan nebula), **Aurora** (violet / purple–pink), **Solar** (yellow / gold neon), or **Heritage** (classic gold, wine, midnight). Persists via **`TeamVisualStore`**; **`IptvilApp`** rebuilds **`Theme`** from **`AppTheme.themeForPalette`** so accents, backdrop, and chrome update app-wide without replacing **`MaterialApp`**. After **`setTeam`**, **`ShellNavigationHub.instance.goTo(ShellDestination.liveTv)`** returns the user to **Live TV** so the theme choice does not leave them on the Theme tab.

## Live TV

**Files:** `lib/ui/live_tv/live_tv_screen.dart`, **`hero_live_preview.dart`** (optional **`bottomInsideScreen`** timeline inside bezel), **`hero_epg_script.dart`** (**`isHebrewDominantEpg`**), **`live_tv_hero_panel.dart`**, **`live_preview_channel.dart`**, `mock_live_tv_data.dart`, `live_tv_favorites_screen.dart`, `live_favorite_picker_screen.dart`

- **Category pills:** **user-defined favorite groups** (from **`LiveFavoriteGroupsStore`**, sorted) appear **first by default**. Categories the user pinned **before favorites** in **Manage groups → TV** (ordered list **`liveBeforeFavorites`** in **`PlaylistGroupVisibilityStore`**) render **before** those favorite pills, left-to-right. **Then** the remaining playlist live categories (still filtered by visibility / hidden rules) follow. Demo mocks use the same store pattern where applicable. **Favorite-only** mode: if every playlist category is hidden, pills can still show **only** favorites. Switching category refreshes the grid and hero when applicable.
- **Hero:** **Design height** **232** logical px; **30–100%** height (**Settings → Edit → Live TV**); **intrinsic** **16:9** preview (**no** non-uniform **`FittedBox`**). **Symmetric** inner padding (**~7** vertical, **14** horizontal). **Timeline** (start · **Ends in …** · end + red **progress**) **inside** the TV **screen** (**`HeroLivePreview.bottomInsideScreen`**). **No** separate **“Broadcasting now” / “Up next”** label row — title carries **“Up next: …”** when off-air. **Row** forced **LTR**: **TV → EPG → logo + channel name** (always **trailing**). **EPG** hugs the logo (**`CrossAxisAlignment.end`** + **`TextAlign.right`** for English; **`isHebrewDominantEpg`** → **`Directionality.rtl`** + **`CrossAxisAlignment.start`** / **`TextAlign.start`**). **Logo** column: fixed **height** + **`Expanded`** name. **`HeroLivePreview`**: native preview + debounced load.
- **Preview audio (Android):** second ExoPlayer runs **unmuted** under the focused channel; **`openIptvilPlayer`** calls **`LivePreviewChannel.pauseForFullscreen`** before fullscreen play and **`resumeAfterFullscreen`** when the route pops so two streams never compete.
- **EPG data:** when not in demo mode, hero and player listen to **`LiveEpgController`**; **`refreshForStream`** runs on channel focus / lineup change with **`epgChannelId`** from **`MockLiveChannel`**. **Read paths** use **`lookupDisplay` / `lookupListings` / `isLoadingFor`** so hero, grid tiles, and fullscreen player stay correct when global “focused” EPG id differs (see **`06-playback-and-native-player.md`**).
- **Grid & lifecycle:** **`LiveChannelBrowseTile`** (`live_tv_channel_browse_tile.dart`) — **`TvFocusable`** with **`parallaxSlide: 0`**, **`focusScale: 1.0`** (no grow past cell — avoids clipping/overlap with category chips), **`ClipRRect`** **`Clip.hardEdge`** around the card. **Logo + text** card style: **`TvCatalogImage`** **`BoxFit.contain`** so channel art is not cropped at the sides; when Xtream EPG is cached for that channel id, a **one-line programme title** appears above the channel name (**`LiveEpgController.lookupDisplay`**). Per-tile **`FocusNode`** + **`GlobalKey`** for scroll + refocus after **`PlayerScreen`** pops; **`openIptvilPlayer`** uses **`suppressPreviousFocusRestore: true`** and **`PlayerBrowseRestore.liveChannelId`**; category pills **`canRequestFocus: false`** briefly during restore. Tile activate opens the player with **full category lineup** (`LiveLineupItem` includes **`epgChannelId`**). Leaving Live TV disposes the preview channel on the Dart side.

### Live TV — D-pad focus ladder (canonical)

**This order is intentional.** Do not change **`NumericFocusOrder`** or custom handlers without re-reading this section; wrong ordering causes **skipping the subcategory row** or **needing to long-press** the D-pad.

**Vertical ladder (bottom → top on screen):**

| Step | Zone | Role |
|------|------|------|
| **1** | **Channel grid** | Default focus when entering Live TV; browse channels. |
| **2** | **Subcategory pills** | Playlist categories + user **favorite** groups (same strip). |
| **3** | **Hero** | Live preview + EPG; **Select** toggles preview audio. |
| **4** | **Top shell bar** | **`AppTopBar`** — Live TV tab, Movies, etc. |

**`OrderedTraversalPolicy` / `NumericFocusOrder` in `live_tv_screen.dart` (must match 1 → 2 → 3):**

- **Grid** = **`NumericFocusOrder(0)`** — lowest number = first in traversal (start on channels).
- **Pills** = **`NumericFocusOrder(1)`** — second.
- **Hero** = **`NumericFocusOrder(2)`** — third.

If hero were **1** and pills **2**, default traversal would go **grid → hero → pills** and **skip subcategory** — **wrong.**

**One short press** (no hold): use **`requestLadderFocus`** in **`tv_focusable.dart`** (immediate **`requestFocus`** + **`scheduleRequestFocusWhenReady`**) for ladder moves.

**Up arrow**

- From **first row** of the grid → **selected subcategory pill** (`_onGridItemKey`).
- From **other rows**, Up moves within the grid only (standard grid navigation).
- From **pills** → **hero** (`_onCategoryKey`).
- From **hero** → **Live TV** tab in the top bar (`LiveTvHeroAudioFocusShell`).

**Back (system)**

- From **any channel tile** → **selected subcategory pill** (`ShellBackCoordinator` → `_tryConsumeShellBack`).
- From **pill** → **hero**.
- From **hero** → **Live TV** tab.
- From **top bar tab** → shell handles (exit / menu mode per **`MainShellScreen`**).

**Down arrow**

- From **hero** → **selected pill**; from **pills** → **first channel tile** in the grid (when the grid has items).

**Shell / cold start:** **`MainShellScreen`** calls **`ShellContentFocusRegistry.request(ShellDestination.liveTv)`** after layout; **`LiveTvScreen`** also bootstraps focus when the real UI and grid nodes exist so D-pad works without switching tabs first. See **`live_tv_screen.dart`** (`_requestShellPrimaryFocus`, `_bootstrapShellFocusIfNeeded`, initState post-catalog callback).

## Favorite setup (Live TV)

**Files:** `live_tv_favorites_screen.dart`, **`live_favorite_group_editor_screen.dart`**, **`live_favorite_picker_screen.dart`**, **`lib/data/live_favorite_groups_store.dart`**

- **Settings → Favorite setup** — **New favorite** / compact **name pills** (`Wrap`); editor: name, order, **Choose channels** (ordered selection, optional order badges **1,2,3…**). Info **banner** at top (same pattern as other settings education strips).
- Editor **Choose channels** row and **channels in this favorite** use compact **pills** / list styling (not large poster cards).
- Picker reuses patterns from **`ShieldTvTextField`** / vertical focus chain on TV where applicable.

### Choose channels (`LiveFavoritePickerScreen`)

**File:** `lib/ui/live_tv/live_favorite_picker_screen.dart`

Fullscreen route from the favorite **editor**. Lets the user pick an **Xtream playlist** (if several), a **live category** (capsule pills), then **toggle channels** in a scrollable grid. Selection order defines favorite order (optional badges).

**Groups / categories**

- Category list comes from **`playlistLiveCatalogCache.categoriesFor(playlistId)`** — **all** live groups for that playlist, **not** filtered by **Manage groups** on/off. Favorites can include channels from hidden groups.

**Vertical layout (top → bottom, space-conscious)**

- **Back** + title **Choose channels** — compact padding and **`titleMedium`** so the **grid’s `Expanded`** keeps height on one or multiple playlists.
- Short **hint** (2 lines max, small type).
- **Playlist** row (when **>1** Xtream playlist): **~30px** tall strip; small **pills**. **OK** on a playlist focuses the **first category pill**; **Down** from a playlist pill also moves to the first category pill.
- **In this favorite** — horizontal strip of **ExcludeFocus** previews (**compact** **`LiveChannelBrowseTile`**); low fixed height so previews do not steal grid space.
- **Add more** + **category pills** — short strip (**~32px**).
- **`Expanded` + `GridView`** — main browse area. **Save / Cancel** sit **below** the grid (not above it).
- **All in category** / **Clear category** — **below** the grid and **above** Save so D-pad flow is: **playlist → categories → grid → bulk actions → Save**. (Putting bulk above the grid caused focus to hit Save before the grid.)

**Grid sizing & tiles**

- **`ScrollController`** on the grid; category change **`jumpTo(0)`** so switching pills resets scroll.
- Cell **`childAspectRatio`** is derived so tiles are **taller** than the old “wide and short” default: roughly **`~2` visible rows** of **6** columns are targeted, with **`clamp(0.68, 1.22)`** so **logo + label** are not clipped. Spacing **~6**; **`clipBehavior: Clip.none`** on the grid so focus rings are not chopped.
- Grid uses **`LiveChannelBrowseTile`** with **`compact: true`** (tighter padding, no EPG line in tile, single-line name) — same visual language as Live TV browse tiles, tuned for dense picker cells.

**Focus / traversal**

- Body wrapped in **`FocusTraversalGroup`(`OrderedTraversalPolicy`)** with **`NumericFocusOrder`** on major blocks (e.g. grid before bulk before Save).
- **Draft previews** are **`ExcludeFocus`** — D-pad stays in playlist / categories / grid / actions; users add/remove from the **grid** (toggle again to remove).

**Back**

- **`PopScope`**: Back from the grid / middle of the screen moves focus to **Save** first; Back again (or from Save/Cancel/Back header) **pops** the picker.

## Movies

**Files:** `lib/ui/movies/movies_screen.dart`, `movie_details_screen.dart`

- Category rails and paged rows; **no outer `ClipRect`** around the main browse column; category **`ListView`** may use **`clipBehavior: Clip.none`** where supported so poster **soft-focus** is less clipped (**`Row.clipBehavior`** omitted on SDKs without that API).
- **Trailer:** **`InAppYoutubeTrailerScreen`** — in-app search, then **`url_launcher`** to **`youtube.com/watch`** (external YouTube app). **`openIptvilPlayer`** calls **`onPlayerClosed` synchronously** for VOD **before** live-preview resume. **`_syncMovieBrowseToId`** updates hero/rail index when the player closes but **does not** focus poster tiles while details is on top.

### Full-bleed cinematic browse (Movies + Series screens)

**Files:** `lib/ui/movies/movies_screen.dart`, `lib/ui/series/series_screen.dart`, `lib/ui/movies/movie_browse_hero_card.dart`, `lib/ui/series/series_browse_hero_card.dart`

**Layout — full-screen backdrop covering the entire page:**

The browse screen uses a `Stack` at the page level. The movie/series backdrop image fills the **entire screen** behind all content (hero text, category pills, poster rail). No app background is visible.

**Layer stack (bottom → top):**

| # | Widget | Purpose |
|---|--------|---------|
| 1 | **`ValueListenableBuilder`** → **`AnimatedContainer`** | **Color-matched background** — uses `backdropPrimary` darkened 72% toward black via `Color.lerp`. Transitions smoothly when the focused movie changes. |
| 2 | **`AnimatedSwitcher`** — `ShaderMask` × 2 + `TvCatalogImage` | Backdrop with **`BoxFit.contain`** + **`Alignment.centerRight`** — shows the **full image** at natural aspect ratio, right-aligned, with slight top/bottom padding. Fades into the color-matched background from the left via horizontal `ShaderMask` (`BlendMode.dstIn`), subtle top/bottom vignette. Image crossfades on focus change. |
| 3 | **`Positioned.fill`** — `Padding` + `Column` | Content overlay: hero text info (top ~45%), category strip, poster rail (bottom ~55%) |

**Color-matched background:** Instead of a fixed dark color, the background is derived from the movie/series `backdropPrimary` color (already extracted from poster art), darkened heavily. This makes the image blend seamlessly into the background — the whole screen looks like one unified visual, not "a picture on a black background."

**Sync fix:** The backdrop layer is inside a `ValueListenableBuilder` tracking `_heroMovie` / `_heroSeries`, so the image and background color always match the focused item in the poster rail.

**Hero text (text-only overlay, left ~46% width):**

The `MovieBrowseHeroCard` / `SeriesBrowseHeroCard` widgets render **only text** — no image, no background box. The backdrop is behind them at the page level.

1. **Title** — up to 2 lines, 32pt bold with drop shadow
2. **Rating badge** (blue pill) + year · duration/genre · season count
3. **Cast line** — when available
4. **Director line** — when available
5. **Description** — max 5 lines with ellipsis

Text has drop shadows for readability over the partially visible backdrop.

**Backdrop transitions:** `AnimatedSwitcher` with fade transitions so the full-screen image crossfades smoothly when navigating between movies/series.

**Series screen** (`series_screen.dart`) uses the identical full-bleed pattern, with `seriesBackdropUrl` instead of `movieBackdropUrl`.

### Movie detail screen (`MovieDetailsScreen`)

**File:** `lib/ui/movies/movie_details_screen.dart`

**Layout — cinematic split (text left, backdrop right):**

The screen uses a full-screen **`Stack`** with no `CosmicSpaceBackdrop`. Instead, the movie's own backdrop image serves as the visual background.

**Layer stack (bottom → top):**

| # | Widget | Purpose |
|---|--------|---------|
| 1 | **`ColoredBox`** `0xFF0A0E1A` | Solid dark base — no cosmic/app background visible |
| 2 | **`Positioned`** right-aligned, **65% width** | Backdrop image via `TvCatalogImage` + `catalogBackdropHiResUrl` |
| 3 | **`ShaderMask`** (horizontal, left-to-right) on the image | Fades image pixels to **transparent** on the left ~30% — no hard cutoff line |
| 4 | **`ShaderMask`** (vertical, top+bottom) on the image | Subtle top/bottom edge fade for polish |
| 5 | **`Positioned`** left side, **52% width** | All text content + action buttons |

**Image blending (no visible seam):**

The backdrop image is wrapped in **two nested `ShaderMask`** widgets with **`BlendMode.dstIn`**:
- **Horizontal mask:** Image fades from fully transparent on the far left to fully opaque around the 45% mark. This eliminates the hard edge where the image meets the dark background — the transition is pixel-level smooth.
- **Vertical mask:** Subtle fade at top and bottom edges.

The image is positioned at **right: 0** with **`BoxFit.cover`** and **`Alignment(0.15, -0.05)`** so it naturally fills the right side without stretching.

**Text content (left column, top to bottom):**

1. **Back button** — `DetailIconBack` (circular, top-left)
2. **Title** — up to 2 lines, 36pt bold
3. **Metadata row** — blue **rating badge** (when available from Xtream) + year · duration · genre
4. **Cast line** — "Cast:" label + names (when available)
5. **Director line** — "Director:" label + names (when available)
6. **Description** — scrollable `SingleChildScrollView` with bottom `ShaderMask` fade-out
7. **Action buttons** — `DetailCompactActionBar`: Play, External, Trailer, My list / Remove, Watched / Unwatch

**Data sources:** `MockMovie.cast`, `MockMovie.director`, `MockMovie.rating` come from the Xtream VOD API — same playlist data that other apps display. When these fields are `null` or empty, the lines are simply hidden.

**Back behavior:** **`PopScope(canPop: false)`** + **`onPopInvokedWithResult`** — system Back pops **only** when not in the **~480 ms** window after the **player** closes (avoids browse appearing when one remote press was meant to exit only the player).

## Series

**Files:** `lib/ui/series/series_screen.dart`, `series_details_screen.dart`

- Category rails similar to movies (same **clipping / focus** notes as Movies).
- Xtream: may load **`get_series_info`** when entering details to populate seasons/episodes.

### Series detail screen (`SeriesDetailsScreen`)

**File:** `lib/ui/series/series_details_screen.dart`

**Layout — same cinematic split as Movies (text left, backdrop right):**

Uses the identical visual treatment as `MovieDetailsScreen`: solid dark base (`0xFF0A0E1A`), backdrop image right-aligned at 65% width with dual `ShaderMask` (horizontal + vertical) fading, no `CosmicSpaceBackdrop`.

**Dynamic backdrop:** The image updates via `ValueListenableBuilder<SeriesDetailsHeroSnapshot>` — shows series art by default, switches to episode still/poster when an episode tile is focused.

**Two-zone layout:**

The screen is split into two vertical zones:

1. **Info zone** (top, constrained to left ~52% width) — over the dark gradient area:
   - **Back button** — `DetailIconBack` with custom key intercepts (Down → first episode)
   - **Title** — up to 2 lines, 36pt bold
   - **Metadata row** — blue **rating badge** (when available) + year · genre · season count
   - **Cast line** — when available from Xtream API
   - **Director line** — when available from Xtream API
   - **Description** — max 4 lines with ellipsis

2. **Episode zone** (below info, **full screen width** left-to-right) — scrollable:
   - Season/episode horizontal rails (`_SeasonEpisodesBlock`) — **7 tiles** visible per row
   - **Action buttons** at the bottom — Play, External, Trailer, My list / Remove

The episode rails are deliberately **not** constrained to the left column — they span the full width so 7 tiles fit comfortably, scrolling horizontally when more episodes exist.

**Episode tiles:** Poster uses **`seriesPosterUrl(series)`** (consistent art). **Caption:** `EpisodeSeasonCaptionBar` — **`MockEpisode.codename`** only (`S02E01`). **Focus ring:** `ListView` uses **`clipBehavior: Clip.none`** + vertical padding so the `TvFocusable` focus ring is fully visible on all four sides (not clipped at top/bottom).

**Data model:** `MockSeries` now includes optional `cast`, `director`, `rating` fields. The Xtream mapper (`xtream_mapper.dart`) populates these from the `get_series` and `get_series_info` API responses. The snapshot codec (`xtream_catalog_snapshot_codec.dart`) persists them.

**Back behavior:** Same **`PopScope`** / **~480 ms** swallow window as Movies.

## Detail actions

**File:** `lib/ui/widgets/detail_actions.dart`

Shared row of TV-friendly action chips used on movie/series detail screens.

## Settings area

**Files:** `settings_screen.dart`, `clock_settings_screen.dart`, `add_playlist_screen.dart`, `playlist_loading_screen.dart`, `my_playlists_screen.dart`, `playlist_epg_time_screen.dart`, `playlist_group_manager_screen.dart`, `backup_screen.dart`, `backup_import_screen.dart`, `backup_manage_screen.dart`, `shield_tv_text_field.dart`, `tv_remote_keys.dart`

- **Main grid:** `SettingsScreen` lists **compact icon tiles** (e.g. Add Playlist, My Playlists, Live/Movie/Series **card** styles, **Clock**, Backup, Demo mode). Sub-screens mirror this pattern where applicable.
- **Sub-screen autofocus:** Card style screens (**Channel cards**, **Movie cards**, **Series cards**) set **`autofocus: true`** on the **first option tile** (`index == 0`) so the user lands directly on the options grid, not on the back button. **Clock** autofocuses the **Clock ON/OFF** toggle. **Backup** autofocuses **Export personal**. This is a TV-critical pattern — without it, D-pad focus starts at the top-left back arrow and the user must scroll down before they can interact with the actual options.
- **Clock:** `ClockSettingsScreen` — toggle visibility, **frame** (digital-HUD: gradient + border + optional **date line** `DD/MM MON` — **`MON`–`SUN` uppercase**, **DSEG** for numerals + **Roboto** for weekday when neon/segment), 12/24h, size, corner, opacity presets, **eight color swatches** (last three **neon**). Runtime state + prefs: `clock_overlay_settings_store.dart`. Rendering: **`ClockOverlayLayer`** in `app.dart` (**`IgnorePointer`**).
- **Add Playlist:** Narrow **centered** layout (`maxWidth: 520`); **Xtream** / **M3U** as **two side-by-side icon tiles** — **focus defaults to Xtream** on open; after a type is chosen, focus moves to **Server URL** (Xtream) or **Name** (M3U). **`ShieldTvTextField`** uses explicit **`keyboardType`** (**`text`**, **`url`**) so Android TV shows the **IME** (do not use **`TextInputType.none`** on editable fields). **ScrollController** + **`resizeToAvoidBottomInset`** + **`viewInsets`** padding + **`Scrollable.ensureVisible`** + **`didChangeMetrics`** keep lower fields visible when the keyboard is up. **“Change type”** / **“Source type”** UI removed; switch Xtream ↔ M3U via **Back** and re-open **Add Playlist**. **Native:** Flutter’s **`TextInputPlugin`** needs a **new enough** **`androidx.core`** (see **`07-android-build-and-branding.md`** — **`EditorInfoCompat.setStylusHandwritingEnabled`**); an outdated forced Core version can crash **before** Dart layout matters.
- **ShieldTvTextField** (`shield_tv_text_field.dart`): TV **`TextField`** with D-pad Up/Down to adjacent fields via **`HardwareKeyboard`**; **`keyboardType`** is configurable (default **text**).
- **My Playlists:** **Grid** responsive (**3 columns** on wide TV, **2** or **1** on smaller widths); compact per-tile actions (**Groups**, **EPG** opens **`PlaylistEpgTimeScreen`** — **Local** + zones, centered ~**640** px like Manage groups category list, **Use**, **Rename**, **Delete**).
- **Manage groups:** Section summary (TV / Movies / Shows) as **icon grid**. **`PlaylistGroupSectionScreen`** (per-section category list): **centered** content **`maxWidth: ~640`**, **Show all / Hide all** chips, **dense** toggle rows; list **`TvFocusable`** rows use **no scale/parallax/elevation** and **inset horizontal padding** so focus rings do not clip off-screen; row text has extra **left inset** so labels sit slightly inward from the bezel. **TV only:** each row has a **pill-order** control (**move-up** icon) to place that category **after** or **before** favorite-group pills and set **position** among “before” categories — see **`04-data-playlists-and-xtream.md`** (**Playlist group visibility**).
- **Backup:** `BackupScreen` — **3-column grid**: Export personal, Export to share, Share latest, Import, Delete. Export requests storage permission via **`BackupStorageChannel.kt`** platform channel, saves to **public** `Download/IPTVIL/`. Import and Delete use **`discoverAllBackupFiles()`** (recursive scan of entire `Download/` tree). **No `SnackBarAction`** on any backup SnackBar (Material 3 makes them indefinite). Full details in **[`09-backup-system.md`](09-backup-system.md)**.
- Add/rename/delete playlists, toggle demo mode, Xtream validation + loading animation; remote key helpers include **up/down** and **left/right** for horizontal focus moves.

### Appearance — Live TV, Movies, Series

**Hub:** `edit_settings_screen.dart` — **Live TV**, **Movies**, **Series** open full-screen editors over a **live preview** of the corresponding browse screen.

| Screen | File(s) | Preview | Controls (persisted stores) |
|--------|---------|---------|------------------------------|
| **Live TV · Appearance** | `live_tv_edit_screen.dart`, `appearance_panel_chrome.dart`, `channel_grid_settings_panel.dart`, `channel_grid_reference_layout.dart`, **`vod_brushed_panel_fill.dart`** | `LiveTvScreen(previewMode: true)` under overlay | **Channel Grid Settings** card (right, **Hide/Show**): same **brushed shell + inset blocks** family as movie grid (**`VodBrushedPanelFill`**, `channelGridInsetDecoration`). **Hero** height (`liveTvHeroLayoutStore`), **Channels** per row (`liveTvGridColumnsStore`), **Tiles** — **2×2 grid** for card display (**D-pad** = move **focus ring** only; **OK** = commit `liveTvCardStyleStore`), **Name** row for global name nudge (`liveTvNameVerticalBiasStore` / horizontal). Full spec: **[`14-live-tv-appearance-channel-grid.md`](14-live-tv-appearance-channel-grid.md)**. |
| **Movies · Appearance** | `media_rail_edit_screen.dart`, `movie_grid_settings_panel.dart` | `MoviesScreen(previewMode: true)` | **Movie Grid Settings** card — **posters per row** (`movieRailPageSizeStore`), **poster display** (`mediaCardStyleStore`), **Hide/Show** clean preview. Details below. |
| **Series · Appearance** | `media_rail_edit_screen.dart`, `movie_grid_settings_panel.dart` | `SeriesScreen(previewMode: true)` | Same **Series Grid Settings** card as **Movies** (**`MovieGridSettingsPanel` / `MovieGridSettingsPanelHost`** with **`MediaGridPanelTarget.series`**): **posters per row** (`seriesRailPageSizeStore`), **poster display** (`mediaCardStyleStore.setSeriesStyle`), **Hide/Show**, **Exit**, **Reset** (defaults: **poster + title + year**). Positioned like Movies (**left ~2%**, **top ~10%**). |

#### Live TV · Appearance — Channel Grid Settings (reference)

- **Canonical spec:** **[`14-live-tv-appearance-channel-grid.md`](14-live-tv-appearance-channel-grid.md)** — rail indices, 2×2 **focus vs committed** style, **Hide/Show** positioning (no full-height focus strip when collapsed), cold-start pointer, **visual design** (shared chrome with movie grid).
- **UI:** **`VodBrushedPanelFill`** + accent frame + inset sections; gold sliders; **neon** ring on the **focused** 2×2 cell; **gold** border/fill + **check** on the **saved** style (may differ until **OK**). Footer uses the same **inset strip** pattern as **`MovieGridSettingsPanel`**.

#### Movies · Appearance — Movie Grid Settings card

- **Files:** **`media_rail_edit_screen.dart`** — route shell for **both** Movies and Series; `LayoutBuilder` + `Stack`, **`ExcludeFocus`** on the preview, **`ColoredBox(shell.canvas)`** under **`playerSettingsRouteBackdrop`**, **`MovieGridSettingsPanelHost`**. **`movie_grid_settings_panel.dart`** — **`MovieGridSettingsPanel`**, **`MovieGridSettingsPanelHost`**, **`MediaGridPanelTarget`** (**movies** vs **series**): same brushed card for **Series · Appearance** with **`seriesRailPageSizeStore`** + **`setSeriesStyle`**, localized **Series Grid Settings** title / **Series Per Row** label.
- **Stores:** **`movieRailPageSizeStore`** or **`seriesRailPageSizeStore`** (slider / ◀▶), **`mediaCardStyleStore.setMovieStyle`** / **`setSeriesStyle`** (poster-only · name+poster · poster+title chips), reset + exit actions.
- **Hide / Show:** **`Hide`** (top-right of the card) collapses the entire settings card; only a prominent **`Show`** chip remains so the browse preview is unobstructed. **`Show`** restores the same card (no change to saved values). Strings: **`movieGridHidePanel`**, **`movieGridShowPanel`** (l10n).
- **Layout & scale:** Card design width **`min(460, 44% of screen width)`**; presentation is scaled with **`FittedBox`** to **65%** of that width from the **top-left** anchor (position **`left: 2%`**, **`top: 10%`** of the route). **`Positioned`** widgets are **direct children** of the route **`Stack`** (valid **`StackParentData`**).
- **Look:** **`VodBrushedPanelFill`** + **1px** **`Color.alphaBlend(accent × 0.28, white × 0.22)`** border overlay; **inset** blocks (**`#1A1A2E`-style** fill via `_movieGridInsetDecoration()`). Focus rings on interactive controls remain **team neon** where applicable; section titles use tracked small caps-style labels. Hub card styles for movies are still edited on **Settings → Appearance** alongside layout shortcuts.
- **Focus:** **`FocusTraversalGroup`** + **`OrderedTraversalPolicy`** with **`NumericFocusOrder`** on controls so D-pad order stays inside the card.

**Backup:** All of the above stores are already serialized in **`IptvilBackupService`** (`liveTvCardStyle`, `liveTvNameVerticalStep`, `heroHeightPercent`, `liveTvGridColumns`, `movieRailPageSize`, `seriesRailPageSize`). See **[`09-backup-system.md`](09-backup-system.md)** — *Appearance editors*.

## Catalog images

**File:** `lib/ui/widgets/tv_catalog_image.dart`

**`TvCatalogImage`:** network image + **`TvImageShimmer`** while loading; empty URL or **error** → **`TvUniversalMediaPlaceholder`** (gradient from **`context.teamPalette`** + **`Icons.live_tv_rounded`**). Used on **Live** tiles, hero logo, **Movies/Series** details, trailer rows, etc.

**`tv_media_urls.dart`:** **`catalogArtUrlLooksLoadable`** gates URLs; missing channel **icon** / **cover** / **backdrop** / episode **still** → **`''`** so the universal placeholder appears (no per-item remote fallback).
