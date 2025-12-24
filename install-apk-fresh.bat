@echo off
echo Installing TUK CU Mass Messaging App on Phone
echo ============================================
echo.

echo [1/3] Checking if phone is connected...
adb devices

echo.
echo [2/3] Uninstalling old version (if exists)...
adb uninstall com.example.christian_union_attendance_app
echo Note: It's OK if uninstall fails - means no old version exists

echo.
echo [3/3] Installing new APK...
adb install "build\app\outputs\flutter-apk\app-release.apk"

echo.
echo Installation complete!
echo Check your phone for the "TUK CU Mass Messaging" app.
echo.
pause