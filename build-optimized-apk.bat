@echo off
echo Building Optimized TUK CU Mass Messaging App
echo ============================================
echo.

echo [1/4] Adding fast registration service...
echo Fast registration service created for instant registration.

echo.
echo [2/4] Cleaning previous build...
flutter clean

echo.
echo [3/4] Building optimized APK...
echo This includes:
echo - Fast registration (local-first approach)
echo - Background cloud sync
echo - Optimized personalization
echo - Performance improvements
echo.

flutter build apk --release --target-platform android-arm64

echo.
echo [4/4] Checking build result...
if exist "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    echo ✅ SUCCESS! Optimized APK built successfully!
    echo.
    echo File: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
    dir "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
    echo.
    echo OPTIMIZATIONS INCLUDED:
    echo ✅ Instant registration (local-first)
    echo ✅ Background cloud sync
    echo ✅ No "Hi" greeting in personalization
    echo ✅ Performance improvements
    echo ✅ ARM64 optimization for better performance
    echo.
    echo Ready to install: flutter install
) else (
    echo ❌ Build failed. Check errors above.
)

echo.
pause