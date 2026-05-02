import 'package:flutter/material.dart';

/// Local demo posters under [assets/images/demo_tv_shows/] (bundled; no network).
const String _kTvShowsDemoDir = 'assets/images/demo_tv_shows';

/// One file per demo title; order matches [kMockSeries] (25 rows). Use `0.png` … `24.png` in [demo_tv_shows].
const List<String> _kTvShowsDemoPosterFiles = [
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
  '24.png',
];

String _tvShowsDemoPoster(int index) {
  if (index < 0 || index >= _kTvShowsDemoPosterFiles.length) {
    return '$_kTvShowsDemoDir/${_kTvShowsDemoPosterFiles[0]}';
  }
  return '$_kTvShowsDemoDir/${_kTvShowsDemoPosterFiles[index]}';
}

/// Catalog taxonomy — UI reads from this list only (no extra hardcoding).
class MockSeriesCategory {
  const MockSeriesCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class MockEpisode {
  const MockEpisode({
    required this.id,
    required this.seriesId,
    required this.season,
    required this.episode,
    required this.title,
    required this.description,
    this.streamUrl,
    this.stillUrl,
  });

  final String id;
  final String seriesId;
  final int season;
  final int episode;
  final String title;
  final String description;
  final String? streamUrl;
  final String? stillUrl;

  String get codename {
    final s = season.toString().padLeft(2, '0');
    final e = episode.toString().padLeft(2, '0');
    return 'S${s}E$e';
  }
}

class MockSeason {
  const MockSeason({required this.number, required this.episodes});

  final int number;
  final List<MockEpisode> episodes;
}

class MockSeries {
  const MockSeries({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.year,
    required this.genre,
    required this.description,
    required this.posterPrimary,
    required this.posterSecondary,
    required this.backdropPrimary,
    required this.backdropSecondary,
    required this.seasons,
    this.coverUrl,
    this.backdropUrl,
    this.cast,
    this.director,
    this.rating,
  });

