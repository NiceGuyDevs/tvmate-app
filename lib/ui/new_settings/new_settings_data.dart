/// 1:1 port of the `CATS` / `THEMES` / `LANGS` / `SUB_LANGS` arrays from
/// `settings.html` (lines 4055–4673 of the reference file).
///
/// Every `id`, `label`, `sub` and default `value` is copied verbatim from the
/// HTML. Runtime-computed strings that the HTML expresses as `valueFn: () =>
/// ...` closures are ported as `NsRow.valueFn` callbacks returning the same
/// text. Icons that the HTML defines as inline SVG strings inside the `ICON`
/// map are mapped here to the closest Material icon — see the
/// per-category `iconBuilder` at the bottom of this file for the mapping
/// table. (A later polish phase can swap these for the real SVGs via
/// `flutter_svg`; the code in this file does not depend on which renderer is
/// used.)
library;

import 'package:flutter/material.dart';

import '../../data/playlist_type.dart' as data_pt;
import '../../data/stored_playlist.dart' show StoredPlaylist;
import 'new_settings_state.dart';

/// One row inside a category group. `kind` mirrors the HTML row `kind` field
/// exactly: `toggle`, `choice`, `page`, `action`.
enum NsRowKind { toggle, choice, page, action }

/// Option for a `choice` row — maps to `{ id, label, sub?, swatch? }` in the
/// HTML. `swatch` is a color applied in front of the label (used by the
/// Theme row and similar colored-radio sheets).
class NsOption {
  const NsOption({
    required this.id,
    required this.label,
    this.sub,
    this.swatch,
  });

  final String id;
  final String label;
  final String? sub;
  final Color? swatch;
}

/// A single row inside a category group. Fields are intentionally named and
/// ordered to match the HTML row objects so diffing against `settings.html`
/// stays straightforward.
class NsRow {
  const NsRow({
    required this.id,
    required this.kind,
    required this.title,
    this.sub,
    this.badge,
    this.danger = false,
    this.value,
    this.valueFn,
    this.options,
    this.optionsFn,
    this.page,
    this.action,
    this.defaultBool = false,
  });

  final String id;
  final NsRowKind kind;
  final String title;
  final String? sub;

  /// Optional small pill after the title (`badge:'PRO'` in the HTML).
  final String? badge;

  /// `danger:true` in the HTML — red text + red focus ring.
  final bool danger;

  /// Static starting value for `choice` rows (option id) or display text for
  /// `page` rows. `valueFn` wins over `value` when both are set.
  final String? value;

  /// Dynamic value for rows where the HTML uses `valueFn: () => ...`. Called
  /// on every paint. Receives the state so it can read e.g. the current
  /// clock size label.
  final String Function(NewSettingsState state)? valueFn;

  /// Static options for `choice` rows, or null when [optionsFn] is set.
  final List<NsOption>? options;

  /// Dynamic options (used by `startup` which reads the current TOPMENU).
  final List<NsOption> Function(NewSettingsState state)? optionsFn;

  /// Target page id for `kind: page` rows.
  final String? page;

  /// Action id for `kind: action` rows (e.g. `resetAll`, `clearAll`).
  final String? action;

  /// Default bool for `toggle` rows (the HTML uses `value: true / false`).
  final bool defaultBool;
}

/// A labelled group inside a category. `label` is null on the single-group
/// categories in the HTML (Playback); non-null otherwise.
class NsGroup {
  const NsGroup({this.label, required this.rows});

  final String? label;
  final List<NsRow> rows;
}

/// Landing page hint for "landing" categories (Playlists, Favorites in the
/// HTML). When set, the category's right-pane immediately renders the named
/// sub-page instead of a group list.
class NsLanding {
  const NsLanding({required this.page});

  final String page;
}

/// A top-level category — renders one button in the left rail and one
/// content view in the right detail pane.
class NsCategory {
  const NsCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.eyebrow,
    required this.desc,
    this.groups = const [],
    this.landing,
    this.metaFn,
  });

  final String id;
  final IconData icon;
  final String title;
  final String eyebrow;
  final String desc;
  final List<NsGroup> groups;
  final NsLanding? landing;

  /// Rail meta badge (count) — the HTML's `metaFn: () => PLAYLISTS.length`.
  final int Function(NewSettingsState state)? metaFn;
}

// ─── THEMES (lines 4055–4065 of settings.html) ───────────────────────────

const List<NsOption> kNsThemes = [
  NsOption(
    id: 'settingsStyle',
    label: 'Settings style',
    sub: 'Cyan chrome + settings.html backdrop',
    swatch: Color(0xFF4DD0E1),
  ),
  NsOption(
    id: 'ember',
    label: 'Ember',
    sub: 'Warm shell + coral / ember focus',
    swatch: Color(0xFFFF8A65),
  ),
  NsOption(
    id: 'nocturne',
    label: 'Nocturne',
    sub: 'Dark purple–rose shell, neon-pink focus',
    swatch: Color(0xFFFF2A9A),
  ),
];

// ─── LANGS (line 4066) ───────────────────────────────────────────────────

const List<NsOption> kNsLangs = [
  NsOption(
    id: 'en',
    label: 'English',
    sub: 'All UI text and dialogs (en)',
  ),
  NsOption(
    id: 'he',
    label: 'עברית',
    sub: 'Hebrew (he)',
  ),
  NsOption(
    id: 'fr',
    label: 'Français',
    sub: 'French (fr)',
  ),
  NsOption(
    id: 'es',
    label: 'Español',
    sub: 'Spanish (es)',
  ),
  NsOption(
    id: 'ar',
    label: 'العربية',
    sub: 'Arabic (ar)',
  ),
];

// ─── SUB_LANGS (lines 4070–4074) ─────────────────────────────────────────
// Two-line options (label + sub) match Performance mode option tiles in
// the expanded choice sheet. ISO code stays on the sub line.

const List<NsOption> kNsSubLangs = [
  NsOption(
    id: 'en',
    label: 'English',
    sub: 'OpenSubtitles & VOD default (en)',
  ),
  NsOption(
    id: 'he',
    label: 'Hebrew',
    sub: 'OpenSubtitles & VOD default (he)',
  ),
  NsOption(
    id: 'es',
    label: 'Spanish',
    sub: 'OpenSubtitles & VOD default (es)',
  ),
  NsOption(
    id: 'fr',
    label: 'French',
    sub: 'OpenSubtitles & VOD default (fr)',
  ),
  NsOption(
    id: 'ar',
    label: 'Arabic',
    sub: 'OpenSubtitles & VOD default (ar)',
  ),
  NsOption(
    id: 'de',
    label: 'German',
    sub: 'OpenSubtitles & VOD default (de)',
  ),
  NsOption(
    id: 'it',
    label: 'Italian',
    sub: 'OpenSubtitles & VOD default (it)',
  ),
  NsOption(
    id: 'pt',
    label: 'Portuguese',
    sub: 'OpenSubtitles & VOD default (pt)',
  ),
  NsOption(
    id: 'ru',
    label: 'Russian',
    sub: 'OpenSubtitles & VOD default (ru)',
  ),
  NsOption(
    id: 'nl',
    label: 'Dutch',
    sub: 'OpenSubtitles & VOD default (nl)',
  ),
  NsOption(
    id: 'pl',
    label: 'Polish',
    sub: 'OpenSubtitles & VOD default (pl)',
  ),
  NsOption(
    id: 'tr',
    label: 'Turkish',
    sub: 'OpenSubtitles & VOD default (tr)',
  ),
];

// ─── TOPMENU (lines 4457–4463) ───────────────────────────────────────────
// Ports the HTML's `TOPMENU` constant. `fixed: true` entries cannot be
// removed from the menu; the rest are optional and can be toggled via the
// "Top menu items & order" sub-page.

class NsTopMenuItem {
  const NsTopMenuItem({
    required this.id,
    required this.label,
    required this.fixed,
  });

  final String id;
  final String label;
  final bool fixed;
}

