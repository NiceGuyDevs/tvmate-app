# Performance tier system (full record)

This document is the **authoritative project record** for how IPTVIL divides **Full quality** vs **Optimized** behavior, how **Automatic** mode chooses between them, and how **Chromecast / Google TV** fits in (separate from the user-facing tier in some cases).

It reflects the implementation in the codebase as of the last update to this file. When you change behavior, update this document in the same PR.

---

## 1. Why this exists

TV devices range from **powerful** set-top boxes (e.g. NVIDIA Shield) to **memory-constrained** sticks (e.g. Chromecast with Google TV). The app offers:

- **Richest experience** where RAM and decoders allow (hero preview + leapfrog pool + large image cache).
- **Reduced concurrent work** on weak devices so navigation, focus, and playback stay smooth **without** forcing everyone onto a minimal UI.

The user selects a **performance mode** in **Settings → Performance** (`PerformanceSettingsScreen`). The effective behavior is driven by `PerformanceTierStore` (`lib/data/performance_tier_store.dart`).

---

## 2. User-facing modes

| Mode | Storage value | Meaning |
|------|----------------|---------|
| **Automatic** | `auto` | Derives **Full** or **Optimized** from **total device RAM** (see §3). |
| **Full quality** | `full` | Always use the **full** experience flags (`isOptimizedEffective == false`). |
| **Optimized** | `optimized` | Always use the **optimized** flags (`isOptimizedEffective == true`). |

- Preference key: `iptvil_performance_tier_mode_v1` in `SharedPreferences`.
- Included in app backup under `performanceTier.mode` (`lib/data/backup/iptvil_backup_service.dart`).

---

## 3. Automatic mode: RAM threshold

When mode is **Automatic**, the app reads **total RAM in MiB** from Android (`ActivityManager.MemoryInfo.totalMem`) via `DeviceMemoryChannel.getTotalRamMb()` (`lib/data/device_memory_channel.dart`, `DeviceInfoChannel.kt`).

**Rule:** if total RAM **≤ 2560 MiB** (~2.5 GB), **Automatic** behaves as **Optimized**; otherwise it behaves as **Full**.

- Constant: `PerformanceTierStore._autoOptimizedRamMbThreshold = 2560` (`lib/data/performance_tier_store.dart`).

If RAM cannot be read (`null`), **Automatic** defaults to **Full** (conservative when unknown).

---

## 4. Effective flag: `isOptimizedEffective`

Most of the app does **not** branch on `mode` directly. It uses:

```dart
bool get isOptimizedEffective
```

- **`full` mode** → always `false`.
- **`optimized` mode** → always `true`.
- **`auto` mode** → `true` iff reported total RAM ≤ 2560 MiB.

This single boolean controls shell weight, image cache, startup sync delay, hero behavior, player pool usage, and related paths.

---

## 5. Chromecast vs “performance tier” (important distinction)

**Chromecast detection** is **not** the same as **Optimized** mode. It is resolved at startup from native code:

- `DeviceInfoChannel` checks `Build.MODEL` / `PRODUCT` / `DEVICE` for `"chromecast"`.
- If matched → `getTvTextInputProfile` returns `"inAppPad"` → Dart sets `DeviceMemoryChannel.tvTextInputProfile = inAppPad`.
- Otherwise → `"fullIme"` (typical Shield / many TVs).

Dart exposes:

- `DeviceMemoryChannel.useInAppTextPadOnly` → `true` on Chromecast-like devices.

**Why it matters for playback**

- **Leapfrog dual-player pool** is disabled when **either** `isOptimizedEffective` **or** `useInAppTextPadOnly` is true (`_useLeapfrogPool` in `lib/player/player_screen.dart`). So **Chromecast always uses a single main ExoPlayer** for live, even if the user chose **Full quality**.
- **Live fast channel switch** (`liveFastSwitch` → native smaller buffers) is enabled when **either** condition is true (`_liveFastChannelSwitch`). That is how **one decoder + fast zaps** was tuned on Chromecast.
- **Hero live preview** in the grid: Optimized **without** Chromecast can suppress the heavy hero to save RAM; **Chromecast keeps the hero** because `useInAppTextPadOnly` is true — fullscreen still releases preview so only one decoder runs during playback (`hero_live_preview.dart` `_suppressHeavyHeroPreview`).

So: **Full on Chromecast** = full Flutter visuals where safe, but **playback path** still follows the **single-player + fast live** rules tied to `useInAppTextPadOnly`.

---

## 6. Side-by-side: Full vs Optimized (effective)

Below, “**Optimized**” means `isOptimizedEffective == true`. “**Full**” means `false`.

