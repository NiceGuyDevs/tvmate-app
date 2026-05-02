import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('he')
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTopMenuManager.
  ///
  /// In en, this message translates to:
  /// **'Top Menu Manager'**
  String get settingsTopMenuManager;

  /// No description provided for @settingsTopMenuManagerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder, add items, set startup'**
  String get settingsTopMenuManagerSubtitle;

  /// No description provided for @settingsShellThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visual team and accent colors'**
  String get settingsShellThemeSubtitle;

  /// No description provided for @settingsShellPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Switch active playlist'**
  String get settingsShellPlaylistSubtitle;

  /// No description provided for @settingsAddPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add Playlist'**
  String get settingsAddPlaylist;

  /// No description provided for @settingsAddPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Xtream or M3U'**
  String get settingsAddPlaylistSubtitle;

  /// No description provided for @settingsMyPlaylists.
  ///
  /// In en, this message translates to:
  /// **'My Playlists'**
  String get settingsMyPlaylists;

  /// No description provided for @settingsMyPlaylistsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No playlists} =1{1 playlist} other{{count} playlists}}'**
  String settingsMyPlaylistsCount(int count);

  /// No description provided for @settingsFavoriteSetup.
  ///
  /// In en, this message translates to:
  /// **'Favorite setup'**
  String get settingsFavoriteSetup;

  /// No description provided for @settingsFavoriteSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live TV channel favorites'**
  String get settingsFavoriteSetupSubtitle;

  /// No description provided for @settingsClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get settingsClock;

  /// No description provided for @settingsClockOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get settingsClockOn;

  /// No description provided for @settingsClockOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get settingsClockOff;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hero {heroPercent}% · {columns} per row'**
  String settingsAppearanceSubtitle(int heroPercent, int columns);

  /// No description provided for @settingsRecordingEdit.
  ///
  /// In en, this message translates to:
  /// **'Catch-up Edit'**
  String get settingsRecordingEdit;

  /// No description provided for @settingsRecordingEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Catch-up channel setup'**
  String get settingsRecordingEditSubtitle;

  /// No description provided for @catchupSelectPlaylistHelp.
  ///
  /// In en, this message translates to:
  /// **'Select a playlist to configure catch-up channels'**
  String get catchupSelectPlaylistHelp;

  /// No description provided for @catchupNoXtreamPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No Xtream playlists found.\nAdd an Xtream playlist first.'**
  String get catchupNoXtreamPlaylists;

  /// No description provided for @catchupBreadcrumbCategories.
  ///
  /// In en, this message translates to:
  /// **'Catch-up · Categories'**
  String get catchupBreadcrumbCategories;

  /// No description provided for @catchupBreadcrumbWithCategory.
  ///
  /// In en, this message translates to:
  /// **'Catch-up · {categoryName}'**
  String catchupBreadcrumbWithCategory(String categoryName);

  /// No description provided for @catchupFilterQuickOn.
  ///
  /// In en, this message translates to:
  /// **'Catch-up filter: ON'**
  String get catchupFilterQuickOn;

  /// No description provided for @catchupFilterQuickOff.
  ///
  /// In en, this message translates to:
  /// **'Catch-up filter: OFF'**
  String get catchupFilterQuickOff;

  /// No description provided for @catchupEmptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up catch-up in Settings'**
  String get catchupEmptyStateTitle;

  /// No description provided for @catchupEmptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings → {entryLabel} to approve\ncategories and channels for catch-up.'**
  String catchupEmptyStateBody(String entryLabel);

  /// No description provided for @catchupXtreamOnly.
  ///
  /// In en, this message translates to:
  /// **'Catch-up is only available for Xtream playlists.'**
  String get catchupXtreamOnly;

  /// No description provided for @catchupManage.
  ///
  /// In en, this message translates to:
  /// **'Manage catch-up'**
  String get catchupManage;

  /// No description provided for @catchupGroupOptions.
  ///
  /// In en, this message translates to:
  /// **'Catch-up options'**
  String get catchupGroupOptions;

  /// No description provided for @catchupGroupCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get catchupGroupCategories;

  /// No description provided for @catchupSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get catchupSelectAll;

  /// No description provided for @catchupClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get catchupClearAll;

  /// No description provided for @catchupFilterSub.
  ///
  /// In en, this message translates to:
  /// **'Only show channels whose source advertises catch-up. Hides everything else from the {tabName} tab for this playlist.'**
  String catchupFilterSub(String tabName);

  /// No description provided for @catchupClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all approvals?'**
  String get catchupClearConfirmTitle;

  /// No description provided for @catchupClearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Removes every approved category and channel from \"{playlistName}\"\'s catch-up list. The playlist itself isn\'t touched.'**
  String catchupClearConfirmMessage(String playlistName);

  /// No description provided for @catchupFilterBannerLead.
  ///
  /// In en, this message translates to:
  /// **'Catch-up filter is on. '**
  String get catchupFilterBannerLead;

  /// No description provided for @catchupFilterHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 channel without catch-up is hidden from this list.} other{{count} channels without catch-up are hidden from this list.}} Turn the filter off in catch-up options to approve them.'**
  String catchupFilterHiddenMessage(int count);

  /// No description provided for @catchupNoChannelsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No channels in this category.'**
  String get catchupNoChannelsInCategory;

  /// No description provided for @catchupNoLiveCategoriesSync.
  ///
  /// In en, this message translates to:
  /// **'No live categories found.\nSync this playlist first.'**
  String get catchupNoLiveCategoriesSync;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export / import settings'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode'**
  String get settingsDemoMode;

  /// No description provided for @settingsDemoModeSubtitleBrowseDemo.
  ///
  /// In en, this message translates to:
  /// **'Browse is demo until you add a playlist'**
  String get settingsDemoModeSubtitleBrowseDemo;

  /// No description provided for @settingsDemoModeSubtitleRealChannels.
  ///
  /// In en, this message translates to:
  /// **'Real channels — demo is off while playlists exist'**
  String get settingsDemoModeSubtitleRealChannels;

  /// No description provided for @settingsDemoModeAbout.
  ///
  /// In en, this message translates to:
  /// **'Built-in demo: sample Live TV, Movies, and Series with bundled artwork and mock listings. Playback uses demo streams so you can explore the UI. Add an Xtream or M3U playlist anytime to use your real IPTV.'**
  String get settingsDemoModeAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsPerformance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get settingsPerformance;

  /// No description provided for @settingsPerformanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full quality or optimized for weaker devices'**
  String get settingsPerformanceSubtitle;

  /// No description provided for @performanceScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performanceScreenTitle;

  /// No description provided for @performanceScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose how hard the app pushes your device. Powerful streamers (for example NVIDIA Shield) can use Full quality. Small sticks and streamers often run smoother with Optimized. Automatic picks from total device memory. You can change this anytime.'**
  String get performanceScreenIntro;

  /// No description provided for @performanceModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get performanceModeAuto;

  /// No description provided for @performanceModeAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended — picks Full or Optimized from device memory'**
  String get performanceModeAutoSubtitle;

  /// No description provided for @performanceModeFull.
  ///
  /// In en, this message translates to:
  /// **'Full quality'**
  String get performanceModeFull;

  /// No description provided for @performanceModeFullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Richest visuals — best on strong hardware'**
  String get performanceModeFullSubtitle;

  /// No description provided for @performanceModeOptimized.
  ///
  /// In en, this message translates to:
  /// **'Optimized'**
  String get performanceModeOptimized;

  /// No description provided for @performanceModeOptimizedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lighter background, smaller cache, deferred sync. One video decoder at a time (grid hero pauses in fullscreen) — smoother on weak TVs'**
  String get performanceModeOptimizedSubtitle;

  /// No description provided for @performanceDetectedRam.
  ///
  /// In en, this message translates to:
  /// **'Detected total RAM: {mb} MB'**
  String performanceDetectedRam(String mb);

  /// No description provided for @performanceDetectedRamUnknown.
  ///
  /// In en, this message translates to:
  /// **'RAM not detected — Automatic uses Full quality'**
  String get performanceDetectedRamUnknown;

  /// No description provided for @performanceAutoCurrentlyUsingFull.
  ///
  /// In en, this message translates to:
  /// **'Right now, Automatic is using Full quality.'**
  String get performanceAutoCurrentlyUsingFull;

  /// No description provided for @performanceAutoCurrentlyUsingOptimized.
  ///
  /// In en, this message translates to:
  /// **'Right now, Automatic is using Optimized.'**
  String get performanceAutoCurrentlyUsingOptimized;

  /// No description provided for @settingsLightningSwitch.
  ///
  /// In en, this message translates to:
  /// **'Lightning switch'**
  String get settingsLightningSwitch;

  /// No description provided for @settingsLightningSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Faster live channel changes (strong devices only)'**
  String get settingsLightningSwitchSubtitle;

  /// No description provided for @lightningSwitchScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Lightning switch'**
  String get lightningSwitchScreenTitle;

  /// No description provided for @lightningSwitchScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'When off, live TV uses the same single-decoder path as Optimized — same buffering and timing. Turn on to use a second decoder for very fast channel changes; this uses more memory and may cause lag on some devices.'**
  String get lightningSwitchScreenIntro;

  /// No description provided for @lightningSwitchModeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get lightningSwitchModeOff;

  /// No description provided for @lightningSwitchModeOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Same live player behavior as Optimized'**
  String get lightningSwitchModeOffSubtitle;

  /// No description provided for @lightningSwitchModeOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get lightningSwitchModeOn;

  /// No description provided for @lightningSwitchModeOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dual-decoder pool — fastest zaps; may lag on some devices'**
  String get lightningSwitchModeOnSubtitle;

  /// No description provided for @lightningSwitchLagSnack.
  ///
  /// In en, this message translates to:
  /// **'Lightning is on. If you notice lag, turn it off here.'**
  String get lightningSwitchLagSnack;

  /// No description provided for @tvRemoteTypingButton.
  ///
  /// In en, this message translates to:
  /// **'Type with TV remote'**
  String get tvRemoteTypingButton;

  /// No description provided for @tvRemoteTypingTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter text'**
  String get tvRemoteTypingTitle;

  /// No description provided for @tvRemoteTypingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tvRemoteTypingDone;

  /// No description provided for @tvRemoteGoogleTvKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'The on-screen keyboard may not open on Google TV or Chromecast. Use the line above to type with your remote.'**
  String get tvRemoteGoogleTvKeyboardHint;

  /// No description provided for @tvKeyboardLanguagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get tvKeyboardLanguagesTitle;

  /// No description provided for @tvKeyboardPickLanguagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark languages to show when you open the list (top or globe). Order follows the order you add them.'**
  String get tvKeyboardPickLanguagesSubtitle;

  /// No description provided for @tvKeyboardLayoutNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'On-screen keyboard not available for this language yet.'**
  String get tvKeyboardLayoutNotAvailable;

  /// No description provided for @languageScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageScreenTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHebrew.
  ///
  /// In en, this message translates to:
  /// **'Hebrew'**
  String get languageHebrew;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// No description provided for @actionPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get actionPlay;

  /// No description provided for @actionExternal.
  ///
  /// In en, this message translates to:
  /// **'External'**
  String get actionExternal;

  /// No description provided for @actionTrailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get actionTrailer;

  /// No description provided for @actionMyList.
  ///
  /// In en, this message translates to:
  /// **'My list'**
  String get actionMyList;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get actionWatched;

  /// No description provided for @actionUnwatch.
  ///
  /// In en, this message translates to:
  /// **'Unwatch'**
  String get actionUnwatch;

  /// No description provided for @actionWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get actionWatching;

  /// No description provided for @actionWatchingOff.
  ///
  /// In en, this message translates to:
  /// **'Not watching'**
  String get actionWatchingOff;

  /// No description provided for @actionContinueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get actionContinueWatching;

  /// No description provided for @actionContinueWatchingOff.
  ///
  /// In en, this message translates to:
  /// **'Clear continue'**
  String get actionContinueWatchingOff;

  /// No description provided for @navLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get navLiveTv;

  /// No description provided for @navMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get navMovies;

  /// No description provided for @navSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get navSeries;

  /// No description provided for @navRecording.
  ///
  /// In en, this message translates to:
  /// **'Catch-up'**
  String get navRecording;

  /// No description provided for @navPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get navPlaylist;

  /// No description provided for @navTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get navTheme;

  /// No description provided for @navClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get navClock;

  /// No description provided for @navAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get navAppearance;

  /// No description provided for @navBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get navBackup;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get navLanguage;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @nsCategoryOldSettings.
  ///
  /// In en, this message translates to:
  /// **'Old settings'**
  String get nsCategoryOldSettings;

  /// No description provided for @searchMoviesAndSeries.
  ///
  /// In en, this message translates to:
  /// **'Search Movies & Series'**
  String get searchMoviesAndSeries;

  /// No description provided for @searchLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Search Live TV'**
  String get searchLiveTv;

  /// No description provided for @searchRecording.
  ///
  /// In en, this message translates to:
  /// **'Search Catch-up'**
  String get searchRecording;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Type to filter this page'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// No description provided for @searchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchApply;

  /// No description provided for @searchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchLabel;

  /// No description provided for @searchPrefixWithQuery.
  ///
  /// In en, this message translates to:
  /// **'Search: {query}'**
  String searchPrefixWithQuery(String query);

  /// No description provided for @playlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistEmptyTitle;

  /// No description provided for @playlistEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add one in Settings'**
  String get playlistEmptySubtitle;

  /// No description provided for @playlistGoToSettings.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get playlistGoToSettings;

  /// No description provided for @playlistDismissBarrier.
  ///
  /// In en, this message translates to:
  /// **'Dismiss playlist switcher'**
  String get playlistDismissBarrier;

  /// No description provided for @playlistStatsLine.
  ///
  /// In en, this message translates to:
  /// **'{liveCount} live · {movieCount} movies · {seriesCount} series'**
  String playlistStatsLine(int liveCount, int movieCount, int seriesCount);

  /// No description provided for @topMenuManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Top Menu Manager'**
  String get topMenuManagerTitle;

  /// No description provided for @topMenuOrderSection.
  ///
  /// In en, this message translates to:
  /// **'Menu order'**
  String get topMenuOrderSection;

  /// No description provided for @topMenuReorderHelp.
  ///
  /// In en, this message translates to:
  /// **'Press OK to pick up, then Up/Down to move, OK to drop.'**
  String get topMenuReorderHelp;

  /// No description provided for @topMenuRemoveHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional tabs: press Right to remove from the bar (OK is only for pick up / drop).'**
  String get topMenuRemoveHelp;

  /// No description provided for @topMenuAddToMenu.
  ///
  /// In en, this message translates to:
  /// **'Add to menu'**
  String get topMenuAddToMenu;

  /// No description provided for @topMenuStartupSection.
  ///
  /// In en, this message translates to:
  /// **'Startup category'**
  String get topMenuStartupSection;

  /// No description provided for @topMenuStartupHelp.
  ///
  /// In en, this message translates to:
  /// **'Which screen opens when the app starts.'**
  String get topMenuStartupHelp;

  /// No description provided for @topMenuSettingsLocked.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get topMenuSettingsLocked;

  /// No description provided for @topMenuAlwaysLast.
  ///
  /// In en, this message translates to:
  /// **'Always last'**
  String get topMenuAlwaysLast;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @mvPickerAddChannel.
  ///
  /// In en, this message translates to:
  /// **'Add channel'**
  String get mvPickerAddChannel;

  /// No description provided for @mvPickerChangeChannel.
  ///
  /// In en, this message translates to:
  /// **'Change channel'**
  String get mvPickerChangeChannel;

  /// No description provided for @mvChooseChannel.
  ///
  /// In en, this message translates to:
  /// **'Choose channel'**
  String get mvChooseChannel;

  /// No description provided for @mvAddScreen.
  ///
  /// In en, this message translates to:
  /// **'Add screen'**
  String get mvAddScreen;

  /// No description provided for @mvChangeChannel.
  ///
  /// In en, this message translates to:
  /// **'Change channel'**
  String get mvChangeChannel;

  /// No description provided for @mvReduceScreen.
  ///
  /// In en, this message translates to:
  /// **'Reduce screen'**
  String get mvReduceScreen;

  /// No description provided for @mvEnlargeScreen.
  ///
  /// In en, this message translates to:
  /// **'Enlarge screen'**
  String get mvEnlargeScreen;

  /// No description provided for @mvFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get mvFullScreen;

  /// No description provided for @mvRemoveScreen.
  ///
  /// In en, this message translates to:
  /// **'Remove screen'**
  String get mvRemoveScreen;

  /// No description provided for @mvExitMultiview.
  ///
  /// In en, this message translates to:
  /// **'Exit multiview'**
  String get mvExitMultiview;

  /// No description provided for @mvMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiview'**
  String get mvMenuTitle;

  /// No description provided for @mvMenuHint.
  ///
  /// In en, this message translates to:
  /// **'▲▼ move · OK · Back'**
  String get mvMenuHint;

  /// No description provided for @demoBlurbLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV demo: category pills and channel grid with bundled logos. Hero panel and labels; sample stream when you open the player.'**
  String get demoBlurbLiveTv;

  /// No description provided for @demoBlurbMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies demo: rows with bundled posters and mock details. Focus a title to update the hero and synopsis.'**
  String get demoBlurbMovies;

  /// No description provided for @demoBlurbSeries.
  ///
  /// In en, this message translates to:
  /// **'Series demo: bundled posters, seasons and episode lists—same flow as Movies. Sample stream for playback.'**
  String get demoBlurbSeries;

  /// No description provided for @demoBlurbRecording.
  ///
  /// In en, this message translates to:
  /// **'Browse catch-up EPG by category, date, and channel. Select a past program to play.'**
  String get demoBlurbRecording;

  /// No description provided for @demoBlurbTeam.
  ///
  /// In en, this message translates to:
  /// **'Choose Cosmic, Aurora, Solar, or Heritage for the shell backdrop and chrome.'**
  String get demoBlurbTeam;

  /// No description provided for @demoBlurbSettings.
  ///
  /// In en, this message translates to:
  /// **'Demo settings hub. Add playlist, manage profiles, and playback options will live here.'**
  String get demoBlurbSettings;

  /// No description provided for @demoBlurbOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional shell destination. Enable it in Top Menu Manager to show it in the bar.'**
  String get demoBlurbOptional;

  /// No description provided for @clockInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Optional floating clock on top of the app. Turn it ON or OFF — the top bar always shows the time; this overlay is extra. Choose 12 or 24 hour, size, corner of the screen, brightness (opacity), and color. Frame adds a border and shows the date under the time; turn it off for time only. Use Adjust position to nudge the overlay per corner with the D-pad. Move focus with the remote and Select to apply each option; changes apply everywhere while you use the app.'**
  String get clockInfoBanner;

  /// No description provided for @clockToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Clock ON'**
  String get clockToggleOn;

  /// No description provided for @clockToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Clock OFF'**
  String get clockToggleOff;

  /// No description provided for @clockTapHide.
  ///
  /// In en, this message translates to:
  /// **'Tap to hide'**
  String get clockTapHide;

  /// No description provided for @clockTapShow.
  ///
  /// In en, this message translates to:
  /// **'Tap to show'**
  String get clockTapShow;

  /// No description provided for @clockFrameOn.
  ///
  /// In en, this message translates to:
  /// **'Frame ON'**
  String get clockFrameOn;

  /// No description provided for @clockFrameOff.
  ///
  /// In en, this message translates to:
  /// **'Frame OFF'**
  String get clockFrameOff;

  /// No description provided for @clockFrameSubOn.
  ///
  /// In en, this message translates to:
  /// **'Border + date under time'**
  String get clockFrameSubOn;

  /// No description provided for @clockFrameSubOff.
  ///
  /// In en, this message translates to:
  /// **'Time only (no border, no date)'**
  String get clockFrameSubOff;

  /// No description provided for @clock12Hour.
  ///
  /// In en, this message translates to:
  /// **'12 hour'**
  String get clock12Hour;

  /// No description provided for @clock12HourSub.
  ///
  /// In en, this message translates to:
  /// **'AM / PM'**
  String get clock12HourSub;

  /// No description provided for @clock24Hour.
  ///
  /// In en, this message translates to:
  /// **'24 hour'**
  String get clock24Hour;

  /// No description provided for @clock24HourSub.
  ///
  /// In en, this message translates to:
  /// **'00–23'**
  String get clock24HourSub;

  /// No description provided for @clockSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get clockSizeSmall;

  /// No description provided for @clockSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get clockSizeMedium;

  /// No description provided for @clockSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get clockSizeLarge;

  /// No description provided for @clockSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get clockSizeSubtitle;

  /// No description provided for @clockCornerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Corner'**
  String get clockCornerSubtitle;

  /// No description provided for @clockCornerTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top left'**
  String get clockCornerTopLeft;

  /// No description provided for @clockCornerTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top right'**
  String get clockCornerTopRight;

  /// No description provided for @clockCornerBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom left'**
  String get clockCornerBottomLeft;

  /// No description provided for @clockCornerBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom right'**
  String get clockCornerBottomRight;

  /// No description provided for @clockAdjustPosition.
  ///
  /// In en, this message translates to:
  /// **'Adjust position'**
  String get clockAdjustPosition;

  /// No description provided for @clockAdjustPositionSub.
  ///
  /// In en, this message translates to:
  /// **'D-pad moves · Back saves'**
  String get clockAdjustPositionSub;

  /// No description provided for @clockOpacitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get clockOpacitySubtitle;

  /// No description provided for @clockOpacityPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String clockOpacityPercent(int percent);

  /// No description provided for @clockColorPreset.
  ///
  /// In en, this message translates to:
  /// **'Color {index}'**
  String clockColorPreset(int index);

  /// No description provided for @clockColorPresetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get clockColorPresetSubtitle;

  /// No description provided for @clockPositionAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust position'**
  String get clockPositionAdjustTitle;

  /// No description provided for @clockPositionCornerLine.
  ///
  /// In en, this message translates to:
  /// **'Corner: {corner}'**
  String clockPositionCornerLine(String corner);

  /// No description provided for @clockPositionOffsetLine.
  ///
  /// In en, this message translates to:
  /// **'Offset: {dx} × {dy} (max ±{max})'**
  String clockPositionOffsetLine(int dx, int dy, int max);

  /// No description provided for @clockPositionHelpEnabled.
  ///
  /// In en, this message translates to:
  /// **'Use the D-pad to move the on-screen clock. Changes apply to this corner only. Back returns to Clock settings.'**
  String get clockPositionHelpEnabled;

  /// No description provided for @clockPositionHelpDisabled.
  ///
  /// In en, this message translates to:
  /// **'Turn the clock ON to see the overlay while you adjust. Offsets are still saved for each corner.'**
  String get clockPositionHelpDisabled;

  /// No description provided for @appearanceLayoutEditors.
  ///
  /// In en, this message translates to:
  /// **'Layout editors'**
  String get appearanceLayoutEditors;

  /// No description provided for @appearanceHeroBackgroundTitle.
  ///
  /// In en, this message translates to:
  /// **'Hero background'**
  String get appearanceHeroBackgroundTitle;

  /// No description provided for @appearanceHeroBackgroundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Colors behind the Live TV preview'**
  String get appearanceHeroBackgroundSubtitle;

  /// No description provided for @heroAppearanceScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Hero background'**
  String get heroAppearanceScreenTitle;

  /// No description provided for @heroAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'Changes save automatically. Reset restores your theme’s default hero look.'**
  String get heroAppearanceHint;

  /// No description provided for @heroAppearanceReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get heroAppearanceReset;

  /// No description provided for @heroAppearanceHideControls.
  ///
  /// In en, this message translates to:
  /// **'Hide controls'**
  String get heroAppearanceHideControls;

  /// No description provided for @heroAppearanceShowControls.
  ///
  /// In en, this message translates to:
  /// **'Show controls'**
  String get heroAppearanceShowControls;

  /// No description provided for @heroAppearanceBase.
  ///
  /// In en, this message translates to:
  /// **'Base color'**
  String get heroAppearanceBase;

  /// No description provided for @heroAppearanceWash.
  ///
  /// In en, this message translates to:
  /// **'Brush color'**
  String get heroAppearanceWash;

  /// No description provided for @heroAppearanceIntensity.
  ///
  /// In en, this message translates to:
  /// **'Brush strength'**
  String get heroAppearanceIntensity;

  /// No description provided for @heroAppearanceBrushStyle.
  ///
  /// In en, this message translates to:
  /// **'Brush style'**
  String get heroAppearanceBrushStyle;

  /// No description provided for @heroAppearanceSectionBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get heroAppearanceSectionBackground;

  /// No description provided for @heroAppearanceSectionTv.
  ///
  /// In en, this message translates to:
  /// **'Preview frame'**
  String get heroAppearanceSectionTv;

  /// No description provided for @heroAppearanceSectionFineTune.
  ///
  /// In en, this message translates to:
  /// **'Fine tune'**
  String get heroAppearanceSectionFineTune;

  /// No description provided for @heroAppearanceShowFrame.
  ///
  /// In en, this message translates to:
  /// **'Show TV frame'**
  String get heroAppearanceShowFrame;

  /// No description provided for @heroAppearanceFrameProfile.
  ///
  /// In en, this message translates to:
  /// **'Frame profile'**
  String get heroAppearanceFrameProfile;

  /// No description provided for @heroAppearanceBezelFinish.
  ///
  /// In en, this message translates to:
  /// **'Bezel finish'**
  String get heroAppearanceBezelFinish;

  /// No description provided for @heroAppearanceGradientDepth.
  ///
  /// In en, this message translates to:
  /// **'Gradient depth'**
  String get heroAppearanceGradientDepth;

  /// No description provided for @heroAppearanceFrameSlim.
  ///
  /// In en, this message translates to:
  /// **'Slim'**
  String get heroAppearanceFrameSlim;

  /// No description provided for @heroAppearanceFrameClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get heroAppearanceFrameClassic;

  /// No description provided for @heroAppearanceFrameBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get heroAppearanceFrameBold;

  /// No description provided for @heroAppearanceFrameMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get heroAppearanceFrameMinimal;

  /// No description provided for @heroAppearanceOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get heroAppearanceOn;

  /// No description provided for @heroAppearanceOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get heroAppearanceOff;

  /// No description provided for @heroAppearanceTabColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get heroAppearanceTabColors;

  /// No description provided for @heroAppearanceTabOverlay.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get heroAppearanceTabOverlay;

  /// No description provided for @heroAppearanceTabFrame.
  ///
  /// In en, this message translates to:
  /// **'Frame'**
  String get heroAppearanceTabFrame;

  /// No description provided for @heroAppearanceTabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get heroAppearanceTabMore;

  /// No description provided for @heroAppearanceWashModeBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get heroAppearanceWashModeBrush;

  /// No description provided for @heroAppearanceWashModeSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get heroAppearanceWashModeSolid;

  /// No description provided for @heroAppearanceHintShort.
  ///
  /// In en, this message translates to:
  /// **'Saves automatically.'**
  String get heroAppearanceHintShort;

  /// No description provided for @heroAppearanceSolidHint.
  ///
  /// In en, this message translates to:
  /// **'Full-screen tint — adjust strength on the Overlay tab.'**
  String get heroAppearanceSolidHint;

  /// No description provided for @heroAppearanceHelpIntro.
  ///
  /// In en, this message translates to:
  /// **'Use − and + on each row to change the look. The two big squares show your background and overlay. Watch the Live TV preview above.'**
  String get heroAppearanceHelpIntro;

  /// No description provided for @heroAppearancePreviewBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get heroAppearancePreviewBackgroundLabel;

  /// No description provided for @heroAppearancePreviewOverlayLabel.
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get heroAppearancePreviewOverlayLabel;

  /// No description provided for @heroAppearanceHueRow.
  ///
  /// In en, this message translates to:
  /// **'Shade'**
  String get heroAppearanceHueRow;

  /// No description provided for @heroAppearanceSatRow.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get heroAppearanceSatRow;

  /// No description provided for @heroAppearanceBriRow.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get heroAppearanceBriRow;

  /// No description provided for @heroAppearanceHueExplain.
  ///
  /// In en, this message translates to:
  /// **'Moves through the rainbow'**
  String get heroAppearanceHueExplain;

  /// No description provided for @heroAppearanceSatExplain.
  ///
  /// In en, this message translates to:
  /// **'Weak color ↔ strong'**
  String get heroAppearanceSatExplain;

  /// No description provided for @heroAppearanceBriExplain.
  ///
  /// In en, this message translates to:
  /// **'Dark ↔ bright'**
  String get heroAppearanceBriExplain;

  /// No description provided for @heroAppearanceFrameBanner.
  ///
  /// In en, this message translates to:
  /// **'TV frame'**
  String get heroAppearanceFrameBanner;

  /// No description provided for @heroAppearanceFrameExplain.
  ///
  /// In en, this message translates to:
  /// **'A border around the small TV preview. Turn it on, then pick thickness and finish.'**
  String get heroAppearanceFrameExplain;

  /// No description provided for @appearancePerRowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count}/row'**
  String appearancePerRowSubtitle(int count);

  /// No description provided for @appearanceChannelCardStyle.
  ///
  /// In en, this message translates to:
  /// **'Channel card style'**
  String get appearanceChannelCardStyle;

  /// No description provided for @appearanceMovieCardStyle.
  ///
  /// In en, this message translates to:
  /// **'Movie card style'**
  String get appearanceMovieCardStyle;

  /// No description provided for @appearanceSeriesCardStyle.
  ///
  /// In en, this message translates to:
  /// **'Series card style'**
  String get appearanceSeriesCardStyle;

  /// No description provided for @cardStyleLiveNameOnly.
  ///
  /// In en, this message translates to:
  /// **'Name only'**
  String get cardStyleLiveNameOnly;

  /// No description provided for @cardStyleLiveLogoNameProgram.
  ///
  /// In en, this message translates to:
  /// **'Logo + name + program'**
  String get cardStyleLiveLogoNameProgram;

  /// No description provided for @cardStyleLiveLogoNameOnly.
  ///
  /// In en, this message translates to:
  /// **'Logo + name'**
  String get cardStyleLiveLogoNameOnly;

  /// No description provided for @cardStyleLiveLogoOnly.
  ///
  /// In en, this message translates to:
  /// **'Logo only'**
  String get cardStyleLiveLogoOnly;

  /// No description provided for @movieGridSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Movie Grid Settings'**
  String get movieGridSettingsTitle;

  /// No description provided for @movieGridMoviesPerRow.
  ///
  /// In en, this message translates to:
  /// **'Movies Per Row:'**
  String get movieGridMoviesPerRow;

  /// No description provided for @movieGridPosterDisplay.
  ///
  /// In en, this message translates to:
  /// **'Poster Display:'**
  String get movieGridPosterDisplay;

  /// No description provided for @movieGridExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get movieGridExit;

  /// No description provided for @movieGridResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset defaults'**
  String get movieGridResetDefaults;

  /// No description provided for @movieGridHidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get movieGridHidePanel;

  /// No description provided for @movieGridShowPanel.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get movieGridShowPanel;

  /// No description provided for @seriesGridSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Series Grid Settings'**
  String get seriesGridSettingsTitle;

  /// No description provided for @seriesGridSeriesPerRow.
  ///
  /// In en, this message translates to:
  /// **'Series Per Row:'**
  String get seriesGridSeriesPerRow;

  /// No description provided for @channelGridSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel Grid Settings'**
  String get channelGridSettingsTitle;

  /// No description provided for @channelGridHeroBannerSize.
  ///
  /// In en, this message translates to:
  /// **'Hero Banner Size:'**
  String get channelGridHeroBannerSize;

  /// No description provided for @channelGridChannelsPerRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Channels Per Row:'**
  String get channelGridChannelsPerRowLabel;

  /// No description provided for @channelGridChannelDisplay.
  ///
  /// In en, this message translates to:
  /// **'Channel Display:'**
  String get channelGridChannelDisplay;

  /// No description provided for @channelGridChNamePosition.
  ///
  /// In en, this message translates to:
  /// **'CH Name Position:'**
  String get channelGridChNamePosition;

  /// No description provided for @channelGridShowSettingsPanel.
  ///
  /// In en, this message translates to:
  /// **'Show settings'**
  String get channelGridShowSettingsPanel;

  /// No description provided for @cardStylePosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Poster+Name+Year'**
  String get cardStylePosterTitle;

  /// No description provided for @cardStylePosterOnly.
  ///
  /// In en, this message translates to:
  /// **'Poster Only'**
  String get cardStylePosterOnly;

  /// No description provided for @cardStyleNamePoster.
  ///
  /// In en, this message translates to:
  /// **'Name+Poster'**
  String get cardStyleNamePoster;

  /// No description provided for @cardStyleTitleOnly.
  ///
  /// In en, this message translates to:
  /// **'Title only'**
  String get cardStyleTitleOnly;

  /// No description provided for @catalogLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get catalogLoading;

  /// No description provided for @catalogLoadingChannels.
  ///
  /// In en, this message translates to:
  /// **'Loading channels…'**
  String get catalogLoadingChannels;

  /// No description provided for @catalogLoadingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Loading library…'**
  String get catalogLoadingLibrary;

  /// No description provided for @catalogPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get catalogPreparing;

  /// No description provided for @catalogErrorPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Could not load playlist'**
  String get catalogErrorPlaylist;

  /// No description provided for @catalogErrorLibrary.
  ///
  /// In en, this message translates to:
  /// **'Could not load library'**
  String get catalogErrorLibrary;

  /// No description provided for @catalogNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get catalogNoCategories;

  /// No description provided for @catalogNoCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This playlist returned no live categories.'**
  String get catalogNoCategoriesSubtitle;

  /// No description provided for @myPlaylistsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Playlists'**
  String get myPlaylistsTitle;

  /// No description provided for @myPlaylistsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only one playlist active at a time.'**
  String get myPlaylistsSubtitle;

  /// No description provided for @myPlaylistsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Add one from Settings.'**
  String get myPlaylistsEmpty;

  /// No description provided for @dialogRenamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get dialogRenamePlaylist;

  /// No description provided for @dialogEditPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Edit playlist'**
  String get dialogEditPlaylist;

  /// No description provided for @dialogPlaylistServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get dialogPlaylistServerUrl;

  /// No description provided for @dialogPlaylistUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get dialogPlaylistUsername;

  /// No description provided for @dialogPlaylistPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get dialogPlaylistPassword;

  /// No description provided for @dialogPlaylistM3uUrl.
  ///
  /// In en, this message translates to:
  /// **'M3U URL'**
  String get dialogPlaylistM3uUrl;

  /// No description provided for @dialogPlaylistEditInvalid.
  ///
  /// In en, this message translates to:
  /// **'Fill all required fields.'**
  String get dialogPlaylistEditInvalid;

  /// No description provided for @dialogPlaylistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dialogPlaylistNameHint;

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @dialogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dialogSave;

  /// No description provided for @dialogDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dialogDelete;

  /// No description provided for @dialogDeletePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get dialogDeletePlaylistTitle;

  /// No description provided for @dialogDeletePlaylistBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from this device.'**
  String dialogDeletePlaylistBody(String name);

  /// No description provided for @playlistTypeXtream.
  ///
  /// In en, this message translates to:
  /// **'Xtream'**
  String get playlistTypeXtream;

  /// No description provided for @playlistTypeM3u.
  ///
  /// In en, this message translates to:
  /// **'M3U'**
  String get playlistTypeM3u;

  /// No description provided for @myPlaylistTileStats.
  ///
  /// In en, this message translates to:
  /// **'{type} · L{live} M{movies} S{series}'**
  String myPlaylistTileStats(String type, int live, int movies, int series);

  /// No description provided for @playlistActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get playlistActiveBadge;

  /// No description provided for @playlistSubscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get playlistSubscriptionActive;

  /// No description provided for @playlistSubscriptionExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get playlistSubscriptionExpired;

  /// No description provided for @playlistExpireOn.
  ///
  /// In en, this message translates to:
  /// **'Expire on {date}'**
  String playlistExpireOn(String date);

  /// No description provided for @playlistChipGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get playlistChipGroups;

  /// No description provided for @playlistChipManageChannels.
  ///
  /// In en, this message translates to:
  /// **'Manage channels'**
  String get playlistChipManageChannels;

  /// No description provided for @manageLiveChannelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage channels'**
  String get manageLiveChannelsTitle;

  /// No description provided for @manageLiveChannelsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a category, then rename channels, hide them from Live TV, or set a custom logo URL.'**
  String get manageLiveChannelsSubtitle;

  /// No description provided for @manageLiveChannelsNeedActive.
  ///
  /// In en, this message translates to:
  /// **'Switch to this playlist first.'**
  String get manageLiveChannelsNeedActive;

  /// No description provided for @manageLiveChannelsNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No live categories. Sync the playlist first.'**
  String get manageLiveChannelsNoCategories;

  /// No description provided for @manageLiveChannelsCategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No channels in this category.'**
  String get manageLiveChannelsCategoryEmpty;

  /// No description provided for @channelOverrideNameAction.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get channelOverrideNameAction;

  /// No description provided for @channelOverrideLogoAction.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get channelOverrideLogoAction;

  /// No description provided for @channelOverrideHiddenFromLive.
  ///
  /// In en, this message translates to:
  /// **'Hidden from Live TV'**
  String get channelOverrideHiddenFromLive;

  /// No description provided for @channelOverrideVisibleInLive.
  ///
  /// In en, this message translates to:
  /// **'Shown in Live TV'**
  String get channelOverrideVisibleInLive;

  /// No description provided for @channelOverrideDisplayNameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get channelOverrideDisplayNameDialogTitle;

  /// No description provided for @channelOverrideDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the server name.'**
  String get channelOverrideDisplayNameHint;

  /// No description provided for @channelOverrideLogoDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom logo URL'**
  String get channelOverrideLogoDialogTitle;

  /// No description provided for @channelOverrideLogoDialogHint.
  ///
  /// In en, this message translates to:
  /// **'Paste an https:// link to a PNG or JPG. Leave empty to use the playlist logo.'**
  String get channelOverrideLogoDialogHint;

  /// No description provided for @playlistGroupEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get playlistGroupEdit;

  /// No description provided for @playlistGroupOriginalLabel.
  ///
  /// In en, this message translates to:
  /// **'Original: {name}'**
  String playlistGroupOriginalLabel(String name);

  /// No description provided for @playlistGroupCustomNameHint.
  ///
  /// In en, this message translates to:
  /// **'Custom name'**
  String get playlistGroupCustomNameHint;

  /// No description provided for @playlistGroupResetAlias.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get playlistGroupResetAlias;

  /// Live TV Manage groups: title for the panel that sets whether this category’s pill appears before or after the user’s favorite group pills.
  ///
  /// In en, this message translates to:
  /// **'Category pill order (Live TV)'**
  String get playlistGroupPillOrderTitle;

  /// Option: show this live category pill after favorite-group pills (default strip order).
  ///
  /// In en, this message translates to:
  /// **'After my favorites'**
  String get playlistGroupPillAfterFavorites;

  /// Option: pin this live category pill to the left of favorite-group pills.
  ///
  /// In en, this message translates to:
  /// **'Before my favorites'**
  String get playlistGroupPillBeforeFavorites;

  /// Numeric field label: order among categories pinned before favorites (1 = leftmost).
  ///
  /// In en, this message translates to:
  /// **'Position (1 = first)'**
  String get playlistGroupPillPositionLabel;

  /// Placeholder for the position field (typically the digit 1).
  ///
  /// In en, this message translates to:
  /// **'1'**
  String get playlistGroupPillPositionHint;

  /// No description provided for @playlistEpgLocal.
  ///
  /// In en, this message translates to:
  /// **'EPG: Local'**
  String get playlistEpgLocal;

  /// No description provided for @playlistEpgOriginal.
  ///
  /// In en, this message translates to:
  /// **'EPG: Original'**
  String get playlistEpgOriginal;

  /// No description provided for @playlistEpgTimeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'EPG time'**
  String get playlistEpgTimeScreenTitle;

  /// No description provided for @playlistEpgTimeScreenHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how programme times are shown for this playlist.'**
  String get playlistEpgTimeScreenHint;

  /// No description provided for @playlistEpgTimeRowLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get playlistEpgTimeRowLocal;

  /// No description provided for @playlistEpgTimeRowLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this device’s time zone'**
  String get playlistEpgTimeRowLocalSubtitle;

  /// No description provided for @playlistEpgTimeRowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original (server)'**
  String get playlistEpgTimeRowOriginal;

  /// No description provided for @playlistEpgTimeRowOriginalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Times as sent by the provider'**
  String get playlistEpgTimeRowOriginalSubtitle;

  /// No description provided for @playlistEpgZoneChip.
  ///
  /// In en, this message translates to:
  /// **'EPG: {zone}'**
  String playlistEpgZoneChip(String zone);

  /// No description provided for @playlistChipUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get playlistChipUse;

  /// No description provided for @playlistChipOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get playlistChipOn;

  /// No description provided for @playlistChipRename.
  ///
  /// In en, this message translates to:
  /// **'Ren'**
  String get playlistChipRename;

  /// No description provided for @playlistChipDelete.
  ///
  /// In en, this message translates to:
  /// **'Del'**
  String get playlistChipDelete;

  /// No description provided for @favSetupInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Create your own Live TV categories. Add a New favorite, give it a name and order (lower numbers appear first), then Choose channels — first pick is position 1, second is 2, and so on. Open a card anytime to edit or delete. Your favorites show on Live TV as category pills alongside your playlist, even if you hide playlist groups.'**
  String get favSetupInfoBanner;

  /// No description provided for @favNewFavorite.
  ///
  /// In en, this message translates to:
  /// **'New favorite'**
  String get favNewFavorite;

  /// No description provided for @favCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'Create a group'**
  String get favCreateGroup;

  /// No description provided for @favGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel} other{{count} channels}} · order {order}'**
  String favGroupSubtitle(int count, int order);

  /// No description provided for @favEditNew.
  ///
  /// In en, this message translates to:
  /// **'New favorite'**
  String get favEditNew;

  /// No description provided for @favEditEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit favorite'**
  String get favEditEdit;

  /// No description provided for @favEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get favEditNameLabel;

  /// No description provided for @favEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown on Live TV as a category'**
  String get favEditNameHint;

  /// No description provided for @favEditOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get favEditOrderLabel;

  /// No description provided for @favEditOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Lower = first among favorites'**
  String get favEditOrderHint;

  /// No description provided for @favEditChooseChannels.
  ///
  /// In en, this message translates to:
  /// **'Choose channels'**
  String get favEditChooseChannels;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @favEditOrderHelp.
  ///
  /// In en, this message translates to:
  /// **'Order: first tap = 1, second = 2… Use All in category / Clear category in the picker.'**
  String get favEditOrderHelp;

  /// No description provided for @favEditChannelsHeading.
  ///
  /// In en, this message translates to:
  /// **'Channels in this favorite'**
  String get favEditChannelsHeading;

  /// No description provided for @favEditNoChannels.
  ///
  /// In en, this message translates to:
  /// **'No channels yet.\nTap Choose channels.'**
  String get favEditNoChannels;

  /// No description provided for @favEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get favEditSave;

  /// No description provided for @favEditDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get favEditDelete;

  /// No description provided for @defaultFavoriteName.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get defaultFavoriteName;

  /// No description provided for @favPickNoXtream.
  ///
  /// In en, this message translates to:
  /// **'No Xtream playlist'**
  String get favPickNoXtream;

  /// No description provided for @favPickNoXtreamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add an Xtream Codes playlist in My playlists to choose channels from any saved panel.'**
  String get favPickNoXtreamSubtitle;

  /// No description provided for @favPickHelpWithPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist → category → grid. Save at bottom. Back → Save.'**
  String get favPickHelpWithPlaylist;

  /// No description provided for @favPickHelpOrderBadges.
  ///
  /// In en, this message translates to:
  /// **'Picks on top (1,2,3…). Back → Save.'**
  String get favPickHelpOrderBadges;

  /// No description provided for @favPickHelpSimple.
  ///
  /// In en, this message translates to:
  /// **'Picks on top. Back → Save.'**
  String get favPickHelpSimple;

  /// No description provided for @favPickInFavorite.
  ///
  /// In en, this message translates to:
  /// **'In this favorite'**
  String get favPickInFavorite;

  /// No description provided for @favPickNoChannelsDraft.
  ///
  /// In en, this message translates to:
  /// **'No channels yet — pick from the grid below.'**
  String get favPickNoChannelsDraft;

  /// No description provided for @favPickChannelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Channel unavailable'**
  String get favPickChannelUnavailable;

  /// No description provided for @favPickAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get favPickAddMore;

  /// No description provided for @favPickNoChannelsCategory.
  ///
  /// In en, this message translates to:
  /// **'No channels in this category.'**
  String get favPickNoChannelsCategory;

  /// No description provided for @favPickAllInCategory.
  ///
  /// In en, this message translates to:
  /// **'All in category'**
  String get favPickAllInCategory;

  /// No description provided for @favPickClearCategory.
  ///
  /// In en, this message translates to:
  /// **'Clear category'**
  String get favPickClearCategory;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @backupInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'Personal includes passwords (keep private). Share strips passwords (safe to send).'**
  String get backupInfoBanner;

  /// No description provided for @backupExportPersonal.
  ///
  /// In en, this message translates to:
  /// **'Export personal'**
  String get backupExportPersonal;

  /// No description provided for @backupExportPersonalSub.
  ///
  /// In en, this message translates to:
  /// **'Full backup with passwords'**
  String get backupExportPersonalSub;

  /// No description provided for @backupExportShare.
  ///
  /// In en, this message translates to:
  /// **'Export to share'**
  String get backupExportShare;

  /// No description provided for @backupExportShareSub.
  ///
  /// In en, this message translates to:
  /// **'Passwords removed'**
  String get backupExportShareSub;

  /// No description provided for @backupShareLastExport.
  ///
  /// In en, this message translates to:
  /// **'Share last export'**
  String get backupShareLastExport;

  /// No description provided for @backupShareLastExportSub.
  ///
  /// In en, this message translates to:
  /// **'Send the file you just saved'**
  String get backupShareLastExportSub;

  /// No description provided for @backupShareLatest.
  ///
  /// In en, this message translates to:
  /// **'Share latest'**
  String get backupShareLatest;

  /// No description provided for @backupShareLatestSub.
  ///
  /// In en, this message translates to:
  /// **'Email, Drive, etc.'**
  String get backupShareLatestSub;

  /// No description provided for @backupImportNavigate.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImportNavigate;

  /// No description provided for @backupImportNavigateSub.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get backupImportNavigateSub;

  /// No description provided for @backupDeleteNavigate.
  ///
  /// In en, this message translates to:
  /// **'Delete backups'**
  String get backupDeleteNavigate;

  /// No description provided for @backupDeleteNavigateSub.
  ///
  /// In en, this message translates to:
  /// **'Remove old files'**
  String get backupDeleteNavigateSub;

  /// No description provided for @backupToastStorageRequired.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to save backups.'**
  String get backupToastStorageRequired;

  /// No description provided for @backupToastSavedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Saved to Downloads: {name}'**
  String backupToastSavedDownloads(String name);

  /// No description provided for @backupToastExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String backupToastExportFailed(String error);

  /// No description provided for @backupShareSubject.
  ///
  /// In en, this message translates to:
  /// **'TVMate Pro backup'**
  String get backupShareSubject;

  /// No description provided for @backupShareBody.
  ///
  /// In en, this message translates to:
  /// **'TVMate Pro settings backup'**
  String get backupShareBody;

  /// No description provided for @backupToastNoBackupsToShare.
  ///
  /// In en, this message translates to:
  /// **'No backup files found. Export one first.'**
  String get backupToastNoBackupsToShare;

  /// No description provided for @backupToastShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String backupToastShareFailed(String error);

  /// No description provided for @backupImportRestoredToast.
  ///
  /// In en, this message translates to:
  /// **'Backup restored. Catalogs are refreshing.'**
  String get backupImportRestoredToast;

  /// No description provided for @nsMessageBackupAppliedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup applied'**
  String get nsMessageBackupAppliedTitle;

  /// No description provided for @nsMessageErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get nsMessageErrorTitle;

  /// No description provided for @nsMessageDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get nsMessageDismiss;

  /// No description provided for @backupImportFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String backupImportFailedToast(String error);

  /// No description provided for @backupImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImportTitle;

  /// No description provided for @backupImportScanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scanning all of Downloads for tvmate-backup files'**
  String get backupImportScanSubtitle;

  /// No description provided for @backupImportRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get backupImportRefresh;

  /// No description provided for @backupImportRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring backup...'**
  String get backupImportRestoring;

  /// No description provided for @backupImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backup files found in Downloads.'**
  String get backupImportEmpty;

  /// No description provided for @backupManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete backups'**
  String get backupManageTitle;

  /// No description provided for @backupManageSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get backupManageSelectAll;

  /// No description provided for @backupManageClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get backupManageClearAll;

  /// No description provided for @backupManageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get backupManageDelete;

  /// No description provided for @backupManageDeleteCount.
  ///
  /// In en, this message translates to:
  /// **'Delete ({count})'**
  String backupManageDeleteCount(int count);

  /// No description provided for @backupManageDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete backups?'**
  String get backupManageDeleteConfirmTitle;

  /// No description provided for @backupManageDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file will be removed from Downloads.} other{{count} files will be removed from Downloads.}}'**
  String backupManageDeleteConfirmBody(int count);

  /// No description provided for @backupManageToastRemoved.
  ///
  /// In en, this message translates to:
  /// **'Selected backups removed.'**
  String get backupManageToastRemoved;

  /// No description provided for @backupManageEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backup files found.'**
  String get backupManageEmpty;

  /// No description provided for @settingsSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get settingsSubtitles;

  /// No description provided for @settingsSubtitlesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default subtitle language'**
  String get settingsSubtitlesSubtitle;

  /// No description provided for @subtitleSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitleSettingsTitle;

  /// No description provided for @subtitleSettingsDefaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default subtitle language'**
  String get subtitleSettingsDefaultLanguage;

  /// No description provided for @subtitleSettingsDefaultLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Search results list this language first.'**
  String get subtitleSettingsDefaultLanguageHint;

  /// No description provided for @subtitleSettingsApiKey.
  ///
  /// In en, this message translates to:
  /// **'OpenSubtitles API key'**
  String get subtitleSettingsApiKey;

  /// No description provided for @subtitleSettingsApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Create a free consumer key at opensubtitles.com'**
  String get subtitleSettingsApiKeyHint;

  /// No description provided for @subtitleSettingsSaveApiKey.
  ///
  /// In en, this message translates to:
  /// **'Save API key'**
  String get subtitleSettingsSaveApiKey;

  /// No description provided for @subtitleVodPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitleVodPickerTitle;

  /// No description provided for @subtitleVodLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get subtitleVodLoading;

  /// No description provided for @subtitleVodEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subtitles found.'**
  String get subtitleVodEmpty;

  /// No description provided for @subtitleVodLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get subtitleVodLanguages;

  /// No description provided for @subtitleVodFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get subtitleVodFiles;

  /// No description provided for @subtitleVodClear.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get subtitleVodClear;

  /// No description provided for @subtitleVodPickLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose a language on the left, or turn subtitles off.'**
  String get subtitleVodPickLanguage;

  /// No description provided for @subtitleVodNoApiKey.
  ///
  /// In en, this message translates to:
  /// **'Add your OpenSubtitles API key in Settings → Subtitles.'**
  String get subtitleVodNoApiKey;

  /// No description provided for @subtitleVodFooterSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get subtitleVodFooterSelect;

  /// No description provided for @subtitleAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle look'**
  String get subtitleAppearanceTitle;

  /// No description provided for @subtitleAppearanceSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitleAppearanceSubtitles;

  /// No description provided for @subtitleAppearanceBackground.
  ///
  /// In en, this message translates to:
  /// **'Background color'**
  String get subtitleAppearanceBackground;

  /// No description provided for @subtitleAppearanceBackgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background transparency'**
  String get subtitleAppearanceBackgroundOpacity;

  /// No description provided for @subtitleAppearanceTextColor.
  ///
  /// In en, this message translates to:
  /// **'Subtitle color'**
  String get subtitleAppearanceTextColor;

  /// No description provided for @subtitleAppearanceSize.
  ///
  /// In en, this message translates to:
  /// **'Subtitle size'**
  String get subtitleAppearanceSize;

  /// No description provided for @subtitleAppearancePosition.
  ///
  /// In en, this message translates to:
  /// **'Subtitle position'**
  String get subtitleAppearancePosition;

  /// No description provided for @subtitleAppearancePositionReady.
  ///
  /// In en, this message translates to:
  /// **'Press Select (OK) to move; press again when done. Then ↑↓←→.'**
  String get subtitleAppearancePositionReady;

  /// No description provided for @subtitleAppearancePositionMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving — D-pad to place. Select to finish. Back cancels move.'**
  String get subtitleAppearancePositionMoving;

  /// No description provided for @subtitleAppearanceHint.
  ///
  /// In en, this message translates to:
  /// **'↑↓ rows · Position: Select twice to move. Exit or Reset below.'**
  String get subtitleAppearanceHint;

  /// No description provided for @subtitleAppearanceExitMenu.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get subtitleAppearanceExitMenu;

  /// No description provided for @subtitleAppearanceResetDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset defaults'**
  String get subtitleAppearanceResetDefaults;

  /// No description provided for @subtitleAppearanceLabelSubtitleBackground.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Background:'**
  String get subtitleAppearanceLabelSubtitleBackground;

  /// No description provided for @subtitleAppearanceLabelTransparency.
  ///
  /// In en, this message translates to:
  /// **'Transparency:'**
  String get subtitleAppearanceLabelTransparency;

  /// No description provided for @subtitleAppearancePreviewLine.
  ///
  /// In en, this message translates to:
  /// **'This is how subtitles will look'**
  String get subtitleAppearancePreviewLine;

  /// No description provided for @subtitleAppearanceVodPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle edit'**
  String get subtitleAppearanceVodPanelTitle;

  /// No description provided for @subtitleAppearancePositionShort.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get subtitleAppearancePositionShort;

  /// No description provided for @parentalSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parental control'**
  String get parentalSettingsTitle;

  /// No description provided for @parentalSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PIN, locks, and blocked channels or titles'**
  String get parentalSettingsSubtitle;

  /// No description provided for @parentalDialogEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get parentalDialogEnterPin;

  /// No description provided for @parentalDialogPinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN (4–8 digits)'**
  String get parentalDialogPinLabel;

  /// No description provided for @parentalDialogSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get parentalDialogSubmit;

  /// No description provided for @parentalPinWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get parentalPinWrong;

  /// No description provided for @parentalSetupWarning.
  ///
  /// In en, this message translates to:
  /// **'Important: remember this PIN. If you forget it, you may need to clear app data or restore from backup. TVMate Pro cannot show your PIN again.'**
  String get parentalSetupWarning;

  /// No description provided for @parentalSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create PIN'**
  String get parentalSetupTitle;

  /// No description provided for @parentalSetupPinLabel.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get parentalSetupPinLabel;

  /// No description provided for @parentalSetupConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get parentalSetupConfirmLabel;

  /// No description provided for @parentalMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match.'**
  String get parentalMismatch;

  /// No description provided for @parentalEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Parental control on'**
  String get parentalEnabledLabel;

  /// No description provided for @parentalLockAllLive.
  ///
  /// In en, this message translates to:
  /// **'Lock all Live TV'**
  String get parentalLockAllLive;

  /// No description provided for @parentalLockAllMovies.
  ///
  /// In en, this message translates to:
  /// **'Lock all Movies'**
  String get parentalLockAllMovies;

  /// No description provided for @parentalLockAllSeries.
  ///
  /// In en, this message translates to:
  /// **'Lock all Series'**
  String get parentalLockAllSeries;

  /// No description provided for @parentalHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get parentalHelpTitle;

  /// No description provided for @parentalHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Set a 4–8 digit PIN. Turn on locks here, or from Live TV (Menu on a channel), movie or series screens (lock icon) to block one channel, category, title, or show. Blocked items ask for the PIN before playback.'**
  String get parentalHelpBody;

  /// No description provided for @parentalSetPinCta.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get parentalSetPinCta;

  /// No description provided for @parentalCreateYourKeyTile.
  ///
  /// In en, this message translates to:
  /// **'Create your key'**
  String get parentalCreateYourKeyTile;

  /// No description provided for @parentalCreateYourKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select to set a PIN and use these controls'**
  String get parentalCreateYourKeySubtitle;

  /// No description provided for @parentalChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get parentalChangePin;

  /// No description provided for @parentalClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear parental (reset PIN and rules)'**
  String get parentalClearAll;

  /// No description provided for @parentalScopeTitleLive.
  ///
  /// In en, this message translates to:
  /// **'Lock on Live TV'**
  String get parentalScopeTitleLive;

  /// No description provided for @parentalBlockThisChannel.
  ///
  /// In en, this message translates to:
  /// **'This channel only'**
  String get parentalBlockThisChannel;

  /// No description provided for @parentalScopeLockChannelOnly.
  ///
  /// In en, this message translates to:
  /// **'Lock channel'**
  String get parentalScopeLockChannelOnly;

  /// No description provided for @parentalScopeLockChannelAndHideBrowse.
  ///
  /// In en, this message translates to:
  /// **'Lock channel & hide in browse'**
  String get parentalScopeLockChannelAndHideBrowse;

  /// No description provided for @parentalScopeLockCategoryOnly.
  ///
  /// In en, this message translates to:
  /// **'Lock category or group'**
  String get parentalScopeLockCategoryOnly;

  /// No description provided for @parentalScopeLockCategoryAndHideBrowse.
  ///
  /// In en, this message translates to:
  /// **'Lock category or group & hide in browse'**
  String get parentalScopeLockCategoryAndHideBrowse;

  /// No description provided for @parentalBlockCategoryOrGroup.
  ///
  /// In en, this message translates to:
  /// **'Entire category or favorite group'**
  String get parentalBlockCategoryOrGroup;

  /// No description provided for @parentalScopeTitleMovie.
  ///
  /// In en, this message translates to:
  /// **'Lock movie'**
  String get parentalScopeTitleMovie;

  /// No description provided for @parentalBlockThisMovie.
  ///
  /// In en, this message translates to:
  /// **'This movie only'**
  String get parentalBlockThisMovie;

  /// No description provided for @parentalBlockMovieCategory.
  ///
  /// In en, this message translates to:
  /// **'Entire movie category'**
  String get parentalBlockMovieCategory;

  /// No description provided for @parentalScopeTitleSeries.
  ///
  /// In en, this message translates to:
  /// **'Lock series'**
  String get parentalScopeTitleSeries;

  /// No description provided for @parentalBlockThisShow.
  ///
  /// In en, this message translates to:
  /// **'This show only'**
  String get parentalBlockThisShow;

  /// No description provided for @parentalBlockSeriesCategory.
  ///
  /// In en, this message translates to:
  /// **'Entire series category'**
  String get parentalBlockSeriesCategory;

  /// No description provided for @parentalLockSaved.
  ///
  /// In en, this message translates to:
  /// **'Lock saved.'**
  String get parentalLockSaved;

  /// No description provided for @parentalUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked.'**
  String get parentalUnlocked;

  /// No description provided for @parentalUnlockThisChannel.
  ///
  /// In en, this message translates to:
  /// **'Unlock this channel'**
  String get parentalUnlockThisChannel;

  /// No description provided for @parentalUnlockCategoryOrGroup.
  ///
  /// In en, this message translates to:
  /// **'Unlock this category or group'**
  String get parentalUnlockCategoryOrGroup;

  /// No description provided for @parentalUnlockThisMovie.
  ///
  /// In en, this message translates to:
  /// **'Unlock this movie'**
  String get parentalUnlockThisMovie;

  /// No description provided for @parentalUnlockMovieCategory.
  ///
  /// In en, this message translates to:
  /// **'Unlock this movie category'**
  String get parentalUnlockMovieCategory;

  /// No description provided for @parentalUnlockThisShow.
  ///
  /// In en, this message translates to:
  /// **'Unlock this show'**
  String get parentalUnlockThisShow;

  /// No description provided for @parentalUnlockSeriesCategory.
  ///
  /// In en, this message translates to:
  /// **'Unlock this series category'**
  String get parentalUnlockSeriesCategory;

  /// No description provided for @parentalPlayerParental.
  ///
  /// In en, this message translates to:
  /// **'Parental'**
  String get parentalPlayerParental;

  /// No description provided for @playerEpgPanelLabel.
  ///
  /// In en, this message translates to:
  /// **'EPG'**
  String get playerEpgPanelLabel;

  /// No description provided for @playerRightPanelQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get playerRightPanelQuality;

  /// No description provided for @playerVodDownloadDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get playerVodDownloadDownloading;

  /// No description provided for @playerVodDownloadVideoTypes.
  ///
  /// In en, this message translates to:
  /// **'Video files'**
  String get playerVodDownloadVideoTypes;

  /// No description provided for @playerVodDownloadPlaylistNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This stream is a playlist (HLS), not a single video file. Download is not available for this format.'**
  String get playerVodDownloadPlaylistNotSupported;

  /// No description provided for @playerVodDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String playerVodDownloadFailed(String error);

  /// No description provided for @playerVodDownloadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved: {path}'**
  String playerVodDownloadSaved(String path);

  /// No description provided for @playerVodDownloadAlreadyInProgress.
  ///
  /// In en, this message translates to:
  /// **'A download is already in progress.'**
  String get playerVodDownloadAlreadyInProgress;

  /// No description provided for @playerVodDownloadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get playerVodDownloadCancel;

  /// No description provided for @playerVodDownloadPickingLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose where to save…'**
  String get playerVodDownloadPickingLocation;

  /// No description provided for @playerVodDownloadSavingToDownloadsFolder.
  ///
  /// In en, this message translates to:
  /// **'Saving to Downloads…'**
  String get playerVodDownloadSavingToDownloadsFolder;

  /// No description provided for @playerVodDownloadCopying.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get playerVodDownloadCopying;

  /// No description provided for @playerVodDownloadErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty file'**
  String get playerVodDownloadErrorEmpty;

  /// No description provided for @playerVodDownloadSavedShort.
  ///
  /// In en, this message translates to:
  /// **'Saved offline: {title}'**
  String playerVodDownloadSavedShort(String title);

  /// No description provided for @playerVodDownloadSavingOffline.
  ///
  /// In en, this message translates to:
  /// **'Saving offline…'**
  String get playerVodDownloadSavingOffline;

  /// No description provided for @accountOfflineDownloadsMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline downloads'**
  String get accountOfflineDownloadsMenuLabel;

  /// No description provided for @accountOfflineDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline downloads'**
  String get accountOfflineDownloadsTitle;

  /// No description provided for @accountOfflineDownloadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos saved on this device. Delete items to free space.'**
  String get accountOfflineDownloadsSubtitle;

  /// No description provided for @accountOfflineDownloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No offline videos yet. Download from a movie or episode while playing.'**
  String get accountOfflineDownloadsEmpty;

  /// No description provided for @accountOfflineDownloadsPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get accountOfflineDownloadsPlay;

  /// No description provided for @accountOfflineDownloadsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountOfflineDownloadsDelete;

  /// No description provided for @accountOfflineDownloadsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get accountOfflineDownloadsDeleteTitle;

  /// No description provided for @accountOfflineDownloadsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the file from your device.'**
  String get accountOfflineDownloadsDeleteBody;

  /// No description provided for @accountOfflineDownloadsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get accountOfflineDownloadsDeleteConfirm;

  /// No description provided for @playerEpgOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel guide'**
  String get playerEpgOverlayTitle;

  /// No description provided for @playerEpgOverlaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get playerEpgOverlaySchedule;

  /// No description provided for @playerEpgOverlayLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading programme guide…'**
  String get playerEpgOverlayLoading;

  /// No description provided for @playerEpgOverlayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No programme information for this channel.'**
  String get playerEpgOverlayEmpty;

  /// No description provided for @playerEpgNowBadge.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get playerEpgNowBadge;

  /// No description provided for @playerEpgLiveRightNow.
  ///
  /// In en, this message translates to:
  /// **'Live right now'**
  String get playerEpgLiveRightNow;

  /// No description provided for @playerEpgDayToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get playerEpgDayToday;

  /// No description provided for @playerEpgDayTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get playerEpgDayTomorrow;

  /// No description provided for @parentalMenuContextLive.
  ///
  /// In en, this message translates to:
  /// **'Parental lock…'**
  String get parentalMenuContextLive;

  /// No description provided for @parentalMustEnableInSettings.
  ///
  /// In en, this message translates to:
  /// **'Turn on parental control and set a PIN in Settings first.'**
  String get parentalMustEnableInSettings;

  /// No description provided for @parentalLockAndHideTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock & hide in browse'**
  String get parentalLockAndHideTitle;

  /// No description provided for @parentalLockAndHideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide restricted items from lists (still PIN-protected if shown elsewhere)'**
  String get parentalLockAndHideSubtitle;

  /// No description provided for @parentalManageRestrictedRules.
  ///
  /// In en, this message translates to:
  /// **'Manage restricted rules'**
  String get parentalManageRestrictedRules;

  /// No description provided for @parentalManageRestrictedRulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View or remove locks on channels, categories, and titles'**
  String get parentalManageRestrictedRulesSubtitle;

  /// No description provided for @parentalRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Restricted rules'**
  String get parentalRulesTitle;

  /// No description provided for @parentalRulesSectionLive.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get parentalRulesSectionLive;

  /// No description provided for @parentalRulesSectionMovies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get parentalRulesSectionMovies;

  /// No description provided for @parentalRulesSectionSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get parentalRulesSectionSeries;

  /// No description provided for @parentalRulesLockAllOn.
  ///
  /// In en, this message translates to:
  /// **'Lock entire section: on'**
  String get parentalRulesLockAllOn;

  /// No description provided for @parentalRulesLockAllOff.
  ///
  /// In en, this message translates to:
  /// **'Lock entire section: off'**
  String get parentalRulesLockAllOff;

  /// No description provided for @parentalRulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No per-item rules for this section.'**
  String get parentalRulesEmpty;

  /// No description provided for @parentalRulesFavoriteGroup.
  ///
  /// In en, this message translates to:
  /// **'Favorite group'**
  String get parentalRulesFavoriteGroup;

  /// No description provided for @parentalRulesCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get parentalRulesCategory;

  /// No description provided for @parentalRulesChannel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get parentalRulesChannel;

  /// No description provided for @parentalRulesMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get parentalRulesMovie;

  /// No description provided for @parentalRulesSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get parentalRulesSeries;

  /// No description provided for @parentalPlayerOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Parental'**
  String get parentalPlayerOverlayTitle;

  /// No description provided for @parentalPlayerOverlayPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Create PIN'**
  String get parentalPlayerOverlayPinTitle;

  /// No description provided for @parentalPlayerOverlayEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on parental control'**
  String get parentalPlayerOverlayEnableTitle;

  /// No description provided for @parentalPlayerOverlayEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your PIN to enable locks from the player'**
  String get parentalPlayerOverlayEnableSubtitle;

  /// No description provided for @parentalRulesRemoveRule.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get parentalRulesRemoveRule;

  /// No description provided for @parentalScopeActionNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This action does not apply right now.'**
  String get parentalScopeActionNotAvailable;

  /// No description provided for @parentalScopeChannelAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This channel is already blocked.'**
  String get parentalScopeChannelAlreadyBlocked;

  /// No description provided for @parentalScopeChannelNotBlocked.
  ///
  /// In en, this message translates to:
  /// **'This channel is not blocked.'**
  String get parentalScopeChannelNotBlocked;

  /// No description provided for @parentalScopeCategoryAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This category or group is already blocked.'**
  String get parentalScopeCategoryAlreadyBlocked;

  /// No description provided for @parentalScopeCategoryNotBlocked.
  ///
  /// In en, this message translates to:
  /// **'This category or group is not blocked.'**
  String get parentalScopeCategoryNotBlocked;

  /// No description provided for @parentalScopeNoCategoryContext.
  ///
  /// In en, this message translates to:
  /// **'No category or group is available for this view.'**
  String get parentalScopeNoCategoryContext;

  /// No description provided for @parentalScopeMovieAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This movie is already blocked.'**
  String get parentalScopeMovieAlreadyBlocked;

  /// No description provided for @parentalScopeMovieNotBlocked.
  ///
  /// In en, this message translates to:
  /// **'This movie is not blocked.'**
  String get parentalScopeMovieNotBlocked;

  /// No description provided for @parentalScopeMovieCategoryAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This movie category is already blocked.'**
  String get parentalScopeMovieCategoryAlreadyBlocked;

  /// No description provided for @parentalScopeMovieCategoryNotBlocked.
  ///
  /// In en, this message translates to:
  /// **'This movie category is not blocked.'**
  String get parentalScopeMovieCategoryNotBlocked;

  /// No description provided for @parentalScopeSeriesAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This show is already blocked.'**
  String get parentalScopeSeriesAlreadyBlocked;

  /// No description provided for @parentalScopeSeriesNotBlocked.
  ///
  /// In en, this message translates to:
  /// **'This show is not blocked.'**
  String get parentalScopeSeriesNotBlocked;

  /// No description provided for @parentalScopeSeriesCategoryAlreadyBlocked.
  ///
  /// In en, this message translates to:
  /// **'This series category is already blocked.'**
  String get parentalScopeSeriesCategoryAlreadyBlocked;

  /// No description provided for @parentalScopeSeriesCategoryNotBlocked.
  ///
  /// In en, this message translates to:
  /// **'This series category is not blocked.'**
  String get parentalScopeSeriesCategoryNotBlocked;

  /// No description provided for @parentalSideMenuSetupBody.
  ///
  /// In en, this message translates to:
  /// **'To use parental controls, set a password first. Enter a 4–8 digit PIN below.'**
  String get parentalSideMenuSetupBody;

  /// No description provided for @parentalSideMenuSetupSave.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get parentalSideMenuSetupSave;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'fr', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
