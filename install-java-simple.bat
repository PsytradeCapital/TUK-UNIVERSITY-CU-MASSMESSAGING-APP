@echo off
echo Installing Java JDK for Android development...
echo.

REM Check if chocolatey is available
choco --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Chocolatey not found. Installing Java manually...
    echo Please download Java JDK from: https://adoptium.net/
    echo After installing Java, run this script again.
    pause
    exit /b 1
)

echo Installing OpenJDK 17...
choco install openjdk17 -y

echo.
echo Setting JAVA_HOME...
for /f "tokens=*" %%i in ('where java 2^>nul') do set JAVA_PATH=%%i
if defined JAVA_PATH (
    for %%i in ("%JAVA_PATH%") do set JAVA_HOME=%%~dpi..
    setx JAVA_HOME "%JAVA_HOME%" /M
    echo JAVA_HOME set to: %JAVA_HOME%
) else (
    echo Java installation may have failed. Please check manually.
)

echo.
echo Java installation complete!
echo Now you can continue with Android SDK setup.
pause