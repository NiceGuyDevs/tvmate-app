# Player Pool System

## Overview

The Player Pool is a native (Kotlin) + Dart architecture that manages
**multiple independent ExoPlayer instances**, each with its own Flutter
`Texture`.  It serves two purposes:

| Feature | Pool usage |
|---------|-----------|
| **Multiview** (up to 4 live channels on screen) | Slots 0-3 — one per tile, all playing simultaneously |
| **Zero-delay channel switching** | Slots 0-1 leapfrog: one plays the current channel, the other silently pre-buffers the next |

---

## Architecture

### Native side — `NativePlayerPool.kt`

Located at `android/app/src/main/kotlin/com/iptvil/iptvil/NativePlayerPool.kt`.

* Manages up to **4 slots** (`MAX_SLOTS = 4`).
* Each slot is a self-contained `Slot` inner class containing:
  * Its own `ExoPlayer` instance (lazy-created).
  * Its own `SurfaceProducer` → Flutter `Texture`.
  * A `backgroundMode` flag controlling quality/resource usage.
  * A **freeze watchdog** that detects stuck streams and auto-recovers.
  * Independent load / play / pause / stop / setVolume / release lifecycle.
* **Focused slots** use full-quality settings:
  * 1920×1080 surface, unlimited bitrate/framerate, 2-8 s buffer.
* **Background slots** use reduced settings:
  * 640×360 surface, 500 kbps bitrate cap, 20 fps cap, 1.5-3 s buffer.
  * `setForceLowestBitrate(true)` — picks the absolute lowest variant.
* Slot 0 handles audio focus; slots 1-3 do not contend.
* Registered via `MethodChannel("com.iptvil/player_pool")`.
* `stopForActivityPause()` pauses every active slot when the app backgrounds.

### Dart side — `player_pool.dart`

Located at `lib/player/player_pool.dart`.

Static API mirroring the native channel:

```
PlayerPool.ensureTexture(slot, {bg})         → Future<int>   // create texture (bg=smaller surface+buffer)
PlayerPool.load(slot, url)                   → Future<void>  // load stream
PlayerPool.play(slot)                        → Future<void>
PlayerPool.pause(slot)                       → Future<void>
PlayerPool.stop(slot)                        → Future<void>
PlayerPool.setVolume(slot, vol)              → Future<void>  // 0.0 – 1.0
PlayerPool.setMaxVideoSize(slot, {w, h})     → Future<void>  // resolution cap per slot (0,0 = uncap)
PlayerPool.releaseSlot(slot)                 → Future<void>
PlayerPool.releaseAll()                      → Future<void>
```

### Integration — `player_screen.dart` (multiview)

* Each `_MvTile` holds: `poolSlot`, `textureId`, `loadedLineup`.
* **Slot allocation**: `_mvSyncDecoders()` assigns pool slots using a
  **lowest-free-slot allocator** — it collects all already-used slot
  numbers and picks the lowest unused one for each new tile.  This
  prevents slot collisions when tiles are added/removed in any order.
* `_mvRouteAudio()` sets volume 1.0 on the focused tile's slot, 0.0 on
  all others.  Also applies adaptive quality: focused tile gets full
  resolution, all others are capped to 640×360.
* `_mvSetFocus()` only calls `_mvRouteAudio()` — zero latency, with
  automatic quality swap.
* `_mvReleasePool()` cleans up all slots when exiting multiview.

---

## Multiview data flow

```
User enters multiview (via right-side panel → Multi option)
  └─ _enterMultiview()
       ├─ Pauses main ExoPlayer (NativeExoPlayerSession)
       ├─ Creates tile 0 for current channel (reuses leapfrog slot 0)
       └─ _mvSyncDecoders()
            └─ Allocates lowest-free pool slot for each new tile
            └─ For each tile (staggered — 1200ms between new slots):
                 ├─ PlayerPool.ensureTexture(slot, bg: !focused)
                 ├─ PlayerPool.setMaxVideoSize(slot, 640×360)  [if bg]
                 ├─ PlayerPool.load(slot, url)
                 └─ PlayerPool.play(slot)
            └─ _mvRouteAudio()  → volume + quality swap

User adds a tile
  └─ _mvAddScreen()
       ├─ Opens channel picker (LiveMultiviewChannelIconsScreen)
       ├─ Appends new _MvTile (poolSlot = -1, allocated by sync)
       └─ _mvSyncDecoders()  — only the new tile loads, existing keep playing

User changes focus (D-pad)
  └─ _mvSetFocus(index)
       └─ _mvRouteAudio()  — volume swap + quality swap, zero reload

User changes a tile's channel
  └─ _mvChangeChannel(tileIndex)
       ├─ Opens channel picker
       ├─ Updates tile's lineupIndex, resets loadedLineup
       └─ _mvSyncDecoders()  — reloads only the changed tile

User removes a tile
  └─ _mvRemoveScreen(tileIndex)
       ├─ Releases removed tile's pool slot
       ├─ Removes from _mvTiles list
       └─ Re-routes audio to current focus

User exits multiview
  └─ _mvExitMultiview() / _mvFullScreen()
       ├─ _mvReleasePool()  → PlayerPool.releaseSlot() per tile
       ├─ Clears tiles
       └─ _switchLiveToIndex() → resumes main ExoPlayer + leapfrog
```

