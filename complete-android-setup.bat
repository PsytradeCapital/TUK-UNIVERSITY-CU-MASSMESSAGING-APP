@echo off
echo TUK CU Mass Messaging - Complete Android Setup
echo =============================================
echo.

REM Step 1: Check Java
echo [1/4] Checking Java installation...
java -version >nul 2>&1
if %errorlevel% neq 0 (
    echo Java not found. Installing Java first...
    call install-java-simple.bat
    if %errorlevel% neq 0 (
        echo Java installation failed. Please install manually.
        pause
        exit /b 1
    )
)

REM Step 2: Set up Android SDK environment
echo [2/4] Setting up Android SDK environment...
set ANDROID_HOME=C:\android-sdk
set PATH=%PATH%;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\bin

REM Step 3: Install Android SDK components
echo [3/4] Installing Android SDK components...
echo This may take a few minutes...
"%ANDROID_HOME%\cmdline-tools\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" "platform-tools" "platforms;android-33" "build-tools;33.0.0"

REM Step 4: Accept licenses
echo [4/4] Accepting Android licenses...
echo y | "%ANDROID_HOME%\cmdline-tools\bin\sdkmanager.bat" --sdk_root="%ANDROID_HOME%" --licenses

echo.
echo Android SDK setup complete!
echo.
echo Next steps:
echo 1. Connect your phone via USB
echo 2. Enable USB debugging on your phone
echo 3. Run: flutter build apk --release
echo 4. Run: flutter install
echo.
pause