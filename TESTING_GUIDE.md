# Testing guide

## Demo mode (default)

1. Launch with no playlists **or** **Demo mode ON** in **Settings**.
2. **Live TV** / **Movies** / **Series** use mocks (Xtream EPG overlay off in demo).
3. **Hero preview:** on **Android**, if channels have playable mock **`streamUrl`**s, the framed preview may still play **live sample HLS** with sound; otherwise falls back to poster art.
4. Automated tests:
   ```text
   flutter pub get
   flutter test
   ```

## Xtream Codes (real data)

### Prerequisites

- Xtream provider (URL, user, password).
- **Android TV** (or device) with network; **`usesCleartextTraffic`** allows **http://** panels.

### Add playlist

1. **Settings → Add Playlist → Xtream Codes**.
2. Save; turn **Demo mode OFF** when playlists exist.

### Browse, hero, preview audio, playback

- **Live TV:** categories from API; grid focus drives **hero EPG** + **debounced preview** URL.
- **Hero:** **two-tone gray** background (no giant channel art behind EPG). **Left / leading:** larger **TV-framed live preview** + **compact** time/progress row. **Center:** **EPG** (larger type). **Right / trailing:** channel **logo + name** (order follows **RTL**).
- **Preview audio:** you should **hear** the focused channel **until** you open **fullscreen play** — then preview **pauses/mutes**; **after Back**, preview **resumes** if still on Live TV.
- **Fullscreen:** **UP/DOWN** lineup updates **EPG** when ids are set on **`LiveLineupItem`**.
- **Back from fullscreen (Live):** returns to **Live TV** with focus on the **same channel tile** (not only on category pills); brief pill disable during restore is expected.
- **Movies / Series:** standard VOD flows from API.
- **Back from fullscreen (VOD):** **one** **Back** from the player must land on **movie/series details** (with **Play** still available), **not** on the **browse** poster grid. The **on-screen** back icon on details still returns to browse.

### Regression checklist

