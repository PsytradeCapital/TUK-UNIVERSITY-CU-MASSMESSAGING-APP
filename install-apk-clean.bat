@echo off
echo Installing TUK CU Mass Messaging App
echo ====================================
echo.

echo [1/4] Checking phone connection...
flutter devices

echo.
echo [2/4] Uninstalling any old version...
flutter install --uninstall-only
echo (It's OK if this fails - means no old version exists)

echo.
echo [3/4] Installing release APK...
flutter install --release

echo.
echo [4/4] Checking installation...
if %errorlevel% equ 0 (
    echo ✅ SUCCESS! App installed successfully!
    echo.
    echo Look for "TUK CU Mass Messaging" app on your phone.
    echo.
    echo Features available:
    echo ✅ Attendee registration
    echo ✅ Mass messaging with personalization
    echo ✅ Cloud sync and backup
    echo ✅ SMS sending
    echo ✅ Analytics and reports
    echo ✅ Document scanning
    echo.
) else (
    echo ❌ Installation failed. Trying manual method...
    echo.
    echo MANUAL INSTALLATION:
    echo 1. Copy this file to your phone: build\app\outputs\flutter-apk\app-release.apk
    echo 2. On your phone, go to Downloads
    echo 3. Tap the APK file
    echo 4. Allow installation from unknown sources if prompted
    echo 5. Install the app
)

pause