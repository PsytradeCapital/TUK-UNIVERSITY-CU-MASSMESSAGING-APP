@echo off
echo ========================================
echo TUK CU Mass Messaging App - Release Build
echo ========================================
echo.

echo Checking Flutter installation...
flutter doctor --version
if %errorlevel% neq 0 (
    echo ERROR: Flutter not found. Please install Flutter and add to PATH.
    pause
    exit /b 1
)

echo.
echo Checking Firebase configuration...
if not exist "android\app\google-services.json" (
    echo ERROR: google-services.json not found in android\app\
    echo Please download from Firebase Console and place in android\app\
    pause
    exit /b 1
)

echo.
echo Cleaning previous builds...
flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)

echo.
echo Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo Running code analysis...
flutter analyze
if %errorlevel% neq 0 (
    echo WARNING: Code analysis found issues. Continue anyway? (y/n)
    set /p continue=
    if /i not "%continue%"=="y" (
        echo Build cancelled by user
        pause
        exit /b 1
    )
)

echo.
echo Building release APK...
flutter build apk --release --verbose
if %errorlevel% neq 0 (
    echo ERROR: APK build failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo BUILD SUCCESSFUL!
echo ========================================
echo.
echo APK Location: build\app\outputs\flutter-apk\app-release.apk
echo APK Size: 
for %%A in (build\app\outputs\flutter-apk\app-release.apk) do echo %%~zA bytes

echo.
echo Next Steps:
echo 1. Test APK on multiple devices
echo 2. Verify Firebase connectivity
echo 3. Test offline/online sync
echo 4. Verify SMS functionality
echo 5. Test user registration and approval
echo.

echo Opening APK location...
explorer build\app\outputs\flutter-apk\

echo.
echo Build completed successfully!
pause