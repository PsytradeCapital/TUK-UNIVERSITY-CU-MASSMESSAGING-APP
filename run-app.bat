@echo off
echo Christian Union Attendance App - Run Script
echo ===========================================
echo.

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please run the installation script first:
    echo - install-all.bat (as Administrator)
    echo - OR quick-setup.ps1 (as Administrator)
    echo.
    pause
    exit /b 1
)

echo Flutter found! Getting dependencies...
flutter pub get

if %errorlevel% neq 0 (
    echo Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo Checking for connected devices...
flutter devices

echo.
echo Choose an option:
echo 1. Run app on connected device/emulator
echo 2. Build APK for installation
echo 3. Run Flutter Doctor
echo 4. Accept Android licenses
echo.
set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" (
    echo.
    echo Starting app...
    flutter run
) else if "%choice%"=="2" (
    echo.
    echo Building APK...
    flutter build apk --release
    echo.
    echo APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo You can now install this APK on any Android device
) else if "%choice%"=="3" (
    echo.
    echo Running Flutter Doctor...
    flutter doctor
) else if "%choice%"=="4" (
    echo.
    echo Accepting Android licenses...
    flutter doctor --android-licenses
) else (
    echo Invalid choice
)

echo.
pause