@echo off
REM Smart Energy System - Test Runner Script for Windows
REM This script runs all unit tests with detailed output

echo ========================================
echo Smart Energy System - Unit Test Runner
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo Please install Flutter from https://flutter.dev
    pause
    exit /b 1
)

echo Running all unit tests...
echo.

REM Run tests with expanded reporter for detailed output
flutter test --reporter expanded

echo.
echo ========================================
echo Test execution completed!
echo ========================================
echo.

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo All tests PASSED! ✓
) else (
    echo Some tests FAILED! ✗
)

echo.
pause
