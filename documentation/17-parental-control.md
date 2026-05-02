# Parental control

## Purpose

Let parents set a **numeric PIN (4–8 digits)** and define **what requires the PIN before playback**: entire Live TV / Movies / Series, specific channels, categories, favorite groups, movies, or series. **Hide from browse** (Live TV only) is **per scope**, not a single global toggle — you choose it when locking a channel, category, or favorite group.

Settings and block lists (including browse-hide sets) are included in **full settings backup** under the JSON key **`parentalControl`**.

## User flows

### First-time setup

1. **Settings → Parental control**
2. Read the **warning** (PIN cannot be recovered from the app).
3. Enter **New PIN** and **Confirm PIN** (digits only, 4–8 characters). PIN entry uses a **compact dialog** with an **inline numpad** (no full-screen settings takeover).
4. Tap **Save PIN** — PIN is stored as **salt + SHA-256 hash** (never plain text).
5. **Parental control** turns **on** automatically after a successful save.

The same **compact PIN + numpad** pattern is used from the **live player side menu** when no PIN exists yet (**create PIN**). If a PIN already exists, the app asks for **verification** only.

### Settings hub (after PIN exists)

Layout is a **compact hub** (main actions + utilities), not a long list of unrelated tiles.

- **Parental control on** — master switch (turning **off** asks for PIN).
- **Lock all Live TV / Movies / Series** — any playback in that area requires PIN.
- **Restricted rules** (or equivalent entry) — lists active locks; rows show **resolved names** (channel, category, movie, series titles where the catalog provides them), not raw ids only.
- **How it works** — short in-app help text.
- **Change PIN** — verify current PIN, then enter new PIN twice (same numpad UX).
- **Clear parental** — verify PIN, then removes PIN and all rules.

There is **no** separate global **“hide locked items from Live TV browse”** switch. Hiding from browse is chosen **per item** in the Live TV scope dialog (see below).

### Live TV — scope dialog (channel tile menu, hero, or player)

When you open **Parental lock…** (or **Parental** from the live player strip), you get **up to four lock modes** plus **unlock** when something is already applied:

| Intent | Effect |
|--------|--------|
| **Lock channel** | Playback of that channel requires PIN; channel **still visible** in the grid. |
| **Lock channel & hide from browse** | Same lock **and** that channel is **omitted** from the Live TV grid for that playlist. |
| **Lock category / favorite group** | All channels in that pill require PIN to play. |
| **Lock category / favorite group & hide from browse** | Same **and** that **whole pill** is hidden from browse (channels in it do not appear elsewhere). |

**Unlock** rows appear only when the current target has a matching lock and/or browse-hide, so you can remove lock-only, hide-only, or both without clearing everything.

Browse filtering uses **`ParentalControlStore.shouldFilterLiveBrowseForParental`** and per-playlist sets: **`browseHideLiveChannels`**, **`browseHideLiveCategories`**, **`browseHideFavoriteGroups`**. Hide-from-browse applies only to **explicitly** flagged ids (not “every channel that shares a category id” in unrelated pills).

If the **current category pill** ends up with **no visible channels** after a rule change (for example you hid the only category that had focus), **Live TV** moves selection to the **first pill that still has channels** (when search is off) so the grid does not stay empty with focus stuck.

### Live TV — playback & hero

- **Playback:** If the current channel matches a rule (lock-all, blocked channel, blocked category, or blocked favorite group), the app shows **Enter PIN** before opening the fullscreen player.
- **Hero preview:** When the **focused** channel is blocked by the same rules (`ParentalControlStore.isLivePlaybackBlocked`), the Live TV **hero does not decode video**: `HeroLivePreview` uses **`parentalBlackout`** — a **black** picture inside the bezel (no texture, no poster fallback), and the **inside-bezel timeline** is hidden. Rebuilds when **`parentalControlStore`** or **`libraryController`** notifies. **Appearance / layout preview** (`LiveTvScreen(previewMode: true)`) skips blackout so editors still show a normal hero.
- **Menu key on a channel tile** (context menu): **Parental lock…** — opens the **scope dialog** above (after PIN when required). Requires parental **on** and PIN configured; otherwise a snackbar explains to use Settings first.
- **Inside the live player**, **right panel** (D-pad **Right**): **Parental** — same scope dialog (uses **browse category id** passed from Live TV when the player opened). First-time PIN creation uses the **compact** dialog with **inline numpad**, not a full-screen parental setup overlay.

