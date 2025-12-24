@echo off
echo Building TUK CU App with Multidex Support
echo ========================================
echo.

echo Checking disk space...
for /f "tokens=3" %%a in ('dir C:\ ^| findstr "bytes free"') do set freespace=%%a
echo Free space: %freespace% bytes

echo.
echo Building APK with multidex support...
echo This requires 15-20 GB free space and may take 10-15 minutes.
echo.

REM Clean first to free space
flutter clean

REM Build with multidex
echo y | flutter build apk --debug

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo SUCCESS! Debug APK built with multidex support.
    echo File: build\app\outputs\flutter-apk\app-debug.apk
    dir "build\app\outputs\flutter-apk\app-debug.apk"
) else (
    echo.
    echo BUILD FAILED - likely due to insufficient disk space.
    echo You need at least 15-20 GB free space.
)

pause