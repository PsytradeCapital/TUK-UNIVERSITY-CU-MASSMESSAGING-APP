@echo off
echo Quick Flutter Installation
echo =========================
echo.

REM Check if Flutter already exists
if exist "C:\flutter\bin\flutter.bat" (
    echo Flutter already installed at C:\flutter
    goto :setup_path
)

echo Downloading Flutter SDK...
powershell -Command "Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip' -OutFile 'C:\flutter-sdk.zip'"

if not exist "C:\flutter-sdk.zip" (
    echo Download failed. Please check internet connection.
    pause
    exit /b 1
)

echo Extracting Flutter...
powershell -Command "Expand-Archive -Path 'C:\flutter-sdk.zip' -DestinationPath 'C:\' -Force"

echo Cleaning up...
del "C:\flutter-sdk.zip"

:setup_path
echo Setting up Flutter PATH...
setx PATH "%PATH%;C:\flutter\bin" /M

echo.
echo Flutter installation complete!
echo Please restart your command prompt and run: flutter doctor
echo.
pause