---

## Stream recovery (native watchdog)

IPTV `.ts` streams can end unexpectedly (`STATE_ENDED`) or stall in
`STATE_BUFFERING`.  The native `Slot` handles both:

### STATE_ENDED recovery

When a slot's stream ends, it automatically **reloads the same URL
after 1 second**.  This keeps tiles alive indefinitely — when a TS
segment closes, the player reconnects and resumes.

### Freeze watchdog (STATE_BUFFERING)

When a slot enters BUFFERING, an **8-second timer** starts.  If still
stuck when the timer fires:

1. The current ExoPlayer is **fully destroyed** (listener removed,
   surface cleared, player released).
2. A **brand new ExoPlayer** is created with the same bg/focused mode.
3. Track constraints are re-applied, stream is reloaded from scratch.
4. The existing `SurfaceProducer` texture is reused (Flutter-side
   unchanged).

This cycle can happen up to **3 times** per slot.  Reaching READY
resets all counters.

### Error retry

On `onPlayerError`, the slot retries up to 3 times with increasing
delays (1s, 2s, 3s).  Track constraints and surface are re-applied
before each retry.

---

## Zero-delay channel switching (implemented)

Uses pool slots 0-1 in **leapfrog** mode when watching a single live
channel (not in multiview).

### How it works

1. **Startup** – `_lfStart()` creates pool slots 0 and 1.  Slot 0 loads
   the current channel (visible, volume 1).  Slot 1 silently pre-buffers
   the **next** channel in the lineup (volume 0).
2. **Channel up** – `_switchLiveToIndex()` detects the target is already
   loaded on the idle slot.  It swaps volumes (idle→1, visible→0) and
   flips `_lfVisibleSlot`.  The now-idle slot starts pre-buffering the
   new next channel.  **No loading delay.**
3. **Channel down** – Same logic, but when the target wasn't pre-buffered
   the idle slot loads it on-demand, then swaps.  After swap, the new
   idle slot pre-buffers the next channel in the user's travel direction.
4. **Arbitrary jump** – If the user picks a far-away channel (e.g. from
   a channel list), the idle slot loads it fresh.  Still faster than
   stopping + reloading a single player, because the swap happens as soon
   as the first frame is decoded.

### State variables

| Variable | Purpose |
|----------|---------|
| `_lfActive` | Whether leapfrog is running |
| `_lfVisibleSlot` | Which pool slot (0 or 1) is currently shown |
| `_lfTexId0` / `_lfTexId1` | Flutter texture IDs for each slot |
| `_lfLoaded0` / `_lfLoaded1` | Lineup index loaded on each slot |

### Lifecycle

- **Activated** after `_bootstrap()` for live channels, and after
  exiting multiview back to single-view.
- **Deactivated** when entering multiview (which needs all 4 slots) and
  when the player screen is disposed.
- The main `NativeExoPlayerSession` is paused while leapfrog is active
  to free a hardware decoder slot.

### Result

Sequential channel flipping (up/down) is **near-instant** — the next
channel is already buffered and rendering before the button is pressed.

---

## Multiview layouts

Layouts match a top-heavy arrangement where the enlarged/focused screen
is always on top and smaller screens sit below.

| Screens | Equal layout | Enlarged layout |
|---------|-------------|-----------------|
| 2 | Side by side (50/50) | Big top, small bottom-center |
| 3 | 2 on top row, 1 centered bottom | Big top, 2 small in bottom row |
| 4 | 2×2 grid | Big top, 3 small in bottom row |

---

## Adaptive quality for background tiles (implemented)

### Problem

Devices with 2 hardware decoders can play 2 full-HD streams without
issue.  The 3rd and 4th streams require software decoders which
cannot sustain full resolution long-term.  Additionally, many IPTV
streams are single-bitrate `.ts` URLs with no lower quality variants.

### Solution: multi-layer resource reduction

Every non-focused tile runs in **background mode** with six layers
of resource reduction:

| Layer | Focused tile | Background tile |
|-------|-------------|-----------------|
| **Track selection: resolution** | Unconstrained | 640×360 max |
| **Track selection: bitrate** | Unlimited | 500 kbps max |
| **Track selection: frame rate** | Unlimited | 20 fps max |
| **Force lowest bitrate** | No | Yes |
| **Surface size** | 1920×1080 | 640×360 |
| **Buffer depth** | 2-8 s | 1.5-3 s |

All constraints are applied **before** `prepare()` so ExoPlayer
selects the correct track from the start, avoiding decoder churn.

### Centralized via `applyTrackConstraints()`

A single private method on each `Slot` applies all track selection
parameters based on `backgroundMode`.  Used by:
- `load()` — before `prepare()`
- `setMaxVideoSize()` — runtime quality toggle
- retry handler — before re-preparing on error
- freeze watchdog — before re-preparing on recovery

