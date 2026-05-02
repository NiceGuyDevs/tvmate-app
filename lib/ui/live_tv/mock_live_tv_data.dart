import 'package:flutter/material.dart';

/// Synthetic Live TV category: grid shows only channels saved in [MyListStore] live list.
const String kLiveTvFavoritesCategoryId = '__tvmate_live_favorites__';

/// Synthetic "All" category: full live channel list (first pill on Live TV browse).
const String kLiveTvAllCategoryId = 'all';

const MockLiveCategory kLiveTvMyFavoritesCategory = MockLiveCategory(
  id: kLiveTvFavoritesCategoryId,
  name: 'My favorites',
);

/// Demo categories only — real app will use Xtream / M3U categories.
class MockLiveCategory {
  const MockLiveCategory({required this.id, required this.name});

  final String id;
  final String name;
}

/// Demo channel + fake EPG fields for the hero.
/// [streamUrl] is set for Xtream live streams; demo mode uses mock URLs in navigation.
class MockLiveChannel {
  const MockLiveChannel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.programTitle,
    required this.description,
    required this.progress,
    required this.logoColor,
    this.streamUrl,
    this.iconUrl,
    this.epgChannelId,
    this.tvArchive,
    this.tvArchiveDuration,
  });

  final String id;
  final String categoryId;
  final String name;
  final String programTitle;
  final String description;

  /// 0–1 for progress bar.
  final double progress;
  final Color logoColor;
  final String? streamUrl;
  final String? iconUrl;

  /// Xtream `epg_channel_id` when it differs from [id]; used for EPG lookups.
  final String? epgChannelId;

  /// Xtream `tv_archive` flag: 1 = catch-up supported, 0 or null = not.
  final int? tvArchive;

  /// Xtream `tv_archive_duration` in days. Null/0 = unknown.
  final int? tvArchiveDuration;

  static const int kDefaultCatchupDays = 7;

  bool get hasCatchup =>
      tvArchive == 1 ||
      (tvArchiveDuration != null && tvArchiveDuration! > 0);

  /// Xtream sent a non-empty `epg_channel_id` (panel maps this stream to EPG).
  bool get hasPanelEpg =>
      epgChannelId != null && epgChannelId!.trim().isNotEmpty;

  /// True for [kLiveTvCatalogLoadingHero] — catalog not read from DB yet (avoid demo flash).
  bool get isCatalogLoadingPlaceholder => id == '__tvmate_catalog_loading__';

  MockLiveChannel copyWith({
    String? name,
    String? iconUrl,
  }) {
    return MockLiveChannel(
      id: id,
      categoryId: categoryId,
      name: name ?? this.name,
      programTitle: programTitle,
      description: description,
      progress: progress,
      logoColor: logoColor,
      streamUrl: streamUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      epgChannelId: epgChannelId,
      tvArchive: tvArchive,
      tvArchiveDuration: tvArchiveDuration,
    );
  }

  /// Days of catch-up history (falls back to [kDefaultCatchupDays] when metadata is missing).
  int get catchupDays {
    if (tvArchiveDuration != null && tvArchiveDuration! > 0) {
      return tvArchiveDuration!;
    }
    return kDefaultCatchupDays;
  }
}

const List<MockLiveCategory> kMockLiveCategories = [
  MockLiveCategory(id: kLiveTvAllCategoryId, name: 'All'),
  MockLiveCategory(id: 'sports', name: 'Sports'),
  MockLiveCategory(id: 'news', name: 'News'),
  MockLiveCategory(id: 'movies', name: 'Movies'),
  MockLiveCategory(id: 'kids', name: 'Kids'),
];

/// Shown as the Live TV hero while the catalog is still empty (real playlists, first frames).
/// Avoids flashing demo channel names before [XtreamCatalogRepository] finishes loading.
const MockLiveChannel kLiveTvCatalogLoadingHero = MockLiveChannel(
  id: '__tvmate_catalog_loading__',
  categoryId: '',
  name: '',
  programTitle: '',
  description: '',
  progress: 0,
  logoColor: Color(0xFF1A1A24),
);

/// Bundled demo channel logos under [assets/images/ch_cannels_demo/] (no network).
const String _kLiveChDemoDir = 'assets/images/ch_cannels_demo';

/// One file per channel; order matches [kMockLiveChannels] (24 rows). Use `0.png` … `23.png` in [ch_cannels_demo].
const List<String> _kLiveChDemoIconFiles = [
  '0.png',
  '1.png',
  '2.png',
  '3.png',
  '4.png',
  '5.png',
  '6.png',
  '7.png',
  '8.png',
  '9.png',
  '10.png',
  '11.png',
  '12.png',
  '13.png',
  '14.png',
  '15.png',
  '16.png',
  '17.png',
  '18.png',
  '19.png',
  '20.png',
  '21.png',
  '22.png',
  '23.png',
];

