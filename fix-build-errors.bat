@echo off
echo Fixing build errors...
echo.

REM Clean build cache
echo [1/3] Cleaning build cache...
flutter clean

REM Get dependencies
echo [2/3] Getting dependencies...
flutter pub get

REM Try building again
echo [3/3] Building APK...
flutter build apk --release

echo.
echo Build attempt complete!
pause