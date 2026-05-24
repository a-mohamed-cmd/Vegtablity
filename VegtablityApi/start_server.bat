@echo off
Title Vegtabilty Api Server

:: الانتقال لمسار الملف الحالي لضمان التشغيل الصحيح عند الضغط عليه مرتين
cd /d "%~dp0"

:: تفعيل البيئة الوهمية (لاحظ النقطة قبل venv لأن مجلدك اسمه .venv)
call .\.venv\Scripts\activate.bat

:: تشغيل السيرفر مع توجيه المخرجات
:: >> log.txt يحفظ الرسائل العادية
:: 2>> error.txt يحفظ رسائل الخطأ فقط
echo Starting Server at %DATE% %TIME% >> log.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 >> log.txt 2>> error.txt

:: لمنع الشاشة من الإغلاق مباشرة في حال حدوث خطأ قبل تشغيل السيرفر
pause
