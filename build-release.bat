@echo off
echo ========================================
echo Smart Energy System - Release Builder
echo ========================================
echo.

:: Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter is not installed or not in PATH
    pause
    exit /b 1
)

echo [1/5] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)

echo.
echo [2/5] Cleaning previous builds...
call flutter clean
call flutter pub get

echo.
echo [3/5] Building Android APK...
call flutter build apk --release
if errorlevel 1 (
    echo ERROR: Android APK build failed
    pause
    exit /b 1
)

echo.
echo [4/5] Building Android App Bundle...
call flutter build appbundle --release
if errorlevel 1 (
    echo ERROR: Android App Bundle build failed
    pause
    exit /b 1
)

echo.
echo [5/5] Building Windows app...
call flutter build windows --release
if errorlevel 1 (
    echo ERROR: Windows build failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo Build outputs:
echo - Android APK: build\app\outputs\flutter-apk\app-release.apk
echo - App Bundle:  build\app\outputs\bundle\release\app-release.aab
echo - Windows:     build\windows\x64\runner\Release\
echo.
echo To create a release:
echo 1. Tag your commit: git tag v1.0.0
echo 2. Push the tag:    git push origin v1.0.0
echo 3. GitHub Actions will automatically create a release
echo.
pause
