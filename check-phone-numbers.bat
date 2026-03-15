@echo off
echo ========================================
echo Checking Phone Numbers in Database
echo ========================================
echo.
echo This will show what phone numbers are stored
echo and why they might be failing validation.
echo.
echo Starting app and capturing logs...
adb logcat -c
adb shell am start -n com.example.christian_union_attendance_app/.MainActivity
timeout /t 5 >nul
echo.
echo Navigating to messaging screen...
echo Please go to Messaging tab now and try to send a message
echo.
pause
echo.
echo Capturing validation logs...
adb logcat | findstr "SMS Validation Invalid phone" > phone_validation_debug.txt
echo.
echo ========================================
echo Done! Check phone_validation_debug.txt
echo ========================================
echo.
echo This file will show:
echo - How many valid vs invalid numbers
echo - Exact format of each invalid number
echo - Why each number failed validation
echo.
pause
