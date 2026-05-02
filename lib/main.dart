import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app.dart';
import 'data/library_controller.dart';
import 'data/live_favorite_groups_store.dart';
import 'data/live_tv_card_style_store.dart';
import 'data/clock_overlay_settings_store.dart';
import 'data/team_visual_store.dart';
import 'data/live_hero_preview_audio_store.dart';
import 'data/live_tv_grid_columns_store.dart';
import 'data/live_tv_hero_appearance_store.dart';
import 'data/live_tv_hero_layout_store.dart';
import 'data/live_tv_name_horizontal_bias_store.dart';
import 'data/live_tv_name_vertical_bias_store.dart';
import 'data/media_card_style_store.dart';
import 'data/movie_rail_page_size_store.dart';
import 'data/series_rail_page_size_store.dart';
import 'data/playlist_epg_timezone_store.dart';
import 'data/parental_control_store.dart';
import 'data/playlist_group_visibility_store.dart';
import 'data/recording_approval_store.dart';
import 'data/app_locale_store.dart';
import 'data/app_session_restore_store.dart';
import 'data/device_memory_channel.dart';
import 'data/lightning_switch_store.dart';
import 'data/performance_tier_store.dart';
import 'data/top_menu_store.dart';
import 'data/library_store_db.dart';
import 'data/xtream_catalog_cache_db.dart';
import 'data/xtream_catalog_repository.dart';
import 'account/account_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }

  // Desktop: initialize sqflite FFI and media_kit
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    mk.MediaKit.ensureInitialized();
  }

  DeviceMemoryChannel.registerImeVisibilityListener();
  await DeviceMemoryChannel.ensureTvTextInputProfileLoaded();
  await DeviceMemoryChannel.ensureIsGoogleTvStreamerLoaded();
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  await libraryStoreDb.initialize();
  await xtreamCatalogCacheDb.initialize();
  // Load account before library so playlist visibility uses the current user id
  // on cold start (owner-tagged rows were hidden → empty list → demo mode).
  await accountStore.ensureLoaded();
  await libraryController.initialize();
  libraryController.onAfterCloudSyncChanged = () {
    unawaited(xtreamCatalogRepository.syncFromLibrary(libraryController));
  };
  await performanceTierStore.ensureLoaded();
  await lightningSwitchStore.ensureLoaded();
  // Do not await — loading the SQLite catalog can be heavy; starting it here
  // avoids an empty Live TV until the first screen's post-frame callback runs.
  // On optimized tier, delay sync so the first frames / focus settle on weak boxes.
  unawaited(_runEarlyCatalogSync());
  await LiveFavoriteGroupsStore.instance.ensureLoaded();
  await playlistGroupVisibilityStore.ensureLoaded();
  await parentalControlStore.ensureLoaded();
  await liveTvCardStyleStore.ensureLoaded();
  await mediaCardStyleStore.ensureLoaded();
  await clockOverlaySettingsStore.ensureLoaded();
  await teamVisualStore.ensureLoaded();
  await liveHeroPreviewAudioStore.ensureLoaded();
  await liveTvHeroLayoutStore.ensureLoaded();
  await liveTvHeroAppearanceStore.ensureLoaded();
  await liveTvGridColumnsStore.ensureLoaded();
  await liveTvNameVerticalBiasStore.ensureLoaded();
  await liveTvNameHorizontalBiasStore.ensureLoaded();
  await movieRailPageSizeStore.ensureLoaded();
  await seriesRailPageSizeStore.ensureLoaded();
  await recordingApprovalStore.ensureLoaded();
  await playlistEpgTimezoneStore.ensureLoaded();
  await topMenuStore.load();
  await AppSessionRestoreStore.instance.ensureLoaded();
  await appLocaleStore.ensureLoaded();
  runApp(const TvMateApp());
}

Future<void> _runEarlyCatalogSync() async {
  if (performanceTierStore.isOptimizedEffective) {
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  try {
    await xtreamCatalogRepository.syncFromLibrary(libraryController);
  } catch (e, st) {
    debugPrint('Early catalog sync failed: $e\n$st');
  }
}
