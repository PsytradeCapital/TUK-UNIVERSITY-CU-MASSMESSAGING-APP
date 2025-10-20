@echo off
setlocal enabledelayedexpansion

echo Christian Union Attendance App - Complete Installation Script
echo =============================================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Starting automated installation...
echo.

REM Create temporary directory
set TEMP_DIR=%TEMP%\flutter_install
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM Function to download files using PowerShell
echo Downloading required files...

REM Download Flutter SDK
echo Downloading Flutter SDK...
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip' -OutFile '%TEMP_DIR%\flutter.zip'}"

if not exist "%TEMP_DIR%\flutter.zip" (
    echo Failed to download Flutter SDK
    goto :error
)

REM Extract Flutter
echo Extracting Flutter SDK to C:\flutter...
powershell -Command "Expand-Archive -Path '%TEMP_DIR%\flutter.zip' -DestinationPath 'C:\' -Force"

if not exist "C:\flutter\bin\flutter.bat" (
    echo Failed to extract Flutter SDK
    goto :error
)

REM Add Flutter to PATH
echo Adding Flutter to system PATH...
setx PATH "%PATH%;C:\flutter\bin" /M

REM Download Git
echo Downloading Git...
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe' -OutFile '%TEMP_DIR%\git-installer.exe'}"

REM Install Git silently
if exist "%TEMP_DIR%\git-installer.exe" (
    echo Installing Git...
    "%TEMP_DIR%\git-installer.exe" /SILENT /NORESTART
    timeout /t 30 /nobreak >nul
)

REM Download Android Studio
echo Downloading Android Studio...
powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://redirector.gvt1.com/edgedl/android/studio/install/2023.1.1.28/android-studio-2023.1.1.28-windows.exe' -OutFile '%TEMP_DIR%\android-studio.exe'}"

REM Install Android Studio
if exist "%TEMP_DIR%\android-studio.exe" (
    echo Installing Android Studio...
    echo Please follow the installation wizard and make sure to install Android SDK
    "%TEMP_DIR%\android-studio.exe"
    echo Waiting for Android Studio installation to complete...
    pause
)

REM Clean up
echo Cleaning up temporary files...
rmdir /s /q "%TEMP_DIR%" 2>nul

REM Refresh environment
echo Refreshing environment variables...
set PATH=%PATH%;C:\flutter\bin

echo.
echo Installation completed!
echo.
echo Verifying Flutter installation...
C:\flutter\bin\flutter.bat doctor

echo.
echo Next steps:
echo 1. Restart your command prompt/PowerShell
echo 2. Run: flutter doctor --android-licenses
echo 3. Navigate to your project directory
echo 4. Run: flutter pub get
echo 5. Run: flutter run
echo.
pause
goto :end

:error
echo.
echo Installation failed. Please check the error messages above.
echo You may need to install components manually.
echo.
pause

:end
endlocal