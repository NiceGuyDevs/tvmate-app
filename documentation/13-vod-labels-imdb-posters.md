# VOD: labels, My List, appearance, IMDb, and all related options

This document is the **full reference** for Movies / Series **watch labels**, **My List** behavior, **Appearance** options that affect VOD UI, **IMDb** rating chips, **backup** fields, **player** auto-labeling, and **TV** focus patterns.

---

## 1. Quick glossary

| Term | Meaning |
|------|---------|
| **VOD label** | One of: none, **watching**, **continue watching**, **watched** (`MovieVodLabel`). |
| **My List** | User-curated favorites (`MyListStore`) — separate from VOD labels. |
| **Team / palette** | Visual theme: Cosmic, Aurora, Solar, Heritage — drives `TeamPalette` and IMDb chip colors. |

---

## 2. Settings → Appearance (options that affect Movies / Series)

All of these are on **Settings → Appearance** (`EditSettingsScreen` / `appearance_panel_chrome.dart` pattern). Values are persisted and included in **backup** (see `09-backup-system.md`).

| Option | Store / key | Valid range / values |
|--------|-------------|----------------------|
| **Movies · posters per row** | `MovieRailPageSizeStore` — `iptvil_movie_rail_page_size_v1` | **4–12** (default **6**) |
| **Series · posters per row** | `SeriesRailPageSizeStore` — `iptvil_series_rail_page_size_v1` | **4–12** (default **6**) |
| **Movie card style** | `iptvil_movie_card_style_v1` | **Poster + Title** · **Poster only** · **Title only** (`MediaPosterCardStyle`) |
| **Series card style** | `iptvil_series_card_style_v1` | Same three modes |

The same **movies per row** and **movie card style** values are editable from **Settings → Appearance → Movies** (full-screen **`MediaRailEditScreen`** with the **Movie Grid Settings** card in **`movie_grid_settings_panel.dart`**) — including **Hide/Show** to preview the browse screen without the panel. See **`05-ui-shell-and-tv-patterns.md`** (*Movies · Appearance — Movie Grid Settings card*).

**Card style behavior:**

- **Poster + Title** — Art with gradient + title (and meta) overlay.
- **Poster only** — Image-focused tile; VOD badges and IMDb chip still apply where implemented.
- **Title only** — Text-only tile; no poster image (no IMDb overlay on art).

Live TV options on the same Appearance page (hero height, grid columns, channel card style, name vertical step) are documented in **`05-ui-shell-and-tv-patterns.md`** and **`09-backup-system.md`**.

---

## 3. Settings → Theme (visual team)

Prefs key: **`iptvil_visual_team_v1`**. Enum **`AppVisualTeam`** (`lib/data/team_visual_store.dart`).

| UI name | Storage string | `TeamPalette` |
|---------|----------------|---------------|
| **Cosmic** | `cyan` (default) | `TeamPalette.cyan` |
| **Aurora** | `violet` | `TeamPalette.violet` |
| **Solar** | `solar` | `TeamPalette.solar` |
| **Heritage** | `heritage` | `TeamPalette.heritage` |

Backup JSON field **`visualTeam`** uses the same storage strings (e.g. **`visualTeam`: `"cyan"`**).

**`TeamPalette`** drives most browse chrome; **`VodImdbRatingBadge`** is **not** team-tinted — it uses a **gold star**, **white** score, and a **soft blurred translucent black** scrim behind the glyph (no hard chip border) for legibility on any poster.

---

## 4. Browse: Movies & Series screens

### 4.1 Category chips

- **All** — deduped titles across categories.
- **My List** — see §5.
- **Per-playlist categories** — Xtream category ids; **group visibility** can hide categories (`PlaylistGroupVisibilityStore`, see `04-data-playlists-and-xtream.md`).

### 4.2 Shell search (unified VOD)

When the user searches from the shell, **Movies** or **Series** tabs can show a **mixed** movie + series rail (`VodUnifiedEntry`, `vod_unified_poster_strip.dart`). Hero and focus behavior switch between **`MockMovie`** and **`MockSeries`** (`_vodUnifiedHeroIsSeries` / `_vodUnifiedHeroIsMovie`).

### 4.3 Hero panel

- Large **backdrop** on the right (~58% width), **metadata** on the left (`MovieBrowseHeroCard` / `SeriesBrowseHeroCard`).
- **IMDb** rating: top-right overlay (`VodImdbRatingBadge`, `heroMeta` size) — see §10.
- Meta line under title: year · duration · genre (movies) or year · genre · seasons (series) — **rating is not duplicated** in that row when the IMDb chip is shown.

