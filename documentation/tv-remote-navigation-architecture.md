# TV remote navigation — architecture

How the navigation system is built, where each piece lives, and how to extend it.

---

## 1. Overview

The navigation system has **three layers**:

| Layer | File(s) | Role |
|-------|---------|------|
| **Spec** | `documentation/tv-remote-navigation-spec.md` | Product rules — what each button does on every screen. |
| **Policy** | `lib/shell/navigation_policy.dart` | Pure logic — given "where am I" + "what's open," returns an **action enum**. No widgets, no `BuildContext`. |
| **Shell + screens** | `main_shell_screen.dart`, browse screens, `player_screen.dart` | Call the policy, then **execute** the returned action (focus move, pop route, exit app, etc.). |

**Principle:** screens report **state** ("overlay is open," "focus is on categories");
the **policy** decides; screens **act**. No screen reimplements global Back rules.

---

## 2. Navigation policy (`navigation_policy.dart`)

### 2.1 Shell — double Back on the top bar

```
NavigationPolicy.shellDoubleBack(focusedTab)
  → ShellBackAction.exitApp      // focused tab IS the launch tab
  → ShellBackAction.goHome       // focused tab is NOT the launch tab
```

**Launch tab** comes from `TopMenuStore.startup` — the user-configured startup
section (defaults to Live TV; changeable in Settings → Top Menu).

### 2.2 Browse — Back from grid or categories

```
NavigationPolicy.browseBack(focusOnCategories: bool)
  → BrowseBackAction.focusCategories   // focus was on grid → move to categories
  → BrowseBackAction.focusTopBar       // focus was on categories → move to top bar
```

### 2.3 Player — Back inside a player

```
NavigationPolicy.playerBack(overlayDepth: int, chromeVisible: bool)
  → PlayerBackAction.peelOverlay       // overlays open → close topmost
  → PlayerBackAction.dismissChrome     // chrome visible, no overlays → hide chrome
  → PlayerBackAction.exitPlayer        // clean video → leave player
```

---

## 3. Shell (`main_shell_screen.dart`)

### 3.1 `_onSystemBack()`

Runs only for the **shell root** (not pushed routes — those handle Back first).

1. If `_menuOpenedFromBack` (focus already on top bar from a previous Back):
   - Increment `_shellBackPressTowardExit`.
   - On **second** press: call `NavigationPolicy.shellDoubleBack(_destination)`.
     - `exitApp` → `_stopPreviewAndExit()`.
     - `goHome` → `_goTo(NavigationPolicy.launchTab)` (navigate to launch section).
2. If `ShellBackCoordinator.tryConsumeBack()` → browse screen handled it.
3. Otherwise → move focus to the **top bar** (`_menuOpenedFromBack = true`).

### 3.2 Focus tracking

- `_onAnyTopNavFocusChanged()` clears `_menuOpenedFromBack` when focus leaves
  the top bar (e.g. user pressed Down to go back into content).
- `ShellContentFocusRegistry` maps each `ShellDestination` to a "primary focus
  request" callback so the shell can push focus into the right screen after tab
  switches.

---

## 4. Browse screens

All browse screens (Live TV, Movies, Series, Recording) follow the same spine:

1. **Register** with `ShellBackCoordinator` in `initState`.
2. **`_tryConsumeShellBack()`** (or `_onShellBack`):
   - If **search** is active → clear search, return `true`.
   - If focus is on **grid / content** → move focus to **category row**, return `true`.
   - If focus is on **category row** → return `false` (let shell move to top bar).
3. **Unregister** in `dispose`.

### Live TV specifics

- Grid → pills → top bar ladder uses `requestLadderFocus` for immediate +
  scheduled focus (handles Android TV timing quirks).
- Category pills: **Up** explicitly moves to `topNavFocus(ShellDestination.liveTv)`.

### Movies / Series specifics

- `_tryConsumeShellBack` returns `false` when focus is already on a category
  chip, which lets the shell take over and move to the top bar.

### Recording specifics

