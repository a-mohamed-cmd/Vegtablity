# سكربت بناء جميع نسخ تطبيق Flutter (Android APK + Windows Desktop)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  🚀 بدء عملية بناء تطبيقات Flutter (Android + Windows)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. تحديث الحزم
Write-Host "[1/3] 📦 جاري تحديث الحزم (flutter pub get)..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل في جلب الحزم." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ تم تحديث الحزم بنجاح." -ForegroundColor Green
Write-Host ""

# 2. بناء الأندرويد APK
Write-Host "[2/3] 📱 جاري بناء تطبيق Android APK (Release)..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل بناء تطبيق Android APK." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ تم بناء تطبيق Android APK بنجاح!" -ForegroundColor Green
Write-Host "📍 المسار: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor DarkGray
Write-Host ""

# 3. بناء الويندوز
Write-Host "[3/3] 💻 جاري بناء تطبيق Windows Desktop (Release)..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل بناء تطبيق Windows Desktop." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ تم بناء تطبيق Windows Desktop بنجاح!" -ForegroundColor Green
Write-Host "📍 المسار: build\windows\x64\runner\Release\" -ForegroundColor DarkGray
Write-Host ""

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  🎉 تم الانتهاء من بناء جميع النسخ بنجاح!" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# فتح مجلدات المخرجات
if (Test-Path "build\app\outputs\flutter-apk") {
    Invoke-Item "build\app\outputs\flutter-apk"
}
if (Test-Path "build\windows\x64\runner\Release") {
    Invoke-Item "build\windows\x64\runner\Release"
}
