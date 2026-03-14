@echo off
echo ========================================
echo Scanner Debug Log Capture
echo ========================================
echo.
echo Instructions:
echo 1. This script will clear logs and wait
echo 2. Open the app and scan an attendance sheet
echo 3. Wait for the scan to complete
echo 4. Press any key here to capture logs
echo.
echo Press any key when ready to start...
pause >nul

echo.
echo Clearing old logs...
adb logcat -c

echo.
echo Logs cleared. Now:
echo 1. Open the app
echo 2. Go to Registration tab
echo 3. Tap camera icon
echo 4. Scan your attendance sheet with 38 attendees
echo 5. Wait for scan to complete
echo 6. Come back here and press any key
echo.
pause

echo.
echo Capturing logs...
adb logcat -d > scanner_full_logs.txt

echo.
echo Filtering for OCR debug output...
findstr /i "ENHANCED flutter" scanner_full_logs.txt > scanner_debug.txt

echo.
echo ========================================
echo Done!
echo ========================================
echo.
echo Please share scanner_debug.txt
echo This will show:
echo - How many attendees were detected
echo - What text was recognized
echo - Why extraction failed (if it did)
echo.
pause