- Has an extra **EPG mode** → **browse mode** peel step before falling through
  to the shell.

---

## 5. Player (`player_screen.dart`)

### 5.0 Single Back handler — critical design decision

On Android TV, one Back press fires through **three** independent systems:

1. **`PopScope.onPopInvokedWithResult`** — from the system back gesture (fires **first**)
2. **`_onPlayerHardwareKey`** — from `HardwareKeyboard` (fires **second**)
3. **`_onRootKey`** — from `Focus.onKeyEvent` (fires **third**)

If all three handle Back, the first dismisses chrome, the second sees "clean"
and exits, and the third may cascade further — causing the "Back exits to grid"
bug that plagued earlier versions.

**Solution:** **`PopScope` is the single authority** for all Back behavior in
the player. The two key handlers consume Back/Escape (`return true` /
`KeyEventResult.handled`) **without taking any action** — they only prevent the
event from propagating to parent widgets.

### 5.1 Live TV player Back order (in `PopScope`)

| # | Condition | Action |
|---|-----------|--------|
| 1 | Catch-up overlay open | Pop the overlay route |
| 2 | Full EPG overlay open | Pop the overlay route |
| 3 | Non-current route on top | Pop it |
| 4 | Multiview menu visible | Hide menu |
| 5 | In multiview | Exit multiview (restores chrome visible) |
| 6 | Right panel visible | Close panel |
| 7 | **Chrome / EPG visible** | `_hideControlsOverlay(immediate: true)` — **instant** dismiss, stay on live |
| 8 | **Clean live** | `_exit()` → back to channel grid |

### 5.2 VOD player Back order (in `PopScope`)

| # | Condition | Action |
|---|-----------|--------|
| 1 | Subtitle style panel open | Close panel (keep bar visible for next Back) |
| 2 | Subtitle picker open | Close picker |
| 3 | Audio offset popup open | Close popup |
| 4 | Speed picker open | Close picker |
| 5 | Timeline / info / any chrome visible | `_hideControlsOverlay()` — dismiss chrome |
| 6 | **Clean movie** | `_exit()` → back to details → grid |

### 5.3 VOD two-level chrome

- **First Down** → show timeline (first level); auto-hides after ~5 s.
- **Second Down** → focus jump strip / icon row (second level); **no auto-hide**
  while focused here.
- **Back** from second level → first level only.
- **Back** from first level → dismiss.

### 5.4 Overlay return-to-chrome

When a pushed overlay closes (EPG from right menu, catch-up, settings), the
`.whenComplete` callback restores `_controlsVisible = true` and calls
`_scheduleHideControls()`. This ensures the user returns to chrome-visible
state, and the next Back **dismisses chrome** rather than exiting.

### 5.5 Immediate vs fade dismiss

- **Back-triggered dismiss:** `_hideControlsOverlay(immediate: true)` — instant,
  no animation. Prevents the "flicker" bug where a fade leaves the overlay
  partially visible while another handler fires.
- **Auto-hide timer:** `_beginLiveOverlayFadeOut()` — gentle fade. Only used
  by `_scheduleHideControls` when the timer expires naturally.

---

## 6. How to add a new screen or section

### 6.1 New browse tab

1. Add the `ShellDestination` enum value.
2. Create the screen widget.
3. In `initState`: register with `ShellBackCoordinator` and
   `ShellContentFocusRegistry`.
4. Implement `_tryConsumeShellBack()`:
   - Search active → clear, return `true`.
   - Focus on content → move to categories, return `true`.
   - Focus on categories → return `false` (shell handles).
5. In `dispose`: unregister.
6. Add the body to `MainShellScreen._buildDestinationBody()`.

The **shell** already handles: categories → top bar → double Back → home/exit.
You get that for free.

### 6.2 New overlay or sub-menu in a player

1. Add a boolean flag (e.g. `_myPanelOpen`).
2. In the **`PopScope.onPopInvokedWithResult`** handler (the **only** place Back
   is handled), add a check **before** the chrome-dismiss step:
   ```dart
   if (_myPanelOpen) {
     setState(() => _myPanelOpen = false);
     return;
   }
   ```
