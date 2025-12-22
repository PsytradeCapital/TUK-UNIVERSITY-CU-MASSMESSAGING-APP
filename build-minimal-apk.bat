@echo off
echo Building Minimal APK for TUK CU Mass Messaging App
echo ==================================================
echo.

REM Clean first
echo [1/4] Cleaning previous build...
flutter clean

REM Get dependencies
echo [2/4] Getting dependencies...
flutter pub get

REM Build with minimal features
echo [3/4] Building APK (this may take 5-10 minutes)...
echo Please wait...
flutter build apk --release --no-tree-shake-icons --split-per-abi

REM Check if build succeeded
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo [4/4] SUCCESS! APK built successfully!
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo File size:
    dir "build\app\outputs\flutter-apk\app-release.apk"
    echo.
    echo Next steps:
    echo 1. Connect your phone via USB
    echo 2. Enable USB debugging
    echo 3. Run: flutter install
    echo.
) else (
    echo.
    echo [4/4] BUILD FAILED!
    echo Check the error messages above.
    echo.
    echo Try running: flutter doctor
    echo.
)

pause