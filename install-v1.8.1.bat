@echo off
echo ========================================
echo Installing v1.8.1 APK
echo ========================================
echo.

echo Checking for connected devices...
adb devices
echo.

echo Installing APK...
adb install -r build\app\outputs\flutter-apk\app-release.apk

echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo Next steps:
echo 1. Open the app on your device
echo 2. Test SMS sending with existing attendees
echo 3. Check logs: adb logcat ^| findstr "SMS"
echo.
pause
