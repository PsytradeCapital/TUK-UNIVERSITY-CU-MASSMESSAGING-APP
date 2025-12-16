@echo off
echo.
echo ========================================
echo    Flutter Minimal Installation
echo ========================================
echo.

REM Check available disk space
echo Checking disk space...
for /f "tokens=3" %%a in ('dir /-c %SystemDrive%\ ^| find "bytes free"') do set FreeSpace=%%a
echo Available space: %FreeSpace% bytes

REM Clean temporary files first
echo.
echo Cleaning temporary files to free up space...
del /q /f "%TEMP%\*.*" 2>nul
for /d %%i in ("%TEMP%\*") do rmdir /s /q "%%i" 2>nul

REM Clean Windows temp
del /q /f "C:\Windows\Temp\*.*" 2>nul
for /d %%i in ("C:\Windows\Temp\*") do rmdir /s /q "%%i" 2>nul

echo Temporary files cleaned.
echo.

REM Use a smaller Flutter installation path
set FLUTTER_PATH=C:\dev\flutter

echo Installing Flutter to: %FLUTTER_PATH%
echo This requires approximately 1.5GB of free space.
echo.

set /p continue="Do you have enough space? Continue? (y/N): "
if /i not "%continue%"=="y" (
    echo Installation cancelled.
    echo.
    echo To free up space:
    echo 1. Run Disk Cleanup (cleanmgr)
    echo 2. Uninstall unused programs
    echo 3. Delete large files you don't need
    echo 4. Move files to external storage
    pause
    exit /b 0
)

REM Create installation directory
if exist "%FLUTTER_PATH%" rmdir /s /q "%FLUTTER_PATH%"
mkdir "%FLUTTER_PATH%" 2>nul

echo.
echo Downloading Flutter SDK (this may take several minutes)...
echo Please be patient...

REM Download using PowerShell with progress
powershell -Command "& {$ProgressPreference = 'Continue'; Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.5-stable.zip' -OutFile '%TEMP%\flutter.zip' -UseBasicParsing}"

if not exist "%TEMP%\flutter.zip" (
    echo ERROR: Download failed. Please check your internet connection.
    pause
    exit /b 1
)

echo.
echo Extracting Flutter SDK...
powershell -Command "& {Expand-Archive -Path '%TEMP%\flutter.zip' -DestinationPath 'C:\dev\' -Force}"

if not exist "%FLUTTER_PATH%\bin\flutter.bat" (
    echo ERROR: Extraction failed.
    pause
    exit /b 1
)

echo.
echo Adding Flutter to PATH...
setx PATH "%PATH%;%FLUTTER_PATH%\bin" >nul 2>&1

echo.
echo Cleaning up download file...
del "%TEMP%\flutter.zip" 2>nul

echo.
echo Running Flutter Doctor...
set PATH=%PATH%;%FLUTTER_PATH%\bin
"%FLUTTER_PATH%\bin\flutter.bat" doctor

echo.
echo ========================================
echo    Installation Complete!
echo ========================================
echo.
echo Flutter installed to: %FLUTTER_PATH%
echo.
echo IMPORTANT: Restart your command prompt to use Flutter commands.
echo.
echo Next steps:
echo 1. Restart your terminal
echo 2. Run 'flutter doctor' to verify installation
echo 3. Install Android Studio for Android development
echo.
pause