---

## 5. My List category and filter pills

On the **My List** chip (second category chip, index 1):

| Pill | Movies rail | Series rail |
|------|-------------|-------------|
| **All** | Only ids in **`MyListStore.movieIds`** | Only **`MyListStore.seriesIds`** |
| **Watched** | **All** catalog movies with **`MovieVodLabel.watched`** | **All** series with **`SeriesVodLabelStore`** watched |
| **Continue watching** | **All** movies with **continueWatching** | **All** series with **continueWatching** |

**Important:** **Watched** / **Continue** are **not** intersected with My List favorites — they show **every** titled item in the loaded catalog that has that label. **All** remains **favorites-only**.

**TV:** Pills use **`TvFocusable`** + dedicated **`FocusNode`s** so D-pad works: **Down** from category row → pills → **Down** to rail; **Left/Right** between pills; **Up** from rail back to pills.

---

## 6. Detail screens — every action

### 6.1 Movie details (`movie_details_screen.dart`)

| Action | Behavior |
|--------|----------|
| **Play** | Opens **`openIptvilPlayer`** with `resumeContentId` `movie_<id>`, `browseRestoreMovieId` = movie id. |
| **External** | Launches stream URL in external app. |
| **Trailer** | In-app YouTube search. |
| **My List** / **Remove** | **`MyListStore.toggleMovie`**. |
| **Watching** / off | **`MovieVodLabelStore.toggleWatching`**. |
| **Continue watching** / off | **`MovieVodLabelStore.toggleContinueWatching`**. |
| **Watched** / **Unwatch** | **`MovieWatchedStore.toggle`** — delegates to **`MovieVodLabelStore`** (`MovieVodLabel.watched` / none). |

**Backdrop:** Large right-side art; **VOD** stamps (watching / continue / watched) bottom-right area; **IMDb** top-right (`VodImdbRatingBadge` **detail** size) when `movie.rating` is non-empty.

### 6.2 Series details (`series_details_screen.dart`)

| Action | Behavior |
|--------|----------|
| **Play** | Plays first episode (if any). |
| **External** | First episode stream in external player. |
| **Trailer** | YouTube search for series title. |
| **My List** / **Remove** | **`MyListStore.toggleSeries`**. |
| **Watching** / off | **`SeriesVodLabelStore.toggleWatching`**. |
| **Continue** / off | **`SeriesVodLabelStore.toggleContinueWatching`**. |
| **Watched** / **Unwatch** | **`SeriesVodLabelStore.setLabel`** watched / none. |

**Episodes:** Each episode tile can show **episode-level** VOD badge from **`EpisodeVodLabelStore`** (see §8). Episode playback uses `resumeContentId` **`episode_<episodeId>`** and **`browseRestoreSeriesId`** (passed as **`browseSeriesId`** in **`PlayerScreen`**).

---

## 7. Data stores (reference)

| Store | Scope | SharedPreferences key | Notes |
|--------|--------|-------------------------|--------|
| **`MovieVodLabelStore`** | Movie id | `movie_vod_labels_v1` | Enum `MovieVodLabel`; legacy migration from `movie_watched_ids` into **watched**. |
| **`SeriesVodLabelStore`** | Series id | `series_vod_labels_v1` | Same enum. |
| **`EpisodeVodLabelStore`** | Episode id | `episode_vod_labels_v1` | Per-episode labels on series detail tiles. |
| **`MovieWatchedStore`** | Movie id (API) | Delegates to **`MovieVodLabelStore`** | `movieIds` = ids with **watched** label; toggle updates VOD store. |
| **`MyListStore`** | movie / series / live ids | `my_list_movie_ids`, `my_list_series_ids`, `my_list_live_channel_ids` | Favorites only. |

---

## 8. Player auto-labeling (`player_screen.dart`)

Method: **`_applyAutoVodMovieLabelIfNeeded`** (runs on player teardown after saving resume).

**Rules** (non-live VOD only):

- Duration must be known (**> 0**).
- Let **`pos`** = current position (ms), **`dur`** = duration.
- **End threshold:** **≥ 92%** of duration → **watched** (and clear resume when applicable).
- **Continue:** **≥ 3 s** and **&lt; 92%** → **continue watching**.

**IDs:**

| Content | `browseMovieId` | `browseSeriesId` | `resumeContentId` |
|---------|-----------------|------------------|-------------------|
| Movie | Set | null | `movie_<id>` |
| Series episode | null | Set | `episode_<episodeId>` |

For **episodes**, both **`EpisodeVodLabelStore`** (episode id) and **`SeriesVodLabelStore`** (series id) are updated. Resume clear: episode completion clears **`episode_...`** resume key; series-only path clears resume when no episode id in key.