/// Default TOPMENU layout. Mutable copies live on [NewSettingsState]
/// (see `state.topMenu`) so the user's reorder / add / remove actions
/// in the sub-page are preserved across re-renders without touching
/// this seed list.
const List<NsTopMenuItem> kNsTopMenuDefault = [
  NsTopMenuItem(id: 'liveTv', label: 'Live TV', fixed: true),
  NsTopMenuItem(id: 'movies', label: 'Movies', fixed: true),
  NsTopMenuItem(id: 'series', label: 'Series', fixed: true),
  NsTopMenuItem(id: 'recording', label: 'Catch-up', fixed: true),
  NsTopMenuItem(id: 'favorites', label: 'Favorites', fixed: false),
  NsTopMenuItem(id: 'team', label: 'Theme', fixed: false),
  NsTopMenuItem(id: 'playlist', label: 'Playlist', fixed: false),
];

/// Available optional items — HTML `TOPMENU_AVAILABLE` at line 4465.
const List<NsTopMenuItem> kNsTopMenuAvailable = [
  NsTopMenuItem(id: 'clock', label: 'Clock', fixed: false),
  NsTopMenuItem(id: 'appearance', label: 'Appearance', fixed: false),
  NsTopMenuItem(id: 'backup', label: 'Backup', fixed: false),
  NsTopMenuItem(id: 'language', label: 'Language', fixed: false),
];

/// Thin shim so the rest of the code base (e.g. the `startup` choice row)
/// can still consume TOPMENU as a list of `NsOption`. The underlying data
/// is whatever the state currently has.
List<NsOption> nsTopMenuAsOptions(List<NsTopMenuItem> items) =>
    items.map((i) => NsOption(id: i.id, label: i.label)).toList();

// ─── Appearance editor (settings.html lines 5200–5244) ──────────────────

