@echo off
echo Checking Build Status...
echo ========================
echo.

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ APK EXISTS!
    echo.
    echo File: build\app\outputs\flutter-apk\app-release.apk
    dir "build\app\outputs\flutter-apk\app-release.apk"
    echo.
    echo Ready to install on phone!
    echo Run: flutter install
) else (
    echo ❌ APK not found
    echo.
    echo Build may still be in progress or failed.
    echo Check for build processes:
    tasklist | findstr flutter
    echo.
    echo To start build: flutter build apk --release
)

echo.
pause