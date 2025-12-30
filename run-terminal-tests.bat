@echo off
REM Terminal Testing Framework - Easy execution script for Windows
REM This script runs the terminal testing framework with comprehensive error handling

setlocal enabledelayedexpansion

echo ========================================
echo   Terminal Testing Framework
echo ========================================
echo.

REM Check if we're in the correct directory
if not exist "lib\terminal_testing\cli\main.dart" (
    echo Error: Terminal testing framework not found in current directory
    echo Please run this script from the Flutter project root directory
    echo Expected file: lib\terminal_testing\cli\main.dart
    echo.
    pause
    exit /b 1
)

REM Check if Dart is available
echo Checking Dart installation...
dart --version >nul 2>&1
if errorlevel 1 (
    echo Error: Dart is not installed or not in PATH
    echo.
    echo Please install Flutter/Dart and ensure it's in your PATH:
    echo 1. Download Flutter from https://flutter.dev/docs/get-started/install
    echo 2. Add Flutter bin directory to your PATH
    echo 3. Run 'flutter doctor' to verify installation
    echo.
    pause
    exit /b 1
)

REM Display Dart version for confirmation
for /f "tokens=*" %%i in ('dart --version 2^>^&1') do set DART_VERSION=%%i
echo Found: !DART_VERSION!
echo.

REM Check if help was requested
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help

REM Display what we're about to run
if "%*"=="" (
    echo Running all terminal tests with default settings...
) else (
    echo Running terminal tests with arguments: %*
)
echo.

REM Run the terminal testing framework
echo Starting test execution...
echo ----------------------------------------
dart run lib/terminal_testing/cli/main.dart %*
set TEST_EXIT_CODE=!errorlevel!

echo ----------------------------------------
echo.

REM Check exit code and provide user-friendly feedback
if !TEST_EXIT_CODE! equ 0 (
    echo ^[SUCCESS^] All tests completed successfully!
    echo Exit code: 0
) else (
    echo ^[FAILURE^] Tests completed with failures or errors.
    echo Exit code: !TEST_EXIT_CODE!
    echo.
    echo Troubleshooting tips:
    echo - Check the test output above for specific failure details
    echo - Run with --verbose for more detailed information
    echo - Use --dry-run to validate test setup
    echo - Run specific categories with --category ^<name^>
)

echo.
echo Run 'run-terminal-tests.bat --help' for usage information.
pause
exit /b !TEST_EXIT_CODE!

:show_help
echo Usage: run-terminal-tests.bat [OPTIONS]
echo.
echo This script runs the Terminal Testing Framework for the Flutter attendance app.
echo All command-line options are passed directly to the testing framework.
echo.
echo Common options:
echo   --help              Show detailed help information
echo   --verbose           Enable verbose output
echo   --quiet             Enable quiet mode
echo   --category ^<name^>   Run specific test category
echo   --timeout ^<sec^>     Set custom timeout
echo   --dry-run           Validate setup without running tests
echo.
echo Examples:
echo   run-terminal-tests.bat
echo   run-terminal-tests.bat --category auth
echo   run-terminal-tests.bat --verbose --timeout 60
echo   run-terminal-tests.bat --dry-run
echo.
echo For complete documentation, run:
echo   run-terminal-tests.bat --help
echo.
pause
exit /b 0