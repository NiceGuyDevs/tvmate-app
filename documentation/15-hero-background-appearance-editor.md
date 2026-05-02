# Hero background appearance editor

Handoff for **Settings → Appearance → Hero background** (tile: wallpaper icon): full-screen **Live TV preview** with a **settings card** docked **bottom-right** (≈ **2%** margin from safe bottom and right edges). Lets users tune the **hero gradient**, **overlay wash** (brush or solid), **TV bezel frame** around the small preview, and related options — **D-pad / remote safe** (no sliders; **− / +** step rows only).

This doc describes **implementation** and a **short user guide** (what each control does). Iteration is expected; treat this as a snapshot.

## Where to open it

- **Settings** → **Appearance** (or **Edit** from player overlay, depending on route) → tile **Hero background** / wallpaper row — pushes **`HeroAppearanceEditScreen`**.

## Primary files

| Area | File |
|------|------|
| Route UI, panel position, scale, chrome | `lib/ui/settings/hero_appearance_edit_screen.dart` — **`HeroAppearanceEditScreen`**, **`_HeroAppearanceSheet`** |
| Persisted state (colors, wash, frame, gradient depth, etc.) | `lib/data/live_tv_hero_appearance_store.dart` — **`LiveTvHeroAppearanceStore`**, prefs key **`live_tv_hero_appearance`** |
| HSV color steppers (− / + rows, decorative hue ring) | `lib/ui/widgets/hero_hsv_color_card.dart` — **`HeroColorTvSteppers`** |
| Hero integration (gradient, wash overlay, frame) | `lib/ui/live_tv/live_tv_hero_panel.dart` |
| TV bezel painting | `lib/ui/live_tv/hero_tv_bezel_frame.dart` — **`HeroTvBezelFrame`** |
| Brushed outer fill (shared) | `lib/ui/settings/vod_brushed_panel_fill.dart` — **`VodBrushedPanelFill`** |
| Strings | `lib/l10n/app_*.arb` — `heroAppearance*` keys |

## Engineering notes (what we built)

- **Input model:** No **`Slider`**, no gesture color wheels — only **`TvFocusable`** targets so D-pad traversal does not get stuck. Small hue ring is **`IgnorePointer`** (decorative).
- **Layout:** Fixed **design size** (e.g. **640×472** logical) inside **`FittedBox`** so the card scales down on small TVs. Optional **`Transform.scale`** (~**0.75**) applied for a smaller on-screen footprint; **alignment bottom-right** keeps the card anchored in the corner.
- **Position:** **`Stack`** overlay: **`Positioned(right, bottom)`** with **2%** of screen width/height plus safe padding; **`ConstrainedBox`** max width/height; **`Align.bottomRight`** + **`FittedBox`** + scale so the panel sits in the **bottom-right** “slot.”
- **Chrome (aligned with Movies grid + VOD subtitle panels):** Outer **brushed** shell + **accent-blended** border; inner blocks use **`#1A1A2E`**-style inset panels (**`heroInsetPanelDecoration`** / same idea as **`VodSubtitlePickerPanel`** `_columnChrome`). **Divider** under the intro row matches subtitle picker headers.
- **Opening the screen:** A **post-frame** call sets **TV frame → On** so the editor starts with the bezel visible; user can turn it **off** (persisted like other fields).
- **Persistence:** Changes save via **`SharedPreferences`**; **Reset to default** clears custom hero look and restores store defaults (including frame **on**).
- **Backup:** Hero appearance fields are included in app backup export/import where the store is wired (see **`09-backup-system.md`** if extended).

---

## User guide — how to use the screen

Use the **directional pad** or remote: move focus between controls; **OK / Enter** activates the focused button.

### Top of the card

- **Short help text** — Explains that **− / +** change values and the **two small color squares** match **Background** (base gradient) and **Overlay** (wash). The **large Live TV preview** behind the card shows the result in real time.
- **Background / Overlay swatches** — Visual only (not buttons): they show the **current** base and wash colors.

### TV frame block

- **TV frame** — Decorative **bezel** around the **small live preview** in the hero (not your physical TV).
- **On / Off** — Turns that bezel **on** or **off**. When **On**, extra rows appear:
  - **Frame profile** — Four styles (e.g. slim, classic, bold, minimal): different **thickness / shape** of the frame.
  - **Bezel finish** — **Round chips** with gradients: different **metallic / material** looks on the frame edge.

**Suggestion:** Start with **On** and try **profile** + **finish** until the preview matches your taste.

### Left column — Background

- **Base color** — **− / +** on three rows (**shade / vivid / light** — HSV-style): controls the **main hero gradient** color.
- **Gradient depth** — How **dark** the bottom of the hero feels (stronger gradient vs flatter).

**Suggestion:** Adjust **base** first, then **depth**, so the channel list and EPG stay readable.

### Right column — Overlay

- **Brush / Solid** — **Brush** = textured wash over the background; **Solid** = flat tint (see on-screen hint for solid mode).
- **Wash / brush color** — Same **− / +** rows as base color, for the **overlay** tint.
- **Brush strength** — How strong the wash is (**0–100%** style).
- **Brush style** (only when **Brush** is selected) — Numbered styles **1…N**: different **texture patterns**.

**Suggestion:** For a subtle look, keep **strength** moderate; switch **Solid** if you want a simple color film over the hero.

### Bottom row

- **Reset to default** — Restores the **theme default** hero look and saved defaults in the store (including turning **custom** off where applicable — see store behavior).
- **Hide controls** — Hides the big card so you can **see the full preview**; a **Show controls** chip appears to bring the editor back.

### Back (outside the card)

- **Back** in the **top bar** exits the screen. Some flows use **double Back** to leave — follow on-screen behavior.

---

## Future tweaks

Position, copy, and defaults may change; keep this file updated when behavior or l10n strings change materially.
