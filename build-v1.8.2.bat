@echo off
echo ========================================
echo Building v1.8.2 - Phone Number Fix Tool
echo ========================================
echo.
echo This version includes:
echo - Phone Number Fix Tool in Settings
echo - Enhanced debug logging
echo - Automatic phone number correction
echo.
echo Building APK...
C:\flutter\bin\flutter.bat build apk --release
echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================
    echo Build Successful!
    echo ========================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo Next steps:
    echo 1. Run: install-v1.8.2.bat
    echo 2. Open app - Go to Settings
    echo 3. Tap "Fix Phone Numbers"
    echo 4. Run the fix
    echo 5. Test SMS sending
    echo.
) else (
    echo ========================================
    echo Build Failed!
    echo ========================================
    echo Please check the error messages above.
    echo.
)
pause
