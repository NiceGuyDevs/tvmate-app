@echo off
setlocal EnableExtensions

cd /d "%~dp0"

set "PUBSPEC=pubspec.yaml"
if not exist "%PUBSPEC%" (
  echo ERROR: %PUBSPEC% not found.
  exit /b 1
)

for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "$m = Select-String -Path '%PUBSPEC%' -Pattern '^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$' | Select-Object -First 1; if (-not $m) { exit 1 }; $m.Matches[0].Groups[1].Value + '|' + $m.Matches[0].Groups[2].Value"`) do (
  set "VERPAIR=%%V"
)

if not defined VERPAIR (
  echo ERROR: Could not read version from %PUBSPEC%.
  echo Expected format: version: x.y.z+build
  exit /b 1
)

for /f "tokens=1,2 delims=|" %%A in ("%VERPAIR%") do (
  set "VERSION_NAME=%%A"
  set "BUILD_NUMBER=%%B"
)

set /a NEW_BUILD=BUILD_NUMBER+1
set "NEW_VERSION=%VERSION_NAME%+%NEW_BUILD%"

echo Current version: %VERSION_NAME%+%BUILD_NUMBER%
echo New version:     %NEW_VERSION%

powershell -NoProfile -Command "$path = '%PUBSPEC%'; $content = Get-Content -Raw -Path $path; $updated = [regex]::Replace($content, '(?m)^\s*version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\s*$', 'version: %NEW_VERSION%', 1); if ($content -eq $updated) { exit 1 }; Set-Content -Path $path -Value $updated -NoNewline"
if errorlevel 1 (
  echo ERROR: Failed to update version in %PUBSPEC%.
  exit /b 1
)

echo Running flutter pub get...
call flutter pub get
if errorlevel 1 (
  echo ERROR: flutter pub get failed.
  exit /b 1
)

set "APK_DIR=build\app\outputs\flutter-apk"

if "%~1"=="1" (
  set "BUILD_TYPE=1"
  goto BUILD_TYPE_SELECTED
)

if "%~1"=="2" (
  set "BUILD_TYPE=2"
  goto BUILD_TYPE_SELECTED
)

echo.
echo Choose build type: (1 = Debug, 2 = Release)
set /p BUILD_TYPE=Enter choice:

set "APK_DIR=build\app\outputs\flutter-apk"

:BUILD_TYPE_SELECTED
if "%BUILD_TYPE%"=="1" goto BUILD_DEBUG
if "%BUILD_TYPE%"=="2" goto BUILD_RELEASE

echo ERROR: Invalid choice. Use 1 or 2.
exit /b 1

:BUILD_DEBUG
echo Building debug APK...
call flutter build apk --debug
if errorlevel 1 (
  echo ERROR: Debug build failed.
  exit /b 1
)

set "SRC_APK=%APK_DIR%\app-debug.apk"
set "DST_APK=%APK_DIR%\TvMate.Pro debug %NEW_BUILD%.apk"

if not exist "%SRC_APK%" (
  echo ERROR: Built APK not found: %SRC_APK%
  exit /b 1
)

if exist "%DST_APK%" del /f /q "%DST_APK%"
copy /y "%SRC_APK%" "%DST_APK%" >nul
if errorlevel 1 (
  echo ERROR: Failed to create renamed debug APK.
  exit /b 1
)

echo Done.
echo Output: %DST_APK%
exit /b 0

:BUILD_RELEASE
echo Building release APK...
call flutter build apk --release
if errorlevel 1 (
  echo ERROR: Release build failed.
  exit /b 1
)

set "SRC_APK=%APK_DIR%\app-release.apk"
if not exist "%SRC_APK%" (
  echo ERROR: Built APK not found: %SRC_APK%
  exit /b 1
)

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"`) do (
  set "TODAY=%%D"
)

if not defined TODAY (
  echo ERROR: Could not get date.
  exit /b 1
)

set "DST_APK=%APK_DIR%\TvMate.Pro_v%VERSION_NAME%_%TODAY%_%NEW_BUILD%.apk"
if exist "%DST_APK%" del /f /q "%DST_APK%"
copy /y "%SRC_APK%" "%DST_APK%" >nul
if errorlevel 1 (
  echo ERROR: Failed to create renamed release APK.
  exit /b 1
)

echo Done.
echo Output: %DST_APK%
exit /b 0