class NsApTab {
  const NsApTab({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// Top tab strip inside the Appearance sub-page.
const List<NsApTab> kNsApTabs = [
  NsApTab(id: 'liveTv', label: 'Live TV', icon: Icons.live_tv_rounded),
  NsApTab(id: 'heroBg', label: 'Hero background', icon: Icons.image_rounded),
  NsApTab(id: 'movies', label: 'Movies', icon: Icons.movie_rounded),
  NsApTab(id: 'series', label: 'Series', icon: Icons.video_library_rounded),
];

/// Live TV channel card style options.
const List<NsOption> kNsApLiveCardStyles = [
  NsOption(id: 'nameOnly', label: 'Name only'),
  NsOption(id: 'logoNameEpg', label: 'Logo + name + EPG'),
  NsOption(id: 'logoName', label: 'Logo + name'),
  NsOption(id: 'logoOnly', label: 'Logo only'),
];

/// Movies / Series poster display options.
const List<NsOption> kNsApMediaStyles = [
  NsOption(id: 'poster', label: 'Poster only'),
  NsOption(id: 'posterTitle', label: 'Poster + title'),
  NsOption(id: 'posterTitleYear', label: 'Poster + title + year'),
];

class NsApSwatch {
  const NsApSwatch({required this.value, required this.name});
  final Color value;
  final String name;
}

const List<NsApSwatch> kNsApBgColors = [
  NsApSwatch(value: Color(0xFF0F1B2A), name: 'Deep blue'),
  NsApSwatch(value: Color(0xFF0D1119), name: 'Charcoal'),
  NsApSwatch(value: Color(0xFF1A1A2E), name: 'Plum night'),
  NsApSwatch(value: Color(0xFF102019), name: 'Forest'),
  NsApSwatch(value: Color(0xFF1F1010), name: 'Ember'),
  NsApSwatch(value: Color(0xFF190E22), name: 'Royal'),
];

const List<NsApSwatch> kNsApOverlayColors = [
  NsApSwatch(value: Color(0xFF4DD0E1), name: 'Cyan'),
  NsApSwatch(value: Color(0xFF7AA2F7), name: 'Blue'),
  NsApSwatch(value: Color(0xFFA78BFA), name: 'Violet'),
  NsApSwatch(value: Color(0xFFF472B6), name: 'Pink'),
  NsApSwatch(value: Color(0xFFFBBF24), name: 'Amber'),
  NsApSwatch(value: Color(0xFF34D399), name: 'Mint'),
];

const List<NsOption> kNsApBezels = [
  NsOption(id: 'off', label: 'Off'),
  NsOption(id: 'slim', label: 'Slim'),
  NsOption(id: 'cinema', label: 'Cinema'),
];

const List<NsOption> kNsApWashes = [
  NsOption(id: 'solid', label: 'Solid'),
  NsOption(id: 'brush', label: 'Brush'),
];

/// Defaults applied by the "Reset section" button — scoped per tab. Mirrors
/// `AP_DEFAULTS` at settings.html line 5239.
class NsApDefaults {
  const NsApDefaults._();

  static const int liveTvHero = 60;
  static const int liveTvCols = 6;
  static const String liveTvCardStyle = 'logoName';

  static const int heroBgGradient = 50;
  static const String heroBgBgColor = '#0F1B2A';
  static const String heroBgWash = 'solid';
  static const String heroBgOverlayColor = '#4DD0E1';
  static const String heroBgBezel = 'cinema';

  static const int mediaPerRow = 8;
  static const String mediaCardStyle = 'poster';
}

// ─── Clock overlay (settings.html lines 4715–4743) ──────────────────────

class NsClockColor {
  const NsClockColor({
    required this.name,
    required this.hex,
    required this.led,
  });

  final String name;

  /// Always an uppercase `#RRGGBB`.
  final String hex;

  /// LED colors switch the preview to the DSEG7 Classic 7-segment font —
  /// mirroring the HTML's `useSegmentDigitFont` check at runtime.
  final bool led;
}

/// Clock preset swatches — ports `CLOCK_COLORS` at settings.html line 4715.
const List<NsClockColor> kNsClockColors = [
  NsClockColor(name: 'White', hex: '#F5F5F5', led: false),
  NsClockColor(name: 'Sky blue', hex: '#7DD3FC', led: false),
  NsClockColor(name: 'Yellow', hex: '#FDE047', led: false),
  NsClockColor(name: 'Mint', hex: '#86EFAC', led: false),
  NsClockColor(name: 'Pink', hex: '#F472B6', led: false),
  NsClockColor(name: 'Neon red', hex: '#FF2A6D', led: true),
  NsClockColor(name: 'Neon green', hex: '#39FF14', led: true),
  NsClockColor(name: 'Neon yellow', hex: '#FFEA00', led: true),
];

/// Continuous-size range (settings.html lines 4730–4732).
const int kNsClockSizeMin = 10;
const int kNsClockSizeMax = 40;

/// Canonical preset sizes — the S/M/L buttons snap the slider to these.
const int kNsClockSizeSmall = 15;
const int kNsClockSizeMedium = 19;
const int kNsClockSizeLarge = 24;

/// Returns the human-readable label for a clock font size.
String nsClockSizeLabel(int px) {
  if (px == kNsClockSizeSmall) return 'Small';
  if (px == kNsClockSizeMedium) return 'Medium';
  if (px == kNsClockSizeLarge) return 'Large';
  return '${px}px';
}

/// True when [hex] is one of the LED preset colors — triggers DSEG 7-seg
/// font on the clock preview.
bool nsClockIsLed(String hex) {
  final low = hex.toLowerCase();
  for (final c in kNsClockColors) {
    if (c.led && c.hex.toLowerCase() == low) return true;
  }
  return false;
}

/// Find a preset by hex; null for a custom value.
NsClockColor? nsClockColorByHex(String hex) {
  final low = hex.toLowerCase();
  for (final c in kNsClockColors) {
    if (c.hex.toLowerCase() == low) return c;
  }
  return null;
}

const List<NsOption> kNsClockFormats = [
  NsOption(id: '12', label: '12h'),
  NsOption(id: '24', label: '24h'),
];

/// Corner picker options — same four IDs the HTML's `.cp-corner` uses.
const Map<String, String> kNsClockCornerLabels = {
  'tl': 'Top-left',
  'tr': 'Top-right',
  'bl': 'Bottom-left',
  'br': 'Bottom-right',
};

/// Swatch name lookup — used for the Hero BG tab meta string.
String? nsApSwatchName(List<NsApSwatch> swatches, String hex) {
  for (final s in swatches) {
    final h = '#${s.value.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    if (h.toLowerCase() == hex.toLowerCase()) return s.name;
  }
  return null;
}

// ─── Playlists (settings.html lines 4393–4444) ───────────────────────────
//
// Full one-to-one shape — including `groups` (live / vod / series) and
// `channels_map` (category id → channels). Every field the HTML reads
// (to render the landing grid, detail hero, groups manager, channels
// overrides, recording approvals) has a corresponding field here.
//
// All values are preview-only; nothing here interacts with the real
// `lib/data/library_controller.dart`.

enum NsPlaylistType { xtream, m3u }

enum NsPlaylistStatus { ok, syncing, error }

class NsPlaylistGroup {
  NsPlaylistGroup({
    required this.id,
    required this.name,
    this.alias,
    this.visible = true,
    this.beforeFav = false,
  });

  final String id;
  String name;
  String? alias;
  bool visible;

  /// Live-only flag: "order this group before Favorites in the nav".
  bool beforeFav;
}

class NsPlaylistChannel {
  NsPlaylistChannel({
    required this.id,
    required this.name,
    this.alias,
    this.logo,
    this.hidden = false,
    this.catchup = true,
  });

  final String id;
  String name;
  String? alias;
  String? logo;
  bool hidden;

  /// Whether the source advertises catch-up for this channel. The
  /// HTML mock flips every 4th channel to `false` (`(i % 4) !== 3`)
  /// — we wire that in the seed helpers so the Recording page's
  /// catch-up filter + "No catch-up" pills behave identically.
  bool catchup;
}

class NsPlaylist {
  NsPlaylist({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.vod,
    required this.series,
    required this.status,
    required this.lastSync,
    required this.active,
    required this.epgMode,
    required this.groups,
    required this.channelsMap,
    this.liveChannelsCount,
  });

  final String id;
  String name;
  NsPlaylistType type;
  String url;

  /// Denormalized VOD / series counts. Channels count is derived from
  /// [channelsMap] so it stays consistent with hide/unhide edits.
  int vod;
  int series;

  NsPlaylistStatus status;
  String lastSync;
  bool active;

  /// `'local'`, `'original'`, or an IANA zone id — see [kNsEpgZones].
  String epgMode;

  /// Groups per section — keys: `'live'`, `'vod'`, `'series'`.
  final Map<String, List<NsPlaylistGroup>> groups;

  /// channelsMap[categoryId] = [channels]. Used by "Manage channels"
  /// flow and for computing total/hidden/renamed counts.
  final Map<String, List<NsPlaylistChannel>> channelsMap;

  /// From [StoredPlaylist.liveCount] when [channelsMap] is not materialized.
  final int? liveChannelsCount;

  /// Total live channels across every category.
  int get channels {
    if (channelsMap.isEmpty && liveChannelsCount != null) {
      return liveChannelsCount!;
    }
    var total = 0;
    for (final list in channelsMap.values) {
      total += list.length;
    }
    return total;
  }

  int get renamedChannelsCount {
    var n = 0;
    for (final list in channelsMap.values) {
      for (final c in list) {
        if (c.alias != null) n++;
      }
    }
    return n;
  }

  int get hiddenChannelsCount {
    var n = 0;
    for (final list in channelsMap.values) {
      for (final c in list) {
        if (c.hidden) n++;
      }
    }
    return n;
  }
}

/// Snap a real [StoredPlaylist] into [NsPlaylist], preserving
/// [previous] group/channel editor maps when non-null.
NsPlaylist buildNsPlaylistFromStored(
  StoredPlaylist stored, {
  required String epgMode,
  required bool isActive,
  NsPlaylist? previous,
}) {
  final type = stored.type == data_pt.PlaylistType.xtream
      ? NsPlaylistType.xtream
      : NsPlaylistType.m3u;
  final url = stored.isXtream
      ? (stored.serverUrl ?? '')
      : (stored.m3uUrl ?? '');

  final Map<String, List<NsPlaylistGroup>> groups;
  final Map<String, List<NsPlaylistChannel>> channelsMap;
  if (previous != null) {
    groups = previous.groups;
    channelsMap = previous.channelsMap;
  } else {
    groups = {
      'live': <NsPlaylistGroup>[],
      'vod': <NsPlaylistGroup>[],
      'series': <NsPlaylistGroup>[],
    };
    channelsMap = <String, List<NsPlaylistChannel>>{};
  }

  return NsPlaylist(
    id: stored.id,
    name: stored.name,
    type: type,
    url: url,
    vod: stored.moviesCount,
    series: stored.seriesCount,
    status: NsPlaylistStatus.ok,
    lastSync: '—',
    active: isActive,
    epgMode: epgMode,
    groups: groups,
    channelsMap: channelsMap,
    liveChannelsCount: stored.liveCount,
  );
}

/// Helper used by the default-seed builder below.
List<NsPlaylistGroup> _seedGroups(List<String> names) {
  final gs = <NsPlaylistGroup>[];
  for (var i = 0; i < names.length; i++) {
    gs.add(NsPlaylistGroup(
      id: 'g-${names[i].replaceAll(' ', '-').toLowerCase()}-$i',
      name: names[i],
      visible: true,
    ));
  }
  return gs;
}

Map<String, List<NsPlaylistChannel>> _seedChannels(
  List<NsPlaylistGroup> liveGroups,
  Map<String, List<String>> namesByGroupName,
) {
  final map = <String, List<NsPlaylistChannel>>{};
  for (final g in liveGroups) {
    final names = namesByGroupName[g.name] ?? const <String>[];
    final list = <NsPlaylistChannel>[];
    for (var i = 0; i < names.length; i++) {
      list.add(NsPlaylistChannel(
        id: '${g.id}-c$i',
        name: names[i],
        // Deterministic mock from `makeChannels` (settings.html line 4123):
        // every 4th channel has no catch-up signal.
        catchup: (i % 4) != 3,
      ));
    }
    map[g.id] = list;
  }
  return map;
}

/// Five mock playlists — one-to-one with settings.html PLAYLISTS at
/// line 4393. Full `groups` + `channels_map` shape so every downstream
/// sub-page (groups manager · channel overrides · recording) has real
/// data to render against.
List<NsPlaylist> nsDefaultPlaylists() {
  // ─── Family Pack — Xtream, active, mixed catalog ──────────────────
  final p1Live = _seedGroups(const [
    'News', 'Sports', 'Movies HD', 'Kids', 'Family', 'Documentary',
    'Music', 'Lifestyle', 'General', 'International', 'Regional', 'Religious',
  ]);
  final p1Channels = _seedChannels(p1Live, const {
    'News': ['BBC News', 'CNN', 'Sky News', 'Al Jazeera', 'Euronews'],
    'Sports': ['Sky Sports 1', 'Sky Sports 2', 'BT Sport 1', 'ESPN', 'Eurosport 1', 'Eurosport 2'],
    'Movies HD': ['HBO', 'Cinemax', 'Showtime', 'Paramount HD', 'Universal HD'],
    'Kids': ['Cartoon Network', 'Nickelodeon', 'Disney Jr', 'Disney XD'],
    'Family': ['Hallmark', 'Lifetime', 'TLC'],
    'Documentary': ['National Geographic', 'Discovery', 'Animal Planet', 'History'],
    'Music': ['MTV', 'VH1', 'MTV Live', 'Kiss TV'],
    'Lifestyle': ['Food Network', 'HGTV', 'Travel Channel'],
    'General': ['ABC', 'NBC', 'CBS', 'Fox'],
    'International': ['TV5Monde', 'DW English', 'RT', 'NHK World'],
    'Regional': ['ITV', 'Channel 4', 'Channel 5'],
    'Religious': ['EWTN', 'TBN'],
  });

  // ─── UK Free-to-Air — M3U, syncing, Live only ─────────────────────
  final p2Live = _seedGroups(const [
    'Freeview', 'News UK', 'Kids UK', 'Sports UK', 'Regional',
  ]);
  final p2Channels = _seedChannels(p2Live, const {
    'Freeview': ['BBC One', 'BBC Two', 'ITV', 'Channel 4', 'Channel 5', 'E4', 'More 4', 'Film 4'],
    'News UK': ['BBC News', 'Sky News UK', 'GB News'],
    'Kids UK': ['CBeebies', 'CBBC', 'CITV'],
    'Sports UK': ['BBC Sport', 'ITV Sport'],
    'Regional': ['STV', 'UTV', 'S4C'],
  });

  // ─── Sports HD — Xtream, auth failed ──────────────────────────────
  final p3Live = _seedGroups(const [
    'Football', 'Basketball', 'American Football', 'Combat', 'Cricket',
    'Motorsport', 'Tennis', 'Golf', 'Sports 4K',
  ]);
  final p3Channels = _seedChannels(p3Live, const {
    'Football': ['Premier League 1', 'Premier League 2', 'La Liga', 'Bundesliga', 'Serie A', 'Ligue 1'],
    'Basketball': ['NBA TV', 'ESPN NBA', 'EuroLeague'],
    'American Football': ['NFL Network', 'ESPN NFL', 'Red Zone'],
    'Combat': ['UFC', 'Boxing TV', 'Fight Network'],
    'Cricket': ['Star Sports 1', 'Willow HD'],
    'Motorsport': ['F1 HD', 'MotoGP HD'],
    'Tennis': ['Tennis Channel'],
    'Golf': ['Golf Channel'],
    'Sports 4K': ['Sky Sports 4K'],
  });

  // ─── Premium 4K — Xtream, small but premium ───────────────────────
  final p4Live = _seedGroups(const [
    '4K Movies', '4K Sports', '4K Documentary', '4K Lifestyle',
  ]);
  final p4Channels = _seedChannels(p4Live, const {
    '4K Movies': ['HBO 4K', 'Paramount 4K', 'Universal 4K', 'Cinemax 4K'],
    '4K Sports': ['Sky Sports 4K', 'ESPN 4K', 'Eurosport 4K'],
    '4K Documentary': ['Nat Geo 4K', 'Discovery 4K'],
    '4K Lifestyle': ['HGTV 4K', 'Food Network 4K'],
  });

  // ─── Latino Mega Pack — M3U, broad ────────────────────────────────
  final p5Live = _seedGroups(const [
    'Deportes', 'Fútbol', 'Noticias', 'Películas', 'Infantil',
    'Telenovelas', 'Música', 'Internacional',
  ]);
  final p5Channels = _seedChannels(p5Live, const {
    'Deportes': ['ESPN Latino', 'Fox Deportes', 'TUDN', 'TyC Sports'],
    'Fútbol': ['Gol TV', 'Fox Sports Premium', 'DirecTV Sports'],
    'Noticias': ['Telemundo Noticias', 'Univision Noticias', 'CNN Español'],
    'Películas': ['HBO Latino', 'Cinemax Latino', 'Cinecanal'],
    'Infantil': ['Cartoon Network LA', 'Nickelodeon LA', 'Discovery Kids LA'],
    'Telenovelas': ['Telemundo', 'Univision', 'Caracol'],
    'Música': ['MTV LA', 'HTV', 'Ritmoson'],
    'Internacional': ['TV5Monde', 'DW Español'],
  });

  return [
    NsPlaylist(
      id: 'p1',
      name: 'Family Pack',
      type: NsPlaylistType.xtream,
      url: 'http://provider.tv:8080/get.php?username=family&password=••••••',
      vod: 7321,
      series: 412,
      status: NsPlaylistStatus.ok,
      lastSync: '2 min ago',
      active: true,
      epgMode: 'local',
      groups: {
        'live': p1Live,
        'vod': _seedGroups(const [
          'Action', 'Comedy', 'Drama', 'Thriller', 'Horror', 'Sci-Fi',
          'Family', 'Romance', 'Documentary', 'Animation', 'Crime', 'War',
        ]),
        'series': _seedGroups(const [
          'Drama', 'Comedy', 'Sci-Fi', 'Crime', 'Animated', 'Reality',
          'Mini-Series', 'Anime',
        ]),
      },
      channelsMap: p1Channels,
    ),
    NsPlaylist(
      id: 'p2',
      name: 'UK Free-to-Air',
      type: NsPlaylistType.m3u,
      url: 'https://iptv-org.github.io/lists/uk.m3u',
      vod: 0,
      series: 0,
      status: NsPlaylistStatus.syncing,
      lastSync: 'syncing…',
      active: false,
      epgMode: 'Europe/London',
      groups: {
        'live': p2Live,
        'vod': <NsPlaylistGroup>[],
        'series': <NsPlaylistGroup>[],
      },
      channelsMap: p2Channels,
    ),
    NsPlaylist(
      id: 'p3',
      name: 'Sports HD',
      type: NsPlaylistType.xtream,
      url: 'http://sports.example/get.php?username=sport&password=••••••',
      vod: 0,
      series: 0,
      status: NsPlaylistStatus.error,
      lastSync: 'auth failed',
      active: false,
      epgMode: 'America/New_York',
      groups: {
        'live': p3Live,
        'vod': <NsPlaylistGroup>[],
        'series': <NsPlaylistGroup>[],
      },
      channelsMap: p3Channels,
    ),
    NsPlaylist(
      id: 'p4',
      name: 'Premium 4K',
      type: NsPlaylistType.xtream,
      url: 'http://uhd.example/get.php?username=uhd&password=••••••',
      vod: 1820,
      series: 96,
      status: NsPlaylistStatus.ok,
      lastSync: 'just now',
      active: false,
      epgMode: 'Europe/London',
      groups: {
        'live': p4Live,
        'vod': _seedGroups(const [
          '4K Action', '4K Drama', '4K Family', '4K Horror', '4K Sci-Fi',
          '4K Documentary',
        ]),
        'series': _seedGroups(const ['4K Drama', '4K Comedy', '4K Anime']),
      },
      channelsMap: p4Channels,
    ),
    NsPlaylist(
      id: 'p5',
      name: 'Latino Mega Pack',
      type: NsPlaylistType.m3u,
      url: 'https://provider.example/latino.m3u',
      vod: 3210,
      series: 240,
      status: NsPlaylistStatus.ok,
      lastSync: '12 min ago',
      active: false,
      epgMode: 'America/Mexico_City',
      groups: {
        'live': p5Live,
        'vod': _seedGroups(const [
          'Acción Latino', 'Comedia Latino', 'Drama Latino', 'Familiar',
          'Romance', 'Terror', 'Cine Mexicano', 'Cine Sudamericano',
        ]),
        'series': _seedGroups(const [
          'Telenovelas', 'Series Latino', 'Comedia Latino', 'Drama Latino',
        ]),
      },
      channelsMap: p5Channels,
    ),
  ];
}

/// Count groups currently marked visible in a section.
int nsVisibleGroupsCount(NsPlaylist p, String section) {
  final list = p.groups[section] ?? const <NsPlaylistGroup>[];
  return list.where((g) => g.visible).length;
}

// ─── EPG zones (settings.html EPG_ZONES, line 4077) ──────────────────────

class NsEpgZone {
  const NsEpgZone({
    required this.id,
    required this.label,
    required this.chip,
    required this.group,
    required this.offset,
  });

  final String id;
  final String label;
  final String chip;

  /// One of `'Europe'`, `'Asia'`, `'Americas'`, `'Africa'`, `'Oceania'`.
  /// Used to render the dropdown's grouped section headers.
  final String group;

  /// Pretty UTC offset like `+01:00`, `−05:00`, `±0:00`.
  final String offset;
}

/// EPG zone catalog — superset of the dropdown menu items rendered by
/// `openEpgMenu` at settings.html line 6423. Each entry is also used by
/// the card's EPG label (via [nsEpgLabel]).
const List<NsEpgZone> kNsEpgZones = [
  // Europe
  NsEpgZone(id: 'Europe/London', label: 'London', chip: 'UK', group: 'Europe', offset: '±0:00'),
  NsEpgZone(id: 'Europe/Dublin', label: 'Dublin', chip: 'IE', group: 'Europe', offset: '±0:00'),
  NsEpgZone(id: 'Europe/Paris', label: 'Paris', chip: 'FR', group: 'Europe', offset: '+01:00'),
  NsEpgZone(id: 'Europe/Berlin', label: 'Berlin', chip: 'DE', group: 'Europe', offset: '+01:00'),
  NsEpgZone(id: 'Europe/Madrid', label: 'Madrid', chip: 'ES', group: 'Europe', offset: '+01:00'),
  NsEpgZone(id: 'Europe/Rome', label: 'Rome', chip: 'IT', group: 'Europe', offset: '+01:00'),
  NsEpgZone(id: 'Europe/Amsterdam', label: 'Amsterdam', chip: 'NL', group: 'Europe', offset: '+01:00'),
  NsEpgZone(id: 'Europe/Athens', label: 'Athens', chip: 'GR', group: 'Europe', offset: '+02:00'),
  NsEpgZone(id: 'Europe/Bucharest', label: 'Bucharest', chip: 'RO', group: 'Europe', offset: '+02:00'),
  NsEpgZone(id: 'Europe/Moscow', label: 'Moscow', chip: 'RU', group: 'Europe', offset: '+03:00'),
  NsEpgZone(id: 'Europe/Istanbul', label: 'Istanbul', chip: 'TR', group: 'Europe', offset: '+03:00'),

  // Asia
  NsEpgZone(id: 'Asia/Jerusalem', label: 'Israel', chip: 'IL', group: 'Asia', offset: '+02:00'),
  NsEpgZone(id: 'Asia/Dubai', label: 'Dubai', chip: 'DXB', group: 'Asia', offset: '+04:00'),
  NsEpgZone(id: 'Asia/Riyadh', label: 'Riyadh', chip: 'KSA', group: 'Asia', offset: '+03:00'),
  NsEpgZone(id: 'Asia/Karachi', label: 'Karachi', chip: 'PK', group: 'Asia', offset: '+05:00'),
  NsEpgZone(id: 'Asia/Kolkata', label: 'India', chip: 'IN', group: 'Asia', offset: '+05:30'),
  NsEpgZone(id: 'Asia/Bangkok', label: 'Bangkok', chip: 'TH', group: 'Asia', offset: '+07:00'),
  NsEpgZone(id: 'Asia/Singapore', label: 'Singapore', chip: 'SG', group: 'Asia', offset: '+08:00'),
  NsEpgZone(id: 'Asia/Hong_Kong', label: 'Hong Kong', chip: 'HK', group: 'Asia', offset: '+08:00'),
  NsEpgZone(id: 'Asia/Tokyo', label: 'Tokyo', chip: 'TYO', group: 'Asia', offset: '+09:00'),
  NsEpgZone(id: 'Asia/Seoul', label: 'Seoul', chip: 'KR', group: 'Asia', offset: '+09:00'),

  // Americas
  NsEpgZone(id: 'America/New_York', label: 'New York', chip: 'NY', group: 'Americas', offset: '−05:00'),
  NsEpgZone(id: 'America/Chicago', label: 'Chicago', chip: 'CHI', group: 'Americas', offset: '−06:00'),
  NsEpgZone(id: 'America/Denver', label: 'Denver', chip: 'DEN', group: 'Americas', offset: '−07:00'),
  NsEpgZone(id: 'America/Los_Angeles', label: 'Los Angeles', chip: 'LA', group: 'Americas', offset: '−08:00'),
  NsEpgZone(id: 'America/Mexico_City', label: 'Mexico City', chip: 'MEX', group: 'Americas', offset: '−06:00'),
  NsEpgZone(id: 'America/Toronto', label: 'Toronto', chip: 'CA', group: 'Americas', offset: '−05:00'),
  NsEpgZone(id: 'America/Sao_Paulo', label: 'São Paulo', chip: 'BR', group: 'Americas', offset: '−03:00'),
  NsEpgZone(id: 'America/Buenos_Aires', label: 'Buenos Aires', chip: 'AR', group: 'Americas', offset: '−03:00'),
  NsEpgZone(id: 'America/Bogota', label: 'Bogotá', chip: 'CO', group: 'Americas', offset: '−05:00'),
  NsEpgZone(id: 'America/Caracas', label: 'Caracas', chip: 'VE', group: 'Americas', offset: '−04:00'),

  // Africa
  NsEpgZone(id: 'Africa/Johannesburg', label: 'Johannesburg', chip: 'ZA', group: 'Africa', offset: '+02:00'),
  NsEpgZone(id: 'Africa/Cairo', label: 'Cairo', chip: 'EG', group: 'Africa', offset: '+02:00'),
  NsEpgZone(id: 'Africa/Lagos', label: 'Lagos', chip: 'NG', group: 'Africa', offset: '+01:00'),

  // Oceania
  NsEpgZone(id: 'Australia/Sydney', label: 'Sydney', chip: 'SYD', group: 'Oceania', offset: '+10:00'),
  NsEpgZone(id: 'Pacific/Auckland', label: 'Auckland', chip: 'NZ', group: 'Oceania', offset: '+12:00'),
];

/// Port of `epgLabel(p)` at settings.html line 4446. Returns the human
/// label for a playlist's EPG mode: "Local time" / "As provided" /
/// zone label / raw id.
String nsEpgLabel(String mode) {
  if (mode.isEmpty || mode == 'local') return 'Local time';
  if (mode == 'original') return 'As provided';
  for (final z in kNsEpgZones) {
    if (z.id == mode) return z.label;
  }
  return mode;
}

// ─── Mock counts (kept for categories w/o their own data yet) ───────────

const int kNsMockFavGroupCount = 3;
const int kNsMockRulesActiveCount = 2;
const String kNsMockLastBackupDate = '2026-04-14';

/// Icon map — lines 4001–4052 of settings.html. Each HTML icon is mapped
/// to the nearest Material icon; the semantic meaning (what the icon
/// represents) is preserved one-for-one. Replacing these with the real
/// inline SVGs later requires only swapping this map.
///
/// Only the icons referenced by phase-1 CATS are listed; others land in
/// later phases as their pages are ported.
class NsIcon {
  const NsIcon._();

  static const IconData playback = Icons.play_arrow_rounded; // ICON.playback
  static const IconData look = Icons.contrast_rounded; // ICON.look
  static const IconData library = Icons.view_list_rounded; // ICON.library
  static const IconData star = Icons.star_outline_rounded; // ICON.star
  static const IconData privacy = Icons.shield_outlined; // ICON.privacy
  static const IconData system = Icons.settings_outlined; // ICON.system
  static const IconData back = Icons.chevron_left_rounded; // ICON.back
  static const IconData chev = Icons.expand_more_rounded; // ICON.chev
  static const IconData search = Icons.search_rounded; // ICON.search
  static const IconData help = Icons.help_outline_rounded;
  static const IconData notif = Icons.notifications_none_rounded;
}

// ─── CATS (lines 4542–4673) ──────────────────────────────────────────────
// One-to-one port. Runtime-computed strings inside `valueFn` closures in
// the HTML are ported as callbacks returning the same text. Empty `groups`
// arrays are kept for landing-page categories (playlists, favorites) so
// the structure matches the HTML exactly.

final List<NsCategory> kNsCats = [
  // 1. Playback (lines 4542–4566)
  NsCategory(
    id: 'playback',
    icon: NsIcon.playback,
    title: 'Playback',
    eyebrow: 'Playback',
    desc: 'How streams are decoded, switched, and subtitled.',
    groups: const [
      NsGroup(
        label: 'Streaming',
        rows: [
          NsRow(
            id: 'perf',
            kind: NsRowKind.choice,
            title: 'Performance mode',
            sub: 'Auto picks based on device RAM. Use Optimized on weaker devices.',
            value: 'auto',
            options: [
              NsOption(id: 'auto', label: 'Automatic', sub: 'Detects device capability'),
              NsOption(id: 'full', label: 'Full quality', sub: 'Best image, more CPU/GPU'),
              NsOption(
                id: 'optimized',
                label: 'Optimized',
                sub: 'Lower memory · stable on cheap TVs',
              ),
            ],
          ),
          NsRow(
            id: 'lightning',
            kind: NsRowKind.toggle,
            title: 'Lightning switch',
            sub: 'Dual-decoder leapfrog channel switching. Requires Full quality.',
            badge: 'PRO',
            defaultBool: false,
          ),
          NsRow(
            id: 'subs',
            kind: NsRowKind.choice,
            title: 'Default subtitle language',
            sub: 'Used when ordering OpenSubtitles results.',
            value: 'en',
            options: kNsSubLangs,
          ),
        ],
      ),
    ],
  ),

  // 2. Look & Feel (lines 4568–4603)
  NsCategory(
    id: 'look',
    icon: NsIcon.look,
    title: 'Look & Feel',
    eyebrow: 'Look & Feel',
    desc: 'Theme, layout density, and the on-screen clock overlay.',
    groups: [
      NsGroup(
        label: 'Theme',
        rows: [
          NsRow(
            id: 'theme',
            kind: NsRowKind.choice,
            title: 'Theme',
            sub: 'Color palette and ambient background.',
            value: 'cyan',
            options: kNsThemes,
          ),
        ],
      ),
      NsGroup(
        label: 'Layout',
        rows: [
          NsRow(
            id: 'appearance',
            kind: NsRowKind.page,
            page: 'appearance',
            title: 'Appearance',
            sub: 'Live TV, Hero background, Movies and Series — layout, density, and card style.',
            // Live value from state so edits in the sub-page immediately
            // update the row's display text on return.
            valueFn: (s) => s.appearanceSummary(),
          ),
          NsRow(
            id: 'topmenu',
            kind: NsRowKind.page,
            page: 'topmenu',
            title: 'Top menu items & order',
            sub: 'Choose which items appear on the top menu and reorder them.',
            // Reads live from state so the count updates when the user
            // adds / removes items on the sub-page.
            valueFn: (s) => '${s.topMenu.length} items',
          ),
          NsRow(
            id: 'startup',
            kind: NsRowKind.choice,
            title: 'Startup tab',
            sub: 'Tab opened when the app launches.',
            value: 'liveTv',
            // Choice options mirror the live TOPMENU so reordering or
            // removing an item there immediately updates the dropdown.
            optionsFn: (s) => nsTopMenuAsOptions(s.topMenu),
          ),
        ],
      ),
      NsGroup(
        label: 'Overlay',
        rows: [
          NsRow(
            id: 'clock',
            kind: NsRowKind.page,
            page: 'clock',
            title: 'Clock overlay',
            sub: 'A small clock that floats over the player. Customize position, size, and color.',
            valueFn: _clockRowValue,
          ),
        ],
      ),
    ],
  ),

  // 3. Playlists (lines 4605–4613) — landing category, no groups
  NsCategory(
    id: 'playlists',
    icon: NsIcon.library,
    title: 'Playlists',
    eyebrow: 'Playlists',
    desc: 'Add, sync and manage your IPTV sources.',
    landing: const NsLanding(page: 'playlists'),
    metaFn: (s) => s.playlists.length,
  ),

  // 4. Favorites (lines 4615–4623) — landing category, no groups
  NsCategory(
    id: 'favorites',
    icon: NsIcon.star,
    title: 'Favorites',
    eyebrow: 'Favorites',
    desc: 'Cross-playlist favorite lists. Pick any channel from any playlist.',
    landing: const NsLanding(page: 'favorites'),
    metaFn: (s) => s.favGroupsCount,
  ),

  // 5. Parental controls (lines 4625–4651)
  NsCategory(
    id: 'privacy',
    icon: NsIcon.privacy,
    title: 'Parental controls',
    eyebrow: 'Parental controls',
    desc: 'Lock channels, categories, or whole sections behind a PIN.',
    groups: [
      const NsGroup(
        label: 'Locks',
        rows: [
          NsRow(
            id: 'parental_master',
            kind: NsRowKind.toggle,
            title: 'Parental controls',
            sub: 'Master switch · requires PIN to disable.',
            defaultBool: false,
          ),
          NsRow(
            id: 'lock_live',
            kind: NsRowKind.toggle,
            title: 'Lock all Live TV',
            sub: 'Hide all live channels behind PIN.',
            defaultBool: false,
          ),
          NsRow(
            id: 'lock_movies',
            kind: NsRowKind.toggle,
            title: 'Lock all Movies',
            sub: 'Hide the entire Movies tab.',
            defaultBool: false,
          ),
          NsRow(
            id: 'lock_series',
            kind: NsRowKind.toggle,
            title: 'Lock all Series',
            sub: 'Hide the entire Series tab.',
            defaultBool: false,
          ),
        ],
      ),
      NsGroup(
        label: 'Custom rules',
        rows: [
          NsRow(
            id: 'rules',
            kind: NsRowKind.page,
            page: 'rules',
            title: 'Restricted rules',
            sub: 'Per-category and per-channel restrictions.',
            valueFn: (s) => '${s.parentalRulesActiveCount} active',
          ),
        ],
      ),
      NsGroup(
        label: 'PIN',
        rows: [
          NsRow(
            id: 'pin',
            kind: NsRowKind.page,
            page: 'pin',
            title: 'PIN code',
            sub: 'Create or change the parental PIN.',
            valueFn: (s) => s.parentalPinValueLabel,
          ),
          const NsRow(
            id: 'clear',
            kind: NsRowKind.action,
            action: 'clearAll',
            title: 'Clear PIN & rules',
            sub: 'Wipes the PIN and every restriction rule. Cannot be undone.',
            danger: true,
          ),
        ],
      ),
    ],
  ),

  // 6. System (lines 4653–4672)
  NsCategory(
    id: 'system',
    icon: NsIcon.system,
    title: 'System',
    eyebrow: 'System',
    desc: 'Account-level options, backups, and developer tools.',
    groups: [
      NsGroup(
        label: 'Account',
        rows: [
          const NsRow(
            id: 'lang',
            kind: NsRowKind.choice,
            title: 'Interface language',
            sub: 'Changes the entire UI language.',
            value: 'en',
            options: kNsLangs,
          ),
          NsRow(
            id: 'backup',
            kind: NsRowKind.page,
            page: 'backup',
            title: 'Backup & restore',
            sub: 'Export your settings and playlists, or import from a file.',
            valueFn: (s) {
              if (s.localDiskBackupCount == 0) return 'No backups yet';
              final d = s.localDiskBackupLastDate;
              if (d == null || d.isEmpty) return 'Backups on device';
              return 'Last export · $d';
            },
          ),
        ],
      ),
      const NsGroup(
        label: 'Developer',
        rows: [
          NsRow(
            id: 'demo',
            kind: NsRowKind.toggle,
            title: 'Demo mode',
            sub: 'Browse with sample data — no real playlists are touched.',
            defaultBool: false,
          ),
          NsRow(
            id: 'reset',
            kind: NsRowKind.action,
            action: 'resetAll',
            title: 'Reset all settings',
            sub: 'Restore every setting in this app to its factory default.',
            danger: true,
          ),
        ],
      ),
    ],
  ),

  // 7. Legacy full settings (previous TVMate settings screen)
  const NsCategory(
    id: 'oldSettings',
    icon: Icons.settings_rounded,
    title: 'Old settings',
    eyebrow: 'Old settings',
    desc: 'Open the previous full settings experience.',
    groups: [
      NsGroup(
        rows: [
          NsRow(
            id: 'openOldSettings',
            kind: NsRowKind.action,
            action: 'openOldSettings',
            title: 'Open classic settings',
            sub:
                'The legacy TVMate settings screen (library, top menu, performance, and more).',
          ),
        ],
      ),
    ],
  ),
];

// ─── Helpers ─────────────────────────────────────────────────────────────

/// Port of the clock row's `valueFn` at line 4598–4600 of settings.html.
String _clockRowValue(NewSettingsState s) {
  final c = s.clock;
  if (!c.enabled) return 'Off';
  final fmt = c.fmt == '24' ? '24h' : '12h';
  final size = switch (c.sizePx) {
    15 => 'Small',
    19 => 'Medium',
    24 => 'Large',
    _ => '${c.sizePx}px',
  };
  final corner = switch (c.corner) {
    'tl' => 'Top-left',
    'tr' => 'Top-right',
    'bl' => 'Bottom-left',
    'br' => 'Bottom-right',
    _ => 'Top-right',
  };
  return '$fmt · $size · $corner';
}

// ═══════════════════════════════════════════════════════════════════════
//  Account — 1:1 port of `ACCOUNT` / `ACC_DURATIONS` / `ACC_PLANS`
//  (settings.html lines 4746–4777 + `renderAccountPage` at 8461).
// ═══════════════════════════════════════════════════════════════════════

/// Device type icon bucket used by the Devices tab (`tv` / `phone` /
/// `laptop` / `unknown`) — matches the `d.type` switch in the HTML
/// `accDeviceIcon` helper.
enum NsAccDeviceType { tv, phone, laptop, unknown }

extension NsAccDeviceTypeStorage on NsAccDeviceType {
  String get storage => switch (this) {
        NsAccDeviceType.tv => 'tv',
        NsAccDeviceType.phone => 'phone',
        NsAccDeviceType.laptop => 'laptop',
        NsAccDeviceType.unknown => 'unknown',
      };

  static NsAccDeviceType parse(String raw) => switch (raw) {
        'tv' => NsAccDeviceType.tv,
        'phone' => NsAccDeviceType.phone,
        'laptop' => NsAccDeviceType.laptop,
        _ => NsAccDeviceType.unknown,
      };
}

class NsAccDevice {
  NsAccDevice({
    required this.id,
    required this.label,
    required this.type,
    required this.lastSeen,
    required this.current,
  });

  final String id;
  String label;
  final NsAccDeviceType type;

  /// ISO-8601 timestamp. We format it relative on render.
  final String lastSeen;
  final bool current;
}

class NsAccount {
  NsAccount({
    required this.isLoggedIn,
    required this.name,
    required this.email,
    required this.initials,
    required this.role,
    required this.status,
    required this.memberSince,
    required this.deviceId,
    required this.isTrial,
    required this.accessUntil,
    required this.trialEndsAt,
    required this.googleLinked,
    required this.deviceLimit,
    required this.devices,
  });

  bool isLoggedIn;
  String name;
  String email;
  String initials;
  String role;
  String status;
  String memberSince;
  String deviceId;
  bool isTrial;
  String? accessUntil;
  String? trialEndsAt;
  bool googleLinked;
  int deviceLimit;
  List<NsAccDevice> devices;
}

/// Seed matching the HTML `ACCOUNT` object (line 4746).
NsAccount nsDefaultAccount() => NsAccount(
      isLoggedIn: true,
      name: 'John Doe',
      email: 'john.doe@example.com',
      initials: 'JD',
      role: 'Pro',
      status: 'active',
      memberSince: 'March 12, 2024',
      deviceId: 'd9f3e21a',
      isTrial: false,
      accessUntil: '2026-12-31T00:00:00Z',
      trialEndsAt: null,
      googleLinked: false,
      deviceLimit: 5,
      devices: [
        NsAccDevice(
          id: 'd9f3e21a',
          label: 'Living Room TV',
          type: NsAccDeviceType.tv,
          lastSeen: '2026-04-17T20:14:00Z',
          current: true,
        ),
        NsAccDevice(
          id: 'a1b2c3d4',
          label: 'Bedroom Stick',
          type: NsAccDeviceType.tv,
          lastSeen: '2026-04-15T08:02:00Z',
          current: false,
        ),
        NsAccDevice(
          id: '550e8400',
          label: 'iPhone 15 Pro',
          type: NsAccDeviceType.phone,
          lastSeen: '2026-04-18T07:45:00Z',
          current: false,
        ),
        NsAccDevice(
          id: '6ba7b810',
          label: 'MacBook Pro',
          type: NsAccDeviceType.laptop,
          lastSeen: '2026-03-30T19:11:00Z',
          current: false,
        ),
      ],
    );

class NsAccDuration {
  const NsAccDuration({
    required this.id,
    required this.label,
    required this.months,
    required this.discount,
  });

  final String id;
  final String label;
  final int months;
  final double discount;
}

/// 1 / 3 / 12 / 36 months with discount % (HTML line 4767).
const List<NsAccDuration> kNsAccDurations = [
  NsAccDuration(id: '1mo', label: '1 Month', months: 1, discount: 0),
  NsAccDuration(id: '3mo', label: '3 Months', months: 3, discount: 0.15),
  NsAccDuration(id: '1yr', label: '1 Year', months: 12, discount: 0.40),
  NsAccDuration(id: '3yr', label: '3 Years', months: 36, discount: 0.50),
];

class NsAccPlan {
  const NsAccPlan({
    required this.id,
    required this.name,
    required this.devices,
    required this.baseCents,
    required this.accent,
    required this.badge,
    required this.features,
  });

  final String id;
  final String name;
  final int devices;

  /// Monthly base price in cents (e.g. 499 = $4.99).
  final int baseCents;

  /// Accent color for price + plan halo (HTML uses per-plan hex).
  final Color accent;

  /// Null when no ribbon badge should render (Starter has none).
  final String? badge;
  final List<String> features;
}

const List<NsAccPlan> kNsAccPlans = [
  NsAccPlan(
    id: 'starter',
    name: 'Starter',
    devices: 1,
    baseCents: 499,
    accent: Color(0xFF4DD0E1),
    badge: null,
    features: [
      'All channels',
      '1 device',
      'HD streaming',
      'Basic support',
    ],
  ),
  NsAccPlan(
    id: 'professional',
    name: 'Professional',
    devices: 3,
    baseCents: 999,
    accent: Color(0xFFA78BFA),
    badge: 'POPULAR',
    features: [
      'All channels',
      '3 devices',
      'FHD streaming',
      'Priority support',
    ],
  ),
  NsAccPlan(
    id: 'premium',
    name: 'Premium',
    devices: 5,
    baseCents: 1499,
    accent: Color(0xFFFB923C),
    badge: 'BEST VALUE',
    features: [
      'All channels',
      '5 devices',
      '4K streaming',
      '24/7 support',
      'Early access',
    ],
  ),
];

/// Port of `accFormatRemaining()` at settings.html line 8412.
/// Renders an ISO-8601 timestamp as "2 days left" / "3 hours left" /
/// "expired" / "No active subscription" — same branches as the HTML.
String nsAccFormatRemaining(String? iso) {
  if (iso == null || iso.isEmpty) return 'No active subscription';
  final end = DateTime.tryParse(iso);
  if (end == null) return 'No active subscription';
  final diff = end.difference(DateTime.now());
  if (diff.isNegative) return 'expired';
  final days = diff.inDays;
  if (days > 30) {
    final months = (days / 30).floor();
    if (months >= 12) {
      final years = (months / 12).floor();
      return '$years year${years == 1 ? '' : 's'} left';
    }
    return '$months month${months == 1 ? '' : 's'} left';
  }
  if (days >= 1) return '$days day${days == 1 ? '' : 's'} left';
  final hours = diff.inHours;
  if (hours >= 1) return '$hours hour${hours == 1 ? '' : 's'} left';
  final minutes = diff.inMinutes;
  return '$minutes minute${minutes == 1 ? '' : 's'} left';
}

/// Port of the HTML `accLastSeen()` helper — "Active now" / "2 hours
/// ago" / "3 days ago" / "Mar 30".
String nsAccLastSeen(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 5) return 'Active now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  // Older than a week → month/day label.
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[t.month - 1]} ${t.day}';
}

/// Monthly + total price for a plan at a given duration. Mirrors
/// `accPriceCombo` at settings.html line 8440.
({String monthly, String total}) nsAccPriceCombo(
  int baseCents,
  NsAccDuration duration,
) {
  final discounted = baseCents * (1 - duration.discount);
  final monthly = '\$${(discounted / 100).toStringAsFixed(2)}/mo';
  final totalCents = discounted * duration.months;
  final total = duration.months == 1
      ? ''
      : '\$${(totalCents / 100).toStringAsFixed(2)} total';
  return (monthly: monthly, total: total);
}

// ═══════════════════════════════════════════════════════════════════════
//  Backup & restore — 1:1 port of `BACKUP_FILES` + `renderBackupPage`
//  (settings.html 4536 + 7816).
// ═══════════════════════════════════════════════════════════════════════

enum NsBackupKind { personal, share }

class NsBackupFile {
  NsBackupFile({
    required this.name,
    required this.size,
    required this.date,
    required this.kind,
    this.diskPath,
  });

