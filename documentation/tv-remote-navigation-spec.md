# TV remote navigation spec

Unified behavior for **D-pad**, **Back**, **OK**, and the shell.
**Android Home** is always separate: it opens the system launcher, not this flow.

---

## 1. Global concepts

### 1.1 Launch / "home" section

- The app has a **configurable startup tab** stored in `TopMenuStore.startup`
  (e.g. Live TV, Movies, Series).
- Rules that say **"go to home browse"** mean: navigate to the **grid + category
  row** for **whatever tab is set as launch** — not necessarily Live TV.

### 1.2 Top tab menu (shell bar)

- Focus can move **Left / Right** between section tabs.
- **Double Back** behavior depends on **which tab is focused** (see §2).

### 1.3 Back = peel, then exit layer-by-layer

- **Inside overlays, players, and nested screens:** Back removes **one** layer at
  a time until the screen is "clean" for that context.
- Back **never** accidentally jumps to the grid or exits the app while nested UI
  is open.

### 1.4 OK / Center

- **OK** always means "activate" — open a channel, play a movie, select a menu
  item, etc.

### 1.5 Android Home (remote)

- Goes to the **system home / launcher**. Not part of the in-app Back ladder.

---

## 2. Shell — exit app vs go home

When focus is on the **top tab bar**:

| Focused tab | Double Back |
|-------------|-------------|
| **Launch / home tab** (user's startup section) | **Close the app** |
| **Any other tab** | **Jump to home browse** — grid + categories for the configured launch section |

From any section (Settings, Movies, etc.), user presses Back until they reach
that section's **root** screen, then Back again → focus on **that section's tab**
in the top bar. From there they can use D-pad or Double Back as in the table.

---

## 3. Live TV — channel grid

- **Up / Down:** move **row by row** in the grid.
- **Left / Right:** previous / next channel; at row ends, **change category** and
  jump to **last / first** channel there.
- **Up from top row:** **category pills**.
- **Back:** jump **directly** to **category pills** (not row-by-row).

---

## 4. Live TV — category pills

- **Up:** **top tab menu** (shell bar).
- **Back:** same as Up → **top tab menu**.

---

## 5. Live TV — fullscreen player

### 5.1 Overlays on live

- **EPG / startup overlay:** Back → hide overlay **immediately**, **stay** on live.
- **Any other overlay / menu** (right menu, multiview, nested flows): Back →
  **one step back**, stay on live until stack is empty.

### 5.2 Clean live (video only, no overlay)

- **Back** → **channel grid**.

### 5.3 Order of leaving (after closing all live overlays)

**Clean live** → Back → **grid** → Back → **pills** → Up/Back → **top tab menu**
→ per §2.

---

## 6. VOD (Movies) — grid & details

### 6.1 Grid

- Same pattern as Live TV grid: browse grid → **categories** with Up / Back;
  from categories Up / Back → **top tab menu**; D-pad as implemented.

### 6.2 Movie details

- **Back** → **movies grid** with **focus on the same movie**.

---

## 7. VOD — playback

### 7.1 Info strip (top)

- **Up:** show **movie details / info** on top (already implemented).
- **Back** while strip visible → **close strip** → **clean video**.

### 7.2 Two-level bottom chrome

- **First Down:** show **first-level** bar / player info; may **auto-hide** after
  ~5 s idle.
- **Second Down:** focus **bottom icon row** (second level).
- **Second level:** **no auto-hide** until user leaves this level (e.g. Back to
  first level).
- **Back** from **second level** → **first level** only.
- **Back** from **first level** → dismiss bar (or idle timer can still hide after
  ~5 s).

### 7.3 Sub-menus (subtitles, settings, etc.)

- **Back** → **one step out** until back to main player UI.
- Then Back as in §7.2 to reach clean video when appropriate.

### 7.4 Clean movie (no bar, no overlay)

- **Back (1st)** → **movie details**.
- **Back (2nd)** → **movies grid**, **same movie focused**.

---

## 8. Series

Same pattern as Movies: **grid → categories → top tab menu**; **details → grid
with same focus**; **player** follows VOD rules (§7).

---

## 9. Recording

Same universal pattern: **browse → categories → top tab menu**; nested views
peel with Back one level at a time.

---

## 10. Settings

- **Back** from each sub-page → parent → … → **main Settings** → Back →
  **Settings tab** on the **top bar**.
- From top bar (Settings focused): Double Back → **home browse** (§1.1), or
  D-pad to other tabs — per §2.

---

## 11. Universal rule (all sections)

| Where you are | Back does |
|---------------|-----------|
| **Overlay / dialog / nested screen** | Peel **one** layer |
| **Section root** (grid, main settings, etc.) | Focus moves to **top tab bar** |
| **Top bar, not launch tab** | Double Back → **home browse** |
| **Top bar, launch tab** | Double Back → **exit app** |
| **Player with chrome/overlay** | Peel one layer, stay in player |
| **Player clean** (no overlay) | Back → previous screen (details or grid) |

**One sentence for designers / devs:**
> OK goes deeper; Back walks up one level; at section root, Back hits the shell;
> on the shell, double Back goes home or exits depending on launch tab.

---

## 12. Master chain (memory aid)

**Live TV player:** overlays → peel with Back → **clean live** → Back → **grid**
→ Back → **pills** → Up/Back → **top menu** → Double Back per §2.

**VOD player:** overlays → **clean movie** → Back → **details** → Back → **grid**
(same poster).

**Any section → home:** reach top bar for current tab → Double Back → home browse
unless focused tab **is** launch tab → then Double Back = exit app (§2).

---

## 13. Implementation notes

### 13.1 Single Back handler in the player

On Android TV, a single Back press can fire through **three** systems:
`PopScope` (system back gesture), `HardwareKeyboard`, and `Focus.onKeyEvent`.
To prevent double-dispatch, the player uses **`PopScope` as the single
authority** for all Back behavior. The two key handlers
(`_onPlayerHardwareKey`, `_onRootKey`) consume Back/Escape without action —
they only prevent the event from propagating further.

### 13.2 Immediate chrome dismiss

When Back dismisses the live TV overlay, it uses `_hideControlsOverlay(immediate: true)`
which **instantly** hides the chrome (no fade animation). The gentle fade is
reserved for the auto-hide timer. This prevents the "flicker" where the overlay
fades out and another handler sees "clean" state in the same frame.

### 13.3 Overlay return-to-chrome

When a pushed overlay closes (EPG from right menu, catch-up, settings), the
player restores `_controlsVisible = true` and schedules auto-hide. This ensures
the next Back **dismisses chrome** rather than exiting the player.

### 13.4 Navigation policy module

`lib/shell/navigation_policy.dart` is the single code authority for shell-level
rules (launch tab, double-Back = home vs exit). Feature screens register state
and delegate Back decisions — they do not reimplement global rules.

### 13.5 Launch tab

The user-configured startup tab (`TopMenuStore.startup`) determines:
- Which section is "home" for the double-Back rule.
- Double Back on the launch tab = **exit app**.
- Double Back on any other tab = **navigate to launch tab browse**.

---

*Document version: v2. Updated after single-handler refactor and full testing.*
