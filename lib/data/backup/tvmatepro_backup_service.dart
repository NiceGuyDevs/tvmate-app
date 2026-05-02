import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../account/account_store.dart';
import '../app_locale_store.dart';
import '../clock_overlay_settings_store.dart';
import '../library_controller.dart';
import '../live_favorite_groups_store.dart';
import '../live_hero_preview_audio_store.dart';
import '../live_tv_card_style_store.dart';
import '../live_tv_grid_columns_store.dart';
import '../live_tv_name_horizontal_bias_store.dart';
import '../live_tv_name_vertical_bias_store.dart';
import '../live_tv_hero_appearance_store.dart';
import '../live_tv_hero_layout_store.dart';
import '../media_card_style_store.dart';
import '../movie_rail_page_size_store.dart';
import '../episode_vod_label_store.dart';
import '../movie_vod_label_store.dart';
import '../movie_watched_store.dart';
import '../series_rail_page_size_store.dart';
import '../series_vod_label_store.dart';
import '../subtitle_appearance_store.dart';
import '../subtitle_settings_store.dart';
import '../../player/playback_resume_store.dart';
import '../../player/vod_audio_offset_store.dart';
import '../my_list_store.dart';
import '../my_space_store.dart';
import '../parental_control_store.dart';
import '../playlist_group_visibility_store.dart';
import '../recording_approval_store.dart';
import '../top_menu_store.dart';
import '../library_disk_store.dart';
import '../stored_playlist.dart';
import '../lightning_switch_store.dart';
import '../performance_tier_store.dart';
import '../playlist_channel_override_store.dart';
import '../playlist_epg_timezone_store.dart';
import '../team_visual_store.dart';
import '../tv_keyboard_language_store.dart';
import '../xtream_catalog_repository.dart';
import 'tvmatepro_backup_constants.dart';
import 'tvmatepro_backup_paths.dart';

enum TvMateBackupKind { personal, share }

/// Build / apply TVMatePro settings backup JSON.
class TvMateBackupService {
  TvMateBackupService._();
  static final TvMateBackupService instance = TvMateBackupService._();

  static Future<void> _ensureStoresLoaded() async {
    await appLocaleStore.ensureLoaded();
    await LiveFavoriteGroupsStore.instance.ensureLoaded();
    await MyListStore.instance.ensureLoaded();
    await MovieWatchedStore.instance.ensureLoaded();
    await MovieVodLabelStore.instance.ensureLoaded();
    await SeriesVodLabelStore.instance.ensureLoaded();
    await EpisodeVodLabelStore.instance.ensureLoaded();
    await clockOverlaySettingsStore.ensureLoaded();
    await liveTvCardStyleStore.ensureLoaded();
    await mediaCardStyleStore.ensureLoaded();
    await liveTvHeroLayoutStore.ensureLoaded();
    await liveTvHeroAppearanceStore.ensureLoaded();
    await liveTvGridColumnsStore.ensureLoaded();
    await liveTvNameVerticalBiasStore.ensureLoaded();
    await liveTvNameHorizontalBiasStore.ensureLoaded();
    await movieRailPageSizeStore.ensureLoaded();
    await seriesRailPageSizeStore.ensureLoaded();
    await teamVisualStore.ensureLoaded();
    await liveHeroPreviewAudioStore.ensureLoaded();
    await playlistGroupVisibilityStore.ensureLoaded();
    await parentalControlStore.ensureLoaded();
    await recordingApprovalStore.ensureLoaded();
    await topMenuStore.load();
    await MySpaceStore.instance.ensureLoaded();
    await SubtitleSettingsStore.instance.ensureLoaded();
    await SubtitleAppearanceStore.instance.ensureLoaded();
    await performanceTierStore.ensureLoaded();
    await lightningSwitchStore.ensureLoaded();
    await playlistEpgTimezoneStore.ensureLoaded();
    await playlistChannelOverrideStore.ensureLoaded();
    await accountStore.ensureLoaded();
  }