  final String name;
  final String size;
  String date;
  final NsBackupKind kind;

  /// Real path on disk when this row is a scanned `tvmate-backup-*.json` file.
  final String? diskPath;
}

/// Seed from settings.html line 4536.
List<NsBackupFile> nsDefaultBackupFiles() => <NsBackupFile>[
      NsBackupFile(
        name: 'tvmate-personal-2026-04-15.tvmbk',
        size: '42 KB',
        date: '3 days ago',
        kind: NsBackupKind.personal,
      ),
      NsBackupFile(
        name: 'tvmate-share-2026-04-12.tvmbk',
        size: '38 KB',
        date: '6 days ago',
        kind: NsBackupKind.share,
      ),
      NsBackupFile(
        name: 'tvmate-personal-2026-03-29.tvmbk',
        size: '40 KB',
        date: '3 weeks ago',
        kind: NsBackupKind.personal,
      ),
    ];

/// Sample server-stored backups so the Cloud section isn't empty on
/// first boot. Same shape as local — differentiates only on the
/// `.tvmbk-cloud` suffix so names are visually distinct.
List<NsBackupFile> nsDefaultCloudBackupFiles() => <NsBackupFile>[
      NsBackupFile(
        name: 'tvmate-cloud-2026-04-19.tvmbk',
        size: '44 KB',
        date: '2 hours ago',
        kind: NsBackupKind.personal,
      ),
      NsBackupFile(
        name: 'tvmate-cloud-2026-04-10.tvmbk',
        size: '38 KB',
        date: '1 week ago',
        kind: NsBackupKind.share,
      ),
    ];

// ═══════════════════════════════════════════════════════════════════════
//  Restricted rules — 1:1 port of `RULES` + `renderRulesPage()` in
//  settings.html (lines 4531 + 7710). A flat list of PIN-protected
//  restrictions with a single switch per row.
// ═══════════════════════════════════════════════════════════════════════

class NsRule {
  NsRule({
    required this.id,
    required this.label,
    required this.scope,
    required this.active,
  });

