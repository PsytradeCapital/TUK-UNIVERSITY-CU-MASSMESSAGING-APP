@echo off
echo Fixing App Loading Issues
echo =========================
echo.

echo [1/4] Checking phone connection...
flutter devices

echo.
echo [2/4] Clearing app data on phone...
flutter install --uninstall-only
timeout /t 3

echo.
echo [3/4] Installing fresh APK...
flutter install --release

echo.
echo [4/4] Launching app...
flutter run --release

echo.
echo If app still shows gray screen:
echo 1. Force close the app on your phone
echo 2. Restart the app
echo 3. Or use the web version (run-web-version.html)
echo.
pause