  /// Serializes current app settings (excluding catalog cache / downloads).
  Future<Map<String, dynamic>> buildSnapshot(TvMateBackupKind kind) async {
    await _ensureStoresLoaded();
    var library =
        Map<String, dynamic>.from(libraryController.exportLibraryForBackup());
    if (kind == TvMateBackupKind.share) {
      library = _stripLibrarySecrets(library);
    }

    final favGroups = [
      for (final g in LiveFavoriteGroupsStore.instance.groupsUnordered)
        g.toJson(),
    ];

    final snap = <String, dynamic>{
      'backupFormat': kTvMateBackupFormatVersion,
      'kind': kind == TvMateBackupKind.personal ? 'personal' : 'share',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appLanguageCode': appLocaleStore.languageCode,
      'performanceTier': performanceTierStore.exportForBackup(),
      'lightningSwitch': lightningSwitchStore.exportForBackup(),
      'library': library,
      'liveFavoriteGroups': favGroups,
      'myList': {
        'movieIds': List<String>.from(MyListStore.instance.movieIds),
        'seriesIds': List<String>.from(MyListStore.instance.seriesIds),
        'liveChannelIds': List<String>.from(MyListStore.instance.liveChannelIds),
      },
      // Legacy: ids with watched label only (derived from MovieVodLabelStore).
      // Full VOD state (watching / continue / watched) is in vodMovieLabels.
      'watchedMovieIds': List<String>.from(MovieWatchedStore.instance.movieIds),
      // Per-id label index: 1=watching, 2=continueWatching, 3=watched (see MovieVodLabel).
      'vodMovieLabels': MovieVodLabelStore.instance.exportForBackup(),
      'vodSeriesLabels': SeriesVodLabelStore.instance.exportForBackup(),
      'vodEpisodeLabels': EpisodeVodLabelStore.instance.exportForBackup(),
      'clock': clockOverlaySettingsStore.exportForBackup(),
      'liveTvCardStyle': liveTvCardStyleStore.style.storageValue,
      'movieCardStyle':
          MediaCardStyleStore.storageString(mediaCardStyleStore.movieStyle),
      'seriesCardStyle':
          MediaCardStyleStore.storageString(mediaCardStyleStore.seriesStyle),
      'heroHeightPercent': liveTvHeroLayoutStore.heroHeightPercent,
      'heroAppearance': liveTvHeroAppearanceStore.exportForBackup(),
      'liveTvGridColumns': liveTvGridColumnsStore.columns,
      'liveTvNameVerticalStep': liveTvNameVerticalBiasStore.step,
      'liveTvNameHorizontalStep': liveTvNameHorizontalBiasStore.step,
      'movieRailPageSize': movieRailPageSizeStore.size,
      'seriesRailPageSize': seriesRailPageSizeStore.size,
      'visualTeam': teamVisualStore.team.storageValue,
      'heroPreviewAudioMuted': liveHeroPreviewAudioStore.muted,
      'groupVisibility': playlistGroupVisibilityStore.exportForBackup(),
      'parentalControl': parentalControlStore.exportForBackup(),
      'recordingApproval': recordingApprovalStore.exportForBackup(),
      'topMenu': topMenuStore.exportForBackup(),
      'subtitles': SubtitleSettingsStore.instance.exportForBackup(
        stripSecrets: kind == TvMateBackupKind.share,
      ),
      'subtitleAppearance': SubtitleAppearanceStore.instance.exportForBackup(),
      'playbackResume': await PlaybackResumeStore.exportForBackup(),
      'vodAudioOffsets': await VodAudioOffsetStore.exportForBackup(),
      'mySpace': {
        'sections': [
          for (final s in MySpaceStore.instance.sectionsUnordered) s.toJson(),
        ],
      },
      'epgTimezone': playlistEpgTimezoneStore.exportForBackup(),
      'channelOverrides': playlistChannelOverrideStore.exportForBackup(),
      'tvKeyboardLanguages': await TvKeyboardLanguageStore.exportForBackup(),
    };

    if (kind == TvMateBackupKind.personal) {
      final acc = await accountStore.exportForBackup();
      if (acc != null) {
        snap['account'] = acc;
      }
    }

    return snap;
  }

  /// Writes JSON to Downloads (or fallback dir). Returns absolute path.
  Future<String> exportToDownloads(TvMateBackupKind kind) async {
    final dir = await resolveTvMateBackupDirectory();
    final name = tvMateBackupFileNameNow();
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    final map = await buildSnapshot(kind);
    final json = const JsonEncoder.withIndent('  ').convert(map);
    await file.writeAsString(json, flush: true);
    return file.path;
  }

