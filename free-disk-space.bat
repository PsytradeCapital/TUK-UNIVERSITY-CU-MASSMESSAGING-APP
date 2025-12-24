@echo off
echo Freeing Disk Space for Flutter Build
echo ====================================
echo.

echo [1/6] Cleaning Flutter cache...
flutter clean
rd /s /q build 2>nul
rd /s /q .dart_tool 2>nul

echo.
echo [2/6] Cleaning Gradle cache...
rd /s /q "%USERPROFILE%\.gradle\caches" 2>nul

echo.
echo [3/6] Cleaning Pub cache...
flutter pub cache clean

echo.
echo [4/6] Cleaning Windows temp files...
del /q /s "%TEMP%\*" 2>nul
rd /s /q "%TEMP%" 2>nul
mkdir "%TEMP%"

echo.
echo [5/6] Running Windows Disk Cleanup...
cleanmgr /sagerun:1

echo.
echo [6/6] Checking available space...
dir C:\ | findstr "bytes free"

echo.
echo Space freed! You need at least 15-20 GB free for full build.
echo If still not enough space, consider:
echo - Moving files to external drive
echo - Uninstalling unused programs
echo - Using cloud storage for documents
echo.
pause