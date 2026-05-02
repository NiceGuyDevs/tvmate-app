# Performance tier (Full / Optimized / Automatic) and TV text input

This document describes the **Performance** settings feature, how **Automatic** chooses a profile, what changes in the app, and how **remote + on-screen keyboard** interact with Flutter on Android TV (NVIDIA Shield, Chromecast with Google TV, etc.).

## Why this feature exists

The same APK runs on **powerful boxes** (e.g. NVIDIA Shield with plenty of RAM) and **small streamers** (e.g. Chromecast with Google TV with ~2 GB RAM). One build can still **tune workload**: richer visuals and faster background work on strong hardware, and a **lighter path** on weaker devices so navigation and playback stay smooth.

## User-facing modes

| Mode | Meaning |
|------|--------|
| **Full quality** | Always use the richest experience the app offers for this build (cosmic backdrop, larger image cache, earlier catalog sync, longer splash path). |
| **Optimized** | Reduce work: lighter backdrop, smaller image cache, deferred catalog sync, shorter splash — tuned for weaker GPUs/CPUs and less RAM. |
| **Automatic** | The app picks **Full** or **Optimized** using **total device RAM** reported by Android. |

### What “Automatic” does (exact rules)

Implementation: `lib/data/performance_tier_store.dart` (`PerformanceTierStore.isOptimizedEffective`).

1. If you chose **Full** manually → behavior is **Full** (not optimized).
2. If you chose **Optimized** manually → behavior is **Optimized**.
3. If you chose **Automatic**:
   - Read **total RAM** from Android (`ActivityManager.MemoryInfo.totalMem`), exposed as MiB via `MethodChannel` (`com.iptvil.iptvil/device`, method `getTotalRamMb`).
   - If RAM **≤ 2560 MiB** → treat as **Optimized**.
   - If RAM **> 2560 MiB** → treat as **Full**.
   - If RAM **cannot be read** → treat as **Full** (safe default).

So on a typical **Shield**, reported RAM is usually **above** 2.5 GiB → **Automatic behaves like Full quality**. On a typical **Chromecast with Google TV**, total RAM is often **at or below** that threshold → **Automatic behaves like Optimized**.

### What you see on the Performance screen

- A line with **detected total RAM** when Android returns a value.
- If RAM is unknown, a note that **Automatic defaults to Full quality**.
- When **Automatic** is selected, an extra line states **what is in effect right now** (Full vs Optimized), matching `isOptimizedEffective`.

## What actually changes when “Optimized” is effective

Roughly (see code for the full list):

- **Backdrop / shell** — `CosmicSpaceBackdrop(lite: true)` in places that listen to `performanceTierStore` (lighter background, no heavy layers).
- **Images** — `ImageCache` byte cap lowered in `lib/app.dart` (`_syncImageCacheWithPerformanceTier`).
- **Catalog** — optional delay before the early Xtream/catalog sync on cold start (`lib/main.dart`, `_runEarlyCatalogSync`).
- **Splash** — shorter path when optimized (`lib/ui/splash/splash_screen.dart`).
- **Backup** — mode is stored under snapshot key `performanceTier` (`lib/data/backup/iptvil_backup_service.dart`).

## Technical map (for developers)

| Area | Files / notes |
|------|----------------|
| RAM + IME signals from Android | `android/.../DeviceInfoChannel.kt`, `MainActivity.kt` |
| Dart channel + IME flag | `lib/data/device_memory_channel.dart` |
| Tier state | `lib/data/performance_tier_store.dart` |
| UI | `lib/ui/settings/performance_settings_screen.dart`, Settings row in `settings_screen.dart` |
| l10n | `lib/l10n/app_*.arb` — `performance*` keys |

## TV remote, search, and typing (Shield / Chromecast)

### Problem you might see

On Android TV, the app uses **`HardwareKeyboard.instance.addHandler`** in a few places so **D-pad Up/Down** move between fields or search rows **without** inserting characters. That is necessary for **physical** TV remotes.

When the **on-screen keyboard (IME)** is open, **the same D-pad keys must be handled by the IME** (move between keys, select letters). If our handler runs first and **consumes** those events, it looks like:

- The keyboard **opens**, but you **cannot move or “type”** with the remote.
- **Search** or **Add playlist** fields feel broken even though focus looks correct.

### Two ways we detect “keyboard is open”

