# IPTVIL — Feature Showcase

A premium IPTV experience designed for the big screen. Built for Android TV, optimized for the remote.

---

## Live TV

Channel switching that feels instant. Hero preview with live video, real-time EPG data, and channel artwork — all updating as you browse. Named favorite groups let you organize channels your way. Category pills filter hundreds of channels in a tap.

- **Near-instant channel switching** — 250 ms playback start with aggressive buffering and direct media swap. No spinner, no black flash.
- **Live hero preview** — Full video preview with audio while browsing the channel grid. Pauses automatically during fullscreen playback.
- **Smart EPG** — Current and upcoming programme info displayed inline on the hero and in the player overlay.
- **Favorite groups** — Create named groups of channels (Sports, News, Kids) that appear as pills before playlist categories.
- **Configurable grid** — Adjust channels per row and hero banner height from Appearance settings.
- **Channel card layouts** — Four tile styles (name only; logo + name + programme; logo + name; logo only). Optional **global name height** control in **Live TV · Appearance** moves channel names up or down on every tile together.

## Movies & Series

Poster-rich browsing with category rails, detail screens, and one-tap playback. Series drill down to seasons and episodes with consistent artwork.

- **Detail screens** — Play, external player, trailer search (YouTube), and My List toggle on every title.
- **Trailer integration** — In-app YouTube search, opens in the YouTube app for reliable playback.
- **My List** — Save movies, series, and live channels across sessions.
- **VOD resume** — Pick up where you left off, persisted across app restarts.
- **Configurable poster layout** — Adjust posters per row for movies and series independently.
- **VOD watch labels** — Watching, continue watching, and watched (manual + automatic from playback); per-episode labels on series episode tiles; My List pills filter **all** titles with that state for Watched / Continue, or saved favorites for **All**. See **`13-vod-labels-imdb-posters.md`**.
- **IMDb rating on posters** — When the playlist provides a rating, a **star + score** readout appears **top-right** on browse posters, browse hero art, and detail backdrops, with a **soft translucent black** scrim behind it for legibility (not a hard team-colored chip).

## Recording / Catch-up (EPG)

Browse past programmes and play catch-up content from providers that support it. Full EPG timeline with day navigation going back up to 10 days.

- **3-strategy EPG fetch** — Pulls from Xtream `get_simple_data_table`, `get_short_epg`, and locally cached XMLTV data for maximum coverage.
- **Optimized catch-up playback** — Closest-sync seeking, 30-second seek increments, scrub-on-hold with single seek-on-release, optional ±1–3 minute jump buttons from the timeline overlay.
- **Per-playlist configuration** — Choose which categories and channels appear in Recording. Optional catch-up-only filter hides channels without archive support.
- **EPG timezone support** — Toggle between original server time and local time per playlist.
- **TV frame mode** — Optional decorative TV bezel around channel logos in the EPG view.

## Themes

Four hand-crafted visual themes that transform the entire app — backdrop, accents, focus chrome, and UI tinting.

- **Cosmic** — Cyan and deep space blues with violet nebula washes.
- **Aurora** — Purple and pink with magenta light leaks.
- **Solar** — Electric yellow, gold, and amber neon.
- **Heritage** — Champagne gold, wine burgundy, and midnight blue elegance.

Every screen uses the `CosmicSpaceBackdrop` — a layered composition of deep gradients, nebula blobs, a deterministic starfield, and soft light leaks. No flat backgrounds anywhere.

## Top Menu Manager

Full control over the navigation bar. Reorder core categories, add optional items, and choose which screen greets you on launch.

- **Core items** — Live TV, Movies, Series, Recording are always present. Drag to reorder.
- **Optional items** — Playlist switcher, Theme, Clock, Appearance, Backup, and Favorite Setup can each be added to or removed from the top bar.
- **Startup category** — Any visible menu item can be set as the default screen on app launch.
- **Settings lock** — Settings always stays last in the menu, non-removable.

