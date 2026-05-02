import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'app_nav.dart';
import 'data/app_locale_store.dart';
import 'data/performance_tier_store.dart';
import 'data/team_visual_store.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'theme/team_palette.dart';
import 'ui/clock/clock_overlay.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/vod/vod_download_strip.dart';

/// Allows mouse drag scrolling on desktop (Flutter desktop only allows
/// trackpad/touch by default, not mouse-button drag).
class _DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

void _syncImageCacheWithPerformanceTier() {
  final cache = PaintingBinding.instance.imageCache;
  if (performanceTierStore.isOptimizedEffective) {
    cache.maximumSize = 80;
    cache.maximumSizeBytes = 40 << 20;
  } else {
    cache.maximumSize = 1000;
    cache.maximumSizeBytes = 100 << 20;
  }
}

/// Root widget — Android TV (Leanback), D-pad first.
///
/// **Multi-language system:** UI strings are defined per locale in ARB files under
/// `lib/l10n/` (template `app_en.arb`), generated into [AppLocalizations], and bound
/// here via [MaterialApp.locale], [AppLocalizations.supportedLocales], and
/// [AppLocalizations.localizationsDelegates]. The active locale comes from
/// [appLocaleStore] (user-chosen language in Settings).
class TvMateApp extends StatelessWidget {
  const TvMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appLocaleStore,
      builder: (context, _) {
        return MaterialApp(
          title: 'TVMate.Pro',
          debugShowCheckedModeBanner: false,
          navigatorKey: AppNav.rootNavigatorKey,
          scaffoldMessengerKey: AppNav.rootScaffoldMessengerKey,
          scrollBehavior: _DesktopScrollBehavior(),
          // Multi-language: see class doc above; ARB → AppLocalizations → MaterialApp.
          locale: appLocaleStore.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (locale, supported) {
            if (locale == null) return const Locale('en');
            for (final s in supported) {
              if (s.languageCode == locale.languageCode) return s;
            }
            return const Locale('en');
          },
          theme: AppTheme.themeForPalette(TeamPalette.canvasTheme),
          builder: (context, child) {
            return ListenableBuilder(
              listenable:
                  Listenable.merge([teamVisualStore, performanceTierStore]),
              builder: (context, _) {
                _syncImageCacheWithPerformanceTier();
                final palette = teamVisualStore.isLoaded
                    ? teamVisualStore.palette
                    : TeamPalette.canvasTheme;
                return Theme(
                  data: AppTheme.themeForPalette(palette).copyWith(
                    pageTransitionsTheme: const PageTransitionsTheme(
                      builders: {
                        TargetPlatform.android: ZoomPageTransitionsBuilder(),
                        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
                      },
                    ),
                  ),
                  // Hebrew/Arabic locales default to RTL; that mirrors Rows and breaks
                  // Android TV D-pad focus (top bar, ladders). Keep layout/focus LTR;
                  // Text still renders RTL scripts correctly via Unicode bidi.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (child != null) child,
                        const ClockOverlayLayer(),
                        const VodDownloadStripLayer(),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