  final int id;
  String label;
  String scope;
  bool active;
}

/// HTML seed rules (line 4531).
List<NsRule> nsDefaultRules() => <NsRule>[
      NsRule(
        id: 1,
        label: 'Lock category · Adult',
        scope: 'All playlists',
        active: true,
      ),
      NsRule(
        id: 2,
        label: 'Lock channel · MTV',
        scope: 'Family Pack',
        active: true,
      ),
      NsRule(
        id: 3,
        label: 'Hide category · Sports',
        scope: 'Family Pack',
        active: false,
      ),
    ];

// ═══════════════════════════════════════════════════════════════════════
//  Favorites — cross-playlist favorite groups.
//  1:1 port of `FAV_COLORS` / `FAV_GROUPS` / helpers (settings.html lines
//  4476–4505, 6780–6871).
// ═══════════════════════════════════════════════════════════════════════

/// Eight HTML-exact swatches used both to paint the fav cover and as
/// the auto-pick sequence for new groups.
const List<String> kNsFavColors = [
  '#4DD0E1', '#FBBF24', '#A78BFA', '#F87171',
  '#4ADE80', '#60A5FA', '#FB923C', '#F472B6',
];

/// A reference to a channel inside a playlist + category. Identified
/// by the triple `{playlistId, categoryId, channelId}`. Matches the
/// JSON shape in `g.refs[]` in settings.html.
class NsFavRef {
  const NsFavRef({
    required this.playlistId,
    required this.categoryId,
    required this.channelId,
  });

