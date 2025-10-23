@echo off
echo Building APK for TUK CU Mass Messaging App
echo ==========================================
echo.

echo Step 1: Cleaning project...
flutter clean

echo Step 2: Getting dependencies...
flutter pub get

echo Step 3: Checking for errors...
flutter analyze

echo Step 4: Building APK...
flutter build apk --release

if %errorlevel% equ 0 (
    echo.
    echo ✅ APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo You can now install this APK on your Android phone:
    echo 1. Copy the APK to your phone
    echo 2. Enable "Install from Unknown Sources" in phone settings
    echo 3. Tap the APK file to install
    echo.
) else (
    echo.
    echo ❌ Build failed. Please check the errors above.
    echo.
)

pause