### Movies & Series

- **Movie detail:** **Play** respects locks; **Parental** opens the scope dialog (**this movie** vs **entire movie category**) after PIN.
- **Series detail:** **Play** on an episode respects locks; **Parental** locks **this show** or **entire series category** after PIN.

(VOD does not use Live TV’s **browse-hide** sets; those apply only to the Live TV grid.)

### Player — Back and EPG

With the **fullscreen Live EPG** overlay open, **Back** is handled so the **root** navigator dismisses the EPG route first (avoids leaving navigation in a bad state where Back no longer reaches the overlay).

## Data model

**File:** `lib/data/parental_control_store.dart`  
**Prefs key:** `iptvil_parental_control_v1`

| Field | Meaning |
|--------|--------|
| `enabled` | Master on/off |
| `pinSalt`, `pinHash` | PIN verification (SHA-256 of salt + PIN) |
| `lockAllLive` / `lockAllMovies` / `lockAllSeries` | Section-wide blocks |
| `liveChannels` | Per playlist id → list of blocked live **stream** ids |
| `liveCategories` | Per playlist → blocked **Xtream live category** ids |
| `favoriteGroups` | Blocked **favorite group** pill ids (including umbrella id when applicable) |
| `browseHideLiveChannels` | Per playlist → stream ids **hidden** from Live TV grid |
| `browseHideLiveCategories` | Per playlist → category ids whose **pill** is hidden from browse |
| `browseHideFavoriteGroups` | Favorite group ids hidden from browse |
| `movieIds` / `vodCategories` | Per playlist → blocked movie ids / VOD category ids |
| `seriesIds` / `seriesCategories` | Per playlist → blocked series ids / series category ids |

Demo / no active playlist uses internal key **`__demo__`**.

## Backup

**`IptvilBackupService`** — snapshot includes **`parentalControl`**: `exportForBackup()` / `replaceFromBackup()` with the fields above (including browse-hide maps). Older backup files **without** new keys leave existing parental state unchanged on import where applicable.

## Implementation map

| Area | Files |
|------|--------|
| Store + hash + browse-hide | `lib/data/parental_control_store.dart` |
| PIN dialogs + numpad | `lib/ui/settings/parental_pin_dialog.dart` |
| Scope picks (four modes + unlock) | `lib/ui/settings/parental_scope_dialogs.dart` |
| Human-readable rule labels | `lib/ui/settings/parental_rule_labels.dart` |
| Restricted rules list screen | `lib/ui/settings/parental_restricted_rules_screen.dart` |
| Playback checks before `openIptvilPlayer` | `lib/ui/parental/parental_playback_guard.dart` |
| Settings UI | `lib/ui/settings/parental_control_settings_screen.dart` |
| Settings grid entry | `lib/ui/settings/settings_screen.dart` |
| Live TV | `lib/ui/live_tv/live_tv_screen.dart` (filtering, catalog change / pill selection); **`lib/ui/live_tv/live_tv_hero_panel.dart`** passes **`viewCategoryId`** + listens for hero blackout; **`lib/ui/live_tv/hero_live_preview.dart`** (`parentalBlackout`) |
| Player right panel + EPG Back + PIN | `lib/player/player_screen.dart` |
| Route args | `lib/player/player_navigation.dart` (`liveViewCategoryId`) |
| Movie / series details | `lib/ui/movies/movie_details_screen.dart`, `lib/ui/series/series_details_screen.dart` |
| Cold-start VOD restore | `lib/ui/movies/movies_screen.dart`, `lib/ui/series/series_screen.dart` |
| Backup | `lib/data/backup/iptvil_backup_service.dart` |
| Startup load | `lib/main.dart` |

## Localization

Strings live in **`lib/l10n/app_*.arb`** (`parental*` keys). Regenerate with **`flutter gen-l10n`**.

## Forgotten PIN (product note)

The app does **not** display the PIN after setup. Recovery options are: **Change PIN** if the old PIN is known; **Clear parental** after PIN; or **restore from backup** that contained the same hashed state. A full **Android clear app storage** removes local parental data (and other app data); see general backup docs in **`09-backup-system.md`**.
