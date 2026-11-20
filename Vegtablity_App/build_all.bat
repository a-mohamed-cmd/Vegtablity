@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Build All Flutter Versions (Android APK + Windows Desktop)
color 0A

echo ========================================================
echo   Starting Flutter Builds (Android APK + Windows)
echo   Working Dir: %CD%
echo ========================================================
echo.

REM 1. Update packages
echo [1/5] Updating packages (flutter pub get)...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed.
    pause
    exit /b 1
)
echo [OK] Packages updated successfully.
echo.

REM 2. Build Android APK for Washa flavor
echo [2/5] Building Android APK for Washa (washa release)...
call flutter build apk --flavor washa --release
if errorlevel 1 (
    echo [ERROR] Failed to build Washa Android APK.
    pause
    exit /b 1
)
echo [OK] Washa Android APK built successfully.
echo Output: build\app\outputs\flutter-apk\app-washa-release.apk
echo.

REM 3. Build Android APK for Jawhara flavor
echo [3/5] Building Android APK for Jawhara (jawhara release)...
call flutter build apk --flavor jawhara --release
if errorlevel 1 (
    echo [ERROR] Failed to build Jawhara Android APK.
    pause
    exit /b 1
)
echo [OK] Jawhara Android APK built successfully.
echo Output: build\app\outputs\flutter-apk\app-jawhara-release.apk
echo.

REM 4. Build Windows Desktop for Washa
echo [4/5] Building Windows Desktop for Washa (washa release)...
call flutter build windows --release --dart-define=FLAVOR=washa
if errorlevel 1 (
    echo [ERROR] Failed to build Washa Windows Desktop.
    pause
    exit /b 1
)
if exist "build\windows_washa" rmdir /s /q "build\windows_washa"
mkdir "build\windows_washa"
xcopy /E /I /Y "build\windows\x64\runner\Release" "build\windows_washa" > nul
echo [OK] Washa Windows Desktop built successfully.
echo Output: build\windows_washa\
echo.

REM 5. Build Windows Desktop for Jawhara
echo [5/5] Building Windows Desktop for Jawhara (jawhara release)...
call flutter build windows --release --dart-define=FLAVOR=jawhara
if errorlevel 1 (
    echo [ERROR] Failed to build Jawhara Windows Desktop.
    pause
    exit /b 1
)
if exist "build\windows_jawhara" rmdir /s /q "build\windows_jawhara"
mkdir "build\windows_jawhara"
xcopy /E /I /Y "build\windows\x64\runner\Release" "build\windows_jawhara" > nul
echo [OK] Jawhara Windows Desktop built successfully.
echo Output: build\windows_jawhara\
echo.

echo ========================================================
echo   All builds completed successfully!
echo ========================================================
echo.

REM Open output folders safely
if exist "%CD%\build\app\outputs\flutter-apk" start "" explorer.exe "%CD%\build\app\outputs\flutter-apk"
if exist "%CD%\build\windows_washa" start "" explorer.exe "%CD%\build\windows_washa"
if exist "%CD%\build\windows_jawhara" start "" explorer.exe "%CD%\build\windows_jawhara"

pause
endlocal