| Area | Full | Optimized |
|------|------|-----------|
| **Image cache** (`lib/app.dart` `_syncImageCacheWithPerformanceTier`) | Up to **1000** images / **100 MiB** | **80** images / **40 MiB** |
| **Early Xtream catalog sync** (`lib/main.dart` `_runEarlyCatalogSync`) | Starts immediately after startup | **Delayed 2 seconds** so first frames / focus settle |
| **Shell backdrop** (`lib/shell/main_shell_screen.dart`) | Full visual backdrop | **Lite** backdrop when optimized |
| **Splash** | Full treatment | Lighter path when optimized (`lib/ui/splash/splash_screen.dart`) |
| **Player settings overlay** (`lib/ui/settings/player_settings_overlay_scope.dart`) | `lite: false` | `lite: true` |
| **Live hero preview in grid** (`lib/ui/live_tv/hero_live_preview.dart`) | Native hero preview when supported | **Suppressed** on non-Chromecast optimized TVs to save RAM; Chromecast still gets hero (see §5) |
| **Opening fullscreen player** (`lib/player/player_navigation.dart`) | `strictSinglePlayer == false` → `LivePreviewChannel.pauseForFullscreen()` | **`LivePreviewChannel.dispose()`** + coordinator marks release — **only one decoder** in fullscreen |
| **After closing player (live)** | `resumeAfterFullscreen()` when supported | Coordinator-driven **re-bootstrap** path for hero (no idle second decoder) |
| **Leapfrog pool (two decoders)** (`lib/player/player_screen.dart` `_useLeapfrogPool`) | **On** when `PlayerPool.supported` and not optimized and not Chromecast | **Off** |
| **Live buffering spinner delay** (`_liveBufferingSpinnerDelay`) | **1.5 s** before showing spinner | **2.0 s** (keep last frame visible longer on slower devices) |
| **Native live load: `liveFastSwitch`** | `false` on strong Auto/Full path | `true` → **fast-live** ExoPlayer buffer profile |

**User-visible copy** for Optimized is also in ARB strings, e.g. `performanceModeOptimizedSubtitle` in `lib/l10n/app_en.arb` (and HE/AR/ES/FR).

---

## 7. Android native playback details

### 7.1 Method channel

- `NativeExoPlayerSession` (`android/.../NativeExoPlayerSession.kt`) handles `load` with arguments including `isLive`, `liveFastSwitch`, `audioDelayMs`, `playbackSpeed`.

### 7.2 Live fast switch (`liveFastSwitch == true`)

When **live** and **`liveFastSwitch`**:

- `DefaultLoadControl` uses the **LIVE_FAST_*** constants (smaller min buffer, lower “start playback” threshold, tighter rebuffer) so **time-to-first-frame** on channel change is minimized.
- `setPrioritizeTimeOverSizeThresholds(true)` stays enabled.
- Switching between fast-live and normal VOD-style profiles may call `releasePlayerKeepSurface()` only when the **profile flips**, not on every zap.

**Current tuned constants** (see companion object in `NativeExoPlayerSession.kt`):

- `LIVE_FAST_MIN_BUFFER_MS` — rolling minimum (e.g. **350** ms class of values).
- `LIVE_FAST_MAX_BUFFER_MS` — cap (e.g. **10_000** ms).
- `LIVE_FAST_PLAYBACK_START_MS` — buffer before starting playback (e.g. **50** ms class — lower = faster start, more rebuffer risk).
- `LIVE_FAST_REBUFFER_MS` — e.g. **220** ms.

VOD / catch-up uses a separate larger buffer profile (`VOD_*` constants).

### 7.3 Channel change without full `stop()`

`applyLoadRunnable` uses **`setMediaItem(..., resetPosition = true)` + `prepare()`** without a full `stop()`, keeping the last frame visible until the new stream renders.

### 7.4 Audio A/V sync and live zaps

`applyAudioDelayMsInternal` configures silence/trim processors. When **delay is 0** and **no trim**, the implementation **skips the seek “nudge”** that previously ran on every load — that removed unnecessary work on **every** live channel change when A/V offset is zero.

---

## 8. Leapfrog pool (Full path only, and not on Chromecast)

On **supported** devices with **Full** effective tier and **not** Chromecast-like:

- `PlayerPool` can keep **two** ExoPlayer slots to **pre-buffer** adjacent channels and swap visibility for **very fast** channel changes.

On **Optimized** or **Chromecast**:

- Leapfrog is **off**; switching uses the **legacy single ExoPlayer** path with **`liveFastSwitch`** where applicable so zaps stay fast **without** doubling decoder RAM.

---

## 9. Files index (quick reference)

| Topic | Location |
|-------|----------|
| Tier enum, RAM threshold, `isOptimizedEffective` | `lib/data/performance_tier_store.dart` |
| RAM + TV text profile + IME helpers | `lib/data/device_memory_channel.dart` |
| Kotlin: RAM MiB, Chromecast → `inAppPad` | `android/.../DeviceInfoChannel.kt` |
| Settings UI | `lib/ui/settings/performance_settings_screen.dart` |
| Image cache + listenable | `lib/app.dart` |
| Deferred catalog sync | `lib/main.dart` |
| Hero suppression rules | `lib/ui/live_tv/hero_live_preview.dart` |
| Fullscreen preview dispose vs pause | `lib/player/player_navigation.dart` |
| Leapfrog, `liveFastSwitch`, spinner delays | `lib/player/player_screen.dart` |
| `load(..., liveFastSwitch: ...)` | `lib/player/player_service.dart`, `native_android_player_service.dart` |
| ExoPlayer session, buffers, audio seek | `android/.../NativeExoPlayerSession.kt` |
| Backup / restore | `lib/data/backup/iptvil_backup_service.dart` |

---

## 10. Operational notes

- **Tuning:** If fast-live buffers are too aggressive, users may see **more rebuffers** on poor networks — adjust `LIVE_FAST_*` in `NativeExoPlayerSession.kt` and document changes here.
- **Product clarity:** “Full” on a **Chromecast** still avoids dual decoders; that is intentional for RAM and stability.
- **Auto threshold:** If typical “weak” devices in the field change (e.g. 3 GB sticks), revisit `_autoOptimizedRamMbThreshold` and this doc.

---

*End of record.*
