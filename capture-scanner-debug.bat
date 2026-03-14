@echo off
echo Capturing recent logs...
adb logcat -d -s flutter:I flutter:D flutter:V > recent_flutter_logs.txt

echo.
echo Searching for ENHANCED OCR debug output...
findstr /i "ENHANCED OCR debug Starting image processing" recent_flutter_logs.txt > scanner_output.txt

echo.
echo Checking file size...
for %%A in (scanner_output.txt) do set size=%%~zA
if %size% EQU 0 (
    echo No scanner debug output found.
    echo.
    echo This means either:
    echo 1. You haven't scanned yet
    echo 2. The scan didn't complete
    echo 3. Debug output is not being logged
    echo.
    echo Showing last 50 flutter log lines instead:
    echo.
    powershell -Command "Get-Content recent_flutter_logs.txt | Select-Object -Last 50"
) else (
    echo Found scanner debug output!
    echo.
    type scanner_output.txt
)

echo.
echo Full logs saved to: recent_flutter_logs.txt
echo Scanner output saved to: scanner_output.txt
echo.
pause
