# Android build, TV manifest, and branding

## Target device class

- **Android TV / Leanback** — `AndroidManifest.xml` declares **`android.software.leanback` with `android:required="false"`**. This keeps **`LEANBACK_LAUNCHER`** (TV home row) while allowing **APK install on phones and STBs** that do not advertise the leanback software feature; `required="true"` often causes a generic **“App not installed”** on sideload.
- **`android.hardware.touchscreen`** — `required="false"` (remote-first).
- **Launcher entries:** `MAIN` + `LAUNCHER` (phones/sideload) and `MAIN` + `LEANBACK_LAUNCHER` (TV home row).

## Manifest highlights

**File:** `android/app/src/main/AndroidManifest.xml`

- `android:banner="@drawable/tv_banner"` — TV row banner.
- `android:icon="@mipmap/ic_launcher"` — launcher / adaptive icon.
- `android:usesCleartextTraffic="true"` — common for IPTV HTTP streams (evaluate security for production).
- `MainActivity` — `singleTop`, hardware acceleration, `LaunchTheme` → `NormalTheme`.
- **`io.flutter.embedding.android.EnableImpeller` → `false`** — Place this **`meta-data` under `<application>`**, **not** inside `<activity>`. If it is only on the activity, Flutter **ignores** it and **Impeller stays on** ([flutter/flutter#154252](https://github.com/flutter/flutter/issues/154252)) — symptoms: **rainbow / neon video**, normal UI. **Impeller (Vulkan)** can mis-sample **MediaCodec YUV** on some **Android TV** GPUs; **Skia + OpenGL** is more reliable for **ExoPlayer → `SurfaceProducer` → `Texture`**. Kotlin still uses **`SurfaceProducer`** (not legacy **`SurfaceTexture`**). Optional: set **`true`** after a Flutter upgrade and re-test on your devices.

**Kotlin:** `MainActivity` registers **`NativeExoPlayerSession`** and **`NativeLivePreviewSession`**. **`onPause()`** calls **`livePreview?.stopForActivityPause()`** so the **hero preview** ExoPlayer is torn down when the activity leaves the foreground (stops background audio on devices that keep the process alive).

## Launcher icon (API 26+ adaptive)

**File:** `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`

- Background: `@color/ic_launcher_background` (see `res/values/colors.xml`).
- Foreground: `@drawable/ic_launcher_fg` — **`drawable/ic_launcher_fg.xml`** layer-list centered on **`@drawable/app_icon`** (typically **`drawable-nodpi/app_icon.png`**, same art as the generated **`ic_launcher_foreground`** mipmaps).

The **`app_icon`** bitmap (**`drawable-nodpi/`** and **`drawable/`**) must be a **real JPEG** or **real PNG** — a **JPEG saved as `.png`** makes **AAPT2** fail at **`mergeReleaseResources`**. **Native splash** uses **`branding_logo`**, not **`app_icon`**.

## TV banner

**File:** `android/app/src/main/res/drawable/tv_banner.xml`

- Layer-list: black background + centered **`tv_banner_logo`** (**`drawable-nodpi/tv_banner_logo.png`**). Rebuild only the TV tile with **`python tools/adjust_tvmate_tv_banner.py`** (16:9 from **`tvmate_pro_brand_master.png`**). That script does **not** change the loading splash — splash stays tied to **`IpTvIl.png`** via **`tools/generate_brand_assets.py`**.

## Flutter launch / native splash

**File:** `android/app/src/main/res/drawable/launch_background.xml`

- Black + centered **`@drawable/branding_logo`** — wide splash art (**`drawable-nodpi/branding_logo.png`**). Separate from **`tv_banner_logo`** (TV home row).

## Flutter-side assets

**Declaration:** `pubspec.yaml` → `assets/images/`

Typical files (when present on disk):

- `splash_logo.png` — wide splash / brand (also referenced from UI where a header logo is shown).
- `IpTvIl.png` — square-ish brand fallback.

## Version code

- Flutter **`pubspec.yaml`** field **`version: x.y.z+build`** maps **`build`** → Android **`versionCode`**. Increment **`+build`** when shipping over an existing install to avoid **INSTALL_FAILED_VERSION_DOWNGRADE**.

## Signing (release)

- `android/app/build.gradle` currently wires **`release` → `signingConfigs.debug`** for convenience. For Play Store or a consistent release key, add a **`signingConfigs.release`** block and point **`buildTypes.release`** at it.

## Building

From project root (developer machine with Flutter SDK):

```bash
flutter pub get
flutter build apk --release
```

Output APK: **`build/app/outputs/flutter-apk/app-release.apk`** (fat APK with multiple ABIs by default).

If Gradle complains about missing drawables, verify **`res/drawable-nodpi/`** contains the PNGs referenced by XML and that resource names are **lowercase** with underscores.

## Sideload troubleshooting

- **“App not installed”** — uninstall any existing package with the same **`applicationId`** if it was signed with a **different** key; ensure the APK transferred completely; bump **`versionCode`** (`pubspec` **+build** number).
- **Leanback** — already relaxed via **`required="false"`** (see above).

## Gradle: AndroidX Core resolution (Flutter text input)

**File:** `android/build.gradle` (project / root)

A **`configurations.all { resolutionStrategy { force … } }`** block pins:

- **`androidx.core:core:1.15.0`**
- **`androidx.core:core-ktx:1.15.0`**
- (and optionally other artifacts, e.g. **`androidx.browser`**)

**Why:** Flutter’s Android **`TextInputPlugin`** calls **`androidx.core.view.inputmethod.EditorInfoCompat.setStylusHandwritingEnabled(EditorInfo, boolean)`** when creating an **`InputConnection`**. That method was added in **AndroidX Core 1.13+**. If Gradle **forces** **`core` / `core-ktx` 1.12.0** (or an older transitive wins), the app can crash with:

```text
java.lang.NoSuchMethodError: No static method setStylusHandwritingEnabled(...) in class EditorInfoCompat
```

when the user focuses a **`TextField`** and the **IME** starts — commonly seen on **Settings → Add Playlist** on **Chromecast with Google TV**, **ONN** streaming devices, etc. **NVIDIA Shield** may appear unaffected in some test passes depending on build history, but the **same APK** should use a **new enough** Core everywhere.

**Do not** lower **`core` / `core-ktx`** below **1.13** without checking the Flutter engine version’s Android embedding; prefer **1.15.0** or newer stable aligned with your **`compileSdk`**.

## NVIDIA Shield / TV testing tips

- Use **`adb connect`** / **wireless debugging** for network ADB when useful.
- Capture **logcat** around playback exit if reporting native crashes; for **keyboard / TextField** crashes, look for **`FATAL EXCEPTION`**, **`EditorInfoCompat`**, **`TextInputPlugin`**.
- Confirm **D-pad** focus order on physical remote, not only emulator.
- Test **Add Playlist** text fields on at least **two** hardware tiers (e.g. Shield + budget stick) after changing AndroidX versions.
- **Video:** on **fullscreen** and **Live TV hero preview**, confirm **natural colors** (no **rainbow** / solarized look) and **no** audio-only **black** picture. If colors are wrong, verify **`EnableImpeller`** **`meta-data`** is under **`<application>`** in **`AndroidManifest.xml`**, then **`flutter clean`** + reinstall. Compare **newer vs older Shield** when possible — same APK should pass both.