## Appearance

All layout and style settings on one compact page — no sub-screen navigation needed for card styles.

- **Layout editors** — Adjust Live TV hero height, channels per row, and movie/series posters per row with visual slider bars.
- **Card style selectors** — Channel, Movie, and Series card styles (e.g., logo + name + programme, poster + title) are inline icon chips — apply instantly on the full-screen preview.
- **Movies · Appearance** — Opens the **Movie Grid Settings** card over a live movies preview: posters per row, poster display modes, exit, and reset. **Hide** tucks the card away so you can see the full browse layout; **Show** brings the card back. The panel uses a brushed slate look, strong frame, and TV-safe focus order (see **`05-ui-shell-and-tv-patterns.md`**).
- **Live TV name position** — Inside **Live TV · Appearance**, the **Tiles** control has a second row (**Name**) to nudge channel names vertically on the whole grid (saved automatically).
- **Single-page design** — Everything fits on screen without scrolling, with room for future additions.

## Clock Overlay

An optional floating clock that lives on top of every screen — because sometimes you need to know the time without leaving your show.

- **12 or 24 hour format**
- **Four screen corners** — Position it wherever you want.
- **Three sizes** — Small, medium, large.
- **Adjustable opacity** — 25%, 50%, 75%, 100%.
- **Eight color presets** — Including three neon options with a 7-segment DSEG font.
- **Optional frame** — Adds a border and date display under the time.

## Playlist Management

Multi-playlist support with a quick-switcher in the top bar.

- **Xtream Codes and M3U** — Add playlists by server URL or M3U file.
- **Quick switcher** — Tap the Playlist button in the top bar to switch between playlists without going to Settings.
- **Group visibility** — Show or hide categories per playlist across Live TV, Movies, and Series.

## Backup & Restore

Never lose your setup. Full settings export that survives uninstall, device migration, or sharing with friends.

- **Personal backup** — Complete copy including credentials. For your own device transfer.
- **Share backup** — Passwords stripped. Safe to send to others.
- **Survives uninstall** — Saved to public Downloads, not app-private storage.
- **One-tap restore** — Import scans your entire Downloads folder recursively. Finds your backup wherever it is.
- **Everything included** — Playlists, favorites, card styles, clock settings, theme, layout preferences, **group visibility** (show/hide categories, aliases, **Live TV** pill order before/after favorites), recording setup, top menu configuration, My List, and My Space sections.

## Player

Native ExoPlayer integration for reliable, high-performance playback on every Android TV device.

- **Hardware-accelerated decoding** — Extension renderers preferred for fastest decode startup.
- **Correct video aspect ratio** — Letterbox/pillarbox with centered texture. No stretching.
- **Live channel lineup** — Switch channels with Up/Down while watching.
- **VOD controls** — D-pad seek with 30-second steps, hold-to-scrub with visual timeline feedback, tap center for pause/play.
- **Minute jumps** — With the timeline open, a second Down focuses a compact row: ±15s, ±1 / ±2 / ±3 minute jumps and play/pause; **Settings** sits on the **far right** (OK opens the same in-player settings as Live TV). Single hardware key path so seeks stay accurate.
- **EPG in player** — Current programme info displayed in the live overlay.
- **Retry on error** — Transient failures auto-retry; fatal errors show a clear overlay with Back navigation.

## Built for TV

Every pixel designed for the 10-foot experience.

- **Remote-first navigation** — D-pad, Back key, and OK button work everywhere. No mouse required.
- **Focus management** — Predictable focus rings, auto-focus on first actionable items, focus restoration after screen transitions.
- **TV-safe margins** — Content stays within the safe zone on all displays.
- **Performance-conscious** — Aggressive buffering, minimal spinner display, fast transitions. Tested on NVIDIA Shield, Fire TV, ONN, Chromecast, and budget Android TV sticks.

---

*IPTVIL — Your channels, your way.*
