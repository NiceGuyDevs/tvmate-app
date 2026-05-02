import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tvmatepro/app.dart';
import 'package:tvmatepro/data/clock_overlay_settings_store.dart';
import 'package:tvmatepro/data/library_controller.dart';
import 'package:tvmatepro/data/library_store_db.dart';
import 'package:tvmatepro/data/xtream_catalog_cache_db.dart';
import 'package:tvmatepro/shell/main_shell_screen.dart';
import 'package:tvmatepro/ui/splash/splash_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    await libraryStoreDb.initialize();
    await xtreamCatalogCacheDb.initialize();
    await libraryController.initialize();
    await clockOverlaySettingsStore.ensureLoaded();
  });

  testWidgets('Splash then opens main shell on Live TV', (tester) async {
    await tester.pumpWidget(const TvMateApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.text('Live TV'), findsWidgets);
  });
}