### Quality swapping on focus change

When the user changes focus between tiles, `_mvRouteAudio()`:
1. Sets volume 1.0 on the focused slot, 0.0 on all others.
2. Calls `setMaxVideoSize(0, 0)` on the focused slot → removes caps,
   resizes surface to 1920×1080.
3. Calls `setMaxVideoSize(640, 360)` on all others → applies caps,
   shrinks surface to 640×360.

This is instant — no stream reload needed.

---

## Live TV navigation (player_screen.dart)

### Full-screen live TV (no multiview)

| Key | EPG visible (first ~4s) | EPG hidden |
|-----|------------------------|------------|
| UP | Switch channel up | Switch channel up |
| DOWN | Switch channel down | Switch channel down |
| LEFT | EPG → previous show | — |
| RIGHT | EPG → next show | **Open right-side panel** |
| SELECT | EPG action (catch-up) | Show EPG overlay |
| BACK | Dismiss EPG | Exit player |

### Right-side options panel

A thin vertical column (56px) slides in from the right edge of the
screen when the user presses RIGHT while the EPG is hidden.
Currently shows the "Multi" (multiview) option.

| Key | Action |
|-----|--------|
| UP / DOWN | Navigate panel items |
| SELECT | Activate selected item (e.g. enter multiview) |
| LEFT / BACK | Close panel |

### Inside multiview

| Key | Action |
|-----|--------|
| Arrow keys | Move focus between tiles (spatial navigation) |
| DOWN | Open tile action menu (add/remove/enlarge/change/fullscreen) |
| SELECT | Open tile action menu |
| BACK | Exit multiview → single channel |

### EPG auto-hide

The EPG overlay auto-hides after **4 seconds** of inactivity.

---

## Top menu navigation (app_top_bar.dart)

### Focus trapping

The top bar uses `_TopBarTraversalPolicy` (extends
`ReadingOrderTraversalPolicy`) which overrides `inDirection()`:
- **LEFT at the first item** → stays put (does not escape to grid)
- **RIGHT at the last item (Search)** → stays put
- **DOWN** → leaves the top bar into the content area
- Normal LEFT/RIGHT between items works via the parent class

### Underline indicator

The colored underline shows under the **focused tab** when the user
is navigating the top bar.  When focus leaves the bar (e.g. DOWN
into content), the underline shows under the **selected** (active)
destination.  Both focused and selected tabs show the underline, but
the focused tab gets the brighter treatment.

---

## Channel picker (live_multiview_channel_icons_screen.dart)

Grid of channel icons used by multiview "Add channel" and "Change
channel" actions.

### Performance

Each cell is its own `_ChannelCell` `StatefulWidget`.  Focus changes
only rebuild the **two affected cells** (old focus + new focus),
not the entire grid.  This prevents the 30-40 second freezes that
occurred when the parent tracked `_focusedIndex` in state and
rebuilt all cells on every D-pad press.

---

## Device compatibility

Most modern Android TV SoCs (Amlogic S905X3/4, MediaTek MT8167,
NVIDIA Tegra) support 2-4 concurrent hardware decoder instances.
All pool slots use `EXTENSION_RENDERER_MODE_PREFER` with
`setEnableDecoderFallback(true)`, letting ExoPlayer automatically
fall back to software decoders when hardware decoders are exhausted.

The adaptive quality system and stream recovery watchdog together
ensure that 3-4 simultaneous streams remain stable even on devices
with only 2 hardware decoders, by reducing the load on software
decoders and automatically recovering from stalls and stream endings.

---

## Relationship to existing players

| Component | Purpose | Status |
|-----------|---------|--------|
| `NativeExoPlayerSession` | Main fullscreen player (live + VOD/catch-up) | Active — used for single-view and VOD |
| `NativeLivePreviewSession` | Hero preview on live TV grid | Active — used by `HeroLivePreview` |
| **`NativePlayerPool`** | Multiview + zero-delay switching | Active — used by multiview tiles and leapfrog |

All three coexist.  Multiview pauses the main session while active and
releases pool slots on exit, resuming the main session seamlessly.

---

## Implementation files summary

| File | Responsibility |
|------|---------------|
| `NativePlayerPool.kt` | Native pool: 4 slots, bg mode, track constraints, freeze watchdog, ENDED recovery, error retry |
| `player_pool.dart` | Dart API: `ensureTexture(bg)`, `load`, `play`, `setVolume`, `setMaxVideoSize`, `release` |
| `player_screen.dart` | Multiview UI: tile management, slot allocation, layout, focus/audio/quality routing, key handling |
| `live_multiview_channel_icons_screen.dart` | Channel picker grid: per-cell state for fast focus, no full-grid rebuilds |
| `app_top_bar.dart` | Top menu: `_TopBarTraversalPolicy` for focus trapping, underline follows focus |
| `player_tv_overlay.dart` | Live + VOD fullscreen chrome (EPG strip, VOD timeline + jump row + trailing Settings); overlay build token **`kPlayerTvOverlayBuild`** |
