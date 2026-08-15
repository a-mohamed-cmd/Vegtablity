@echo off
chcp 65001 > nul
title بناء جميع نسخ Flutter (Android APK + Windows Desktop)
color 0A

echo ========================================================
echo   🚀 بدء عملية بناء تطبيقات Flutter (Android + Windows)
echo ========================================================
echo.

:: 1. تحديث الحزم
echo [1/3] 📦 جاري تحديث حزم المشروع (flutter pub get)...
call flutter pub get
if %errorlevel% neq 0 (
    echo ❌ فشل في جلب الحزم.
    pause
    exit /b %errorlevel%
)
echo ✅ تم تحديث الحزم بنجاح.
echo.

:: 2. بناء تطبيق الأندرويد APK
echo [2/3] 📱 جاري بناء تطبيق Android APK (Release)...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo ❌ فشل بناء تطبيق Android APK.
    pause
    exit /b %errorlevel%
)
echo ✅ تم بناء تطبيق Android APK بنجاح!
echo 📍 مسار ملف APK: build\app\outputs\flutter-apk\app-release.apk
echo.

:: 3. بناء تطبيق الويندوز Windows EXE
echo [3/3] 💻 جاري بناء تطبيق Windows Desktop (Release)...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo ❌ فشل بناء تطبيق Windows Desktop.
    pause
    exit /b %errorlevel%
)
echo ✅ تم بناء تطبيق Windows Desktop بنجاح!
echo 📍 مسار مجلد Windows: build\windows\x64\runner\Release\
echo.

echo ========================================================
echo   🎉 تم الانتهاء من بناء جميع النسخ بنجاح!
echo ========================================================
echo.

:: فتح مجلدات المخرجات للمستخدم
start "" "build\app\outputs\flutter-apk"
start "" "build\windows\x64\runner\Release"

pause
