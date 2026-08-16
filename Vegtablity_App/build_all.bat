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

:: 2. بناء تطبيق Android APK لشركة واشا (Washa Flavor)
echo [2/4] 📱 جاري بناء تطبيق Android APK لـ واشا (Washa Release)...
call flutter build apk --flavor washa --release
if %errorlevel% neq 0 (
    echo ❌ فشل بناء تطبيق Android APK لـ واشا.
    pause
    exit /b %errorlevel%
)
echo ✅ تم بناء تطبيق واشا بنجاح!
echo 📍 ملف APK: build\app\outputs\flutter-apk\app-washa-release.apk
echo.

:: 3. بناء تطبيق Android APK لشركة الجوهرة (Jawhara Flavor)
echo [3/4] 📱 جاري بناء تطبيق Android APK لـ الجوهرة (Jawhara Release)...
call flutter build apk --flavor jawhara --release
if %errorlevel% neq 0 (
    echo ❌ فشل بناء تطبيق Android APK لـ الجوهرة.
    pause
    exit /b %errorlevel%
)
echo ✅ تم بناء تطبيق الجوهرة بنجاح!
echo 📍 ملف APK: build\app\outputs\flutter-apk\app-jawhara-release.apk
echo.

:: 4. بناء تطبيق الويندوز لشركة واشا (Washa Windows)
echo [4/5] 💻 جاري بناء تطبيق Windows Desktop لـ واشا (Washa Release)...
call flutter build windows --release --dart-define=FLAVOR=washa
if %errorlevel% neq 0 (
    echo ❌ فشل بناء تطبيق Windows لـ واشا.
    pause
    exit /b %errorlevel%
)
if exist "build\windows_washa" rmdir /s /q "build\windows_washa"
mkdir "build\windows_washa"
xcopy /E /I /Y "build\windows\x64\runner\Release" "build\windows_washa" > nul
echo ✅ تم بناء تطبيق Windows واشا بنجاح!
echo 📍 مجلد واشا Windows: build\windows_washa\
echo.

:: 5. بناء تطبيق الويندوز لشركة الجوهرة (Jawhara Windows)
echo [5/5] 💻 جاري بناء تطبيق Windows Desktop لـ الجوهرة (Jawhara Release)...
call flutter build windows --release --dart-define=FLAVOR=jawhara
if %errorlevel% neq 0 (
    echo ❌ فشل بناء تطبيق Windows لـ الجوهرة.
    pause
    exit /b %errorlevel%
)
if exist "build\windows_jawhara" rmdir /s /q "build\windows_jawhara"
mkdir "build\windows_jawhara"
xcopy /E /I /Y "build\windows\x64\runner\Release" "build\windows_jawhara" > nul
echo ✅ تم بناء تطبيق Windows الجوهرة بنجاح!
echo 📍 مجلد الجوهرة Windows: build\windows_jawhara\
echo.

echo ========================================================
echo   🎉 تم الانتهاء من بناء جميع النسخ بنجاح!
echo ========================================================
echo.

:: فتح مجلدات المخرجات للمستخدم
start "" "build\app\outputs\flutter-apk"
start "" "build\windows_washa"
start "" "build\windows_jawhara"

pause