  final String playlistId;
  final String categoryId;
  final String channelId;

  String get key => '$playlistId::$channelId';

  bool sameChannel(NsFavRef other) =>
      playlistId == other.playlistId && channelId == other.channelId;
}

/// A user-defined cross-playlist favorite list. Mirrors the HTML's
/// `FAV_GROUPS[i]` shape.
class NsFavGroup {
  NsFavGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.color,
    required this.refs,
  });

  final String id;
  String name;
  int sortOrder;
  String color;
  List<NsFavRef> refs;
}

/// Build a couple of sample favorite groups from the live playlists so
/// the landing card grid isn't empty on first boot. Mirrors the HTML's
/// three seed groups (Sports Night / Kids Saturday / News Wall). We
/// resolve refs dynamically so we don't hard-code channel ids that
/// might not exist in the current seed.
List<NsFavGroup> nsDefaultFavGroups(List<NsPlaylist> playlists) {
  if (playlists.isEmpty) return <NsFavGroup>[];
  final firstPl = playlists.first;
  final live = firstPl.groups['live'] ?? const <NsPlaylistGroup>[];
  if (live.isEmpty) return <NsFavGroup>[];

  NsFavRef? refAt(int catIdx, int chIdx) {
    if (catIdx >= live.length) return null;
    final cat = live[catIdx];
    final channels =
        firstPl.channelsMap[cat.id] ?? const <NsPlaylistChannel>[];
    if (chIdx >= channels.length) return null;
    return NsFavRef(
      playlistId: firstPl.id,
      categoryId: cat.id,
      channelId: channels[chIdx].id,
    );
  }

  List<NsFavRef> pick(List<(int, int)> pairs) {
    final out = <NsFavRef>[];
    for (final (catIdx, chIdx) in pairs) {
      final r = refAt(catIdx, chIdx);
      if (r != null) out.add(r);
    }
    return out;
  }

  return <NsFavGroup>[
    NsFavGroup(
      id: 'fg1',
      name: 'Sports Night',
      sortOrder: 1,
      color: kNsFavColors[0],
      refs: pick(const [(1, 0), (1, 2), (1, 4)]),
    ),
    NsFavGroup(
      id: 'fg2',
      name: 'Kids Saturday',
      sortOrder: 2,
      color: kNsFavColors[1],
      refs: pick(const [(2, 0), (2, 1), (2, 2)]),
    ),
    NsFavGroup(
      id: 'fg3',
      name: 'News Wall',
      sortOrder: 3,
      color: kNsFavColors[2],
      refs: pick(const [(0, 0), (0, 1), (0, 2), (0, 3)]),
    ),
  ];
}

