// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTopMenuManager => 'Top Menu Manager';

  @override
  String get settingsTopMenuManagerSubtitle =>
      'Reorder, add items, set startup';

  @override
  String get settingsShellThemeSubtitle => 'Visual team and accent colors';

  @override
  String get settingsShellPlaylistSubtitle => 'Switch active playlist';

  @override
  String get settingsAddPlaylist => 'Add Playlist';

  @override
  String get settingsAddPlaylistSubtitle => 'Xtream or M3U';

  @override
  String get settingsMyPlaylists => 'My Playlists';

  @override
  String settingsMyPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
      zero: 'No playlists',
    );
    return '$_temp0';
  }

  @override
  String get settingsFavoriteSetup => 'Favorite setup';

  @override
  String get settingsFavoriteSetupSubtitle => 'Live TV channel favorites';

  @override
  String get settingsClock => 'Clock';

  @override
  String get settingsClockOn => 'ON';

  @override
  String get settingsClockOff => 'OFF';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String settingsAppearanceSubtitle(int heroPercent, int columns) {
    return 'Hero $heroPercent% · $columns per row';
  }

  @override
  String get settingsRecordingEdit => 'Catch-up Edit';

  @override
  String get settingsRecordingEditSubtitle => 'Catch-up channel setup';

  @override
  String get catchupSelectPlaylistHelp =>
      'Select a playlist to configure catch-up channels';

  @override
  String get catchupNoXtreamPlaylists =>
      'No Xtream playlists found.\nAdd an Xtream playlist first.';

  @override
  String get catchupBreadcrumbCategories => 'Catch-up · Categories';

  @override
  String catchupBreadcrumbWithCategory(String categoryName) {
    return 'Catch-up · $categoryName';
  }

  @override
  String get catchupFilterQuickOn => 'Catch-up filter: ON';

  @override
  String get catchupFilterQuickOff => 'Catch-up filter: OFF';

  @override
  String get catchupEmptyStateTitle => 'Set up catch-up in Settings';

  @override
  String catchupEmptyStateBody(String entryLabel) {
    return 'Go to Settings → $entryLabel to approve\ncategories and channels for catch-up.';
  }

  @override
  String get catchupXtreamOnly =>
      'Catch-up is only available for Xtream playlists.';

  @override
  String get catchupManage => 'Manage catch-up';

  @override
  String get catchupGroupOptions => 'Catch-up options';

  @override
  String get catchupGroupCategories => 'Categories';

  @override
  String get catchupSelectAll => 'Select all';

  @override
  String get catchupClearAll => 'Clear all';

  @override
  String catchupFilterSub(String tabName) {
    return 'Only show channels whose source advertises catch-up. Hides everything else from the $tabName tab for this playlist.';
  }

  @override
  String get catchupClearConfirmTitle => 'Clear all approvals?';

  @override
  String catchupClearConfirmMessage(String playlistName) {
    return 'Removes every approved category and channel from \"$playlistName\"\'s catch-up list. The playlist itself isn\'t touched.';
  }

  @override
  String get catchupFilterBannerLead => 'Catch-up filter is on. ';

  @override
  String catchupFilterHiddenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels without catch-up are hidden from this list.',
      one: '1 channel without catch-up is hidden from this list.',
    );
    return '$_temp0 Turn the filter off in catch-up options to approve them.';
  }

  @override
  String get catchupNoChannelsInCategory => 'No channels in this category.';

  @override
  String get catchupNoLiveCategoriesSync =>
      'No live categories found.\nSync this playlist first.';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsBackupSubtitle => 'Export / import settings';

  @override
  String get settingsDemoMode => 'Demo mode';

  @override
  String get settingsDemoModeSubtitleBrowseDemo =>
      'Browse is demo until you add a playlist';

  @override
  String get settingsDemoModeSubtitleRealChannels =>
      'Real channels — demo is off while playlists exist';

  @override
  String get settingsDemoModeAbout =>
      'Built-in demo: sample Live TV, Movies, and Series with bundled artwork and mock listings. Playback uses demo streams so you can explore the UI. Add an Xtream or M3U playlist anytime to use your real IPTV.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Interface language';

  @override
  String get settingsPerformance => 'Performance';

  @override
  String get settingsPerformanceSubtitle =>
      'Full quality or optimized for weaker devices';

  @override
  String get performanceScreenTitle => 'Performance';

  @override
  String get performanceScreenIntro =>
      'Choose how hard the app pushes your device. Powerful streamers (for example NVIDIA Shield) can use Full quality. Small sticks and streamers often run smoother with Optimized. Automatic picks from total device memory. You can change this anytime.';

  @override
  String get performanceModeAuto => 'Automatic';

  @override
  String get performanceModeAutoSubtitle =>
      'Recommended — picks Full or Optimized from device memory';

  @override
  String get performanceModeFull => 'Full quality';

  @override
  String get performanceModeFullSubtitle =>
      'Richest visuals — best on strong hardware';

  @override
  String get performanceModeOptimized => 'Optimized';

  @override
  String get performanceModeOptimizedSubtitle =>
      'Lighter background, smaller cache, deferred sync. One video decoder at a time (grid hero pauses in fullscreen) — smoother on weak TVs';

  @override
  String performanceDetectedRam(String mb) {
    return 'Detected total RAM: $mb MB';
  }

  @override
  String get performanceDetectedRamUnknown =>
      'RAM not detected — Automatic uses Full quality';

  @override
  String get performanceAutoCurrentlyUsingFull =>
      'Right now, Automatic is using Full quality.';

  @override
  String get performanceAutoCurrentlyUsingOptimized =>
      'Right now, Automatic is using Optimized.';

  @override
  String get settingsLightningSwitch => 'Lightning switch';

  @override
  String get settingsLightningSwitchSubtitle =>
      'Faster live channel changes (strong devices only)';

  @override
  String get lightningSwitchScreenTitle => 'Lightning switch';

  @override
  String get lightningSwitchScreenIntro =>
      'When off, live TV uses the same single-decoder path as Optimized — same buffering and timing. Turn on to use a second decoder for very fast channel changes; this uses more memory and may cause lag on some devices.';

  @override
  String get lightningSwitchModeOff => 'Off';

  @override
  String get lightningSwitchModeOffSubtitle =>
      'Same live player behavior as Optimized';

  @override
  String get lightningSwitchModeOn => 'On';

  @override
  String get lightningSwitchModeOnSubtitle =>
      'Dual-decoder pool — fastest zaps; may lag on some devices';

  @override
  String get lightningSwitchLagSnack =>
      'Lightning is on. If you notice lag, turn it off here.';

  @override
  String get tvRemoteTypingButton => 'Type with TV remote';

  @override
  String get tvRemoteTypingTitle => 'Enter text';

  @override
  String get tvRemoteTypingDone => 'Done';

  @override
  String get tvRemoteGoogleTvKeyboardHint =>
      'The on-screen keyboard may not open on Google TV or Chromecast. Use the line above to type with your remote.';

  @override
  String get tvKeyboardLanguagesTitle => 'Languages';

  @override
  String get tvKeyboardPickLanguagesSubtitle =>
      'Mark languages to show when you open the list (top or globe). Order follows the order you add them.';

  @override
  String get tvKeyboardLayoutNotAvailable =>
      'On-screen keyboard not available for this language yet.';

  @override
  String get languageScreenTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrew => 'Hebrew';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageGerman => 'German';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageItalian => 'Italian';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageVietnamese => 'Vietnamese';

  @override
  String get actionPlay => 'Play';

  @override
  String get actionExternal => 'External';

  @override
  String get actionTrailer => 'Trailer';

  @override
  String get actionMyList => 'My list';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionWatched => 'Watched';

  @override
  String get actionUnwatch => 'Unwatch';

  @override
  String get actionWatching => 'Watching';

  @override
  String get actionWatchingOff => 'Not watching';

  @override
  String get actionContinueWatching => 'Continue watching';

  @override
  String get actionContinueWatchingOff => 'Clear continue';

  @override
  String get navLiveTv => 'Live TV';

  @override
  String get navMovies => 'Movies';

  @override
  String get navSeries => 'Series';

  @override
  String get navRecording => 'Catch-up';

  @override
  String get navPlaylist => 'Playlist';

  @override
  String get navTheme => 'Theme';

  @override
  String get navClock => 'Clock';

  @override
  String get navAppearance => 'Appearance';

  @override
  String get navBackup => 'Backup';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navLanguage => 'Language';

  @override
  String get navSettings => 'Settings';

  @override
  String get nsCategoryOldSettings => 'Old settings';

  @override
  String get searchMoviesAndSeries => 'Search Movies & Series';

  @override
  String get searchLiveTv => 'Search Live TV';

  @override
  String get searchRecording => 'Search Catch-up';

  @override
  String get searchHint => 'Type to filter this page';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchApply => 'Apply';

  @override
  String get searchLabel => 'Search';

  @override
  String searchPrefixWithQuery(String query) {
    return 'Search: $query';
  }

  @override
  String get playlistEmptyTitle => 'No playlists yet';

  @override
  String get playlistEmptySubtitle => 'Add one in Settings';

  @override
  String get playlistGoToSettings => 'Go to Settings';

  @override
  String get playlistDismissBarrier => 'Dismiss playlist switcher';

  @override
  String playlistStatsLine(int liveCount, int movieCount, int seriesCount) {
    return '$liveCount live · $movieCount movies · $seriesCount series';
  }

  @override
  String get topMenuManagerTitle => 'Top Menu Manager';

  @override
  String get topMenuOrderSection => 'Menu order';

  @override
  String get topMenuReorderHelp =>
      'Press OK to pick up, then Up/Down to move, OK to drop.';

  @override
  String get topMenuRemoveHelp =>
      'Optional tabs: press Right to remove from the bar (OK is only for pick up / drop).';

  @override
  String get topMenuAddToMenu => 'Add to menu';

  @override
  String get topMenuStartupSection => 'Startup category';

  @override
  String get topMenuStartupHelp => 'Which screen opens when the app starts.';

  @override
  String get topMenuSettingsLocked => 'Settings';

  @override
  String get topMenuAlwaysLast => 'Always last';

  @override
  String get commonBack => 'Back';

  @override
  String get mvPickerAddChannel => 'Add channel';

  @override
  String get mvPickerChangeChannel => 'Change channel';

  @override
  String get mvChooseChannel => 'Choose channel';

  @override
  String get mvAddScreen => 'Add screen';

  @override
  String get mvChangeChannel => 'Change channel';

  @override
  String get mvReduceScreen => 'Reduce screen';

  @override
  String get mvEnlargeScreen => 'Enlarge screen';

  @override
  String get mvFullScreen => 'Full screen';

  @override
  String get mvRemoveScreen => 'Remove screen';

  @override
  String get mvExitMultiview => 'Exit multiview';

  @override
  String get mvMenuTitle => 'Multiview';

  @override
  String get mvMenuHint => '▲▼ move · OK · Back';

  @override
  String get demoBlurbLiveTv =>
      'Live TV demo: category pills and channel grid with bundled logos. Hero panel and labels; sample stream when you open the player.';

  @override
  String get demoBlurbMovies =>
      'Movies demo: rows with bundled posters and mock details. Focus a title to update the hero and synopsis.';

  @override
  String get demoBlurbSeries =>
      'Series demo: bundled posters, seasons and episode lists—same flow as Movies. Sample stream for playback.';

  @override
  String get demoBlurbRecording =>
      'Browse catch-up EPG by category, date, and channel. Select a past program to play.';

  @override
  String get demoBlurbTeam =>
      'Choose Cosmic, Aurora, Solar, or Heritage for the shell backdrop and chrome.';

  @override
  String get demoBlurbSettings =>
      'Demo settings hub. Add playlist, manage profiles, and playback options will live here.';

  @override
  String get demoBlurbOptional =>
      'Optional shell destination. Enable it in Top Menu Manager to show it in the bar.';

  @override
  String get clockInfoBanner =>
      'Optional floating clock on top of the app. Turn it ON or OFF — the top bar always shows the time; this overlay is extra. Choose 12 or 24 hour, size, corner of the screen, brightness (opacity), and color. Frame adds a border and shows the date under the time; turn it off for time only. Use Adjust position to nudge the overlay per corner with the D-pad. Move focus with the remote and Select to apply each option; changes apply everywhere while you use the app.';

  @override
  String get clockToggleOn => 'Clock ON';

  @override
  String get clockToggleOff => 'Clock OFF';

  @override
  String get clockTapHide => 'Tap to hide';

  @override
  String get clockTapShow => 'Tap to show';

  @override
  String get clockFrameOn => 'Frame ON';

  @override
  String get clockFrameOff => 'Frame OFF';

  @override
  String get clockFrameSubOn => 'Border + date under time';

  @override
  String get clockFrameSubOff => 'Time only (no border, no date)';

  @override
  String get clock12Hour => '12 hour';

  @override
  String get clock12HourSub => 'AM / PM';

  @override
  String get clock24Hour => '24 hour';

  @override
  String get clock24HourSub => '00–23';

  @override
  String get clockSizeSmall => 'Small';

  @override
  String get clockSizeMedium => 'Medium';

  @override
  String get clockSizeLarge => 'Large';

  @override
  String get clockSizeSubtitle => 'Size';

  @override
  String get clockCornerSubtitle => 'Corner';

  @override
  String get clockCornerTopLeft => 'Top left';

  @override
  String get clockCornerTopRight => 'Top right';

  @override
  String get clockCornerBottomLeft => 'Bottom left';

  @override
  String get clockCornerBottomRight => 'Bottom right';

  @override
  String get clockAdjustPosition => 'Adjust position';

  @override
  String get clockAdjustPositionSub => 'D-pad moves · Back saves';

  @override
  String get clockOpacitySubtitle => 'Opacity';

  @override
  String clockOpacityPercent(int percent) {
    return '$percent%';
  }

  @override
  String clockColorPreset(int index) {
    return 'Color $index';
  }

  @override
  String get clockColorPresetSubtitle => 'Preset';

  @override
  String get clockPositionAdjustTitle => 'Adjust position';

  @override
  String clockPositionCornerLine(String corner) {
    return 'Corner: $corner';
  }

  @override
  String clockPositionOffsetLine(int dx, int dy, int max) {
    return 'Offset: $dx × $dy (max ±$max)';
  }

  @override
  String get clockPositionHelpEnabled =>
      'Use the D-pad to move the on-screen clock. Changes apply to this corner only. Back returns to Clock settings.';

  @override
  String get clockPositionHelpDisabled =>
      'Turn the clock ON to see the overlay while you adjust. Offsets are still saved for each corner.';

  @override
  String get appearanceLayoutEditors => 'Layout editors';

  @override
  String get appearanceHeroBackgroundTitle => 'Hero background';

  @override
  String get appearanceHeroBackgroundSubtitle =>
      'Colors behind the Live TV preview';

  @override
  String get heroAppearanceScreenTitle => 'Hero background';

  @override
  String get heroAppearanceHint =>
      'Changes save automatically. Reset restores your theme’s default hero look.';

  @override
  String get heroAppearanceReset => 'Reset to default';

  @override
  String get heroAppearanceHideControls => 'Hide controls';

  @override
  String get heroAppearanceShowControls => 'Show controls';

  @override
  String get heroAppearanceBase => 'Base color';

  @override
  String get heroAppearanceWash => 'Brush color';

  @override
  String get heroAppearanceIntensity => 'Brush strength';

  @override
  String get heroAppearanceBrushStyle => 'Brush style';

  @override
  String get heroAppearanceSectionBackground => 'Background';

  @override
  String get heroAppearanceSectionTv => 'Preview frame';

  @override
  String get heroAppearanceSectionFineTune => 'Fine tune';

  @override
  String get heroAppearanceShowFrame => 'Show TV frame';

  @override
  String get heroAppearanceFrameProfile => 'Frame profile';

  @override
  String get heroAppearanceBezelFinish => 'Bezel finish';

  @override
  String get heroAppearanceGradientDepth => 'Gradient depth';

  @override
  String get heroAppearanceFrameSlim => 'Slim';

  @override
  String get heroAppearanceFrameClassic => 'Classic';

  @override
  String get heroAppearanceFrameBold => 'Bold';

  @override
  String get heroAppearanceFrameMinimal => 'Minimal';

  @override
  String get heroAppearanceOn => 'On';

  @override
  String get heroAppearanceOff => 'Off';

  @override
  String get heroAppearanceTabColors => 'Colors';

  @override
  String get heroAppearanceTabOverlay => 'Overlay';

  @override
  String get heroAppearanceTabFrame => 'Frame';

  @override
  String get heroAppearanceTabMore => 'More';

  @override
  String get heroAppearanceWashModeBrush => 'Brush';

  @override
  String get heroAppearanceWashModeSolid => 'Solid';

  @override
  String get heroAppearanceHintShort => 'Saves automatically.';

  @override
  String get heroAppearanceSolidHint =>
      'Full-screen tint — adjust strength on the Overlay tab.';

  @override
  String get heroAppearanceHelpIntro =>
      'Use − and + on each row to change the look. The two big squares show your background and overlay. Watch the Live TV preview above.';

  @override
  String get heroAppearancePreviewBackgroundLabel => 'Background';

  @override
  String get heroAppearancePreviewOverlayLabel => 'Overlay';

  @override
  String get heroAppearanceHueRow => 'Shade';

  @override
  String get heroAppearanceSatRow => 'Vivid';

  @override
  String get heroAppearanceBriRow => 'Light';

  @override
  String get heroAppearanceHueExplain => 'Moves through the rainbow';

  @override
  String get heroAppearanceSatExplain => 'Weak color ↔ strong';

  @override
  String get heroAppearanceBriExplain => 'Dark ↔ bright';

  @override
  String get heroAppearanceFrameBanner => 'TV frame';

  @override
  String get heroAppearanceFrameExplain =>
      'A border around the small TV preview. Turn it on, then pick thickness and finish.';

  @override
  String appearancePerRowSubtitle(int count) {
    return '$count/row';
  }

  @override
  String get appearanceChannelCardStyle => 'Channel card style';

  @override
  String get appearanceMovieCardStyle => 'Movie card style';

  @override
  String get appearanceSeriesCardStyle => 'Series card style';

  @override
  String get cardStyleLiveNameOnly => 'Name only';

  @override
  String get cardStyleLiveLogoNameProgram => 'Logo + name + program';

  @override
  String get cardStyleLiveLogoNameOnly => 'Logo + name';

  @override
  String get cardStyleLiveLogoOnly => 'Logo only';

  @override
  String get movieGridSettingsTitle => 'Movie Grid Settings';

  @override
  String get movieGridMoviesPerRow => 'Movies Per Row:';

  @override
  String get movieGridPosterDisplay => 'Poster Display:';

  @override
  String get movieGridExit => 'Exit';

  @override
  String get movieGridResetDefaults => 'Reset defaults';

  @override
  String get movieGridHidePanel => 'Hide';

  @override
  String get movieGridShowPanel => 'Show';

  @override
  String get seriesGridSettingsTitle => 'Series Grid Settings';

  @override
  String get seriesGridSeriesPerRow => 'Series Per Row:';

  @override
  String get channelGridSettingsTitle => 'Channel Grid Settings';

  @override
  String get channelGridHeroBannerSize => 'Hero Banner Size:';

  @override
  String get channelGridChannelsPerRowLabel => 'Channels Per Row:';

  @override
  String get channelGridChannelDisplay => 'Channel Display:';

  @override
  String get channelGridChNamePosition => 'CH Name Position:';

  @override
  String get channelGridShowSettingsPanel => 'Show settings';

  @override
  String get cardStylePosterTitle => 'Poster+Name+Year';

  @override
  String get cardStylePosterOnly => 'Poster Only';

  @override
  String get cardStyleNamePoster => 'Name+Poster';

  @override
  String get cardStyleTitleOnly => 'Title only';

  @override
  String get catalogLoading => 'Loading…';

  @override
  String get catalogLoadingChannels => 'Loading channels…';

  @override
  String get catalogLoadingLibrary => 'Loading library…';

  @override
  String get catalogPreparing => 'Preparing…';

  @override
  String get catalogErrorPlaylist => 'Could not load playlist';

  @override
  String get catalogErrorLibrary => 'Could not load library';

  @override
  String get catalogNoCategories => 'No categories';

  @override
  String get catalogNoCategoriesSubtitle =>
      'This playlist returned no live categories.';

  @override
  String get myPlaylistsTitle => 'My Playlists';

  @override
  String get myPlaylistsSubtitle => 'Only one playlist active at a time.';

  @override
  String get myPlaylistsEmpty => 'No playlists yet. Add one from Settings.';

  @override
  String get dialogRenamePlaylist => 'Rename playlist';

  @override
  String get dialogEditPlaylist => 'Edit playlist';

  @override
  String get dialogPlaylistServerUrl => 'Server URL';

  @override
  String get dialogPlaylistUsername => 'Username';

  @override
  String get dialogPlaylistPassword => 'Password';

  @override
  String get dialogPlaylistM3uUrl => 'M3U URL';

  @override
  String get dialogPlaylistEditInvalid => 'Fill all required fields.';

  @override
  String get dialogPlaylistNameHint => 'Name';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get dialogSave => 'Save';

  @override
  String get dialogDelete => 'Delete';

  @override
  String get dialogDeletePlaylistTitle => 'Delete playlist?';

  @override
  String dialogDeletePlaylistBody(String name) {
    return '\"$name\" will be removed from this device.';
  }

  @override
  String get playlistTypeXtream => 'Xtream';

  @override
  String get playlistTypeM3u => 'M3U';

  @override
  String myPlaylistTileStats(String type, int live, int movies, int series) {
    return '$type · L$live M$movies S$series';
  }

  @override
  String get playlistActiveBadge => 'ACTIVE';

  @override
  String get playlistSubscriptionActive => 'Active';

  @override
  String get playlistSubscriptionExpired => 'Expired';

  @override
  String playlistExpireOn(String date) {
    return 'Expire on $date';
  }

  @override
  String get playlistChipGroups => 'Groups';

  @override
  String get playlistChipManageChannels => 'Manage channels';

  @override
  String get manageLiveChannelsTitle => 'Manage channels';

  @override
  String get manageLiveChannelsSubtitle =>
      'Pick a category, then rename channels, hide them from Live TV, or set a custom logo URL.';

  @override
  String get manageLiveChannelsNeedActive => 'Switch to this playlist first.';

  @override
  String get manageLiveChannelsNoCategories =>
      'No live categories. Sync the playlist first.';

  @override
  String get manageLiveChannelsCategoryEmpty => 'No channels in this category.';

  @override
  String get channelOverrideNameAction => 'Name';

  @override
  String get channelOverrideLogoAction => 'Logo';

  @override
  String get channelOverrideHiddenFromLive => 'Hidden from Live TV';

  @override
  String get channelOverrideVisibleInLive => 'Shown in Live TV';

  @override
  String get channelOverrideDisplayNameDialogTitle => 'Display name';

  @override
  String get channelOverrideDisplayNameHint =>
      'Leave empty to use the server name.';

  @override
  String get channelOverrideLogoDialogTitle => 'Custom logo URL';

  @override
  String get channelOverrideLogoDialogHint =>
      'Paste an https:// link to a PNG or JPG. Leave empty to use the playlist logo.';

  @override
  String get playlistGroupEdit => 'Edit';

  @override
  String playlistGroupOriginalLabel(String name) {
    return 'Original: $name';
  }

  @override
  String get playlistGroupCustomNameHint => 'Custom name';

  @override
  String get playlistGroupResetAlias => 'Reset';

  @override
  String get playlistGroupPillOrderTitle => 'Category pill order (Live TV)';

  @override
  String get playlistGroupPillAfterFavorites => 'After my favorites';

  @override
  String get playlistGroupPillBeforeFavorites => 'Before my favorites';

  @override
  String get playlistGroupPillPositionLabel => 'Position (1 = first)';

  @override
  String get playlistGroupPillPositionHint => '1';

  @override
  String get playlistEpgLocal => 'EPG: Local';

  @override
  String get playlistEpgOriginal => 'EPG: Original';

  @override
  String get playlistEpgTimeScreenTitle => 'EPG time';

  @override
  String get playlistEpgTimeScreenHint =>
      'Choose how programme times are shown for this playlist.';

  @override
  String get playlistEpgTimeRowLocal => 'Local';

  @override
  String get playlistEpgTimeRowLocalSubtitle => 'Use this device’s time zone';

  @override
  String get playlistEpgTimeRowOriginal => 'Original (server)';

  @override
  String get playlistEpgTimeRowOriginalSubtitle =>
      'Times as sent by the provider';

  @override
  String playlistEpgZoneChip(String zone) {
    return 'EPG: $zone';
  }

  @override
  String get playlistChipUse => 'Use';

  @override
  String get playlistChipOn => 'On';

  @override
  String get playlistChipRename => 'Ren';

  @override
  String get playlistChipDelete => 'Del';

  @override
  String get favSetupInfoBanner =>
      'Create your own Live TV categories. Add a New favorite, give it a name and order (lower numbers appear first), then Choose channels — first pick is position 1, second is 2, and so on. Open a card anytime to edit or delete. Your favorites show on Live TV as category pills alongside your playlist, even if you hide playlist groups.';

  @override
  String get favNewFavorite => 'New favorite';

  @override
  String get favCreateGroup => 'Create a group';

  @override
  String favGroupSubtitle(int count, int order) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return '$_temp0 · order $order';
  }

  @override
  String get favEditNew => 'New favorite';

  @override
  String get favEditEdit => 'Edit favorite';

  @override
  String get favEditNameLabel => 'Name';

  @override
  String get favEditNameHint => 'Shown on Live TV as a category';

  @override
  String get favEditOrderLabel => 'Order';

  @override
  String get favEditOrderHint => 'Lower = first among favorites';

  @override
  String get favEditChooseChannels => 'Choose channels';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get favEditOrderHelp =>
      'Order: first tap = 1, second = 2… Use All in category / Clear category in the picker.';

  @override
  String get favEditChannelsHeading => 'Channels in this favorite';

  @override
  String get favEditNoChannels => 'No channels yet.\nTap Choose channels.';

  @override
  String get favEditSave => 'Save';

  @override
  String get favEditDelete => 'Delete';

  @override
  String get defaultFavoriteName => 'Favorite';

  @override
  String get favPickNoXtream => 'No Xtream playlist';

  @override
  String get favPickNoXtreamSubtitle =>
      'Add an Xtream Codes playlist in My playlists to choose channels from any saved panel.';

  @override
  String get favPickHelpWithPlaylist =>
      'Playlist → category → grid. Save at bottom. Back → Save.';

  @override
  String get favPickHelpOrderBadges => 'Picks on top (1,2,3…). Back → Save.';

  @override
  String get favPickHelpSimple => 'Picks on top. Back → Save.';

  @override
  String get favPickInFavorite => 'In this favorite';

  @override
  String get favPickNoChannelsDraft =>
      'No channels yet — pick from the grid below.';

  @override
  String get favPickChannelUnavailable => 'Channel unavailable';

  @override
  String get favPickAddMore => 'Add more';

  @override
  String get favPickNoChannelsCategory => 'No channels in this category.';

  @override
  String get favPickAllInCategory => 'All in category';

  @override
  String get favPickClearCategory => 'Clear category';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get backupInfoBanner =>
      'Personal includes passwords (keep private). Share strips passwords (safe to send).';

  @override
  String get backupExportPersonal => 'Export personal';

  @override
  String get backupExportPersonalSub => 'Full backup with passwords';

  @override
  String get backupExportShare => 'Export to share';

  @override
  String get backupExportShareSub => 'Passwords removed';

  @override
  String get backupShareLastExport => 'Share last export';

  @override
  String get backupShareLastExportSub => 'Send the file you just saved';

  @override
  String get backupShareLatest => 'Share latest';

  @override
  String get backupShareLatestSub => 'Email, Drive, etc.';

  @override
  String get backupImportNavigate => 'Import backup';

  @override
  String get backupImportNavigateSub => 'Restore from file';

  @override
  String get backupDeleteNavigate => 'Delete backups';

  @override
  String get backupDeleteNavigateSub => 'Remove old files';

  @override
  String get backupToastStorageRequired =>
      'Storage permission is required to save backups.';

  @override
  String backupToastSavedDownloads(String name) {
    return 'Saved to Downloads: $name';
  }

  @override
  String backupToastExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get backupShareSubject => 'TVMate Pro backup';

  @override
  String get backupShareBody => 'TVMate Pro settings backup';

  @override
  String get backupToastNoBackupsToShare =>
      'No backup files found. Export one first.';

  @override
  String backupToastShareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get backupImportRestoredToast =>
      'Backup restored. Catalogs are refreshing.';

  @override
  String get nsMessageBackupAppliedTitle => 'Backup applied';

  @override
  String get nsMessageErrorTitle => 'Something went wrong';

  @override
  String get nsMessageDismiss => 'Dismiss';

  @override
  String backupImportFailedToast(String error) {
    return 'Import failed: $error';
  }

  @override
  String get backupImportTitle => 'Import backup';

  @override
  String get backupImportScanSubtitle =>
      'Scanning all of Downloads for tvmate-backup files';

  @override
  String get backupImportRefresh => 'Refresh';

  @override
  String get backupImportRestoring => 'Restoring backup...';

  @override
  String get backupImportEmpty => 'No backup files found in Downloads.';

  @override
  String get backupManageTitle => 'Delete backups';

  @override
  String get backupManageSelectAll => 'Select all';

  @override
  String get backupManageClearAll => 'Clear all';

  @override
  String get backupManageDelete => 'Delete';

  @override
  String backupManageDeleteCount(int count) {
    return 'Delete ($count)';
  }

  @override
  String get backupManageDeleteConfirmTitle => 'Delete backups?';

  @override
  String backupManageDeleteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files will be removed from Downloads.',
      one: '1 file will be removed from Downloads.',
    );
    return '$_temp0';
  }

  @override
  String get backupManageToastRemoved => 'Selected backups removed.';

  @override
  String get backupManageEmpty => 'No backup files found.';

  @override
  String get settingsSubtitles => 'Subtitles';

  @override
  String get settingsSubtitlesSubtitle => 'Default subtitle language';

  @override
  String get subtitleSettingsTitle => 'Subtitles';

  @override
  String get subtitleSettingsDefaultLanguage => 'Default subtitle language';

  @override
  String get subtitleSettingsDefaultLanguageHint =>
      'Search results list this language first.';

  @override
  String get subtitleSettingsApiKey => 'OpenSubtitles API key';

  @override
  String get subtitleSettingsApiKeyHint =>
      'Create a free consumer key at opensubtitles.com';

  @override
  String get subtitleSettingsSaveApiKey => 'Save API key';

  @override
  String get subtitleVodPickerTitle => 'Subtitles';

  @override
  String get subtitleVodLoading => 'Searching…';

  @override
  String get subtitleVodEmpty => 'No subtitles found.';

  @override
  String get subtitleVodLanguages => 'Languages';

  @override
  String get subtitleVodFiles => 'Files';

  @override
  String get subtitleVodClear => 'Off';

  @override
  String get subtitleVodPickLanguage =>
      'Choose a language on the left, or turn subtitles off.';

  @override
  String get subtitleVodNoApiKey =>
      'Add your OpenSubtitles API key in Settings → Subtitles.';

  @override
  String get subtitleVodFooterSelect => 'Select';

  @override
  String get subtitleAppearanceTitle => 'Subtitle look';

  @override
  String get subtitleAppearanceSubtitles => 'Subtitles';

  @override
  String get subtitleAppearanceBackground => 'Background color';

  @override
  String get subtitleAppearanceBackgroundOpacity => 'Background transparency';

  @override
  String get subtitleAppearanceTextColor => 'Subtitle color';

  @override
  String get subtitleAppearanceSize => 'Subtitle size';

  @override
  String get subtitleAppearancePosition => 'Subtitle position';

  @override
  String get subtitleAppearancePositionReady =>
      'Press Select (OK) to move; press again when done. Then ↑↓←→.';

  @override
  String get subtitleAppearancePositionMoving =>
      'Moving — D-pad to place. Select to finish. Back cancels move.';

  @override
  String get subtitleAppearanceHint =>
      '↑↓ rows · Position: Select twice to move. Exit or Reset below.';

  @override
  String get subtitleAppearanceExitMenu => 'Exit';

  @override
  String get subtitleAppearanceResetDefaults => 'Reset defaults';

  @override
  String get subtitleAppearanceLabelSubtitleBackground =>
      'Subtitle Background:';

  @override
  String get subtitleAppearanceLabelTransparency => 'Transparency:';

  @override
  String get subtitleAppearancePreviewLine => 'This is how subtitles will look';

  @override
  String get subtitleAppearanceVodPanelTitle => 'Subtitle edit';

  @override
  String get subtitleAppearancePositionShort => 'Position';

  @override
  String get parentalSettingsTitle => 'Parental control';

  @override
  String get parentalSettingsSubtitle =>
      'PIN, locks, and blocked channels or titles';

  @override
  String get parentalDialogEnterPin => 'Enter PIN';

  @override
  String get parentalDialogPinLabel => 'PIN (4–8 digits)';

  @override
  String get parentalDialogSubmit => 'Submit';

  @override
  String get parentalPinWrong => 'Wrong PIN.';

  @override
  String get parentalSetupWarning =>
      'Important: remember this PIN. If you forget it, you may need to clear app data or restore from backup. TVMate Pro cannot show your PIN again.';

  @override
  String get parentalSetupTitle => 'Create PIN';

  @override
  String get parentalSetupPinLabel => 'New PIN';

  @override
  String get parentalSetupConfirmLabel => 'Confirm PIN';

  @override
  String get parentalMismatch => 'PINs do not match.';

  @override
  String get parentalEnabledLabel => 'Parental control on';

  @override
  String get parentalLockAllLive => 'Lock all Live TV';

  @override
  String get parentalLockAllMovies => 'Lock all Movies';

  @override
  String get parentalLockAllSeries => 'Lock all Series';

  @override
  String get parentalHelpTitle => 'How it works';

  @override
  String get parentalHelpBody =>
      'Set a 4–8 digit PIN. Turn on locks here, or from Live TV (Menu on a channel), movie or series screens (lock icon) to block one channel, category, title, or show. Blocked items ask for the PIN before playback.';

  @override
  String get parentalSetPinCta => 'Save PIN';

  @override
  String get parentalCreateYourKeyTile => 'Create your key';

  @override
  String get parentalCreateYourKeySubtitle =>
      'Select to set a PIN and use these controls';

  @override
  String get parentalChangePin => 'Change PIN';

  @override
  String get parentalClearAll => 'Clear parental (reset PIN and rules)';

  @override
  String get parentalScopeTitleLive => 'Lock on Live TV';

  @override
  String get parentalBlockThisChannel => 'This channel only';

  @override
  String get parentalScopeLockChannelOnly => 'Lock channel';

  @override
  String get parentalScopeLockChannelAndHideBrowse =>
      'Lock channel & hide in browse';

  @override
  String get parentalScopeLockCategoryOnly => 'Lock category or group';

  @override
  String get parentalScopeLockCategoryAndHideBrowse =>
      'Lock category or group & hide in browse';

  @override
  String get parentalBlockCategoryOrGroup =>
      'Entire category or favorite group';

  @override
  String get parentalScopeTitleMovie => 'Lock movie';

  @override
  String get parentalBlockThisMovie => 'This movie only';

  @override
  String get parentalBlockMovieCategory => 'Entire movie category';

  @override
  String get parentalScopeTitleSeries => 'Lock series';

  @override
  String get parentalBlockThisShow => 'This show only';

  @override
  String get parentalBlockSeriesCategory => 'Entire series category';

  @override
  String get parentalLockSaved => 'Lock saved.';

  @override
  String get parentalUnlocked => 'Unlocked.';

  @override
  String get parentalUnlockThisChannel => 'Unlock this channel';

  @override
  String get parentalUnlockCategoryOrGroup => 'Unlock this category or group';

  @override
  String get parentalUnlockThisMovie => 'Unlock this movie';

  @override
  String get parentalUnlockMovieCategory => 'Unlock this movie category';

  @override
  String get parentalUnlockThisShow => 'Unlock this show';

  @override
  String get parentalUnlockSeriesCategory => 'Unlock this series category';

  @override
  String get parentalPlayerParental => 'Parental';

  @override
  String get playerEpgPanelLabel => 'EPG';

  @override
  String get playerRightPanelQuality => 'Quality';

  @override
  String get playerVodDownloadDownloading => 'Downloading…';

  @override
  String get playerVodDownloadVideoTypes => 'Video files';

  @override
  String get playerVodDownloadPlaylistNotSupported =>
      'This stream is a playlist (HLS), not a single video file. Download is not available for this format.';

  @override
  String playerVodDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String playerVodDownloadSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get playerVodDownloadAlreadyInProgress =>
      'A download is already in progress.';

  @override
  String get playerVodDownloadCancel => 'Cancel download';

  @override
  String get playerVodDownloadPickingLocation => 'Choose where to save…';

  @override
  String get playerVodDownloadSavingToDownloadsFolder => 'Saving to Downloads…';

  @override
  String get playerVodDownloadCopying => 'Saving…';

  @override
  String get playerVodDownloadErrorEmpty => 'Empty file';

  @override
  String playerVodDownloadSavedShort(String title) {
    return 'Saved offline: $title';
  }

  @override
  String get playerVodDownloadSavingOffline => 'Saving offline…';

  @override
  String get accountOfflineDownloadsMenuLabel => 'Offline downloads';

  @override
  String get accountOfflineDownloadsTitle => 'Offline downloads';

  @override
  String get accountOfflineDownloadsSubtitle =>
      'Videos saved on this device. Delete items to free space.';

  @override
  String get accountOfflineDownloadsEmpty =>
      'No offline videos yet. Download from a movie or episode while playing.';

  @override
  String get accountOfflineDownloadsPlay => 'Play';

  @override
  String get accountOfflineDownloadsDelete => 'Delete';

  @override
  String get accountOfflineDownloadsDeleteTitle => 'Delete download?';

  @override
  String get accountOfflineDownloadsDeleteBody =>
      'This removes the file from your device.';

  @override
  String get accountOfflineDownloadsDeleteConfirm => 'Delete';

  @override
  String get playerEpgOverlayTitle => 'Channel guide';

  @override
  String get playerEpgOverlaySchedule => 'Upcoming';

  @override
  String get playerEpgOverlayLoading => 'Loading programme guide…';

  @override
  String get playerEpgOverlayEmpty =>
      'No programme information for this channel.';

  @override
  String get playerEpgNowBadge => 'NOW';

  @override
  String get playerEpgLiveRightNow => 'Live right now';

  @override
  String get playerEpgDayToday => 'Today';

  @override
  String get playerEpgDayTomorrow => 'Tomorrow';

  @override
  String get parentalMenuContextLive => 'Parental lock…';

  @override
  String get parentalMustEnableInSettings =>
      'Turn on parental control and set a PIN in Settings first.';

  @override
  String get parentalLockAndHideTitle => 'Lock & hide in browse';

  @override
  String get parentalLockAndHideSubtitle =>
      'Hide restricted items from lists (still PIN-protected if shown elsewhere)';

  @override
  String get parentalManageRestrictedRules => 'Manage restricted rules';

  @override
  String get parentalManageRestrictedRulesSubtitle =>
      'View or remove locks on channels, categories, and titles';

  @override
  String get parentalRulesTitle => 'Restricted rules';

  @override
  String get parentalRulesSectionLive => 'Live TV';

  @override
  String get parentalRulesSectionMovies => 'Movies';

  @override
  String get parentalRulesSectionSeries => 'Series';

  @override
  String get parentalRulesLockAllOn => 'Lock entire section: on';

  @override
  String get parentalRulesLockAllOff => 'Lock entire section: off';

  @override
  String get parentalRulesEmpty => 'No per-item rules for this section.';

  @override
  String get parentalRulesFavoriteGroup => 'Favorite group';

  @override
  String get parentalRulesCategory => 'Category';

  @override
  String get parentalRulesChannel => 'Channel';

  @override
  String get parentalRulesMovie => 'Movie';

  @override
  String get parentalRulesSeries => 'Series';

  @override
  String get parentalPlayerOverlayTitle => 'Parental';

  @override
  String get parentalPlayerOverlayPinTitle => 'Create PIN';

  @override
  String get parentalPlayerOverlayEnableTitle => 'Turn on parental control';

  @override
  String get parentalPlayerOverlayEnableSubtitle =>
      'Verify your PIN to enable locks from the player';

  @override
  String get parentalRulesRemoveRule => 'Remove rule';

  @override
  String get parentalScopeActionNotAvailable =>
      'This action does not apply right now.';

  @override
  String get parentalScopeChannelAlreadyBlocked =>
      'This channel is already blocked.';

  @override
  String get parentalScopeChannelNotBlocked => 'This channel is not blocked.';

  @override
  String get parentalScopeCategoryAlreadyBlocked =>
      'This category or group is already blocked.';

  @override
  String get parentalScopeCategoryNotBlocked =>
      'This category or group is not blocked.';

  @override
  String get parentalScopeNoCategoryContext =>
      'No category or group is available for this view.';

  @override
  String get parentalScopeMovieAlreadyBlocked =>
      'This movie is already blocked.';

  @override
  String get parentalScopeMovieNotBlocked => 'This movie is not blocked.';

  @override
  String get parentalScopeMovieCategoryAlreadyBlocked =>
      'This movie category is already blocked.';

  @override
  String get parentalScopeMovieCategoryNotBlocked =>
      'This movie category is not blocked.';

  @override
  String get parentalScopeSeriesAlreadyBlocked =>
      'This show is already blocked.';

  @override
  String get parentalScopeSeriesNotBlocked => 'This show is not blocked.';

  @override
  String get parentalScopeSeriesCategoryAlreadyBlocked =>
      'This series category is already blocked.';

  @override
  String get parentalScopeSeriesCategoryNotBlocked =>
      'This series category is not blocked.';

  @override
  String get parentalSideMenuSetupBody =>
      'To use parental controls, set a password first. Enter a 4–8 digit PIN below.';

  @override
  String get parentalSideMenuSetupSave => 'Save and continue';
}