String _liveChDemoIcon(int index) {
  if (index < 0 || index >= _kLiveChDemoIconFiles.length) {
    return '$_kLiveChDemoDir/${_kLiveChDemoIconFiles[0]}';
  }
  return '$_kLiveChDemoDir/${_kLiveChDemoIconFiles[index]}';
}

final List<MockLiveChannel> kMockLiveChannels = [
  MockLiveChannel(
    id: 's1',
    categoryId: 'sports',
    name: 'Arena 1 HD',
    programTitle: 'Friday Night Football — Semifinals',
    description:
        'Live coverage from the stadium with pre-game analysis and halftime wrap-up.',
    progress: 0.62,
    logoColor: Color(0xFF1E88E5),
    iconUrl: _liveChDemoIcon(0),
  ),
  MockLiveChannel(
    id: 's2',
    categoryId: 'sports',
    name: 'Prime Sports',
    programTitle: 'Tennis Weekly: Clay Court Spotlight',
    description:
        'Highlights and interviews from this week\'s biggest matches across Europe.',
    progress: 0.18,
    logoColor: Color(0xFF43A047),
    iconUrl: _liveChDemoIcon(1),
  ),
  MockLiveChannel(
    id: 's3',
    categoryId: 'sports',
    name: 'Rush X',
    programTitle: 'Motorsport Tonight',
    description:
        'Qualifying recap, paddock drama, and what to watch in tomorrow\'s sprint race.',
    progress: 0.41,
    logoColor: Color(0xFFE53935),
    iconUrl: _liveChDemoIcon(2),
  ),
  MockLiveChannel(
    id: 's4',
    categoryId: 'sports',
    name: 'Coastal Sports Net',
    programTitle: 'Surf & Sail Championships',
    description:
        'Conditions report, start times, and athlete profiles from the bay finals.',
    progress: 0.73,
    logoColor: Color(0xFF00897B),
    iconUrl: _liveChDemoIcon(3),
  ),
  MockLiveChannel(
    id: 's5',
    categoryId: 'sports',
    name: 'Ice Central',
    programTitle: 'Hockey Highlights',
    description:
        'Goals, saves, and turning points from tonight\'s divisional double-header.',
    progress: 0.09,
    logoColor: Color(0xFF5E35B1),
    iconUrl: _liveChDemoIcon(4),
  ),
  MockLiveChannel(
    id: 's6',
    categoryId: 'sports',
    name: 'Pitchline HD',
    programTitle: 'Derby Day Build-Up',
    description:
        'Lineups, injuries, and tactical notes ahead of the weekend headline match.',
    progress: 0.55,
    logoColor: Color(0xFFD84315),
    iconUrl: _liveChDemoIcon(5),
  ),
  MockLiveChannel(
    id: 'n1',
    categoryId: 'news',
    name: 'City News 24',
    programTitle: 'Morning Brief: Transit & Markets',
    description:
        'Commuter updates, opening bell context, and the top three local stories.',
    progress: 0.34,
    logoColor: Color(0xFF3949AB),
    iconUrl: _liveChDemoIcon(6),
  ),
  MockLiveChannel(
    id: 'n2',
    categoryId: 'news',
    name: 'Global Wire',
    programTitle: 'World Desk Midday',
    description:
        'Diplomatic signals, science milestones, and weather patterns on the move.',
    progress: 0.51,
    logoColor: Color(0xFF6D4C41),
    iconUrl: _liveChDemoIcon(7),
  ),
  MockLiveChannel(
    id: 'n3',
    categoryId: 'news',
    name: 'Business Now',
    programTitle: 'Closing Arguments — Tech Earnings',
    description:
        'Analyst reaction, guidance watch-outs, and what it means for your portfolio.',
    progress: 0.66,
    logoColor: Color(0xFFC62828),
    iconUrl: _liveChDemoIcon(8),
  ),
  MockLiveChannel(
    id: 'n4',
    categoryId: 'news',
    name: 'Weather Front',
    programTitle: 'Storm Track & Weekend Outlook',
    description:
        'Interactive radar, safety reminders, and hour-by-hour forecasts for the metro.',
    progress: 0.22,
    logoColor: Color(0xFF0277BD),
    iconUrl: _liveChDemoIcon(9),
  ),
  MockLiveChannel(
    id: 'n5',
    categoryId: 'news',
    name: 'Capitol Report',
    programTitle: 'Committee Hearings — Live Blog',
    description:
        'Amendment watch, vote clocks, and corridor interviews as bills move.',
    progress: 0.48,
    logoColor: Color(0xFF4527A0),
    iconUrl: _liveChDemoIcon(10),
  ),
  MockLiveChannel(
    id: 'm1',
    categoryId: 'movies',
    name: 'Cinema World',
    programTitle: 'Saturday Premium — Spy Chronicle',
    description:
        'A cryptic message pulls an analyst back into the field for one last operation.',
    progress: 0.44,
    logoColor: Color(0xFFAD1457),
    iconUrl: _liveChDemoIcon(11),
  ),
  MockLiveChannel(
    id: 'm2',
    categoryId: 'movies',
    name: 'Retro Rewind',
    programTitle: 'Classic: Midnight Express Lane',
    description:
        'Restored print with commentary track from the director and composer.',
    progress: 0.88,
    logoColor: Color(0xFFF9A825),
    iconUrl: _liveChDemoIcon(12),
  ),
  MockLiveChannel(
    id: 'm3',
    categoryId: 'movies',
    name: 'Indie Lane',
    programTitle: 'Festival Winner — Quiet Harbor',
    description:
        'A coastal town’s secrets surface when siblings return for a long summer.',
    progress: 0.05,
    logoColor: Color(0xFF546E7A),
    iconUrl: _liveChDemoIcon(13),
  ),
  MockLiveChannel(
    id: 'm4',
    categoryId: 'movies',
    name: 'Action Zone',
    programTitle: 'Double Feature: Chase Atlas',
    description:
        'High-stakes vault job across three cities — minimal cuts, maximum tension.',
    progress: 0.57,
    logoColor: Color(0xFFEF6C00),
    iconUrl: _liveChDemoIcon(14),
  ),
  MockLiveChannel(
    id: 'm5',
    categoryId: 'movies',
    name: 'Arthouse East',
    programTitle: 'Director Spotlight: Long Takes',
    description:
        'A career retrospective with rare set photos and restored 35mm trailers.',
    progress: 0.33,
    logoColor: Color(0xFF4E342E),
    iconUrl: _liveChDemoIcon(15),
  ),
  MockLiveChannel(
    id: 'm6',
    categoryId: 'movies',
    name: 'Late Show Movies',
    programTitle: 'Creature Feature Marathon',
    description:
        'Practical effects, miniature work, and composer cues from cult midnight slots.',
    progress: 0.71,
    logoColor: Color(0xFF37474F),
    iconUrl: _liveChDemoIcon(16),
  ),
  MockLiveChannel(
    id: 'k1',
    categoryId: 'kids',
    name: 'Playhouse Jr.',
    programTitle: 'Music Train — Colors & Rhymes',
    description:
        'Sing-alongs, gentle lessons, and a surprise guest puppet every episode.',
    progress: 0.29,
    logoColor: Color(0xFF7CB342),
    iconUrl: _liveChDemoIcon(17),
  ),
  MockLiveChannel(
    id: 'k2',
    categoryId: 'kids',
    name: 'Science Buddies',
    programTitle: 'Why Does Lightning Zigzag?',
    description:
        'Hands-on demos, slow-motion captures, and safe experiments at home.',
    progress: 0.76,
    logoColor: Color(0xFF039BE5),
    iconUrl: _liveChDemoIcon(18),
  ),
  MockLiveChannel(
    id: 'k3',
    categoryId: 'kids',
    name: 'Toon Harbor',
    programTitle: 'Captain Crate — Map Mishap',
    description:
        'A wrong turn leads to a new friend and a lesson in teamwork on the waves.',
    progress: 0.12,
    logoColor: Color(0xFF8E24AA),
    iconUrl: _liveChDemoIcon(19),
  ),
  MockLiveChannel(
    id: 'k4',
    categoryId: 'kids',
    name: 'Sports Kids',
    programTitle: 'Junior League Highlights',
    description:
        'Respect on the court, fair play moments, and athlete spotlights from schools.',
    progress: 0.49,
    logoColor: Color(0xFF00ACC1),
    iconUrl: _liveChDemoIcon(20),
  ),
  MockLiveChannel(
    id: 'k5',
    categoryId: 'kids',
    name: 'Storytime Circle',
    programTitle: 'Dragons Who Share',
    description:
        'Bedtime fables with soft animation and read-along captions for early readers.',
    progress: 0.38,
    logoColor: Color(0xFFFF8F00),
    iconUrl: _liveChDemoIcon(21),
  ),
  MockLiveChannel(
    id: 'k6',
    categoryId: 'kids',
    name: 'Nature Sprouts',
    programTitle: 'Tide Pool Walk',
    description:
        'Tide charts, creature IDs, and leave-no-trace tips for family outings.',
    progress: 0.64,
    logoColor: Color(0xFF689F38),
    iconUrl: _liveChDemoIcon(22),
  ),
  MockLiveChannel(
    id: 'k7',
    categoryId: 'kids',
    name: 'Math Galaxy',
    programTitle: 'Fraction Pizza Party',
    description:
        'Split toppings fairly, then chart the slices with colorful bar graphs.',
    progress: 0.07,
    logoColor: Color(0xFF7E57C2),
    iconUrl: _liveChDemoIcon(23),
  ),
];

List<MockLiveChannel> mockChannelsForCategory(String categoryId) {
  if (categoryId == kLiveTvAllCategoryId) {
    return List<MockLiveChannel>.from(kMockLiveChannels);
  }
  return kMockLiveChannels
      .where((c) => c.categoryId == categoryId)
      .toList(growable: false);
}