  Future<void> applyFromJsonString(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const TvMateBackupException('Not a JSON object.');
    }
    await applyFromMap(decoded);
  }

  Future<void> applyFromMap(Map<String, dynamic> m) async {
    await _ensureStoresLoaded();
    final ver = m['backupFormat'];
    if (ver is! num || ver.toInt() != kTvMateBackupFormatVersion) {
      throw TvMateBackupException(
        'Unsupported backup version: $ver (expected $kTvMateBackupFormatVersion).',
      );
    }

    final lang = m['appLanguageCode'];
    if (lang is String && AppLocaleStore.supportedLanguageCodes.contains(lang)) {
      await appLocaleStore.setLanguageCode(lang);
    }

    final perf = m['performanceTier'];
    if (perf is Map<String, dynamic>) {
      await performanceTierStore.applyFromBackup(perf);
    }

    final lightning = m['lightningSwitch'];
    if (lightning is Map<String, dynamic>) {
      await lightningSwitchStore.applyFromBackup(lightning);
    }

    final lib = m['library'];
    if (lib is! Map<String, dynamic>) {
      throw const TvMateBackupException('Missing library.');
    }
    await _applyLibrary(lib);

    final gv = m['groupVisibility'];
    if (gv is Map<String, dynamic>) {
      await playlistGroupVisibilityStore.replaceFromBackup(gv);
    } else {
      await playlistGroupVisibilityStore.replaceFromBackup(null);
    }

    final pc = m['parentalControl'];
    if (pc is Map<String, dynamic>) {
      await parentalControlStore.replaceFromBackup(pc);
    }

    final favRaw = m['liveFavoriteGroups'];
    if (favRaw is List) {
      final maps = <Map<String, dynamic>>[
        for (final e in favRaw)
          if (e is Map<String, dynamic>) e,
      ];
      await LiveFavoriteGroupsStore.instance.replaceFromBackup(maps);
    } else {
      await LiveFavoriteGroupsStore.instance.replaceFromBackup(const []);
    }

    final myList = m['myList'];
    if (myList is Map<String, dynamic>) {
      await MyListStore.instance.replaceFromBackup(
        movieIds: List<String>.from(myList['movieIds'] as List? ?? const []),
        seriesIds: List<String>.from(myList['seriesIds'] as List? ?? const []),
        liveChannelIds:
            List<String>.from(myList['liveChannelIds'] as List? ?? const []),
      );
    } else {
      await MyListStore.instance.replaceFromBackup(
        movieIds: const [],
        seriesIds: const [],
        liveChannelIds: const [],
      );
    }

    final vodLabelsRaw = m['vodMovieLabels'];
    if (vodLabelsRaw is Map<String, dynamic>) {
      await MovieVodLabelStore.instance.replaceFromBackupMap(vodLabelsRaw);
    } else {
      final watchedRaw = m['watchedMovieIds'];
      if (watchedRaw is List) {
        await MovieVodLabelStore.instance.replaceWatchedOnlyFromLegacyBackup(
          List<String>.from(watchedRaw),
        );
      } else {
        // No movie VOD block: clear labels (avoid stale state vs backup file).
        await MovieVodLabelStore.instance.replaceFromBackupMap({});
      }
    }

    final vodSeriesRaw = m['vodSeriesLabels'];
    if (vodSeriesRaw is Map<String, dynamic>) {
      await SeriesVodLabelStore.instance.replaceFromBackupMap(vodSeriesRaw);
    } else {
      await SeriesVodLabelStore.instance.replaceFromBackupMap({});
    }

    final vodEpisodeRaw = m['vodEpisodeLabels'];
    if (vodEpisodeRaw is Map<String, dynamic>) {
      await EpisodeVodLabelStore.instance.replaceFromBackupMap(vodEpisodeRaw);
    } else {
      await EpisodeVodLabelStore.instance.replaceFromBackupMap({});
    }

    final clock = m['clock'];
    if (clock is Map<String, dynamic>) {
      await clockOverlaySettingsStore.applyBackup(clock);
    }

    final ltStyle = m['liveTvCardStyle'] as String?;
    if (ltStyle != null) {
      await liveTvCardStyleStore.setStyle(
        LiveTvCardStyleStore.parseStyleStorage(ltStyle),
      );
    }

    final mvStyle = m['movieCardStyle'] as String?;
    if (mvStyle != null) {
      await mediaCardStyleStore.setMovieStyle(
        MediaCardStyleStore.parseStorage(mvStyle),
      );
    }
    final srStyle = m['seriesCardStyle'] as String?;
    if (srStyle != null) {
      await mediaCardStyleStore.setSeriesStyle(
        MediaCardStyleStore.parseStorage(srStyle),
      );
    }

    final heroPct = m['heroHeightPercent'];
    if (heroPct is num) {
      await liveTvHeroLayoutStore.setHeroHeightPercent(heroPct.toInt());
    }

    final heroApp = m['heroAppearance'];
    if (heroApp is Map<String, dynamic>) {
      await liveTvHeroAppearanceStore.replaceFromBackup(heroApp);
    }

    final gridCols = m['liveTvGridColumns'];
    if (gridCols is num) {
      await liveTvGridColumnsStore.setColumns(gridCols.toInt());
    }

    final nameStep = m['liveTvNameVerticalStep'];
    if (nameStep is num) {
      await liveTvNameVerticalBiasStore.setStep(nameStep.toInt());
    }
    final nameHStep = m['liveTvNameHorizontalStep'];
    if (nameHStep is num) {
      await liveTvNameHorizontalBiasStore.setStep(nameHStep.toInt());
    }
    final movRail = m['movieRailPageSize'];
    if (movRail is num) {
      await movieRailPageSizeStore.setSize(movRail.toInt());
    }
    final serRail = m['seriesRailPageSize'];
    if (serRail is num) {
      await seriesRailPageSizeStore.setSize(serRail.toInt());
    }

    final team = m['visualTeam'] as String?;
    if (team != null) {
      await teamVisualStore.setTeam(TeamVisualStore.parseStorage(team));
    }

    final muted = m['heroPreviewAudioMuted'];
    if (muted is bool) {
      await liveHeroPreviewAudioStore.setMuted(muted);
    }

    final ms = m['mySpace'];
    if (ms is Map<String, dynamic>) {
      final list = ms['sections'] as List? ?? const [];
      final maps = <Map<String, dynamic>>[
        for (final e in list)
          if (e is Map<String, dynamic>) e,
      ];
      await MySpaceStore.instance.replaceFromBackup(maps);
    } else {
      await MySpaceStore.instance.replaceFromBackup(const []);
    }

    final ra = m['recordingApproval'];
    if (ra is Map<String, dynamic>) {
      await recordingApprovalStore.replaceFromBackup(ra);
    } else {
      await recordingApprovalStore.replaceFromBackup(null);
    }

    final tm = m['topMenu'];
    if (tm is Map<String, dynamic>) {
      await topMenuStore.replaceFromBackup(tm);
    }

    final sub = m['subtitles'];
    if (sub is Map<String, dynamic>) {
      await SubtitleSettingsStore.instance.applyFromBackup(sub);
    }

    final app = m['subtitleAppearance'];
    if (app is Map<String, dynamic>) {
      await SubtitleAppearanceStore.instance.applyFromBackup(app);
    }

    final resume = m['playbackResume'];
    if (resume is Map<String, dynamic>) {
      await PlaybackResumeStore.applyFromBackup(resume);
    }

    final vodAud = m['vodAudioOffsets'];
    if (vodAud is Map<String, dynamic>) {
      await VodAudioOffsetStore.applyFromBackup(vodAud);
    }

    final epgTz = m['epgTimezone'];
    if (epgTz is Map<String, dynamic>) {
      await playlistEpgTimezoneStore.replaceFromBackup(epgTz);
    }

    final chOverrides = m['channelOverrides'];
    if (chOverrides is Map<String, dynamic>) {
      await playlistChannelOverrideStore.replaceFromBackup(chOverrides);
    }

    final kbdLangs = m['tvKeyboardLanguages'];
    if (kbdLangs is List) {
      await TvKeyboardLanguageStore.replaceFromBackup(
        List<String>.from(kbdLangs),
      );
    }

    final acct = m['account'];
    if (acct is Map<String, dynamic>) {
      await accountStore.applyFromBackup(acct);
    }

    await xtreamCatalogRepository.syncFromLibrary(libraryController);
  }

  Future<void> _applyLibrary(Map<String, dynamic> m) async {
    if (m['v'] != kLibraryDiskFormatVersion) {
      throw TvMateBackupException(
        'Bad library block (v ${m['v']}, expected $kLibraryDiskFormatVersion).',
      );
    }
    final pl = m['playlists'];
    if (pl is! List) {
      throw const TvMateBackupException('Invalid playlists.');
    }
    final next = <StoredPlaylist>[];
    for (final e in pl) {
      if (e is Map<String, dynamic>) {
        try {
          next.add(StoredPlaylist.fromJson(e));
        } catch (err, st) {
          debugPrint('Backup skip playlist: $err\n$st');
        }
      }
    }
    await libraryController.replaceFromBackup(
      newPlaylists: next,
      newActiveId: m['activePlaylistId'] as String?,
      demoModePref: m['demoMode'] as bool? ?? true,
      demoFixApplied: m['demoFixApplied'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _stripLibrarySecrets(Map<String, dynamic> lib) {
    final out = Map<String, dynamic>.from(lib);
    final pl = out['playlists'];
    if (pl is List) {
      out['playlists'] = [
        for (final e in pl) _stripPlaylistMap(e),
      ];
    }
    return out;
  }

  static dynamic _stripPlaylistMap(dynamic e) {
    if (e is! Map<String, dynamic>) return e;
    final o = Map<String, dynamic>.from(e);
    o['username'] = null;
    o['password'] = null;
    return o;
  }
}

class TvMateBackupException implements Exception {
  const TvMateBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}