  final String id;
  final String categoryId;
  final String title;
  final int year;
  final String genre;
  final String description;
  final Color posterPrimary;
  final Color posterSecondary;
  final Color backdropPrimary;
  final Color backdropSecondary;
  final List<MockSeason> seasons;
  final String? coverUrl;
  final String? backdropUrl;
  final String? cast;
  final String? director;
  final String? rating;
}

const List<MockSeriesCategory> kMockSeriesCategories = [
  MockSeriesCategory(id: 'action', name: 'Action'),
  MockSeriesCategory(id: 'drama', name: 'Drama'),
  MockSeriesCategory(id: 'crime', name: 'Crime'),
  MockSeriesCategory(id: 'kids', name: 'Kids'),
];

List<MockSeries> mockSeriesForCategory(String categoryId) {
  return kMockSeries
      .where((s) => s.categoryId == categoryId)
      .toList(growable: false);
}

final List<MockSeries> kMockSeries = _buildMockSeries();

List<MockSeries> _buildMockSeries() {
  MockEpisode ep(
    String seriesId,
    int season,
    int n,
    String title,
    String desc,
  ) {
    return MockEpisode(
      id: '${seriesId}_s${season}_e$n',
      seriesId: seriesId,
      season: season,
      episode: n,
      title: title,
      description: desc,
    );
  }

  return [
    MockSeries(
      id: 'sv_ashes',
      categoryId: 'action',
      title: 'City of Ashes',
      year: 2023,
      genre: 'Action',
      description:
          'A fire-unit captain and a whistleblower chase an arson pattern through the tunnels beneath a reclaimed port.',
      posterPrimary: const Color(0xFFB71C1C),
      posterSecondary: const Color(0xFF2A0A0A),
      backdropPrimary: const Color(0xFF6A1518),
      backdropSecondary: const Color(0xFF050203),
      coverUrl: _tvShowsDemoPoster(0),
      backdropUrl: _tvShowsDemoPoster(0),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_ashes', 1, 1, 'Pilot: Smoke reading',
                'The crew answers a warehouse fire with oddly symmetrical burn marks.'),
            ep('sv_ashes', 1, 2, 'Heat map',
                'City sensors fail during a night of coordinated dumpster fires.'),
            ep('sv_ashes', 1, 3, 'Glass rain',
                'A high-rise drill exposes missing extinguishers on alternating floors.'),
            ep('sv_ashes', 1, 4, 'Ghost hydrant',
                'An abandoned block shows flow meters spinning with no water loss.'),
            ep('sv_ashes', 1, 5, 'Rapid retrofit',
                'Contractors race to replace cladding before a festival weekend.'),
            ep('sv_ashes', 1, 6, 'Blackout drift',
                'A blackout strands trains beside old chemical storage.'),
          ],
        ),
        MockSeason(
          number: 2,
          episodes: [
            ep('sv_ashes', 2, 1, 'Cold open ocean',
                'Harbor foam patterns mirror a map found in the pilot.'),
            ep('sv_ashes', 2, 2, 'Relay 19',
                'Radios pick up a callsign that belongs to a decommissioned station.'),
            ep('sv_ashes', 2, 3, 'Delta drills',
                'Simulations collide with a real alarm inside a museum retrofit.'),
            ep('sv_ashes', 2, 4, 'Salt lines',
                'Tracing residue leads to an importer with two ledgers.'),
            ep('sv_ashes', 2, 5, 'End shift',
                'An evidence room audit collides with a surprise inspection.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_ridge',
      categoryId: 'action',
      title: 'Ridge Runners',
      year: 2021,
      genre: 'Action / Adventure',
      description:
          'Volunteer medics cross mountain passes with night-only routes disputed by border drones.',
      posterPrimary: const Color(0xFF1565C0),
      posterSecondary: const Color(0xFF0B2038),
      backdropPrimary: const Color(0xFF123B68),
      backdropSecondary: const Color(0xFF03070F),
      coverUrl: _tvShowsDemoPoster(1),
      backdropUrl: _tvShowsDemoPoster(1),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_ridge', 1, 1, 'Whiteout manifest',
                'A missing page lists medicine lots never delivered.'),
            ep('sv_ridge', 1, 2, 'Drone hollow',
                'A grounded UAV carries firmware signed yesterday with an old key.'),
            ep('sv_ridge', 1, 3, 'Second road',
                'Guides argue over a seasonal trail shown on two conflicting maps.'),
            ep('sv_ridge', 1, 4, 'Harbor lights',
                'A buoy network pulses an SOS nobody claims to maintain.'),
          ],
        ),
        MockSeason(
          number: 2,
          episodes: [
            ep('sv_ridge', 2, 1, 'Green dawn',
                'Satellite chlorophyll spikes above a normally bare ridge.'),
            ep('sv_ridge', 2, 2, 'Ice choir',
                'Wind-harps on guy lines mask the sound of approaching rotors.'),
            ep('sv_ridge', 2, 3, 'Paper canyon',
                'Permits stamped the same hour appear in three jurisdictions.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_still',
      categoryId: 'drama',
      title: 'Stillwater Papers',
      year: 2022,
      genre: 'Drama',
      description:
          'A small claims clerk inherits a ledger that reopens land disputes across two counties.',
      posterPrimary: const Color(0xFF6A1B9A),
      posterSecondary: const Color(0xFF1D0F2A),
      backdropPrimary: const Color(0xFF3A2061),
      backdropSecondary: const Color(0xFF05030A),
      coverUrl: _tvShowsDemoPoster(2),
      backdropUrl: _tvShowsDemoPoster(2),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_still', 1, 1, 'Chain of custody',
                'An envelope arrives with a wax seal but no sender.'),
            ep('sv_still', 1, 2, 'Fence line',
                'Neighbours discover their survey pins disagree by two meters.'),
            ep('sv_still', 1, 3, 'Ordinance night',
                'A town meeting agenda duplicates an item from 1989 verbatim.'),
            ep('sv_still', 1, 4, 'Blue ink',
                'Photocopies fade except for marginal notes in cobalt pencil.'),
            ep('sv_still', 1, 5, 'Harrow bridge',
                'Weight limits change overnight with no paper trail.'),
          ],
        ),
        MockSeason(
          number: 2,
          episodes: [
            ep('sv_still', 2, 1, 'Spring thaw',
                'Melting ice reveals stakes painted two colours.'),
            ep('sv_still', 2, 2, 'County swap',
                'Database merges duplicate parcel IDs for unrelated lots.'),
            ep('sv_still', 2, 3, 'Witness oak',
                'Tree rings match a photo timestamp everyone disputes.'),
            ep('sv_still', 2, 4, 'Closing costs',
                'A bank hold references a mortgage clause from a dissolved lender.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_lantern',
      categoryId: 'drama',
      title: 'Lantern House',
      year: 2024,
      genre: 'Drama / Family',
      description:
          'Three generations resettle a coastal inn where guests leave identical diary entries.',
      posterPrimary: const Color(0xFF00897B),
      posterSecondary: const Color(0xFF08302C),
      backdropPrimary: const Color(0xFF0E4A43),
      backdropSecondary: const Color(0xFF020807),
      coverUrl: _tvShowsDemoPoster(3),
      backdropUrl: _tvShowsDemoPoster(3),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_lantern', 1, 1, 'High tide keys',
                'Every room key turns the same deadbolt until midnight.'),
            ep('sv_lantern', 1, 2, 'Guest book',
                'Signatures repeat with different hand pressures.'),
            ep('sv_lantern', 1, 3, 'Boat wake',
                'A delivery skiff arrives with cargo not on the manifest.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_line',
      categoryId: 'crime',
      title: 'Thin Blue Ledger',
      year: 2020,
      genre: 'Crime',
      description:
          'Forensic accountants follow bounced donations through precinct-adjacent charities.',
      posterPrimary: const Color(0xFF37474F),
      posterSecondary: const Color(0xFF141A1E),
      backdropPrimary: const Color(0xFF1E2A30),
      backdropSecondary: const Color(0xFF020304),
      coverUrl: _tvShowsDemoPoster(4),
      backdropUrl: _tvShowsDemoPoster(4),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_line', 1, 1, 'Opening balance',
                'A charity kiosk logs the same card hash every six minutes.'),
            ep('sv_line', 1, 2, 'Charity relay',
                'Volunteer shifts overlap by exactly one minute citywide.'),
            ep('sv_line', 1, 3, 'Ink variance',
                'Receipt printers show micro offsets that match a cold case.'),
            ep('sv_line', 1, 4, 'Night court',
                'A judge recuses after spotting her signature on a donor roll.'),
          ],
        ),
        MockSeason(
          number: 2,
          episodes: [
            ep('sv_line', 2, 1, 'New ledger',
                'Software migration duplicates donor IDs as vendor IDs.'),
            ep('sv_line', 2, 2, 'Watch command',
                'Radio silence coincides with payout windows.'),
            ep('sv_line', 2, 3, 'Paper vault',
                'Boxes labelled shred contain uncatalogued deposit slips.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_signal',
      categoryId: 'crime',
      title: 'Signal Eight',
      year: 2025,
      genre: 'Crime / Mystery',
      description:
          'Cold-case radio bursts return on the same frequency the original victims monitored.',
      posterPrimary: const Color(0xFFC62828),
      posterSecondary: const Color(0xFF350D12),
      backdropPrimary: const Color(0xFF6B1B20),
      backdropSecondary: const Color(0xFF060102),
      coverUrl: _tvShowsDemoPoster(5),
      backdropUrl: _tvShowsDemoPoster(5),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_signal', 1, 1, 'Carrier hum',
                'A spectrum plot spikes when windows fog in one apartment.'),
            ep('sv_signal', 1, 2, 'Phase lock',
                'Two scanners disagree on whether the signal moves.'),
            ep('sv_signal', 1, 3, 'Echo date',
                'Timestamps align with a blackout nobody remembers.'),
            ep('sv_signal', 1, 4, 'Dead microphone',
                'A seized mic powers on in an evidence locker without a battery.'),
            ep('sv_signal', 1, 5, 'Guard band',
                'Interference masks a second signal beneath the first.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_club',
      categoryId: 'kids',
      title: 'Curiosity Club',
      year: 2023,
      genre: 'Kids',
      description:
          'A treehouse lab crew turns everyday mysteries into gentle experiments.',
      posterPrimary: const Color(0xFFFF8F00),
      posterSecondary: const Color(0xFF3D2600),
      backdropPrimary: const Color(0xFF7A4800),
      backdropSecondary: const Color(0xFF070401),
      coverUrl: _tvShowsDemoPoster(6),
      backdropUrl: _tvShowsDemoPoster(6),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_club', 1, 1, 'Magnet morning',
                'Spoons stick to the railing after a foggy night.'),
            ep('sv_club', 1, 2, 'Bubble code',
                'Different soaps make square-shaped pops.'),
            ep('sv_club', 1, 3, 'Shadow chess',
                'Sun angles duplicate shapes on two unrelated walls.'),
            ep('sv_club', 1, 4, 'Seed race',
                'Plants sprout at different speeds under coloured films.'),
          ],
        ),
        MockSeason(
          number: 2,
          episodes: [
            ep('sv_club', 2, 1, 'Kite maths',
                'Tails hum at notes that match string lengths.'),
            ep('sv_club', 2, 2, 'Ice lens',
                'Frozen droplets bend light into overlapping rainbows.'),
            ep('sv_club', 2, 3, 'Sand clock',
                'Different grains fall at rates that predict a tide change.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo01',
      categoryId: 'action',
      title: 'Northwind Unit',
      year: 2024,
      genre: 'Action',
      description:
          'Elite responders trace cascading failures across linked transit hubs in winter.',
      posterPrimary: const Color(0xFFE65100),
      posterSecondary: const Color(0xFF331A00),
      backdropPrimary: const Color(0xFF7A3400),
      backdropSecondary: const Color(0xFF0A0400),
      coverUrl: _tvShowsDemoPoster(7),
      backdropUrl: _tvShowsDemoPoster(7),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo01', 1, 1, 'Briefing', 'Snow shifts close two corridors at once.'),
            ep('sv_demo01', 1, 2, 'Relay', 'Credentials mismatch at a rural handoff.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo02',
      categoryId: 'action',
      title: 'Chrome Harbor',
      year: 2022,
      genre: 'Action / Thriller',
      description:
          'Dock crews recover cargo that broadcasts the wrong bill of lading worldwide.',
      posterPrimary: const Color(0xFF00B8D4),
      posterSecondary: const Color(0xFF003844),
      backdropPrimary: const Color(0xFF006876),
      backdropSecondary: const Color(0xFF000A0C),
      coverUrl: _tvShowsDemoPoster(8),
      backdropUrl: _tvShowsDemoPoster(8),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo02', 1, 1, 'Quay scan', 'RFID stacks disagree with crane cameras.'),
            ep('sv_demo02', 1, 2, 'Night tide', 'A barge leaves no wake on radar.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo03',
      categoryId: 'drama',
      title: 'Paper Hearts',
      year: 2023,
      genre: 'Drama',
      description:
          'A print shop inherits wedding invites that predict breakups with eerie timing.',
      posterPrimary: const Color(0xFFAD1457),
      posterSecondary: const Color(0xFF2C0E1C),
      backdropPrimary: const Color(0xFF6B1C3D),
      backdropSecondary: const Color(0xFF050103),
      coverUrl: _tvShowsDemoPoster(9),
      backdropUrl: _tvShowsDemoPoster(9),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo03', 1, 1, 'Proof', 'Ink dries differently on every reprint.'),
            ep('sv_demo03', 1, 2, 'Guest list', 'Two names appear twice with different fonts.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo04',
      categoryId: 'drama',
      title: 'Midnight Annex',
      year: 2021,
      genre: 'Drama / Mystery',
      description:
          'Night-shift archivists index tapes that play conversations from rooms that no longer exist.',
      posterPrimary: const Color(0xFF5C6BC0),
      posterSecondary: const Color(0xFF1A1F3D),
      backdropPrimary: const Color(0xFF333C6E),
      backdropSecondary: const Color(0xFF04050A),
      coverUrl: _tvShowsDemoPoster(10),
      backdropUrl: _tvShowsDemoPoster(10),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo04', 1, 1, 'Shelf 14', 'A label peels to reveal a second catalog code.'),
            ep('sv_demo04', 1, 2, 'Static hour', 'Hum matches a ventilation shaft nobody mapped.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo05',
      categoryId: 'crime',
      title: 'Badge Math',
      year: 2025,
      genre: 'Crime',
      description:
          'Detectives model overtime patterns to predict where the next precinct leak lands.',
      posterPrimary: const Color(0xFF455A64),
      posterSecondary: const Color(0xFF151C21),
      backdropPrimary: const Color(0xFF263238),
      backdropSecondary: const Color(0xFF020304),
      coverUrl: _tvShowsDemoPoster(11),
      backdropUrl: _tvShowsDemoPoster(11),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo05', 1, 1, 'Shift curve', 'Peaks align with jury duty summons.'),
            ep('sv_demo05', 1, 2, 'Roster gap', 'A ghost badge clocks in from a closed desk.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo06',
      categoryId: 'crime',
      title: 'Velvet Jury',
      year: 2020,
      genre: 'Crime / Legal',
      description:
          'Alternate jurors swap notes through a forum that scrubs itself every sundown.',
      posterPrimary: const Color(0xFF8D6E63),
      posterSecondary: const Color(0xFF2A221E),
      backdropPrimary: const Color(0xFF4E3F38),
      backdropSecondary: const Color(0xFF060504),
      coverUrl: _tvShowsDemoPoster(12),
      backdropUrl: _tvShowsDemoPoster(12),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo06', 1, 1, 'Voir dire', 'Questionnaires share fingerprints across trials.'),
            ep('sv_demo06', 1, 2, 'Sidebar', 'A transcript redacts the same word twice differently.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo07',
      categoryId: 'kids',
      title: 'Starlight Scouts',
      year: 2024,
      genre: 'Kids',
      description:
          'Campers chart constellations and learn why some stars “blink” in rhythm together.',
      posterPrimary: const Color(0xFF7CB342),
      posterSecondary: const Color(0xFF243314),
      backdropPrimary: const Color(0xFF4A6B22),
      backdropSecondary: const Color(0xFF050702),
      coverUrl: _tvShowsDemoPoster(13),
      backdropUrl: _tvShowsDemoPoster(13),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo07', 1, 1, 'Polaris patch', 'Badges glow when the sky is unusually clear.'),
            ep('sv_demo07', 1, 2, 'Meteor math', 'Counts never match between two hilltops.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo08',
      categoryId: 'kids',
      title: 'Robo Pen Pals',
      year: 2022,
      genre: 'Kids / Comedy',
      description:
          'Two classrooms trade voice notes through a translator that loves terrible puns.',
      posterPrimary: const Color(0xFFFFB300),
      posterSecondary: const Color(0xFF4D3500),
      backdropPrimary: const Color(0xFF806000),
      backdropSecondary: const Color(0xFF0D0900),
      coverUrl: _tvShowsDemoPoster(14),
      backdropUrl: _tvShowsDemoPoster(14),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo08', 1, 1, 'Hello loop', 'Greetings echo in the wrong language twice.'),
            ep('sv_demo08', 1, 2, 'Punchline bug', 'Jokes arrive translated into recipes.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo09',
      categoryId: 'action',
      title: 'Copper Run',
      year: 2023,
      genre: 'Action',
      description:
          'Train marshals chase copper thieves who only strike when track sensors recalibrate.',
      posterPrimary: const Color(0xFFD84315),
      posterSecondary: const Color(0xFF401408),
      backdropPrimary: const Color(0xFF7A260C),
      backdropSecondary: const Color(0xFF0C0401),
      coverUrl: _tvShowsDemoPoster(15),
      backdropUrl: _tvShowsDemoPoster(15),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo09', 1, 1, 'Signal drift', 'Axle heat spikes without freight manifests.'),
            ep('sv_demo09', 1, 2, 'Third rail', 'Voltage reads steady while lights flicker.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo10',
      categoryId: 'drama',
      title: 'Glass Orchard',
      year: 2025,
      genre: 'Drama',
      description:
          'Siblings graft heirloom apples while sensors insist the soil chemistry is impossible.',
      posterPrimary: const Color(0xFF00897B),
      posterSecondary: const Color(0xFF002E29),
      backdropPrimary: const Color(0xFF004D45),
      backdropSecondary: const Color(0xFF000302),
      coverUrl: _tvShowsDemoPoster(16),
      backdropUrl: _tvShowsDemoPoster(16),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo10', 1, 1, 'Root map', 'Lines diverge under a stone wall nobody built.'),
            ep('sv_demo10', 1, 2, 'Harvest moon', 'Sugar readings spike before the fruit reddens.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo11',
      categoryId: 'crime',
      title: 'Cold Ledger FM',
      year: 2019,
      genre: 'Crime / Drama',
      description:
          'A pirate radio host reads account numbers that match unsolved ATM skims.',
      posterPrimary: const Color(0xFF6D4C41),
      posterSecondary: const Color(0xFF1F1512),
      backdropPrimary: const Color(0xFF3E2B24),
      backdropSecondary: const Color(0xFF050302),
      coverUrl: _tvShowsDemoPoster(17),
      backdropUrl: _tvShowsDemoPoster(17),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo11', 1, 1, 'Carrier wave', 'Static spells a routing number on odd nights.'),
            ep('sv_demo11', 1, 2, 'Call-in', 'Listeners describe the same branch closing twice.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo12',
      categoryId: 'action',
      title: 'Amber Drift',
      year: 2021,
      genre: 'Action / Sci-Fi',
      description:
          'Pilots navigate dust storms that leave amber shells on windshields like time capsules.',
      posterPrimary: const Color(0xFFFF6F00),
      posterSecondary: const Color(0xFF4D2100),
      backdropPrimary: const Color(0xFF804000),
      backdropSecondary: const Color(0xFF0D0600),
      coverUrl: _tvShowsDemoPoster(18),
      backdropUrl: _tvShowsDemoPoster(18),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo12', 1, 1, 'Gust lock', 'Engines cough only when heading changes by 7°.'),
            ep('sv_demo12', 1, 2, 'Shell game', 'Amber flakes contain pollen from extinct plants.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo13',
      categoryId: 'drama',
      title: 'Quiet Frequency',
      year: 2024,
      genre: 'Drama',
      description:
          'A hearing therapist maps “dead air” pockets where patients hear old radio dramas.',
      posterPrimary: const Color(0xFF3949AB),
      posterSecondary: const Color(0xFF111633),
      backdropPrimary: const Color(0xFF1F2766),
      backdropSecondary: const Color(0xFF02030A),
      coverUrl: _tvShowsDemoPoster(19),
      backdropUrl: _tvShowsDemoPoster(19),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo13', 1, 1, 'Threshold', 'Whispers align with vacuum tube hiss patterns.'),
            ep('sv_demo13', 1, 2, 'Feedback', 'Patients hum the same ad jingle from different decades.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo14',
      categoryId: 'crime',
      title: 'Ink Witness',
      year: 2023,
      genre: 'Crime',
      description:
          'Forensic ink dating collides with forgeries that reference tomorrow’s headlines.',
      posterPrimary: const Color(0xFF1E88E5),
      posterSecondary: const Color(0xFF0D2840),
      backdropPrimary: const Color(0xFF104A78),
      backdropSecondary: const Color(0xFF02060A),
      coverUrl: _tvShowsDemoPoster(20),
      backdropUrl: _tvShowsDemoPoster(20),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo14', 1, 1, 'Press check', 'A plate warms before the paper arrives.'),
            ep('sv_demo14', 1, 2, 'Bleed test', 'Margins shift when humidity is controlled.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo15',
      categoryId: 'kids',
      title: 'Cloud Kitchen Jr.',
      year: 2023,
      genre: 'Kids',
      description:
          'Young chefs compete to plate dishes that look like weather patterns.',
      posterPrimary: const Color(0xFFEC407A),
      posterSecondary: const Color(0xFF461327),
      backdropPrimary: const Color(0xFF7A2342),
      backdropSecondary: const Color(0xFF070205),
      coverUrl: _tvShowsDemoPoster(21),
      backdropUrl: _tvShowsDemoPoster(21),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo15', 1, 1, 'Cumulus toast', 'Bread rises into layered curves.'),
            ep('sv_demo15', 1, 2, 'Fog soup', 'Steam refuses to rise until the timer sings.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo16',
      categoryId: 'action',
      title: 'Razor Reef',
      year: 2020,
      genre: 'Action',
      description:
          'Divers recover cargo from a reef that rearranges itself between tides.',
      posterPrimary: const Color(0xFF00ACC1),
      posterSecondary: const Color(0xFF003238),
      backdropPrimary: const Color(0xFF00606B),
      backdropSecondary: const Color(0xFF000506),
      coverUrl: _tvShowsDemoPoster(22),
      backdropUrl: _tvShowsDemoPoster(22),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo16', 1, 1, 'Low slack', 'Chains vibrate at a frequency the ship denies.'),
            ep('sv_demo16', 1, 2, 'Coral map', 'Polyps grow toward a buoy that should not exist.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo17',
      categoryId: 'drama',
      title: 'Winter Registry',
      year: 2022,
      genre: 'Drama',
      description:
          'A census caravan discovers towns that share one address across three counties.',
      posterPrimary: const Color(0xFF78909C),
      posterSecondary: const Color(0xFF242B2F),
      backdropPrimary: const Color(0xFF455A64),
      backdropSecondary: const Color(0xFF040506),
      coverUrl: _tvShowsDemoPoster(23),
      backdropUrl: _tvShowsDemoPoster(23),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo17', 1, 1, 'Duplicate lot', 'Two deeds reference the same rock formation.'),
            ep('sv_demo17', 1, 2, 'Snow line', 'Drifts stop at a fence that appears on no plat.'),
          ],
        ),
      ],
    ),
    MockSeries(
      id: 'sv_demo18',
      categoryId: 'crime',
      title: 'Neon Alibi',
      year: 2024,
      genre: 'Crime / Thriller',
      description:
          'Security tapes show suspects in places where neon tubes were replaced that morning.',
      posterPrimary: const Color(0xFFE91E63),
      posterSecondary: const Color(0xFF45091D),
      backdropPrimary: const Color(0xFF7A1038),
      backdropSecondary: const Color(0xFF060103),
      coverUrl: _tvShowsDemoPoster(24),
      backdropUrl: _tvShowsDemoPoster(24),
      seasons: [
        MockSeason(
          number: 1,
          episodes: [
            ep('sv_demo18', 1, 1, 'Tube log', 'Ballast signatures differ by one minute per block.'),
            ep('sv_demo18', 1, 2, 'Glow shift', 'A marquee spells a name that is not on payroll.'),
          ],
        ),
      ],
    ),
  ];
}