- [ ] Demo / Xtream lists and URLs behave as expected.
- [ ] Hero **EPG** updates when changing focused channel (short/simple EPG when panel supports it).
- [ ] **Preview video + audio** on device; **no** preview + main player **both** loud after exiting fullscreen (preview resumes **after** pop).
- [ ] **Video picture quality:** **no** black screen with audio-only on **fullscreen** or **hero preview**; **no** rainbow / neon / solarized colors (UI may look fine while video is wrong — usually means **Impeller** still on: confirm **`EnableImpeller`** **`meta-data`** is under **`<application>`** in **`AndroidManifest.xml`**). Re-test after **`flutter clean`** + fresh install if unsure.
- [ ] **Device generations:** when possible, same APK on **two** hardware tiers (e.g. **newer + older NVIDIA Shield**, or **Shield + ONN / Chromecast**) — **live + VOD + hero preview** should show **natural colors** and stable motion.
- [ ] **Leave app from Live TV** (Home or **double Back** from shell menu): **hero preview audio stops** (no ExoPlayer left playing in background on Shield / similar).
- [ ] **Large Xtream catalog — process death:** With **Demo off** and a **large** Xtream playlist loaded, open **Live TV** (categories + channels visible), then **remove the app from Recents** / force-stop and reopen — **Live TV** should still show **real** categories/channels (not empty / mock-only). Relies on **file-backed** catalog cache (**`iptvil_cat_full_*.json`**); see **`documentation/04-data-playlists-and-xtream.md`**.
- [ ] **Theme:** open **Theme** tab — cycle **Cosmic**, **Aurora**, **Solar**, **Heritage**; backdrop and accents update; shell should jump to **Live TV** after each choice; choice **persists** after restart; playback and playlists unchanged.
- [ ] **Shell:** **Back** from browse focuses **top bar**; **two more Back** exits app from that state.
- [ ] **M3U-only** active playlist → browse unsupported message on live/movies/series.
- [ ] **Settings → Clock:** enable clock; time appears on **shell, browse, player, menus**; **D-pad** still navigates content (clock does not steal focus). Toggle **Frame ON** — HUD (gradient + border + **date** line **`DD/MM MON`** with **`MON`–`SUN` in capitals**); **Frame OFF** — plain time only. **12/24h**, corner, size, opacity, colors persist after app restart.
- [ ] **Neon clock colors** (last three swatches): time uses **7-segment** style + **glow**; framed date shows **DSEG** numerals + **uppercase** weekday; non-neon colors unchanged.
- [ ] **Settings → Add Playlist:** **Xtream** tile is **focused on entry**; **left/right** moves between Xtream and M3U; after picking a source, **first field** (Server URL or M3U Name) is focused; **on-screen keyboard** appears for text fields; **Password** / **Name** stay **visible** above the keyboard (scroll/insets); no **Change type** row (use **Back** and re-open to switch source type). Repeat on a **second** device class if possible (e.g. **ONN / Chromecast** vs **Shield**) so **AndroidX Core** alignment is verified.
- [ ] **Movies / Series — trailer:** open trailer flow; list searches in-app; **Play** opens **YouTube** (app or browser) for the watch URL.
- [ ] **Settings → Favorite setup — New/Edit favorite:** **Name** and **Order** fields show the **TV keyboard** when focused.
- [ ] **Settings → My Playlists:** up to **three** playlist cards per row on a wide TV; actions (**Groups**, **EPG** time picker — Local / Original / zone — chip updates, **Use**, **Rename**, **Delete**) still work.
- [ ] **Settings → Manage groups →** (TV, Movies, or Shows): list is **not** full screen width; moving focus **down** the category rows **does not** clip the focus ring or push toggles off the **right** edge.
- [ ] **Favorite setup:** **New favorite** / edit flows; ordered channel picker; **Live TV** shows favorite **pills** even when **all** playlist live categories are **hidden** (if at least one group exists).
- [ ] **Movies / Series** poster rails: focused poster **focus ring / shadow** not visibly **cut off** at row edges (within SDK limits — **`Row.clipBehavior`** not used on older Flutter).
- [ ] **Movies — VOD picture:** play a **movie** (various aspect ratios if possible: **16:9**, **4:3**, **2.39:1**). Image should **not** look stretched; **black bars** top/bottom or left/right as needed, **centered** (see **`documentation/06-playback-and-native-player.md`**).
- [ ] **VOD seek (D-pad):** **Left/Right** should jump in **~30 s** steps; **holding** should feel **fast** (repeating skips). If too coarse/fine, tune constants in **`player_screen.dart`** (see **`documentation/06-playback-and-native-player.md`**).
- [ ] **VOD jump row + Settings:** **Down** twice (tier B) → **Right** to the **far-right** gear → **OK** opens **Settings** over the video; **Back** returns to the player with D-pad still working. Same **Settings** experience as Live TV in-player (**`openPlayerSettingsOverlay`**).
- [ ] **Missing art:** channels or VOD items **without** a valid poster/icon URL should show the **same** gradient + TV icon placeholder (**not** random per-title remote images). Broken image URLs should match.
- [ ] **Movies:** open **details** → **Play** → **Back** from player → still on **details** (can press **Play** again immediately). **Not** back on the poster grid only.
- [ ] **Series:** open **details** → play an **episode** → **Back** from player → still on **series details** (episode grid).
- [ ] **Live TV:** open channel **fullscreen** → **Back** → focus returns to the **channel tile**; channel logos in grid **not** cut off at left/right **edges** of the tile (logo+text **card style**).
- [ ] **Known visual:** occasional **chrome flash** on **shell / top bar** transitions — log if still reproducible after release.

## Device matrix (expectations)

- **Premium / powerful TV (e.g. NVIDIA Shield):** Usually the smoothest scrolling, animations, and **hero preview** + fullscreen handoff — use as the **reference** device.
- **Budget sticks and OEM boxes (e.g. ONN 4K, Chromecast with Google TV):** The **same** APK and features should run, but **UI may feel less smooth** (lower CPU/GPU RAM, tighter graphics memory, vendor Android builds). That is **hardware variance**, not a separate app build. Profile jank on those devices only if you need parity with Shield-level fluidity.

## Release APK / sideload

- **`flutter build apk --release`** → **`build/app/outputs/flutter-apk/app-release.apk`**. If **`mergeReleaseResources`** fails on **`app_icon`**, confirm **`drawable-nodpi/app_icon.jpg`** is a **real JPEG** (not a JPEG renamed **`.png`**) — see **`documentation/07-android-build-and-branding.md`**.
- **Install failures:** uninstall conflicting package; bump **`pubspec`** **+build**; **`leanback` not required** (see `documentation/07-android-build-and-branding.md`).
- **Add Playlist on budget TV:** After a build that includes **AndroidX Core 1.15.0** (see **`documentation/07-android-build-and-branding.md`**), open **Settings → Add Playlist**, pick **Xtream** or **M3U**, focus a text field — app must **not** crash when the IME appears (`NoSuchMethodError` / **`EditorInfoCompat`** if Core is too old).
