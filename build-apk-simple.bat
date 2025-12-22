@echo off
echo Building APK for TUK CU Mass Messaging App...
echo =============================================
echo.

echo Cleaning previous build...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building APK (this may take 10-15 minutes)...
flutter build apk --release --no-tree-shake-icons

if %errorlevel% equ 0 (
    echo.
    echo ✅ BUILD SUCCESSFUL!
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Next steps:
    echo 1. Connect your phone via USB
    echo 2. Enable USB debugging on your phone
    echo 3. Run: flutter install
    echo.
    echo Or copy the APK file to your phone and install manually.
) else (
    echo.
    echo ❌ BUILD FAILED
    echo Check the errors above and try again.
)

pause