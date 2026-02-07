@echo off
echo Building TUK CU App with Correct Java Path
echo ==========================================
echo.

REM Set correct Java path
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

echo Using Java: %JAVA_HOME%
echo.

REM Verify Java is accessible
"%JAVA_HOME%\bin\java.exe" -version
if errorlevel 1 (
    echo ERROR: Java not found at %JAVA_HOME%
    pause
    exit /b 1
)

echo.
echo Java verified successfully. Building APK...
echo.

REM Clean and build
C:\flutter\bin\flutter.bat clean
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat build apk --release

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo SUCCESS! Release APK built successfully.
    echo File: build\app\outputs\flutter-apk\app-release.apk
    dir "build\app\outputs\flutter-apk\app-release.apk"
) else (
    echo.
    echo BUILD FAILED - APK not found.
)

pause