Full player behavior: **`06-playback-and-native-player.md`**.

---

## 9. Posters: VOD badges and layout

| Element | Placement | Widgets |
|---------|-----------|---------|
| **VOD state** | **Bottom-left** | `MovieWatchedCornerBadge`, `MovieContinueWatchingCornerBadge`, `MovieWatchingCornerBadge` (`movie_watched_badge.dart`). |
| **IMDb** | **Top-right** | `VodImdbRatingBadge` — sizes: **`poster`** (rails), **`heroMeta`** (browse hero), **`detail`** (detail backdrop). |

**Rails:** `movie_poster_rail.dart`, `series_poster_rail.dart`, and inline **`_MoviePosterTile`** in **`movies_screen.dart`**. **`IgnorePointer`** on IMDb so focus stays on **`TvFocusable`** posters.

**Xtream rating field:** Mapped in **`xtream_mapper.dart`** from `rating`, `rating_5based`, `imdb_rating`, `rating_imdb`, etc. Empty → no IMDb chip.

---

## 10. IMDb badge widget (`vod_imdb_rating_badge.dart`)

- **`VodImdbRatingBadgeSize.poster`** — Rail posters.
- **`VodImdbRatingBadgeSize.heroMeta`** — Browse hero top-right.
- **`VodImdbRatingBadgeSize.detail`** — Detail screen backdrop.

Styling: **star + number** only (no **“IMDb”** prefix on the row). **Gold** star (`Icons.star_rounded`), **white** bold rating text, light **text shadow**. Behind both: a **blurred** semi-transparent **black** layer ( **`ImageFilter.blur`** ) so the readout reads as a soft **drop shadow / scrim**, not a rounded chip with an accent border.

---

## 11. Backup JSON fields (`IptvilBackupService`)

Every export includes **all** non-none VOD labels. **`MovieVodLabel`** index: **0** = none (not stored), **1** = watching, **2** = continue watching, **3** = watched.

| JSON key | Contents |
|----------|----------|
| **`vodMovieLabels`** | `{ "movieId": 1 \| 2 \| 3 }` — full movie VOD state |
| **`vodSeriesLabels`** | `{ "seriesId": 1 \| 2 \| 3 }` |
| **`vodEpisodeLabels`** | `{ "episodeId": 1 \| 2 \| 3 }` |
| **`watchedMovieIds`** | `string[]` — ids with **watched** only; redundant with `vodMovieLabels` but kept for older importers |
| **`myList`** | `{ movieIds, seriesIds, liveChannelIds }` (favorites; separate from VOD labels) |

**Restore:** If **`vodMovieLabels`** is present → full replace. If missing → legacy **`watchedMovieIds`** list only, or empty map if neither key exists. **Series** and **episode** maps: if the key is missing → replaced with **empty** (so restored device does not keep stale labels). Other settings (Appearance, team, etc.): **`09-backup-system.md`**.

---

## 12. Related documentation

| Document | Topics |
|----------|--------|
| **`05-ui-shell-and-tv-patterns.md`** | Shell, TV focus, Live TV hero. |
| **`06-playback-and-native-player.md`** | `openIptvilPlayer`, VOD overlay, resume. |
| **`09-backup-system.md`** | Full backup inventory. |
| **`11-feature-showcase.md`** | Product-level feature list. |
| **`08-feature-history-and-decisions.md`** | Engineering history. |

---

## 13. Source file index

| Area | Files |
|------|--------|
| VOD stores | `lib/data/movie_vod_label_store.dart`, `series_vod_label_store.dart`, `episode_vod_label_store.dart`, `movie_watched_store.dart`, `my_list_store.dart` |
| Appearance | `lib/data/media_card_style_store.dart`, `movie_rail_page_size_store.dart`, `series_rail_page_size_store.dart`, `team_visual_store.dart` |
| Player | `lib/player/player_screen.dart`, `lib/player/player_navigation.dart` |
| Backup | `lib/data/backup/iptvil_backup_service.dart` |
| UI | `movies_screen.dart`, `series_screen.dart`, `movie_poster_rail.dart`, `series_poster_rail.dart`, `movie_details_screen.dart`, `series_details_screen.dart`, `movie_browse_hero_card.dart`, `series_browse_hero_card.dart`, `vod_imdb_rating_badge.dart`, `movie_watched_badge.dart` |
| Xtream mapping | `lib/xtream/xtream_mapper.dart` |
| Theme | `lib/theme/team_palette.dart`, `team_palette_theme.dart` |