/// First two word-initials of a channel / group name, upper-cased and
/// capped at 3 chars (matches `favInitials` in settings.html line 6865).
String nsFavInitials(String source) {
  final s = source.trim();
  if (s.isEmpty) return '·';
  final parts = s
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p.isEmpty ? '' : p[0])
      .join()
      .toUpperCase();
  if (parts.isEmpty) return '·';
  return parts.length > 3 ? parts.substring(0, 3) : parts;
}

/// Result of resolving a [NsFavRef] — null when the channel has been
/// renamed / hidden / removed.
class NsFavResolved {
  const NsFavResolved({
    required this.channel,
    required this.playlist,
    required this.category,
  });
  final NsPlaylistChannel channel;
  final NsPlaylist playlist;
  final NsPlaylistGroup? category;
}

/// Look up a category by id. Returns `null` if the id is unknown (defensive
/// — callers can fall back to the first category).
NsCategory? nsCategoryById(String id) {
  for (final c in kNsCats) {
    if (c.id == id) return c;
  }
  return null;
}

/// Look up an option label by id within an options list. Used by the row
/// renderer to render the current value of a `choice` row.
String nsOptionLabelById(List<NsOption> options, String id) {
  for (final o in options) {
    if (o.id == id) return o.label;
  }
  return id;
}
