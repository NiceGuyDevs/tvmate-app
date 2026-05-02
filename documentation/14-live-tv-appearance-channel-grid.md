# Live TV · Appearance — Channel Grid Settings

Handoff for **Settings → Edit → Live TV** (and the **Live TV · Appearance** route): right-docked **Channel Grid Settings** card over **`LiveTvScreen(previewMode: true)`**, D-pad **rail** navigation, **2×2 channel display** grid (focus vs committed style), **Hide/Show**, and how this ties into **cold start** behavior.

## Files (primary)

| Area | File |
|------|------|
| Route / rail keys / focus index | `lib/ui/settings/live_tv_edit_screen.dart` |
| Panel + host (expanded/collapsed, FittedBox) | `lib/ui/settings/channel_grid_settings_panel.dart` |
| Reference UI (sliders, 2×2 pills, name row) | `lib/ui/settings/channel_grid_reference_layout.dart` |
| Brushed shell (shared with Movie/Series grid + VOD subtitle panels) | `lib/ui/settings/vod_brushed_panel_fill.dart` — **`VodBrushedPanelFill`** |
| Card style order (grid indices 0–3) | `lib/data/live_tv_card_style_store.dart` — `kChannelGridDisplayStyleOrder` |
| Cold start shell + VOD snapshot | `lib/data/app_session_restore_store.dart`, `lib/shell/main_shell_screen.dart` |
| Live + VOD player markers | `lib/player/player_session_restore_marker.dart`, `lib/player/player_screen.dart` |

## Visual design (shared with Movie / Series grid settings)

The **Channel Grid Settings** card uses the same **nested brushed** vocabulary as **`MovieGridSettingsPanel`** and the **VOD subtitle style** editor:

- **Outer shell:** **`VodBrushedPanelFill`** (stacked brushed slate + grain), **~12px** corner radius, soft **drop shadow**, and a **1px** frame tint **`Color.alphaBlend(accent × 0.28, white × 0.22)`** (non-interactive overlay) so team accent reads subtly on the border.
- **Section blocks:** **`channelGridInsetDecoration(focused: …)`** in `channel_grid_reference_layout.dart` — **`#1A1A2E`-style** fill, light border; **gold** border emphasis when that rail section is active.
- **Hero / Channels sliders:** Gold–orange track (not team accent), white thumb, tick labels.
- **Channel display 2×2:** **Neon** (`teamPalette.neonLine`) **outer ring** = D-pad **focus**; **gold border + light gold fill + check** = **committed** saved style (can differ from focus until **OK**). Aligns with **poster mode chips** on the movie grid.
- **Footer (Exit / Reset):** Same **inset strip** pattern as the movie grid footer — **`channelGridInsetDecoration(focused: false)`** wrapping the button row; inner buttons use flat fill + optional **neon** ring when that footer rail section is selected.

Behavior (rail indices, focus vs commit, Hide/Show) is unchanged; this block is **chrome only**.

## Panel layout and Hide / Show

- **Position:** `Stack` overlay in **`live_tv_edit_screen.dart`**: **`Positioned(top, right)`** with **`MediaQuery`** padding. When the **full card** is visible, **`bottom`** is also set so the slot has a **max height** and the inner **`FittedBox`** can scale the card down on short TVs.
- **Collapsed (Hide):** **`bottom`** is **omitted** and the **`Align(topRight)`** wrapper is **not** used — only the **Show settings** chip is laid out. This avoids a **full-height** strip on the right (which made the TV **focus highlight** cover a huge blue/cyan rectangle).
- **Host:** **`ChannelGridSettingsPanelHost`** toggles **`_panelVisible`**; collapsed state wraps the chip in **`SizedBox(width: targetW)`** + **`Align(topRight)`** so **`Row`/`Flexible`** get **bounded** width (layout bug fix).
- **Rail `Focus`:** **`canRequestFocus: true`** always; when collapsed, **OK** on the rail calls **`expandPanel()`** on the host state so the chip does not rely on focus alone.

## Rail sections (D-pad vertical order)

Indices match **`ChannelGridSettingsPanel.kSection*`** and **`LiveTvEditScreen`**:

