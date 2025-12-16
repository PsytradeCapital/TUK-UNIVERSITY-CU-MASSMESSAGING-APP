@echo off
echo.
echo ========================================
echo    Flutter Installation Script
echo ========================================
echo.

REM Check if Flutter is already installed
if exist "C:\flutter\bin\flutter.bat" (
    echo Flutter is already installed at C:\flutter
    echo.
    set /p continue="Do you want to reinstall? (y/N): "
    if /i not "%continue%"=="y" (
        echo Installation cancelled.
        pause
        exit /b 0
    )
)

echo Step 1: Creating installation directory...
if exist "C:\flutter" rmdir /s /q "C:\flutter"
mkdir "C:\flutter" 2>nul

echo.
echo Step 2: Downloading Flutter SDK...
echo This may take a few minutes depending on your internet connection...
echo.

REM Download Flutter using PowerShell
powershell -Command "& {Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip' -OutFile '%TEMP%\flutter_windows.zip' -UseBasicParsing}"

if not exist "%TEMP%\flutter_windows.zip" (
    echo ERROR: Failed to download Flutter SDK
    echo Please check your internet connection and try again.
    pause
    exit /b 1
)

echo.
echo Step 3: Extracting Flutter SDK...
powershell -Command "& {Expand-Archive -Path '%TEMP%\flutter_windows.zip' -DestinationPath 'C:\' -Force}"

if not exist "C:\flutter\bin\flutter.bat" (
    echo ERROR: Failed to extract Flutter SDK
    pause
    exit /b 1
)

echo.
echo Step 4: Adding Flutter to PATH...
REM Add Flutter to PATH for current user
setx PATH "%PATH%;C:\flutter\bin" >nul 2>&1

echo.
echo Step 5: Running Flutter Doctor...
set PATH=%PATH%;C:\flutter\bin
C:\flutter\bin\flutter.bat doctor

echo.
echo Step 6: Cleaning up...
if exist "%TEMP%\flutter_windows.zip" del "%TEMP%\flutter_windows.zip"

echo.
echo ========================================
echo    Installation Complete!
echo ========================================
echo.
echo Flutter has been installed to: C:\flutter
echo.
echo IMPORTANT: Please restart your command prompt or IDE
echo to use Flutter commands.
echo.
echo Next steps:
echo 1. Restart your terminal/command prompt
echo 2. Run 'flutter doctor' to verify installation
echo 3. Install Android Studio for Android development
echo 4. Install VS Code with Flutter extension
echo.
echo Useful commands:
echo   flutter doctor          - Check installation
echo   flutter create myapp    - Create new project
echo   flutter run             - Run your app
echo   flutter build apk       - Build APK
echo.
pause