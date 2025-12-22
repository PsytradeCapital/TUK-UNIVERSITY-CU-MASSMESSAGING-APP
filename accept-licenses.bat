@echo off
echo Accepting Android SDK licenses...
(echo y & echo y & echo y & echo y & echo y & echo y & echo y) | "C:\android-sdk\cmdline-tools\bin\sdkmanager.bat" --sdk_root="C:\android-sdk" --licenses
echo.
echo Licenses accepted!
pause
