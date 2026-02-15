@echo off
echo Building TUK CU App with Smart Features
echo ========================================
echo.

REM Set correct Java path
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

echo Using Java: %JAVA_HOME%
echo.

echo Getting dependencies...
C:\flutter\bin\flutter.bat pub get

echo.
echo Building APK (this will take several minutes)...
echo.

C:\flutter\bin\flutter.bat build apk --release --no-tree-shake-icons

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo ========================================
    echo SUCCESS! APK built successfully
    echo ========================================
    echo.
    echo APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    dir "build\app\outputs\flutter-apk\app-release.apk"
    echo.
    echo New Features Added:
    echo - Smart matching for document scanner
    echo - Clickable reports with filtered member views
    echo.
) else (
    echo.
    echo BUILD FAILED - APK not found
    echo Check the error messages above
)

pause
