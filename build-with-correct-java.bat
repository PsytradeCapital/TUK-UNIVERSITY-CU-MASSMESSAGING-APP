@echo off
echo Setting up Java environment for Flutter build...

REM Set Java Home to Android Studio's JDK
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

REM Verify Java is working
echo Testing Java installation...
"%JAVA_HOME%\bin\java.exe" -version
if %errorlevel% neq 0 (
    echo ERROR: Java not found at %JAVA_HOME%\bin\java.exe
    pause
    exit /b 1
)

echo Java found successfully!
echo.

REM Clean previous build
echo Cleaning previous build...
C:\flutter\bin\flutter.bat clean

REM Build APK with correct Java
echo Building APK with correct Java environment...
C:\flutter\bin\flutter.bat build apk --release

if %errorlevel% equ 0 (
    echo.
    echo ✅ SUCCESS! APK built successfully!
    echo.
    if exist "build\app\outputs\flutter-apk\app-release.apk" (
        echo 📱 APK Location: build\app\outputs\flutter-apk\app-release.apk
        for %%I in ("build\app\outputs\flutter-apk\app-release.apk") do echo 📊 Size: %%~zI bytes
        echo.
        echo 🚀 Ready for deployment!
    )
) else (
    echo.
    echo ❌ Build failed. Check errors above.
)

pause