3. Do **NOT** add Back handling to `_onPlayerHardwareKey` or `_onRootKey` —
   those only consume the event to prevent double-dispatch.
4. If the overlay is a **pushed route**, set a flag before pushing and clear it
   in `.whenComplete`. Restore `_controlsVisible = true` in `.whenComplete` so
   the user returns to chrome (not clean video).

### 6.3 New settings sub-page

Just use `Navigator.push`. Back naturally pops routes until the main Settings
screen, then the shell takes over. No extra wiring needed.

---

## 7. Key files reference

| File | Purpose |
|------|---------|
| `documentation/tv-remote-navigation-spec.md` | Product spec (what each button does) |
| `documentation/tv-remote-navigation-architecture.md` | This file (how it's built) |
| `lib/shell/navigation_policy.dart` | Policy module (pure logic, no UI) |
| `lib/shell/main_shell_screen.dart` | Shell: top bar, Back → home/exit, tab switching |
| `lib/shell/shell_back_coordinator.dart` | Two-step Back: browse screen → shell |
| `lib/shell/shell_content_focus_registry.dart` | Focus routing after tab changes |
| `lib/shell/shell_navigation_hub.dart` | Cross-shell navigation (e.g. after "add playlist") |
| `lib/shell/shell_destination.dart` | Enum of all shell tabs |
| `lib/data/top_menu_store.dart` | User's menu order + **startup tab** (`TopMenuStore.startup`) |
| `lib/ui/settings/tv_remote_keys.dart` | D-pad / Back / OK key detection helpers |
| `lib/ui/focus/tv_focusable.dart` | Focus ring, D-pad repeat, ladder helpers |
| `lib/player/player_screen.dart` | Player: Live + VOD key handling, overlay stack |

---

## 8. Testing checklist (manual, remote only)

### Shell & browse

| Scenario | Expected |
|----------|----------|
| Grid → Back | Focus on category row |
| Category → Back | Focus on top bar (current tab) |
| Category → Up | Focus on top bar (same as Back) |
| Top bar (non-launch) → Back×2 | Navigate to launch tab browse |
| Top bar (launch) → Back×2 | Exit app |

### Live TV player

| Scenario | Expected |
|----------|----------|
| Startup EPG/chrome visible → Back | Chrome hides **immediately**, stay on live |
| Right menu open → Back | Menu closes, stay on live |
| Right menu → Settings → Back | Settings closes, chrome visible, stay on live |
| Right menu → EPG overlay → Back | EPG closes, chrome visible, stay on live |
| Right menu → Catch-up → Back | Catch-up closes, chrome visible, stay on live |
| Right menu → Multiview → Back | Exit multiview, chrome visible, stay on live |
| Multiview menu visible → Back | Menu hides, stay in multiview |
| Chrome visible (no overlays) → Back | Chrome hides, stay on live |
| Clean live (nothing on screen) → Back | Exit to channel grid |

### VOD player

| Scenario | Expected |
|----------|----------|
| Timeline/bar visible → Back | Bar hides, stay on movie |
| Jump strip focused (2nd level) → Back | Back to 1st level bar only |
| Subtitle style editor → Back | Editor closes, bar stays visible |
| Subtitle picker → Back | Picker closes, bar stays visible |
| Speed picker → Back | Picker closes |
| Audio offset popup → Back | Popup closes |
| Info strip (Up) visible → Back | Strip hides, stay on movie |
| Clean movie (nothing on screen) → Back | Exit to details |
| Details → Back | Grid, same poster focused |

### Settings & other sections

| Scenario | Expected |
|----------|----------|
| Settings sub-page → Back | Parent settings page |
| Main settings → Back | Top bar (Settings tab) |
| Recording EPG mode → Back | Browse mode |
| Recording browse → Back | Top bar |

---

*Architecture version: v2. Updated after single-handler refactor and full testing.*