| Index | Section |
|-------|---------|
| 0 | **Hide** (collapses to Show chip) |
| 1 | **Hero** banner size (gold slider / ◀▶) |
| 2 | **Channels** per row |
| 3 | **Tiles** — two sub-rows: **0** = channel **display** 2×2, **1** = **CH Name Position** (OK arms D-pad for name nudge) |
| 4–5 | Footer **Exit** / **Reset defaults** |

**Inside Tiles → Channel display (sub-row 0):** the four options are a **logical 2×2** matching **`kChannelGridDisplayStyleOrder`**:

- Row 0: indices **0**, **1** — `logoOnly`, `logoNameOnly`
- Row 1: indices **2**, **3** — `logoNameEpg`, `nameOnly`

**Up/Down/Left/Right** move a **focus cursor** only (see below). **CH Name Position** uses **OK** to arm **`_nameAdjustArmed`**; then arrows adjust **`liveTvNameVerticalBiasStore`** / **`liveTvNameHorizontalBiasStore`**.

## Channel display 2×2 — focus vs committed selection

**Requirement:** Moving the D-pad must **not** change the saved card style until the user confirms.

- **`_channelDisplayFocusIndex`** (0–3) in **`_LiveTvEditScreenState`**: D-pad **cursor** for the 2×2 grid when **`_section == poster`** and **`_posterSubRow == 0`**.
- **`liveTvCardStyleStore.style`**: **committed** choice (persisted; drives the live preview + grid tiles app-wide).
- **OK / Select** on the **Channel display** row applies **`setStyle(kChannelGridDisplayStyleOrder[_channelDisplayFocusIndex])`** via **`_setChannelDisplayStyleIndex`**.

**Sync rules for `_channelDisplayFocusIndex`:**

- **`initState`:** set from **`indexOf(store.style)`** in the order list.
- **Navigating down** from **Channels** into **Tiles** (first time on poster section): set to **`indexOf(store.style)`** so the cursor matches the current saved style.
- **Reset defaults:** after reset, focus index is updated to match the default style (**logo + name + programme** = index **2** in the order list).

**UI (`ChannelGridDisplaySegmentRow` / `_SegmentPill`):**

- **Neon outer ring** (`teamPalette.neonLine`): **focused** cell (D-pad cursor) when the Tiles **display** row is active.
- **Gold border + fill + check icon:** **committed** style (`current == s` from store) — can differ from the focused cell until the user presses **OK**.

## Stores touched from this screen

- **`liveTvHeroLayoutStore`** — hero height %
- **`liveTvGridColumnsStore`** — columns per row
- **`liveTvCardStyleStore`** — four card layouts (committed on **OK** in the 2×2)
- **`liveTvNameVerticalBiasStore`** / **`liveTvNameHorizontalBiasStore`** — global name position on tiles (when CH Name row is armed)

Backup keys for these are listed in **`09-backup-system.md`** (*Appearance editors*).

## Cold start / shell tab (related)

**Default:** cold start opens the **Live TV** tab.

**Exceptions** (persisted in **`AppSessionRestoreStore`**):

- **Live fullscreen** with a channel: restore **live** context (existing live restore in **`live_tv_screen.dart`**) and clear conflicting VOD snapshot.
- **VOD** (movie/episode) player with **`resumeContentId`**: snapshot written when the player opens; on next launch, **Movies** or **Series** tab opens and the player can restore; **OK** to apply style is unrelated to this.

Browsing **Settings** only and killing the app still lands on **Live TV** — the shell destination persisted for “everything else” is **`liveTv`**.

For implementation detail, see **`app_session_restore_store.dart`** (`persistSession`, `initialShellDestination`, `recordVodPlaybackSnapshot`, `consumeVodColdRestoreIf`).

## Related docs

- **[`05-ui-shell-and-tv-patterns.md`](05-ui-shell-and-tv-patterns.md)** — Appearance hub table, Movies grid settings pattern.
- **[`ARCHITECTURE.md`](../ARCHITECTURE.md)** — high-level shell + player flows.
- **[`08-feature-history-and-decisions.md`](08-feature-history-and-decisions.md)** — changelog-style decisions.
