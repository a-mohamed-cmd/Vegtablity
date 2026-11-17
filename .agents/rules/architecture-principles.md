---
trigger: always_on
description: مبادئ العمل المعمارية الإلزامية على مستوى جميع لغات المشروع (VB.NET WPF, Python FastAPI, Flutter Dart, SQL Server)
---

# مبادئ العمل المعمارية الإلزامية في مشروع Vegtablity

يجب الالتزام الصارم بالمبادئ التالية في جميع التعديلات والإضافات داخل المشروع وعلى مستوى أي لغة برمجة (`VB.NET`, `Python`, `Dart/Flutter`, `T-SQL`):

1. **تطبيق معمارية MVVM على مستوى كافة اللغات وحتى في SQL:**
   - **طبقة العرض (`View` — XAML / Flutter Screens):** مسؤولة فقط عن العرض المرئي والتفاعل (UI & Animations) وترتبط بـ `ViewModel` عبر الـ DataBinding والـ Commands والأحداث (`Events`)، دون أي منطق أعمال أو استعلامات.
   - **طبقة منطق العرض (`ViewModel` — VB.NET ViewModels / Flutter Providers & Controllers):** تدير الحالة (`State`) والتحقق من المدخلات والأوامر (`Commands`)، وتتواصل حصراً مع طبقة الخدمات (`Services`).
   - **طبقة الخدمات والنماذج (`Services & Models` — VB.NET Services / Python Routers & Services):** تستدعي **الإجراءات المخزنة (`Stored Procedures`) فقط** عبر `StoredProcedures.vb` (`CommandType.StoredProcedure`)، ويُمنع كتابة استعلامات SQL نصية (`Inline SQL`) داخل الكود البرمجي.
   - **طبقة قاعدة البيانات (`SQL MVVM Layer` — Stored Procedures & Triggers):** تُفصل فيها مسؤولية استرجاع وحفظ البيانات (`Stored Procedures` مع دعم الترقيم `Pagination`) عن القيود المحاسبية التلقائية والعمليات الذرية (`Triggers` المحمية بـ `Transaction / Savepoint` و`TRY...CATCH` ورسائل `RAISERROR` الإرشادية).

2. **منع التعديل المباشر على قاعدة البيانات — المصدر الوحيد للأكواد هو `SQLVegtablity.sql`:**
   - **يُمنع منعاً باتاً** تنفيذ تعديلات مباشرة على قاعدة البيانات من خارج ملف السكربت المعتمد أو تضمين أوامر `DDL / Inline SQL` داخل أكواد التطبيقات.
   - جميع الأكواد الخاصة بقاعدة البيانات (جداول `Tables`، إجراءات مخزنة `Stored Procedures`، مراقبات `Triggers`، فهارس `Indexes`) يجب أن تُكتب وتُوثّق حصراً داخل الملف المرجعي الوحيد:
     `d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql`

