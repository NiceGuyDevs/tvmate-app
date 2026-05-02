// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsTopMenuManager => 'القائمة العلوية';

  @override
  String get settingsTopMenuManagerSubtitle =>
      'إعادة ترتيب وإضافة وبدء التشغيل';

  @override
  String get settingsShellThemeSubtitle => 'الفريق المظهري وألوان التمييز';

  @override
  String get settingsShellPlaylistSubtitle => 'تبديل القائمة النشطة';

  @override
  String get settingsAddPlaylist => 'إضافة قائمة';

  @override
  String get settingsAddPlaylistSubtitle => 'Xtream أو M3U';

  @override
  String get settingsMyPlaylists => 'قوائمي';

  @override
  String settingsMyPlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قائمة',
      many: '$count قائمة',
      few: '$count قوائم',
      two: 'قائمتان',
      one: 'قائمة واحدة',
      zero: 'لا قوائم',
    );
    return '$_temp0';
  }

  @override
  String get settingsFavoriteSetup => 'المفضلة';

  @override
  String get settingsFavoriteSetupSubtitle => 'قنوات التلفزيون المفضلة';

  @override
  String get settingsClock => 'الساعة';

  @override
  String get settingsClockOn => 'تشغيل';

  @override
  String get settingsClockOff => 'إيقاف';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String settingsAppearanceSubtitle(int heroPercent, int columns) {
    return 'المقدمة $heroPercent% · $columns في الصف';
  }

  @override
  String get settingsRecordingEdit => 'تعديل الإعادات';

  @override
  String get settingsRecordingEditSubtitle => 'إعداد الأرشيف';

  @override
  String get catchupSelectPlaylistHelp =>
      'اختر قائمة لضبط قنوات التأخير/الأرشيف';

  @override
  String get catchupNoXtreamPlaylists =>
      'لا توجد قوائم Xtream.\nأضف قائمة من هذا النوع أولاً.';

  @override
  String get catchupBreadcrumbCategories => 'الإعادات · التصنيفات';

  @override
  String catchupBreadcrumbWithCategory(String categoryName) {
    return 'الإعادات · $categoryName';
  }

  @override
  String get catchupFilterQuickOn => 'مُرشح الإعادات: مفعّل';

  @override
  String get catchupFilterQuickOff => 'مُرشح الإعادات: إيقاف';

  @override
  String get catchupEmptyStateTitle => 'اضبط ميزة التأخير في الإعدادات';

  @override
  String catchupEmptyStateBody(String entryLabel) {
    return 'اذهب إلى الإعدادات → $entryLabel للموافقة على\nالتصنيفات والقنوات.';
  }

  @override
  String get catchupXtreamOnly => 'ميزة التأخير متاحة فقط لقوائم Xtream.';

  @override
  String get catchupManage => 'إدارة التأخير';

  @override
  String get catchupGroupOptions => 'خيارات التأخير';

  @override
  String get catchupGroupCategories => 'التصنيفات';

  @override
  String get catchupSelectAll => 'تحديد الكل';

  @override
  String get catchupClearAll => 'مسح الكل';

  @override
  String catchupFilterSub(String tabName) {
    return 'يعرض فقط القنوات التي يُعلن مصدرها عن دعم الأرشيف. يخفي الباقي في تبويب $tabName لهذه القائمة.';
  }

  @override
  String get catchupClearConfirmTitle => 'هل تريد مسح كل الموافقات؟';

  @override
  String catchupClearConfirmMessage(String playlistName) {
    return 'يُزال كل التصنيفات والقنوات المعتمدة من قائمة «$playlistName» للتأخير. القائمة نفسها لا تُحذف.';
  }

  @override
  String get catchupFilterBannerLead => 'مُرشح التأخير مفعّل. ';

  @override
  String catchupFilterHiddenMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قناة بلا أرشيف مخفية في هذه القائمة.',
      one: 'قناة واحدة بلا أرشيف مُخفاة في هذه القائمة.',
    );
    return '$_temp0 عطّل المُرشح في خيارات التأخير لاعتمادها.';
  }

  @override
  String get catchupNoChannelsInCategory => 'لا توجد قنوات في هذا التصنيف.';

  @override
  String get catchupNoLiveCategoriesSync =>
      'لا توجد تصنيفات مباشرة.\nزامِن هذه القائمة أولاً.';

  @override
  String get settingsBackup => 'النسخ الاحتياطي';

  @override
  String get settingsBackupSubtitle => 'تصدير / استيراد الإعدادات';

  @override
  String get settingsDemoMode => 'وضع تجريبي';

  @override
  String get settingsDemoModeSubtitleBrowseDemo => 'تصفح تجريبي حتى تضيف قائمة';

  @override
  String get settingsDemoModeSubtitleRealChannels =>
      'قنوات حقيقية — التجريبي متوقف عند وجود قوائم';

  @override
  String get settingsDemoModeAbout =>
      'وضع تجريبي مدمج: عينات تلفزيون مباشر وأفلام ومسلسلات مع صور مدمجة وقوائم وهمية. التشغيل عبر بث تجريبي. أضف قائمة Xtream أو M3U لاستخدام IPTV الحقيقي.';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageSubtitle => 'لغة الواجهة';

  @override
  String get settingsPerformance => 'الأداء';

  @override
  String get settingsPerformanceSubtitle =>
      'جودة كاملة أو مُحسّن للأجهزة الأضعف';

  @override
  String get performanceScreenTitle => 'الأداء';

  @override
  String get performanceScreenIntro =>
      'اختر حجم الضغط على الجهاز. الأجهزة القوية (مثل NVIDIA Shield) يمكنها الجودة الكاملة. الأجهزة الصغيرة غالباً تكون أسلس في الوضع المُحسّن. التلقائي يعتمد على ذاكرة الجهاز. يمكنك التغيير في أي وقت.';

  @override
  String get performanceModeAuto => 'تلقائي';

  @override
  String get performanceModeAutoSubtitle => 'موصى به — يختار حسب الذاكرة';

  @override
  String get performanceModeFull => 'جودة كاملة';

  @override
  String get performanceModeFullSubtitle => 'أفضل مظهر — أجهزة قوية';

  @override
  String get performanceModeOptimized => 'مُحسّن';

  @override
  String get performanceModeOptimizedSubtitle =>
      'خلفية أخف وذاكرة أصغر ومزامنة مؤجلة. مشغّل فيديو واحد في كل لحظة (معاينة الشبكة تتوقف أثناء ملء الشاشة) — أكثر سلاسة على التلفزيونات الضعيفة';

  @override
  String performanceDetectedRam(String mb) {
    return 'إجمالي الذاكرة المكتشفة: $mb ميجابايت';
  }

  @override
  String get performanceDetectedRamUnknown =>
      'لم يُكتشف الذاكرة — التلقائي يستخدم الجودة الكاملة';

  @override
  String get performanceAutoCurrentlyUsingFull =>
      'حاليًا، التلقائي يستخدم الجودة الكاملة.';

  @override
  String get performanceAutoCurrentlyUsingOptimized =>
      'حاليًا، التلقائي يستخدم الوضع المحسّن.';

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
  String get tvRemoteTypingButton => 'الكتابة بجهاز التحكم';

  @override
  String get tvRemoteTypingTitle => 'إدخال النص';

  @override
  String get tvRemoteTypingDone => 'تم';

  @override
  String get tvRemoteGoogleTvKeyboardHint =>
      'قد لا تُفتح لوحة المفاتيح على Google TV أو Chromecast. استخدم السطر أعلاه للكتابة بالجهاز.';

  @override
  String get tvKeyboardLanguagesTitle => 'اللغات';

  @override
  String get tvKeyboardPickLanguagesSubtitle =>
      'حدد اللغات التي تظهر في القائمة (أعلى أو الكرة الأرضية). الترتيب يتبع ترتيب إضافتها.';

  @override
  String get tvKeyboardLayoutNotAvailable =>
      'لوحة المفاتيح على الشاشة غير متوفرة لهذه اللغة بعد.';

  @override
  String get languageScreenTitle => 'اللغة';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageHebrew => 'العبرية';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get languageSpanish => 'الإسبانية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageRussian => 'الروسية';

  @override
  String get languageGerman => 'الألمانية';

  @override
  String get languagePortuguese => 'البرتغالية';

  @override
  String get languageItalian => 'الإيطالية';

  @override
  String get languageTurkish => 'التركية';

  @override
  String get languageHindi => 'الهندية';

  @override
  String get languageJapanese => 'اليابانية';

  @override
  String get languageKorean => 'الكورية';

  @override
  String get languageChinese => 'الصينية';

  @override
  String get languageVietnamese => 'الفيتنامية';

  @override
  String get actionPlay => 'تشغيل';

  @override
  String get actionExternal => 'خارجي';

  @override
  String get actionTrailer => 'المقطع الدعائي';

  @override
  String get actionMyList => 'قائمتي';

  @override
  String get actionRemove => 'إزالة';

  @override
  String get actionWatched => 'مُشاهَد';

  @override
  String get actionUnwatch => 'إلغاء المشاهدة';

  @override
  String get actionWatching => 'مشاهدة';

  @override
  String get actionWatchingOff => 'إيقاف';

  @override
  String get actionContinueWatching => 'متابعة';

  @override
  String get actionContinueWatchingOff => 'مسح';

  @override
  String get navLiveTv => 'بث مباشر';

  @override
  String get navMovies => 'أفلام';

  @override
  String get navSeries => 'مسلسلات';

  @override
  String get navRecording => 'إعادات';

  @override
  String get navPlaylist => 'قائمة تشغيل';

  @override
  String get navTheme => 'سِمَة';

  @override
  String get navClock => 'ساعة';

  @override
  String get navAppearance => 'المظهر';

  @override
  String get navBackup => 'نسخ احتياطي';

  @override
  String get navFavorites => 'المفضلة';

  @override
  String get navLanguage => 'اللغة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get nsCategoryOldSettings => 'الإعدادات القديمة';

  @override
  String get searchMoviesAndSeries => 'بحث الأفلام والمسلسلات';

  @override
  String get searchLiveTv => 'بحث البث المباشر';

  @override
  String get searchRecording => 'بحث الإعادات';

  @override
  String get searchHint => 'اكتب لتصفية هذه الصفحة';

  @override
  String get searchClear => 'مسح';

  @override
  String get searchApply => 'تطبيق';

  @override
  String get searchLabel => 'بحث';

  @override
  String searchPrefixWithQuery(String query) {
    return 'بحث: $query';
  }

  @override
  String get playlistEmptyTitle => 'لا قوائم بعد';

  @override
  String get playlistEmptySubtitle => 'أضف من الإعدادات';

  @override
  String get playlistGoToSettings => 'الذهاب إلى الإعدادات';

  @override
  String get playlistDismissBarrier => 'إغلاق مبدّل القائمة';

  @override
  String playlistStatsLine(int liveCount, int movieCount, int seriesCount) {
    return '$liveCount مباشر · $movieCount أفلام · $seriesCount مسلسلات';
  }

  @override
  String get topMenuManagerTitle => 'مدير القائمة العلوية';

  @override
  String get topMenuOrderSection => 'ترتيب القائمة';

  @override
  String get topMenuReorderHelp =>
      'موافق للإمساك، ثم أعلى/أسفل للنقل، موافق للإفلات.';

  @override
  String get topMenuRemoveHelp =>
      'تبويبات اختيارية: يمين لإزالتها من الشريط (موافق للإمساك/الإفلات فقط).';

  @override
  String get topMenuAddToMenu => 'إضافة إلى القائمة';

  @override
  String get topMenuStartupSection => 'فئة البدء';

  @override
  String get topMenuStartupHelp => 'الشاشة عند فتح التطبيق.';

  @override
  String get topMenuSettingsLocked => 'الإعدادات';

  @override
  String get topMenuAlwaysLast => 'دائمًا الأخير';

  @override
  String get commonBack => 'رجوع';

  @override
  String get mvPickerAddChannel => 'إضافة قناة';

  @override
  String get mvPickerChangeChannel => 'تغيير القناة';

  @override
  String get mvChooseChannel => 'اختر قناة';

  @override
  String get mvAddScreen => 'إضافة شاشة';

  @override
  String get mvChangeChannel => 'تغيير القناة';

  @override
  String get mvReduceScreen => 'تصغير الشاشة';

  @override
  String get mvEnlargeScreen => 'تكبير الشاشة';

  @override
  String get mvFullScreen => 'ملء الشاشة';

  @override
  String get mvRemoveScreen => 'إزالة الشاشة';

  @override
  String get mvExitMultiview => 'خروج من العرض المتعدد';

  @override
  String get mvMenuTitle => 'عرض متعدد';

  @override
  String get mvMenuHint => '▲▼ تحريك · موافق · رجوع';

  @override
  String get demoBlurbLiveTv =>
      'تجريبي تلفزيون مباشر: فئات وشبكة قنوات بشعارات مدمجة. لوحة البطل والتسميات؛ بث تجريبي عند فتح المشغّل.';

  @override
  String get demoBlurbMovies =>
      'تجريبي أفلام: صفوف بملصقات مدمجة وتفاصيل وهمية. ركّز على عنوان لتحديث البطل والملخص.';

  @override
  String get demoBlurbSeries =>
      'تجريبي مسلسلات: ملصقات مدمجة ومواسم وحلقات. نفس تدفق الأفلام؛ بث تجريبي عند التشغيل.';

  @override
  String get demoBlurbRecording => 'تصفح الأرشيف حسب الفئة والتاريخ والقناة.';

  @override
  String get demoBlurbTeam =>
      'اختر Cosmic أو Aurora أو Solar أو Heritage للمظهر.';

  @override
  String get demoBlurbSettings =>
      'مركز إعدادات تجريبي. القائمة والتشغيل لاحقًا.';

  @override
  String get demoBlurbOptional => 'وجهة اختيارية. فعّلها من مدير القائمة.';

  @override
  String get clockInfoBanner =>
      'Optional floating clock on top of the app. Turn it ON or OFF — the top bar always shows the time; this overlay is extra. Choose 12 or 24 hour, size, corner of the screen, brightness (opacity), and color. Frame adds a border and shows the date under the time; turn it off for time only. Use Adjust position to nudge the overlay per corner with the D-pad. Move focus with the remote and Select to apply each option; changes apply everywhere while you use the app.';

  @override
  String get clockToggleOn => 'الساعة تعمل';

  @override
  String get clockToggleOff => 'الساعة متوقفة';

  @override
  String get clockTapHide => 'اضغط للإخفاء';

  @override
  String get clockTapShow => 'اضغط للإظهار';

  @override
  String get clockFrameOn => 'الإطار يعمل';

  @override
  String get clockFrameOff => 'الإطار متوقف';

  @override
  String get clockFrameSubOn => 'حدود + تاريخ تحت الوقت';

  @override
  String get clockFrameSubOff => 'الوقت فقط (بدون حدود وتاريخ)';

  @override
  String get clock12Hour => '12 ساعة';

  @override
  String get clock12HourSub => 'ص/م';

  @override
  String get clock24Hour => '24 ساعة';

  @override
  String get clock24HourSub => '00–23';

  @override
  String get clockSizeSmall => 'صغير';

  @override
  String get clockSizeMedium => 'متوسط';

  @override
  String get clockSizeLarge => 'كبير';

  @override
  String get clockSizeSubtitle => 'الحجم';

  @override
  String get clockCornerSubtitle => 'الزاوية';

  @override
  String get clockCornerTopLeft => 'أعلى اليسار';

  @override
  String get clockCornerTopRight => 'أعلى اليمين';

  @override
  String get clockCornerBottomLeft => 'أسفل اليسار';

  @override
  String get clockCornerBottomRight => 'أسفل اليمين';

  @override
  String get clockAdjustPosition => 'ضبط الموضع';

  @override
  String get clockAdjustPositionSub => 'الأسهم تحرّك · الرجوع يحفظ';

  @override
  String get clockOpacitySubtitle => 'الشفافية';

  @override
  String clockOpacityPercent(int percent) {
    return '$percent٪';
  }

  @override
  String clockColorPreset(int index) {
    return 'لون $index';
  }

  @override
  String get clockColorPresetSubtitle => 'جاهز';

  @override
  String get clockPositionAdjustTitle => 'ضبط الموضع';

  @override
  String clockPositionCornerLine(String corner) {
    return 'الزاوية: $corner';
  }

  @override
  String clockPositionOffsetLine(int dx, int dy, int max) {
    return 'الإزاحة: $dx × $dy (حد أقصى ±$max)';
  }

  @override
  String get clockPositionHelpEnabled =>
      'استخدم لوحة الاتجاهات لتحريك الساعة على الشاشة. التغييرات لهذه الزاوية فقط. الرجوع يعود إلى إعدادات الساعة.';

  @override
  String get clockPositionHelpDisabled =>
      'شغّل الساعة لرؤية الطبقة أثناء الضبط. تُحفظ الإزاحات لكل زاوية.';

  @override
  String get appearanceLayoutEditors => 'محررات التخطيط';

  @override
  String get appearanceHeroBackgroundTitle => 'خلفية البطل';

  @override
  String get appearanceHeroBackgroundSubtitle => 'الألوان خلف معاينة التلفزيون';

  @override
  String get heroAppearanceScreenTitle => 'خلفية البطل';

  @override
  String get heroAppearanceHint =>
      'يُحفظ تلقائياً. الإعادة تستعيد المظهر الافتراضي للسمة.';

  @override
  String get heroAppearanceReset => 'إعادة للافتراضي';

  @override
  String get heroAppearanceHideControls => 'إخفاء عناصر التحكم';

  @override
  String get heroAppearanceShowControls => 'إظهار عناصر التحكم';

  @override
  String get heroAppearanceBase => 'لون الأساس';

  @override
  String get heroAppearanceWash => 'لون الفرشاة';

  @override
  String get heroAppearanceIntensity => 'قوة الفرشاة';

  @override
  String get heroAppearanceBrushStyle => 'نمط الفرشاة';

  @override
  String get heroAppearanceSectionBackground => 'الخلفية';

  @override
  String get heroAppearanceSectionTv => 'إطار المعاينة';

  @override
  String get heroAppearanceSectionFineTune => 'ضبط دقيق';

  @override
  String get heroAppearanceShowFrame => 'إظهار إطار التلفزيون';

  @override
  String get heroAppearanceFrameProfile => 'شكل الإطار';

  @override
  String get heroAppearanceBezelFinish => 'لمسة الإطار';

  @override
  String get heroAppearanceGradientDepth => 'عمق التدرج';

  @override
  String get heroAppearanceFrameSlim => 'رفيع';

  @override
  String get heroAppearanceFrameClassic => 'كلاسيكي';

  @override
  String get heroAppearanceFrameBold => 'سميك';

  @override
  String get heroAppearanceFrameMinimal => 'بسيط';

  @override
  String get heroAppearanceOn => 'تشغيل';

  @override
  String get heroAppearanceOff => 'إيقاف';

  @override
  String get heroAppearanceTabColors => 'ألوان';

  @override
  String get heroAppearanceTabOverlay => 'طبقة';

  @override
  String get heroAppearanceTabFrame => 'إطار';

  @override
  String get heroAppearanceTabMore => 'المزيد';

  @override
  String get heroAppearanceWashModeBrush => 'فرشاة';

  @override
  String get heroAppearanceWashModeSolid => 'متجانس';

  @override
  String get heroAppearanceHintShort => 'يُحفظ تلقائياً.';

  @override
  String get heroAppearanceSolidHint =>
      'لون يغطي كامل الخلفية — القوة في تبويب الطبقة.';

  @override
  String get heroAppearanceHelpIntro =>
      'استخدم − و + في كل صف. المربعات تعرض الخلفية والطبقة. انظر معاينة التلفزيون أعلاه.';

  @override
  String get heroAppearancePreviewBackgroundLabel => 'الخلفية';

  @override
  String get heroAppearancePreviewOverlayLabel => 'الطبقة';

  @override
  String get heroAppearanceHueRow => 'الدرجة';

  @override
  String get heroAppearanceSatRow => 'التشبع';

  @override
  String get heroAppearanceBriRow => 'السطوع';

  @override
  String get heroAppearanceHueExplain => 'حول قوس الألوان';

  @override
  String get heroAppearanceSatExplain => 'باهت ↔ قوي';

  @override
  String get heroAppearanceBriExplain => 'داكن ↔ فاتح';

  @override
  String get heroAppearanceFrameBanner => 'إطار التلفزيون';

  @override
  String get heroAppearanceFrameExplain =>
      'حدود حول معاينة الشاشة الصغيرة. شغّل، ثم السُمك واللمسة.';

  @override
  String appearancePerRowSubtitle(int count) {
    return '$count/صف';
  }

  @override
  String get appearanceChannelCardStyle => 'نمط بطاقة القناة';

  @override
  String get appearanceMovieCardStyle => 'نمط بطاقة الفيلم';

  @override
  String get appearanceSeriesCardStyle => 'نمط بطاقة المسلسل';

  @override
  String get cardStyleLiveNameOnly => 'الاسم فقط';

  @override
  String get cardStyleLiveLogoNameProgram => 'شعار + اسم + برنامج';

  @override
  String get cardStyleLiveLogoNameOnly => 'شعار + اسم';

  @override
  String get cardStyleLiveLogoOnly => 'شعار فقط';

  @override
  String get movieGridSettingsTitle => 'إعدادات شبكة الأفلام';

  @override
  String get movieGridMoviesPerRow => 'أفلام لكل صف:';

  @override
  String get movieGridPosterDisplay => 'عرض الملصق:';

  @override
  String get movieGridExit => 'خروج';

  @override
  String get movieGridResetDefaults => 'إعادة الافتراضي';

  @override
  String get movieGridHidePanel => 'إخفاء';

  @override
  String get movieGridShowPanel => 'عرض';

  @override
  String get seriesGridSettingsTitle => 'إعدادات شبكة المسلسلات';

  @override
  String get seriesGridSeriesPerRow => 'مسلسلات لكل صف:';

  @override
  String get channelGridSettingsTitle => 'إعدادات شبكة القنوات';

  @override
  String get channelGridHeroBannerSize => 'حجم الشريط البطولي:';

  @override
  String get channelGridChannelsPerRowLabel => 'قنوات في الصف:';

  @override
  String get channelGridChannelDisplay => 'عرض القناة:';

  @override
  String get channelGridChNamePosition => 'موضع اسم القناة:';

  @override
  String get channelGridShowSettingsPanel => 'إظهار الإعدادات';

  @override
  String get cardStylePosterTitle => 'ملصق+اسم+سنة';

  @override
  String get cardStylePosterOnly => 'ملصق فقط';

  @override
  String get cardStyleNamePoster => 'اسم+ملصق';

  @override
  String get cardStyleTitleOnly => 'عنوان فقط';

  @override
  String get catalogLoading => 'جارٍ التحميل…';

  @override
  String get catalogLoadingChannels => 'جارٍ تحميل القنوات…';

  @override
  String get catalogLoadingLibrary => 'جارٍ تحميل المكتبة…';

  @override
  String get catalogPreparing => 'جارٍ التحضير…';

  @override
  String get catalogErrorPlaylist => 'تعذّر تحميل القائمة';

  @override
  String get catalogErrorLibrary => 'تعذّر تحميل المكتبة';

  @override
  String get catalogNoCategories => 'لا فئات';

  @override
  String get catalogNoCategoriesSubtitle =>
      'لم تُرجع هذه القائمة فئات بث مباشر.';

  @override
  String get myPlaylistsTitle => 'قوائمي';

  @override
  String get myPlaylistsSubtitle => 'قائمة واحدة نشطة في كل مرة.';

  @override
  String get myPlaylistsEmpty => 'لا قوائم بعد. أضف من الإعدادات.';

  @override
  String get dialogRenamePlaylist => 'إعادة تسمية القائمة';

  @override
  String get dialogEditPlaylist => 'تعديل القائمة';

  @override
  String get dialogPlaylistServerUrl => 'عنوان الخادم';

  @override
  String get dialogPlaylistUsername => 'اسم المستخدم';

  @override
  String get dialogPlaylistPassword => 'كلمة المرور';

  @override
  String get dialogPlaylistM3uUrl => 'عنوان M3U';

  @override
  String get dialogPlaylistEditInvalid => 'املأ جميع الحقول المطلوبة.';

  @override
  String get dialogPlaylistNameHint => 'الاسم';

  @override
  String get dialogCancel => 'إلغاء';

  @override
  String get dialogSave => 'حفظ';

  @override
  String get dialogDelete => 'حذف';

  @override
  String get dialogDeletePlaylistTitle => 'حذف القائمة؟';

  @override
  String dialogDeletePlaylistBody(String name) {
    return 'سيتم إزالة «$name» من هذا الجهاز.';
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
  String get playlistActiveBadge => 'نشط';

  @override
  String get playlistSubscriptionActive => 'نشط';

  @override
  String get playlistSubscriptionExpired => 'منتهي';

  @override
  String playlistExpireOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String get playlistChipGroups => 'المجموعات';

  @override
  String get playlistChipManageChannels => 'إدارة القنوات';

  @override
  String get manageLiveChannelsTitle => 'إدارة القنوات';

  @override
  String get manageLiveChannelsSubtitle =>
      'اختر فئة، ثم غيّر الاسم أو أخفِ من البث المباشر أو عيّن رابط شعار.';

  @override
  String get manageLiveChannelsNeedActive => 'فعّل هذه القائمة أولاً.';

  @override
  String get manageLiveChannelsNoCategories => 'لا توجد فئات بث. زامن القائمة.';

  @override
  String get manageLiveChannelsCategoryEmpty => 'لا قنوات في هذه الفئة.';

  @override
  String get channelOverrideNameAction => 'الاسم';

  @override
  String get channelOverrideLogoAction => 'الشعار';

  @override
  String get channelOverrideHiddenFromLive => 'مخفية من البث المباشر';

  @override
  String get channelOverrideVisibleInLive => 'ظاهرة في البث المباشر';

  @override
  String get channelOverrideDisplayNameDialogTitle => 'اسم العرض';

  @override
  String get channelOverrideDisplayNameHint => 'اتركه فارغًا لاسم الخادم.';

  @override
  String get channelOverrideLogoDialogTitle => 'رابط شعار مخصص';

  @override
  String get channelOverrideLogoDialogHint =>
      'الصق رابط https:// لصورة PNG أو JPG. فارغ = شعار القائمة.';

  @override
  String get playlistGroupEdit => 'تعديل';

  @override
  String playlistGroupOriginalLabel(String name) {
    return 'الأصلي: $name';
  }

  @override
  String get playlistGroupCustomNameHint => 'اسم مخصص';

  @override
  String get playlistGroupResetAlias => 'إعادة';

  @override
  String get playlistGroupPillOrderTitle =>
      'ترتيب أزرار التصنيف (البث المباشر)';

  @override
  String get playlistGroupPillAfterFavorites => 'بعد مفضلاتي';

  @override
  String get playlistGroupPillBeforeFavorites => 'قبل مفضلاتي';

  @override
  String get playlistGroupPillPositionLabel => 'الترتيب (1 = الأيسر)';

  @override
  String get playlistGroupPillPositionHint => '1';

  @override
  String get playlistEpgLocal => 'دليل: محلي';

  @override
  String get playlistEpgOriginal => 'دليل: أصلي';

  @override
  String get playlistEpgTimeScreenTitle => 'وقت الدليل';

  @override
  String get playlistEpgTimeScreenHint =>
      'اختر كيفية عرض أوقات البرامج لهذه القائمة.';

  @override
  String get playlistEpgTimeRowLocal => 'محلي';

  @override
  String get playlistEpgTimeRowLocalSubtitle => 'منطقة زمنية للجهاز';

  @override
  String get playlistEpgTimeRowOriginal => 'أصلي (الخادم)';

  @override
  String get playlistEpgTimeRowOriginalSubtitle => 'الأوقات كما يرسلها المزوّد';

  @override
  String playlistEpgZoneChip(String zone) {
    return 'دليل: $zone';
  }

  @override
  String get playlistChipUse => 'استخدام';

  @override
  String get playlistChipOn => 'تشغيل';

  @override
  String get playlistChipRename => 'تسمية';

  @override
  String get playlistChipDelete => 'حذف';

  @override
  String get favSetupInfoBanner =>
      'أنشئ فئات التلفزيون المباشر الخاصة بك. أضف مفضلة جديدة، وحدد اسماً وترتيباً (الأرقام الأصغر أولاً)، ثم اختر القنوات — الاختيار الأول هو الموضع 1، الثاني 2، وهكذا. افتح البطاقة في أي وقت للتعديل أو الحذف. تظهر مفضلاتك في التلفزيون المباشر كأقراص فئات بجانب قائمتك، حتى إذا أخفيت مجموعات القائمة.';

  @override
  String get favNewFavorite => 'مفضلة جديدة';

  @override
  String get favCreateGroup => 'إنشاء مجموعة';

  @override
  String favGroupSubtitle(int count, int order) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قنوات',
      one: 'قناة واحدة',
    );
    return '$_temp0 · الترتيب $order';
  }

  @override
  String get favEditNew => 'مفضلة جديدة';

  @override
  String get favEditEdit => 'تعديل المفضلة';

  @override
  String get favEditNameLabel => 'الاسم';

  @override
  String get favEditNameHint => 'يُعرض في التلفزيون المباشر كفئة';

  @override
  String get favEditOrderLabel => 'الترتيب';

  @override
  String get favEditOrderHint => 'الأقل = أولاً بين المفضلات';

  @override
  String get favEditChooseChannels => 'اختيار القنوات';

  @override
  String selectedCount(int count) {
    return '$count محددة';
  }

  @override
  String get favEditOrderHelp =>
      'الترتيب: أول ضغطة = 1، الثانية = 2… استخدم «الكل في الفئة» / «مسح الفئة» في المنتقي.';

  @override
  String get favEditChannelsHeading => 'القنوات في هذه المفضلة';

  @override
  String get favEditNoChannels => 'لا قنوات بعد.\nاضغط اختيار القنوات.';

  @override
  String get favEditSave => 'حفظ';

  @override
  String get favEditDelete => 'حذف';

  @override
  String get defaultFavoriteName => 'مفضلة';

  @override
  String get favPickNoXtream => 'لا قائمة Xtream';

  @override
  String get favPickNoXtreamSubtitle =>
      'أضف قائمة Xtream Codes في «قوائمي» لاختيار القنوات من أي لوحة محفوظة.';

  @override
  String get favPickHelpWithPlaylist =>
      'قائمة → فئة → شبكة. حفظ في الأسفل. رجوع → حفظ.';

  @override
  String get favPickHelpOrderBadges =>
      'الاختيارات في الأعلى (1،2،3…). رجوع → حفظ.';

  @override
  String get favPickHelpSimple => 'الاختيارات في الأعلى. رجوع → حفظ.';

  @override
  String get favPickInFavorite => 'في هذه المفضلة';

  @override
  String get favPickNoChannelsDraft => 'لا قنوات بعد — اختر من الشبكة أدناه.';

  @override
  String get favPickChannelUnavailable => 'القناة غير متوفرة';

  @override
  String get favPickAddMore => 'إضافة المزيد';

  @override
  String get favPickNoChannelsCategory => 'لا قنوات في هذه الفئة.';

  @override
  String get favPickAllInCategory => 'الكل في الفئة';

  @override
  String get favPickClearCategory => 'مسح الفئة';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get backupInfoBanner =>
      'الشخصي يتضمن كلمات مرور (أبقه خاصاً). المشاركة تزيل كلمات المرور (آمن للإرسال).';

  @override
  String get backupExportPersonal => 'تصدير شخصي';

  @override
  String get backupExportPersonalSub => 'نسخة كاملة مع كلمات المرور';

  @override
  String get backupExportShare => 'تصدير للمشاركة';

  @override
  String get backupExportShareSub => 'تمت إزالة كلمات المرور';

  @override
  String get backupShareLastExport => 'مشاركة آخر تصدير';

  @override
  String get backupShareLastExportSub => 'إرسال الملف الذي حفظته للتو';

  @override
  String get backupShareLatest => 'مشاركة الأحدث';

  @override
  String get backupShareLatestSub => 'بريد، Drive، إلخ';

  @override
  String get backupImportNavigate => 'استيراد نسخة';

  @override
  String get backupImportNavigateSub => 'استعادة من ملف';

  @override
  String get backupDeleteNavigate => 'حذف النسخ';

  @override
  String get backupDeleteNavigateSub => 'إزالة ملفات قديمة';

  @override
  String get backupToastStorageRequired => 'يلزم إذن التخزين لحفظ النسخ.';

  @override
  String backupToastSavedDownloads(String name) {
    return 'حُفظ في التنزيلات: $name';
  }

  @override
  String backupToastExportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get backupShareSubject => 'نسخة TVMate Pro';

  @override
  String get backupShareBody => 'نسخة إعدادات TVMate Pro';

  @override
  String get backupToastNoBackupsToShare => 'لا ملفات نسخ. صدّر أولاً.';

  @override
  String backupToastShareFailed(String error) {
    return 'فشلت المشاركة: $error';
  }

  @override
  String get backupImportRestoredToast =>
      'تمت استعادة النسخة. جارٍ تحديث الكتالوجات.';

  @override
  String get nsMessageBackupAppliedTitle => 'تم تطبيق النسخة الاحتياطية';

  @override
  String get nsMessageErrorTitle => 'حدث خطأ ما';

  @override
  String get nsMessageDismiss => 'إغلاق';

  @override
  String backupImportFailedToast(String error) {
    return 'فشل الاستيراد: $error';
  }

  @override
  String get backupImportTitle => 'استيراد نسخة';

  @override
  String get backupImportScanSubtitle =>
      'جارٍ فحص مجلد التنزيلات لملفات tvmate-backup';

  @override
  String get backupImportRefresh => 'تحديث';

  @override
  String get backupImportRestoring => 'جارٍ استعادة النسخة…';

  @override
  String get backupImportEmpty => 'لا ملفات نسخ في التنزيلات.';

  @override
  String get backupManageTitle => 'حذف النسخ';

  @override
  String get backupManageSelectAll => 'تحديد الكل';

  @override
  String get backupManageClearAll => 'مسح التحديد';

  @override
  String get backupManageDelete => 'حذف';

  @override
  String backupManageDeleteCount(int count) {
    return 'حذف ($count)';
  }

  @override
  String get backupManageDeleteConfirmTitle => 'حذف النسخ؟';

  @override
  String backupManageDeleteConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيتم حذف $count ملفات من التنزيلات.',
      one: 'سيُحذف ملف واحد من التنزيلات.',
    );
    return '$_temp0';
  }

  @override
  String get backupManageToastRemoved => 'تمت إزالة النسخ المحددة.';

  @override
  String get backupManageEmpty => 'لا ملفات نسخ.';

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
  String get subtitleAppearanceLabelSubtitleBackground => 'خلفية الترجمة:';

  @override
  String get subtitleAppearanceLabelTransparency => 'الشفافية:';

  @override
  String get subtitleAppearancePreviewLine => 'هكذا ستبدو الترجمة';

  @override
  String get subtitleAppearanceVodPanelTitle => 'تحرير الترجمة';

  @override
  String get subtitleAppearancePositionShort => 'الموضع';

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
  String get parentalUnlocked => 'تم إلغاء القفل.';

  @override
  String get parentalUnlockThisChannel => 'إلغاء قفل هذا القناة';

  @override
  String get parentalUnlockCategoryOrGroup => 'إلغاء قفل هذه الفئة أو المجموعة';

  @override
  String get parentalUnlockThisMovie => 'إلغاء قفل هذا الفيلم';

  @override
  String get parentalUnlockMovieCategory => 'إلغاء قفل فئة الأفلام هذه';

  @override
  String get parentalUnlockThisShow => 'إلغاء قفل هذا المسلسل';

  @override
  String get parentalUnlockSeriesCategory => 'إلغاء قفل فئة المسلسلات هذه';

  @override
  String get parentalPlayerParental => 'Parental';

  @override
  String get playerEpgPanelLabel => 'دليل البرامج';

  @override
  String get playerRightPanelQuality => 'الجودة';

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
  String get playerEpgOverlayTitle => 'دليل القناة';

  @override
  String get playerEpgOverlaySchedule => 'القادم';

  @override
  String get playerEpgOverlayLoading => 'جاري تحميل الدليل…';

  @override
  String get playerEpgOverlayEmpty => 'لا توجد معلومات برامج لهذه القناة.';

  @override
  String get playerEpgNowBadge => 'الآن';

  @override
  String get playerEpgLiveRightNow => 'مباشر الآن';

  @override
  String get playerEpgDayToday => 'اليوم';

  @override
  String get playerEpgDayTomorrow => 'غداً';

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
