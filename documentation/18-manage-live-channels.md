# Manage live channels (per playlist)

## Purpose

Let users **per playlist** customize how **live** channels appear in **Live TV**: **rename** the display name, **hide** a channel from the grid (without removing it from the server catalog), or set a **custom logo URL**. Overrides are keyed by **Xtream stream id** (same id as `MockLiveChannel.id`).

This does **not** change the provider’s playlist on the server; it only affects presentation inside the app.

## User flows

### Entry

1. **Settings → My playlists** (playlist list).
2. On a playlist card, open **Manage channels** (`playlistChipManageChannels` in l10n).
3. **Manage channels** shows **live categories** from `XtreamCatalogRepository.liveCategories` (same source as Live TV). Category labels respect **Playlist group visibility** renames via `playlistGroupVisibilityStore.categoryDisplayName(...)`.

### Active playlist requirement

- **Manage channels** is only fully interactive when that playlist is **the active playlist** (`libraryController.activePlaylistId`). If another playlist is active, categories appear **dimmed** and taps do nothing; copy explains to **switch to this playlist first** (`manageLiveChannelsNeedActive`).

### Category → channel list

1. Tap a category → **ManageLiveChannelsCategoryScreen**.
2. Channels are loaded with `xtreamCatalogRepository.liveChannelsForCategory(categoryId)`.
3. **Order:** Channels appear in **playlist / catalog order** — the sequence in `liveChannelsAll` as synced from the panel (filtered by category). They are **not** sorted A–Z in the UI.

### Per-channel actions

| Action | Behavior |
|--------|----------|
| **Name** | Opens a dialog; saving calls `playlistChannelOverrideStore.setDisplayName`. Empty clears the override. |
| **Logo** | Dialog for custom **logo URL**; `setLogoUrl`. Empty clears. |
| **Hide from Live TV** | Toggle; `setHidden`. Hidden channels **do not appear** in the Live TV grid for that playlist; they remain visible in **Manage channels** so the user can unhide. |

The list uses `ListenableBuilder` on `playlistChannelOverrideStore` and `xtreamCatalogRepository` so renames and sync updates refresh immediately.

## Data model

**File:** `lib/data/playlist_channel_override_store.dart`  
**Singleton:** `playlistChannelOverrideStore`  
**SharedPreferences key:** `iptvil_channel_overrides_v1`

**JSON shape (conceptual):**

```json
{
  "<playlistId>": {
    "<channelId>": {
      "name": "optional display name",
      "hidden": true,
      "logo": "https://..."
    }
  }
}
```

- **playlistId:** `StoredPlaylist.id`.
- **channelId:** Xtream **stream** id (string), matching `MockLiveChannel.id`.
- Entries are **pruned** when no name, no logo, not hidden (see `_isEmptyOverride`).

## How Live TV applies overrides

**File:** `lib/ui/live_tv/live_tv_screen.dart`

- **`_applyChannelPresentation`:** For the active non-demo playlist, filters out `isHidden` channels, then **`apply(playlistId, channel)`** so display name and icon URL reflect overrides.
- **Favorite groups:** `_channelsForFavoriteGroup` also skips hidden channels and applies name/logo.

**Model helper:** `MockLiveChannel.copyWith` in `lib/ui/live_tv/mock_live_tv_data.dart` — used by `PlaylistChannelOverrideStore.apply`.

## Catalog source

**File:** `lib/data/xtream_catalog_repository.dart`

- **`liveChannelsAll`** — full ordered list after sync / load.
- **`liveChannelsForCategory(categoryId)`** — `where` on `categoryId`, **preserving** `liveChannelsAll` order.

## Implementation map

| Area | Files |
|------|--------|
| Store + persistence | `lib/data/playlist_channel_override_store.dart` |
| UI: categories + category channel list + dialogs | `lib/ui/settings/manage_live_channels_screen.dart` (`ManageLiveChannelsScreen`, `ManageLiveChannelsCategoryScreen`) |
| Entry from playlist list | `lib/ui/settings/my_playlists_screen.dart` |
| Live TV consumption | `lib/ui/live_tv/live_tv_screen.dart` |
| Catalog / ordering | `lib/data/xtream_catalog_repository.dart` (`liveChannelsForCategory`) |
| Group visibility labels (categories) | `lib/data/playlist_group_visibility_store.dart` |

## Localization

Strings: **`lib/l10n/app_*.arb`** — keys `playlistChipManageChannels`, `manageLiveChannels*`. Regenerate with **`flutter gen-l10n`**.

## Backup

**Full settings backup** (`IptvilBackupService`) does **not** currently include `iptvil_channel_overrides_v1`. Overrides are **device-local** until export/import is added. Other playlist-related backup slices include e.g. **`groupVisibility`** and **`parentalControl`**, but not channel rename/hide/logo.

## Related docs

- **Xtream data & sync:** [`04-data-playlists-and-xtream.md`](04-data-playlists-and-xtream.md)
- **Live TV UI patterns:** [`05-ui-shell-and-tv-patterns.md`](05-ui-shell-and-tv-patterns.md), [`14-live-tv-appearance-channel-grid.md`](14-live-tv-appearance-channel-grid.md)
