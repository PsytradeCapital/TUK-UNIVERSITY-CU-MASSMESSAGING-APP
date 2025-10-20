@echo off
echo Christian Union Attendance App - Setup Script
echo =============================================
echo.

echo Checking Flutter installation...
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo.
    echo Please install Flutter first:
    echo 1. Download from: https://docs.flutter.dev/get-started/install/windows
    echo 2. Extract to C:\flutter
    echo 3. Add C:\flutter\bin to your PATH
    echo 4. Restart this script
    echo.
    pause
    exit /b 1
)

echo Flutter found! Checking Flutter doctor...
flutter doctor

echo.
echo Getting dependencies...
flutter pub get

echo.
echo Setup complete! You can now:
echo 1. Connect an Android device or start an emulator
echo 2. Run: flutter run
echo 3. Or build APK: flutter build apk --release
echo.

echo Checking for connected devices...
flutter devices

echo.
echo Setup script completed!
pause