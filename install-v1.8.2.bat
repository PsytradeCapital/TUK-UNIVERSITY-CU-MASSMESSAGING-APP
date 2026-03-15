@echo off
echo ========================================
echo Installing v1.8.2 - Phone Number Fix Tool
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
echo IMPORTANT: Run the Phone Number Fix
echo.
echo Steps:
echo 1. Open the app
echo 2. Go to Settings tab
echo 3. Tap "Fix Phone Numbers" (first option)
echo 4. Tap "Run Fix" button
echo 5. Wait for completion
echo 6. Go to Messaging and test sending
echo.
echo The fix will correct all invalid phone numbers
echo in your database automatically.
echo.
pause
