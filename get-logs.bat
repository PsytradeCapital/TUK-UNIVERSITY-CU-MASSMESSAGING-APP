@echo off
echo Clearing logs...
adb logcat -c

echo Starting app...
adb shell am force-stop com.example.christian_union_attendance_app
timeout /t 2 /nobreak >nul
adb shell am start -n com.example.christian_union_attendance_app/.MainActivity

echo Waiting 10 seconds for app to initialize...
timeout /t 10 /nobreak

echo Capturing logs...
adb logcat -d > full_logs.txt

echo.
echo Logs saved to full_logs.txt
echo.
echo Filtering for important messages...
findstr /i "BackgroundSyncService ENHANCED flutter Error Exception" full_logs.txt > filtered_logs.txt

echo.
echo Filtered logs saved to filtered_logs.txt
echo.
echo Done! Please share filtered_logs.txt
pause
