// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsTopMenuManager => 'מנהל תפריט עליון';

  @override
  String get settingsTopMenuManagerSubtitle => 'סדר מחדש, הוספת פריטים, הפעלה';

  @override
  String get settingsShellThemeSubtitle => 'צוות ויזואלי וצבעי הדגשה';

  @override
  String get settingsShellPlaylistSubtitle => 'החלפת פלייליסט פעיל';

  @override
  String get settingsAddPlaylist => 'הוספת פלייליסט';

  @override
  String get settingsAddPlaylistSubtitle => 'Xtream או M3U';

  @override
  String get settingsMyPlaylists => 'הפלייליסטים שלי';

  @override
  String settingsMyPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פלייליסטים',
      two: 'שני פלייליסטים',
      one: 'פלייליסט אחד',
      zero: 'אין פלייליסטים',
    );
    return '$_temp0';
  }

  @override
  String get settingsFavoriteSetup => 'הגדרות מועדפים';

  @override
  String get settingsFavoriteSetupSubtitle => 'ערוצי טלוויזיה חיים מועדפים';

  @override
  String get settingsClock => 'שעון';

  @override
  String get settingsClockOn => 'פועל';

  @override
  String get settingsClockOff => 'כבוי';

  @override
  String get settingsAppearance => 'מראה';

  @override
  String settingsAppearanceSubtitle(int heroPercent, int columns) {
    return 'הירו $heroPercent% · $columns בשורה';
  }

  @override
  String get settingsRecordingEdit => 'עריכת הקלטות';

  @override
  String get settingsRecordingEditSubtitle => 'הגדרת ערוצי ארכיון';

  @override
  String get catchupSelectPlaylistHelp =>
      'בחרו פלייליסט כדי להגדיר ערוצי ארכיון';

  @override
  String get catchupNoXtreamPlaylists =>
      'לא נמצאו פלייליסטי Xtream.\nהוסיפו תחילה פלייליסט כזה.';

  @override
  String get catchupBreadcrumbCategories => 'הקלטות · קטגוריות';

  @override
  String catchupBreadcrumbWithCategory(String categoryName) {
    return 'הקלטות · $categoryName';
  }

  @override
  String get catchupFilterQuickOn => 'מסנן הקלטות: מופעל';

  @override
  String get catchupFilterQuickOff => 'מסנן הקלטות: כבוי';

  @override
  String get catchupEmptyStateTitle => 'הגדירו הקלטה בהגדרות';

  @override
  String catchupEmptyStateBody(String entryLabel) {
    return 'עברו להגדרות → $entryLabel כדי לאשר\nקטגוריות וערוצים.';
  }

  @override
  String get catchupXtreamOnly => 'הקלטה/ארכיון זמינים רק לרשימות מסוג Xtream.';

  @override
  String get catchupManage => 'ניהול הקלטות';

  @override
  String get catchupGroupOptions => 'אפשרויות הקלטה';

  @override
  String get catchupGroupCategories => 'קטגוריות';

  @override
  String get catchupSelectAll => 'בחירה מלאה';

  @override
  String get catchupClearAll => 'נקה';

  @override
  String catchupFilterSub(String tabName) {
    return 'הצגה רק של ערוצים שהמקור מפרסם להם ארכיון. מסתיר את כל השאר בלשונית $tabName עבור רשימה זו.';
  }

  @override
  String get catchupClearConfirmTitle => 'לנקות את כל האישורים?';

  @override
  String catchupClearConfirmMessage(String playlistName) {
    return 'מסירים את כל הקטגוריות והערוצים המאושרים מרשימת ההקלטות של \"$playlistName\". הרשימה עצמה לא משתנה.';
  }

  @override
  String get catchupFilterBannerLead => 'מסנן ארכיון מופעל. ';

  @override
  String catchupFilterHiddenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ערוצים בלי אפשרות ארכיון מוסתרים מהרשימה.',
      one: 'ערוץ 1 בלי אפשרות ארכיון מוסתר מהרשימה.',
    );
    return '$_temp0 כבו את המסנן דרך אפשרויות הקלטה כדי לאשר אותם.';
  }

  @override
  String get catchupNoChannelsInCategory => 'אין ערוצים בקטגוריה הזו.';

  @override
  String get catchupNoLiveCategoriesSync =>
      'לא נמצאו קטגוריות חי.\nסנכרנו את הרשימה.';

  @override
  String get settingsBackup => 'גיבוי';

  @override
  String get settingsBackupSubtitle => 'ייצוא / ייבוא הגדרות';

  @override
  String get settingsDemoMode => 'מצב הדגמה';

  @override
  String get settingsDemoModeSubtitleBrowseDemo =>
      'עיון בהדגמה עד שתוסיף פלייליסט';

  @override
  String get settingsDemoModeSubtitleRealChannels =>
      'ערוצים אמיתיים — הדגמה כבויה כשיש פלייליסטים';

  @override
  String get settingsDemoModeAbout =>
      'מצב הדגמה מובנה: דוגמאות לטלוויזיה חיה, סרטים וסדרות עם אמנות מובנית ורשימות דמה. הניגון בזרמי דמו. ניתן להוסיף פלייליסט Xtream או M3U בכל עת.';

  @override
  String get settingsLanguage => 'שפה';

  @override
  String get settingsLanguageSubtitle => 'שפת הממשק';

  @override
  String get settingsPerformance => 'ביצועים';

  @override
  String get settingsPerformanceSubtitle =>
      'איכות מלאה או מותאם למכשירים חלשים יותר';

  @override
  String get performanceScreenTitle => 'ביצועים';

  @override
  String get performanceScreenIntro =>
      'בחרו כמה האפליקציה עומסת על המכשיר. סטרימרים חזקים (למשל NVIDIA Shield) יכולים להשתמש באיכות מלאה. מקלות וסטרימרים קטנים לרוב חלקים יותר במצב מותאם. אוטומטי בוחש לפי זיכרון המכשיר. אפשר לשנות בכל עת.';

  @override
  String get performanceModeAuto => 'אוטומטי';

  @override
  String get performanceModeAutoSubtitle =>
      'מומלץ — בוחש מלא או מותאם לפי זיכרון';

  @override
  String get performanceModeFull => 'איכות מלאה';

  @override
  String get performanceModeFullSubtitle => 'חזות עשירה — מתאים לחומרה חזקה';

  @override
  String get performanceModeOptimized => 'מותאם';

  @override
  String get performanceModeOptimizedSubtitle =>
      'רקע קל יותר, מטמון קטן יותר, סנכרון מאוחר. פענוח וידאו אחד בכל רגע (תצוגת גיבור בגריד נעצרת במסך מלא) — חלק יותר בטלוויזיות חלשות';

  @override
  String performanceDetectedRam(String mb) {
    return 'זיכרון כולל שזוהה: $mb MB';
  }

  @override
  String get performanceDetectedRamUnknown =>
      'זיכרון לא זוהה — אוטומטי משתמש באיכות מלאה';

  @override
  String get performanceAutoCurrentlyUsingFull =>
      'כרגע, אוטומטי משתמש באיכות מלאה.';

  @override
  String get performanceAutoCurrentlyUsingOptimized =>
      'כרגע, אוטומטי משתמש במצב מותאם.';

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
  String get tvRemoteTypingButton => 'הקלד עם השלט';

  @override
  String get tvRemoteTypingTitle => 'הזנת טקסט';

  @override
  String get tvRemoteTypingDone => 'סיום';

  @override
  String get tvRemoteGoogleTvKeyboardHint =>
      'מקלדת על המסך לא תמיד נפתחת ב‑Google TV או Chromecast. השתמשו בשורה למעלה כדי להקליד עם השלט.';

  @override
  String get tvKeyboardLanguagesTitle => 'שפות';

  @override
  String get tvKeyboardPickLanguagesSubtitle =>
      'סמנו שפות שיופיעו ברשימה (למעלה או גלובוס). הסדר הוא לפי סדר ההוספה.';

  @override
  String get tvKeyboardLayoutNotAvailable =>
      'מקלדת על המסך עדיין לא זמינה לשפה זו.';

  @override
  String get languageScreenTitle => 'שפה';

  @override
  String get languageEnglish => 'אנגלית';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get languageFrench => 'צרפתית';

  @override
  String get languageSpanish => 'ספרדית';

  @override
  String get languageArabic => 'ערבית';

  @override
  String get languageRussian => 'רוסית';

  @override
  String get languageGerman => 'גרמנית';

  @override
  String get languagePortuguese => 'פורטוגזית';

  @override
  String get languageItalian => 'איטלקית';

  @override
  String get languageTurkish => 'טורקית';

  @override
  String get languageHindi => 'הינדי';

  @override
  String get languageJapanese => 'יפנית';

  @override
  String get languageKorean => 'קוריאנית';

  @override
  String get languageChinese => 'סינית';

  @override
  String get languageVietnamese => 'וייטנאמית';

  @override
  String get actionPlay => 'נגן';

  @override
  String get actionExternal => 'חיצוני';

  @override
  String get actionTrailer => 'טריילר';

  @override
  String get actionMyList => 'הרשימה שלי';

  @override
  String get actionRemove => 'הסר';

  @override
  String get actionWatched => 'נצפה';

  @override
  String get actionUnwatch => 'בטל צפייה';

  @override
  String get actionWatching => 'צופה';

  @override
  String get actionWatchingOff => 'לא צופה';

  @override
  String get actionContinueWatching => 'המשך צפייה';

  @override
  String get actionContinueWatchingOff => 'נקה המשך';

  @override
  String get navLiveTv => 'טלוויזיה חיה';

  @override
  String get navMovies => 'סרטים';

  @override
  String get navSeries => 'סדרות';

  @override
  String get navRecording => 'הקלטות';

  @override
  String get navPlaylist => 'פלייליסט';

  @override
  String get navTheme => 'ערכת נושא';

  @override
  String get navClock => 'שעון';

  @override
  String get navAppearance => 'מראה';

  @override
  String get navBackup => 'גיבוי';

  @override
  String get navFavorites => 'מועדפים';

  @override
  String get navLanguage => 'שפה';

  @override
  String get navSettings => 'הגדרות';

  @override
  String get nsCategoryOldSettings => 'הגדרות ישנות';

  @override
  String get searchMoviesAndSeries => 'חיפוש סרטים וסדרות';

  @override
  String get searchLiveTv => 'חיפוש טלוויזיה חיה';

  @override
  String get searchRecording => 'חיפוש הקלטות';

  @override
  String get searchHint => 'הקלד לסינון העמוד';

  @override
  String get searchClear => 'נקה';

  @override
  String get searchApply => 'החל';

  @override
  String get searchLabel => 'חיפוש';

  @override
  String searchPrefixWithQuery(String query) {
    return 'חיפוש: $query';
  }

  @override
  String get playlistEmptyTitle => 'אין עדיין פלייליסטים';

  @override
  String get playlistEmptySubtitle => 'הוסף בהגדרות';

  @override
  String get playlistGoToSettings => 'מעבר להגדרות';

  @override
  String get playlistDismissBarrier => 'סגירת בורר הפלייליסט';

  @override
  String playlistStatsLine(int liveCount, int movieCount, int seriesCount) {
    return '$liveCount ערוצים חיים · $movieCount סרטים · $seriesCount סדרות';
  }

  @override
  String get topMenuManagerTitle => 'מנהל תפריט עליון';

  @override
  String get topMenuOrderSection => 'סדר תפריט';

  @override
  String get topMenuReorderHelp =>
      'לחץ אישור לאיסוף, אז למעלה/למטה להזזה, אישור לשחרור.';

  @override
  String get topMenuRemoveHelp =>
      'כרטיסיות אופציונליות: ימינה להסרה מהשורה (אישור רק לאיסוף/שחרור).';

  @override
  String get topMenuAddToMenu => 'הוסף לתפריט';

  @override
  String get topMenuStartupSection => 'קטגוריית הפעלה';

  @override
  String get topMenuStartupHelp => 'איזה מסך נפתח כשהאפליקציה מתחילה.';

  @override
  String get topMenuSettingsLocked => 'הגדרות';

  @override
  String get topMenuAlwaysLast => 'תמיד אחרון';

  @override
  String get commonBack => 'חזרה';

  @override
  String get mvPickerAddChannel => 'הוסף ערוץ';

  @override
  String get mvPickerChangeChannel => 'החלף ערוץ';

  @override
  String get mvChooseChannel => 'בחר ערוץ';

  @override
  String get mvAddScreen => 'הוסף מסך';

  @override
  String get mvChangeChannel => 'החלף ערוץ';

  @override
  String get mvReduceScreen => 'הקטן מסך';

  @override
  String get mvEnlargeScreen => 'הגדל מסך';

  @override
  String get mvFullScreen => 'מסך מלא';

  @override
  String get mvRemoveScreen => 'הסר מסך';

  @override
  String get mvExitMultiview => 'יציאה מריבוי מסכים';

  @override
  String get mvMenuTitle => 'ריבוי מסכים';

  @override
  String get mvMenuHint => '▲▼ ניווט · אישור · חזרה';

  @override
  String get demoBlurbLiveTv =>
      'דמו לטלוויזיה חיה: קטגוריות ורשת ערוצים עם לוגואים מובנים. פאנל גיבור ותוויות; זרם הדגמה בפתיחת הנגן.';

  @override
  String get demoBlurbMovies =>
      'דמו סרטים: שורות עם פוסטרים מובנים ופרטים דמה. מיקוד בכותרת מעדכן את הגיבור והתקציר.';

  @override
  String get demoBlurbSeries =>
      'דמו סדרות: פוסטרים מובנים, עונות ופרקים. אותו זרם כמו בסרטים; זרם הדגמה בניגון.';

  @override
  String get demoBlurbRecording =>
      'עיון ב-EPG ארכיון לפי קטגוריה, תאריך וערוץ. בחר תוכנית עבר כדי לנגן.';

  @override
  String get demoBlurbTeam =>
      'בחר Cosmic, Aurora, Solar או Heritage לרקע ולממשק.';

  @override
  String get demoBlurbSettings =>
      'מרכז הגדרות הדגמה. פלייליסט, פרופילים ונגן יתווספו כאן.';

  @override
  String get demoBlurbOptional =>
      'יעד אופציונלי. הפעל במנהל תפריט עליון כדי להציג בסרגל.';

  @override
  String get clockInfoBanner =>
      'שעון צף אופציונלי מעל האפליקציה. הפעל או כבה — בסרגל העליון תמיד מוצג הזמן; זהו שכבה נוספת. בחר 12 או 24 שעות, גודל, פינה, בהירות (אטימות) וצבע. מסגרת מוסיפה גבול ותאריך מתחת לשעה; כבה לזמן בלבד. השתמש ב״התאם מיקום״ כדי להזיז את השכבה בכל פינה עם השלט. עבור עם המרחוק ובחר כדי להחיל; השינויים נשמרים בזמן שימוש.';

  @override
  String get clockToggleOn => 'שעון: פועל';

  @override
  String get clockToggleOff => 'שעון: כבוי';

  @override
  String get clockTapHide => 'לחץ להסתרה';

  @override
  String get clockTapShow => 'לחץ להצגה';

  @override
  String get clockFrameOn => 'מסגרת: פועלת';

  @override
  String get clockFrameOff => 'מסגרת: כבויה';

  @override
  String get clockFrameSubOn => 'גבול + תאריך מתחת לשעה';

  @override
  String get clockFrameSubOff => 'שעה בלבד (בלי גבול ותאריך)';

  @override
  String get clock12Hour => '12 שעות';

  @override
  String get clock12HourSub => 'לפנה״צ / אחה״צ';

  @override
  String get clock24Hour => '24 שעות';

  @override
  String get clock24HourSub => '00–23';

  @override
  String get clockSizeSmall => 'קטן';

  @override
  String get clockSizeMedium => 'בינוני';

  @override
  String get clockSizeLarge => 'גדול';

  @override
  String get clockSizeSubtitle => 'גודל';

  @override
  String get clockCornerSubtitle => 'פינה';

  @override
  String get clockCornerTopLeft => 'למעלה משמאל';

  @override
  String get clockCornerTopRight => 'למעלה מימין';

  @override
  String get clockCornerBottomLeft => 'למטה משמאל';

  @override
  String get clockCornerBottomRight => 'למטה מימין';

  @override
  String get clockAdjustPosition => 'התאם מיקום';

  @override
  String get clockAdjustPositionSub => 'D-pad זז · חזרה שומרת';

  @override
  String get clockOpacitySubtitle => 'אטימות';

  @override
  String clockOpacityPercent(int percent) {
    return '$percent%';
  }

  @override
  String clockColorPreset(int index) {
    return 'צבע $index';
  }

  @override
  String get clockColorPresetSubtitle => 'ערכה';

  @override
  String get clockPositionAdjustTitle => 'התאם מיקום';

  @override
  String clockPositionCornerLine(String corner) {
    return 'פינה: $corner';
  }

  @override
  String clockPositionOffsetLine(int dx, int dy, int max) {
    return 'היסט: $dx × $dy (מקס׳ ±$max)';
  }

  @override
  String get clockPositionHelpEnabled =>
      'השתמש ב-D-pad כדי להזיז את השעון על המסך. השינויים חלים על הפינה הנוכחית בלבד. חזרה חוזרת להגדרות השעון.';

  @override
  String get clockPositionHelpDisabled =>
      'הפעל את השעון כדי לראות את השכבה בזמן ההתאמה. ההיסטים נשמרים לכל פינה.';

  @override
  String get appearanceLayoutEditors => 'עורכי פריסה';

  @override
  String get appearanceHeroBackgroundTitle => 'רקע גיבור';

  @override
  String get appearanceHeroBackgroundSubtitle =>
      'צבעים מאחורי תצוגת טלוויזיה חיה';

  @override
  String get heroAppearanceScreenTitle => 'רקע גיבור';

  @override
  String get heroAppearanceHint =>
      'שינויים נשמרים אוטומטית. איפוס מחזיר את מראה ברירת המחדל של הנושא.';

  @override
  String get heroAppearanceReset => 'איפוס לברירת מחדל';

  @override
  String get heroAppearanceHideControls => 'הסתר פקדים';

  @override
  String get heroAppearanceShowControls => 'הצג פקדים';

  @override
  String get heroAppearanceBase => 'צבע בסיס';

  @override
  String get heroAppearanceWash => 'צבע מברשת';

  @override
  String get heroAppearanceIntensity => 'עוצמת מברשת';

  @override
  String get heroAppearanceBrushStyle => 'סגנון מברשת';

  @override
  String get heroAppearanceSectionBackground => 'רקע';

  @override
  String get heroAppearanceSectionTv => 'מסגרת תצוגה';

  @override
  String get heroAppearanceSectionFineTune => 'כיוון עדין';

  @override
  String get heroAppearanceShowFrame => 'הצג מסגרת טלוויזיה';

  @override
  String get heroAppearanceFrameProfile => 'פרופיל מסגרת';

  @override
  String get heroAppearanceBezelFinish => 'גימור מסגרת';

  @override
  String get heroAppearanceGradientDepth => 'עומק הגרדיאנט';

  @override
  String get heroAppearanceFrameSlim => 'צר';

  @override
  String get heroAppearanceFrameClassic => 'קלאסי';

  @override
  String get heroAppearanceFrameBold => 'מודגש';

  @override
  String get heroAppearanceFrameMinimal => 'מינימלי';

  @override
  String get heroAppearanceOn => 'פועל';

  @override
  String get heroAppearanceOff => 'כבוי';

  @override
  String get heroAppearanceTabColors => 'צבעים';

  @override
  String get heroAppearanceTabOverlay => 'שכבה';

  @override
  String get heroAppearanceTabFrame => 'מסגרת';

  @override
  String get heroAppearanceTabMore => 'עוד';

  @override
  String get heroAppearanceWashModeBrush => 'מברשת';

  @override
  String get heroAppearanceWashModeSolid => 'אחיד';

  @override
  String get heroAppearanceHintShort => 'נשמר אוטומטית.';

  @override
  String get heroAppearanceSolidHint => 'צבע מלא — עוצמה בלשונית שכבה.';

  @override
  String get heroAppearanceHelpIntro =>
      'בשורות: − ו־+ משנים. הריבועים מראים רקע ושכבה. הסתכלו על התצוגה למעלה.';

  @override
  String get heroAppearancePreviewBackgroundLabel => 'רקע';

  @override
  String get heroAppearancePreviewOverlayLabel => 'שכבה';

  @override
  String get heroAppearanceHueRow => 'גוון';

  @override
  String get heroAppearanceSatRow => 'רוויה';

  @override
  String get heroAppearanceBriRow => 'בהירות';

  @override
  String get heroAppearanceHueExplain => 'לאורך הקשת';

  @override
  String get heroAppearanceSatExplain => 'חלש ↔ חזק';

  @override
  String get heroAppearanceBriExplain => 'כהה ↔ בהיר';

  @override
  String get heroAppearanceFrameBanner => 'מסגרת לטלוויזיה';

  @override
  String get heroAppearanceFrameExplain =>
      'מסגרת סביב תצוגת הטלוויזיה הקטנה. הפעלה, עובי וגימור.';

  @override
  String appearancePerRowSubtitle(int count) {
    return '$count/שורה';
  }

  @override
  String get appearanceChannelCardStyle => 'סגנון כרטיס ערוץ';

  @override
  String get appearanceMovieCardStyle => 'סגנון כרטיס סרט';

  @override
  String get appearanceSeriesCardStyle => 'סגנון כרטיס סדרה';

  @override
  String get cardStyleLiveNameOnly => 'שם בלבד';

  @override
  String get cardStyleLiveLogoNameProgram => 'לוגו + שם + תוכנית';

  @override
  String get cardStyleLiveLogoNameOnly => 'לוגו + שם';

  @override
  String get cardStyleLiveLogoOnly => 'לוגו בלבד';

  @override
  String get movieGridSettingsTitle => 'הגדרות רשת סרטים';

  @override
  String get movieGridMoviesPerRow => 'סרטים בשורה:';

  @override
  String get movieGridPosterDisplay => 'תצוגת פוסטר:';

  @override
  String get movieGridExit => 'יציאה';

  @override
  String get movieGridResetDefaults => 'איפוס לברירת מחדל';

  @override
  String get movieGridHidePanel => 'הסתר';

  @override
  String get movieGridShowPanel => 'הצג';

  @override
  String get seriesGridSettingsTitle => 'הגדרות רשת סדרות';

  @override
  String get seriesGridSeriesPerRow => 'סדרות בשורה:';

  @override
  String get channelGridSettingsTitle => 'הגדרות רשת ערוצים';

  @override
  String get channelGridHeroBannerSize => 'גודל באנר הירו:';

  @override
  String get channelGridChannelsPerRowLabel => 'ערוצים בשורה:';

  @override
  String get channelGridChannelDisplay => 'תצוגת ערוץ:';

  @override
  String get channelGridChNamePosition => 'מיקום שם ערוץ:';

  @override
  String get channelGridShowSettingsPanel => 'הצג הגדרות';

  @override
  String get cardStylePosterTitle => 'פוסטר+שם+שנה';

  @override
  String get cardStylePosterOnly => 'פוסטר בלבד';

  @override
  String get cardStyleNamePoster => 'שם+פוסטר';

  @override
  String get cardStyleTitleOnly => 'כותרת בלבד';

  @override
  String get catalogLoading => 'טוען…';

  @override
  String get catalogLoadingChannels => 'טוען ערוצים…';

  @override
  String get catalogLoadingLibrary => 'טוען ספרייה…';

  @override
  String get catalogPreparing => 'מכין…';

  @override
  String get catalogErrorPlaylist => 'לא ניתן לטעון את הפלייליסט';

  @override
  String get catalogErrorLibrary => 'לא ניתן לטעון את הספרייה';

  @override
  String get catalogNoCategories => 'אין קטגוריות';

  @override
  String get catalogNoCategoriesSubtitle => 'הפלייליסט לא החזיר קטגוריות חיות.';

  @override
  String get myPlaylistsTitle => 'הפלייליסטים שלי';

  @override
  String get myPlaylistsSubtitle => 'פלייליסט אחד פעיל בכל פעם.';

  @override
  String get myPlaylistsEmpty => 'אין עדיין פלייליסטים. הוסף מההגדרות.';

  @override
  String get dialogRenamePlaylist => 'שינוי שם פלייליסט';

  @override
  String get dialogEditPlaylist => 'עריכת פלייליסט';

  @override
  String get dialogPlaylistServerUrl => 'כתובת שרת';

  @override
  String get dialogPlaylistUsername => 'שם משתמש';

  @override
  String get dialogPlaylistPassword => 'סיסמה';

  @override
  String get dialogPlaylistM3uUrl => 'כתובת M3U';

  @override
  String get dialogPlaylistEditInvalid => 'מלאו את כל השדות הנדרשים.';

  @override
  String get dialogPlaylistNameHint => 'שם';

  @override
  String get dialogCancel => 'ביטול';

  @override
  String get dialogSave => 'שמירה';

  @override
  String get dialogDelete => 'מחיקה';

  @override
  String get dialogDeletePlaylistTitle => 'למחוק פלייליסט?';

  @override
  String dialogDeletePlaylistBody(String name) {
    return '\"$name\" יוסר מהמכשיר.';
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
  String get playlistActiveBadge => 'פעיל';

  @override
  String get playlistSubscriptionActive => 'פעיל';

  @override
  String get playlistSubscriptionExpired => 'פג תוקף';

  @override
  String playlistExpireOn(String date) {
    return 'תוקף עד $date';
  }

  @override
  String get playlistChipGroups => 'קבוצות';

  @override
  String get playlistChipManageChannels => 'ניהול ערוצים';

  @override
  String get manageLiveChannelsTitle => 'ניהול ערוצים';

  @override
  String get manageLiveChannelsSubtitle =>
      'בחרו קטגוריה, ואז שנה שם, הסתר מטלוויזיה חיה או הגדר לוגו מותאם.';

  @override
  String get manageLiveChannelsNeedActive => 'החליפו לפלייליסט הזה תחילה.';

  @override
  String get manageLiveChannelsNoCategories =>
      'אין קטגוריות שידור. סנכרנו את הפלייליסט.';

  @override
  String get manageLiveChannelsCategoryEmpty => 'אין ערוצים בקטגוריה זו.';

  @override
  String get channelOverrideNameAction => 'שם';

  @override
  String get channelOverrideLogoAction => 'לוגו';

  @override
  String get channelOverrideHiddenFromLive => 'מוסתר בטלוויזיה חיה';

  @override
  String get channelOverrideVisibleInLive => 'מוצג בטלוויזיה חיה';

  @override
  String get channelOverrideDisplayNameDialogTitle => 'שם תצוגה';

  @override
  String get channelOverrideDisplayNameHint => 'השאירו ריק לשם מהשרת.';

  @override
  String get channelOverrideLogoDialogTitle => 'כתובת לוגו מותאמת';

  @override
  String get channelOverrideLogoDialogHint =>
      'הדביקו קישור https:// לתמונת PNG או JPG. ריק = לוגו מהפלייליסט.';

  @override
  String get playlistGroupEdit => 'עריכה';

  @override
  String playlistGroupOriginalLabel(String name) {
    return 'מקורי: $name';
  }

  @override
  String get playlistGroupCustomNameHint => 'שם מותאם';

  @override
  String get playlistGroupResetAlias => 'איפוס';

  @override
  String get playlistGroupPillOrderTitle => 'סדר כפתורי קטגוריה (לייב)';

  @override
  String get playlistGroupPillAfterFavorites => 'אחרי המועדפים שלי';

  @override
  String get playlistGroupPillBeforeFavorites => 'לפני המועדפים שלי';

  @override
  String get playlistGroupPillPositionLabel => 'מיקום (1 = ראשון)';

  @override
  String get playlistGroupPillPositionHint => '1';

  @override
  String get playlistEpgLocal => 'EPG: מקומי';

  @override
  String get playlistEpgOriginal => 'EPG: מקורי';

  @override
  String get playlistEpgTimeScreenTitle => 'זמן EPG';

  @override
  String get playlistEpgTimeScreenHint =>
      'בחרו איך מוצגים זמני התוכניות לרשימה זו.';

  @override
  String get playlistEpgTimeRowLocal => 'מקומי';

  @override
  String get playlistEpgTimeRowLocalSubtitle => 'אזור הזמן של המכשיר';

  @override
  String get playlistEpgTimeRowOriginal => 'מקורי (שרת)';

  @override
  String get playlistEpgTimeRowOriginalSubtitle => 'הזמנים כפי שנשלחו מהספק';

  @override
  String playlistEpgZoneChip(String zone) {
    return 'EPG: $zone';
  }

  @override
  String get playlistChipUse => 'שימוש';

  @override
  String get playlistChipOn => 'פועל';

  @override
  String get playlistChipRename => 'שם';

  @override
  String get playlistChipDelete => 'מחיקה';

  @override
  String get favSetupInfoBanner =>
      'צרו קטגוריות טלוויזיה חיה משלכם. הוסיפו מועדף חדש, תנו שם וסדר (מספרים נמוכים מופיעים ראשונים), ואז בחרו ערוצים — הבחירה הראשונה היא מיקום 1, השנייה 2, וכן הלאה. פתחו כרטיס בכל עת לעריכה או מחיקה. המועדפים מופיעים בטלוויזיה חיה ככרטיסיות קטגוריה לצד הפלייליסט, גם אם מסתירים קבוצות מהפלייליסט.';

  @override
  String get favNewFavorite => 'מועדף חדש';

  @override
  String get favCreateGroup => 'יצירת קבוצה';

  @override
  String favGroupSubtitle(int count, int order) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ערוצים',
      one: 'ערוץ אחד',
    );
    return '$_temp0 · סדר $order';
  }

  @override
  String get favEditNew => 'מועדף חדש';

  @override
  String get favEditEdit => 'עריכת מועדף';

  @override
  String get favEditNameLabel => 'שם';

  @override
  String get favEditNameHint => 'מוצג בטלוויזיה חיה כקטגוריה';

  @override
  String get favEditOrderLabel => 'סדר';

  @override
  String get favEditOrderHint => 'נמוך = ראשון במועדפים';

  @override
  String get favEditChooseChannels => 'בחירת ערוצים';

  @override
  String selectedCount(int count) {
    return '$count נבחרו';
  }

  @override
  String get favEditOrderHelp =>
      'סדר: לחיצה ראשונה = 1, שנייה = 2… השתמשו ב״הכל בקטגוריה״ / ״נקה קטגוריה״ בבוחר.';

  @override
  String get favEditChannelsHeading => 'ערוצים במועדף זה';

  @override
  String get favEditNoChannels => 'אין עדיין ערוצים.\nלחצו על בחירת ערוצים.';

  @override
  String get favEditSave => 'שמירה';

  @override
  String get favEditDelete => 'מחיקה';

  @override
  String get defaultFavoriteName => 'מועדף';

  @override
  String get favPickNoXtream => 'אין פלייליסט Xtream';

  @override
  String get favPickNoXtreamSubtitle =>
      'הוסיפו פלייליסט Xtream Codes ב״הפלייליסטים שלי״ כדי לבחור ערוצים מכל לוח שמור.';

  @override
  String get favPickHelpWithPlaylist =>
      'פלייליסט → קטגוריה → רשת. שמירה למטה. חזרה → שמירה.';

  @override
  String get favPickHelpOrderBadges => 'בחירות למעלה (1,2,3…). חזרה → שמירה.';

  @override
  String get favPickHelpSimple => 'בחירות למעלה. חזרה → שמירה.';

  @override
  String get favPickInFavorite => 'במועדף זה';

  @override
  String get favPickNoChannelsDraft => 'אין עדיין ערוצים — בחרו מהרשת למטה.';

  @override
  String get favPickChannelUnavailable => 'הערוץ לא זמין';

  @override
  String get favPickAddMore => 'הוספת ערוצים';

  @override
  String get favPickNoChannelsCategory => 'אין ערוצים בקטגוריה זו.';

  @override
  String get favPickAllInCategory => 'הכל בקטגוריה';

  @override
  String get favPickClearCategory => 'נקה קטגוריה';

  @override
  String get commonSave => 'שמירה';

  @override
  String get commonCancel => 'ביטול';

  @override
  String get backupInfoBanner =>
      'אישי כולל סיסמאות (שמרו פרטי). שיתוף מסיר סיסמאות (בטוח לשליחה).';

  @override
  String get backupExportPersonal => 'ייצוא אישי';

  @override
  String get backupExportPersonalSub => 'גיבוי מלא עם סיסמאות';

  @override
  String get backupExportShare => 'ייצוא לשיתוף';

  @override
  String get backupExportShareSub => 'סיסמאות הוסרו';

  @override
  String get backupShareLastExport => 'שיתוף הייצוא האחרון';

  @override
  String get backupShareLastExportSub => 'שליחת הקובץ ששמרתם עכשיו';

  @override
  String get backupShareLatest => 'שיתוף האחרון';

  @override
  String get backupShareLatestSub => 'דוא״ל, Drive וכו׳';

  @override
  String get backupImportNavigate => 'ייבוא גיבוי';

  @override
  String get backupImportNavigateSub => 'שחזור מקובץ';

  @override
  String get backupDeleteNavigate => 'מחיקת גיבויים';

  @override
  String get backupDeleteNavigateSub => 'הסרת קבצים ישנים';

  @override
  String get backupToastStorageRequired =>
      'נדרשת הרשאת אחסון כדי לשמור גיבויים.';

  @override
  String backupToastSavedDownloads(String name) {
    return 'נשמר בהורדות: $name';
  }

  @override
  String backupToastExportFailed(String error) {
    return 'הייצוא נכשל: $error';
  }

  @override
  String get backupShareSubject => 'גיבוי TVMate Pro';

  @override
  String get backupShareBody => 'גיבוי הגדרות TVMate Pro';

  @override
  String get backupToastNoBackupsToShare => 'לא נמצאו קבצי גיבוי. ייצאו קודם.';

  @override
  String backupToastShareFailed(String error) {
    return 'השיתוף נכשל: $error';
  }

  @override
  String get backupImportRestoredToast => 'הגיבוי שוחזר. הקטלוגים מתעדכנים.';

  @override
  String get nsMessageBackupAppliedTitle => 'הגיבוי הוחל';

  @override
  String get nsMessageErrorTitle => 'משהו השתבש';

  @override
  String get nsMessageDismiss => 'סגור';

  @override
  String backupImportFailedToast(String error) {
    return 'הייבוא נכשל: $error';
  }

  @override
  String get backupImportTitle => 'ייבוא גיבוי';

  @override
  String get backupImportScanSubtitle =>
      'סורק את כל תיקיית ההורדות לקבצי tvmate-backup';

  @override
  String get backupImportRefresh => 'רענון';

  @override
  String get backupImportRestoring => 'משחזר גיבוי…';

  @override
  String get backupImportEmpty => 'לא נמצאו קבצי גיבוי בהורדות.';

  @override
  String get backupManageTitle => 'מחיקת גיבויים';

  @override
  String get backupManageSelectAll => 'בחר הכל';

  @override
  String get backupManageClearAll => 'נקה בחירה';

  @override
  String get backupManageDelete => 'מחק';

  @override
  String backupManageDeleteCount(int count) {
    return 'מחק ($count)';
  }

  @override
  String get backupManageDeleteConfirmTitle => 'למחוק גיבויים?';

  @override
  String backupManageDeleteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count קבצים יוסרו מההורדות.',
      one: 'קובץ אחד יוסר מההורדות.',
    );
    return '$_temp0';
  }

  @override
  String get backupManageToastRemoved => 'הגיבויים שנבחרו הוסרו.';

  @override
  String get backupManageEmpty => 'לא נמצאו קבצי גיבוי.';

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
  String get subtitleAppearanceLabelSubtitleBackground => 'רקע כתוביות:';

  @override
  String get subtitleAppearanceLabelTransparency => 'שקיפות:';

  @override
  String get subtitleAppearancePreviewLine => 'כך ייראו הכתוביות';

  @override
  String get subtitleAppearanceVodPanelTitle => 'עריכת כתוביות';

  @override
  String get subtitleAppearancePositionShort => 'מיקום';

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
  String get parentalUnlocked => 'בוטל הנעילה.';

  @override
  String get parentalUnlockThisChannel => 'בטל נעילת ערוץ זה';

  @override
  String get parentalUnlockCategoryOrGroup => 'בטל נעילת קטגוריה או קבוצה זו';

  @override
  String get parentalUnlockThisMovie => 'בטל נעילת סרט זה';

  @override
  String get parentalUnlockMovieCategory => 'בטל נעילת קטגוריית סרטים זו';

  @override
  String get parentalUnlockThisShow => 'בטל נעילת סדרה זו';

  @override
  String get parentalUnlockSeriesCategory => 'בטל נעילת קטגוריית סדרות זו';

  @override
  String get parentalPlayerParental => 'Parental';

  @override
  String get playerEpgPanelLabel => 'לוח שידורים';

  @override
  String get playerRightPanelQuality => 'איכות';

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
  String get playerEpgOverlayTitle => 'מדריך הערוץ';

  @override
  String get playerEpgOverlaySchedule => 'הבאים';

  @override
  String get playerEpgOverlayLoading => 'טוען לוח שידורים…';

  @override
  String get playerEpgOverlayEmpty => 'אין מידע על תוכניות לערוץ זה.';

  @override
  String get playerEpgNowBadge => 'עכשיו';

  @override
  String get playerEpgLiveRightNow => 'שידור חי עכשיו';

  @override
  String get playerEpgDayToday => 'היום';

  @override
  String get playerEpgDayTomorrow => 'מחר';

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
