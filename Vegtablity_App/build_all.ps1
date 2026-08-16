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

# 2. بناء الأندرويد APK لشركة واشا
Write-Host "[2/4] 📱 جاري بناء تطبيق Android APK لـ واشا (Washa Release)..." -ForegroundColor Yellow
flutter build apk --flavor washa --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل بناء تطبيق Android APK لـ واشا." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ تم بناء تطبيق واشا بنجاح!" -ForegroundColor Green
Write-Host "📍 المسار: build\app\outputs\flutter-apk\app-washa-release.apk" -ForegroundColor DarkGray
Write-Host ""

# 3. بناء الأندرويد APK لشركة الجوهرة
Write-Host "[3/4] 📱 جاري بناء تطبيق Android APK لـ الجوهرة (Jawhara Release)..." -ForegroundColor Yellow
flutter build apk --flavor jawhara --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل بناء تطبيق Android APK لـ الجوهرة." -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "✅ تم بناء تطبيق الجوهرة بنجاح!" -ForegroundColor Green
Write-Host "📍 المسار: build\app\outputs\flutter-apk\app-jawhara-release.apk" -ForegroundColor DarkGray
Write-Host ""

# 4. بناء تطبيق الويندوز لشركة واشا
Write-Host "[4/5] 💻 جاري بناء تطبيق Windows Desktop لـ واشا (Washa Release)..." -ForegroundColor Yellow
flutter build windows --release --dart-define=FLAVOR=washa
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل بناء تطبيق Windows لـ واشا." -ForegroundColor Red
    exit $LASTEXITCODE
}
if (Test-Path "build\windows_washa") { Remove-Item -Recurse -Force "build\windows_washa" }
New-Item -ItemType Directory -Force -Path "build\windows_washa" | Out-Null
Copy-Item -Recurse -Force "build\windows\x64\runner\Release\*" "build\windows_washa"
Write-Host "✅ تم بناء تطبيق Windows واشا بنجاح!" -ForegroundColor Green
Write-Host "📍 المسار: build\windows_washa\" -ForegroundColor DarkGray
Write-Host ""

# 5. بناء تطبيق الويندوز لشركة الجوهرة
Write-Host "[5/5] 💻 جاري بناء تطبيق Windows Desktop لـ الجوهرة (Jawhara Release)..." -ForegroundColor Yellow
flutter build windows --release --dart-define=FLAVOR=jawhara
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ فشل بناء تطبيق Windows لـ الجوهرة." -ForegroundColor Red
    exit $LASTEXITCODE
}
if (Test-Path "build\windows_jawhara") { Remove-Item -Recurse -Force "build\windows_jawhara" }
New-Item -ItemType Directory -Force -Path "build\windows_jawhara" | Out-Null
Copy-Item -Recurse -Force "build\windows\x64\runner\Release\*" "build\windows_jawhara"
Write-Host "✅ تم بناء تطبيق Windows الجوهرة بنجاح!" -ForegroundColor Green
Write-Host "📍 المسار: build\windows_jawhara\" -ForegroundColor DarkGray
Write-Host ""

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  🎉 تم الانتهاء من بناء جميع النسخ بنجاح!" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# فتح مجلدات المخرجات
if (Test-Path "build\app\outputs\flutter-apk") {
    Invoke-Item "build\app\outputs\flutter-apk"
}
if (Test-Path "build\windows_washa") {
    Invoke-Item "build\windows_washa"
}
if (Test-Path "build\windows_jawhara") {
    Invoke-Item "build\windows_jawhara"
}