1. **`MediaQuery.viewInsets.bottom`** — works on some builds when the window resizes for the IME.
2. **Native Android — `WindowInsetsCompat.Type.ime()`** — `MainActivity` attaches `ViewCompat.setOnApplyWindowInsetsListener` on the `decorView` and treats the IME as visible if the IME inset is **visible** or its **bottom inset &gt; 0**.
3. **Native Android — `ViewTreeObserver.OnGlobalLayoutListener`** — compares **`getWindowVisibleDisplayFrame`** to the root height. If the visible frame’s bottom is far above the screen bottom (typical when the on-screen keyboard eats space), we treat the IME as open. This catches **Google Chromecast with Google TV** and similar devices where **neither** Flutter `viewInsets` **nor** IME window insets reliably signal “keyboard showing,” so D-pad would otherwise keep getting stolen by Dart.

Dart receives a single combined flag via `DeviceInfoChannel.onImeVisibilityChanged` (`imeVisibility` on `com.iptvil.iptvil/device`). `DeviceMemoryChannel.imeLikelyOpenForTvTextInput(context)` is true if **Flutter viewInsets** *or* that native flag indicates the IME.

**NVIDIA Shield** often worked even when only (1)+(2) applied; **Chromecast** commonly needed (3) as well.

`ShieldTvTextField` and the shell search dialog also use **`WidgetsBindingObserver.didChangeMetrics`** so the widget rebuilds when insets update a frame late.

### Where handlers defer to the IME

- `lib/ui/settings/shield_tv_text_field.dart` — form fields (Add Playlist, etc.).
- `lib/shell/app_top_bar.dart` — shell **search** dialog (`_ShellSearchDialog`).

If typing still fails on a **specific screen**, check whether that screen uses a raw `TextField` with another global key handler that does not use this guard.

## “Use keyboard on mobile device” (Google TV / Chromecast)

That message usually comes from **Google TV itself**, not from app strings. The OS often prefers typing through the **Google TV** or **Google Home** app on your **phone** (same Wi‑Fi) when it thinks that is faster than the on-TV Gboard layout.

**Things to try (no code):**

- On the **Chromecast / Google TV**: **Settings → Remotes & accessories** (or similar) — look for options about the **virtual remote** / **phone keyboard** and whether the on-screen TV keyboard is allowed.
- In the **Google TV app** on the phone: remote / keyboard settings — some users can reduce how often the TV pushes the phone flow.
- **Disconnect** extra “remote” integrations (e.g. home automation remotes) if they compete for input; some threads report the phone-keyboard prompt when **multiple** remote/keyboard backends are active.
- A **USB or Bluetooth keyboard** attached to the TV often bypasses the phone flow entirely.

**In this project:** When a `ShieldTvTextField` or the shell search field gains focus, the app also calls **`InputMethodManager.showSoftInput`** from native code (`requestShowSoftInput` on `com.iptvil.iptvil/device`) to nudge **on-TV Gboard**. That helps on some builds; it cannot override a hard OS policy that only offers the phone keyboard.

**Add Playlist — in-app remote pad (no IME):** On **Add Playlist**, each field has **“Type with TV remote”**, which opens **`tv_remote_char_pad_overlay.dart`**: digits, letters, URL symbols, space, backspace, caps for letters — **no system keyboard**. Opening **Add Playlist** also calls **`prepareForTextInput`** on the device channel so native **player pool / preview / fullscreen player** pause and free RAM, reducing **LMK kills of Gboard** (`com.google.android.inputmethod.latin`) on Chromecast-class devices.

## Troubleshooting checklist

1. **Confirm Performance lines** — Shield: “Automatic → Full”; Chromecast: often “Automatic → Optimized”; both consistent with RAM rules above.
2. **Typing with IME** — After opening the keyboard, D-pad should move inside the keyboard; OK/Enter selects a character. If not, capture **device model + Android version** and whether **viewInsets** or **native IME** events fire (logcat / debug).
3. **“Cannot navigate / play”** — If the issue is **outside** text fields (e.g. cannot focus Play on a row), that is separate from IME routing; file under focus/TV patterns (`05-ui-shell-and-tv-patterns.md`) or player doc (`06-playback-and-native-player.md`).

## Related docs

- `05-ui-shell-and-tv-patterns.md` — shell, focus, TV patterns.
- `07-android-build-and-branding.md` — build, Leanback, packaging.
- `09-backup-system.md` — backup keys including `performanceTier`.
- `README.md` — documentation index.
