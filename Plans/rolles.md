# القواعد الهندسية والمعمارية الإلزامية لبناء وتطوير نظام Vegtablity (`Rules`)

هذا الملف هو المرجع الإلزامي لجميع التعديلات والإضافات البرمجية وقواعد البيانات في منظومة **Vegtablity ERP & POS** عبر كافة المنصات (**WPF / VB.NET**، **FastAPI / Python**، **Flutter / Dart**، **SQL Server / T-SQL**).

---

## 1. تطبيق معمارية MVVM على كافة اللغات والطبقات

يجب الفصل الصارم بين المسؤوليات في جميع الوحدات والشاشات:

1. **طبقة العرض (`View` — XAML / Flutter Screens & Widgets):**
   - مسؤولة فقط عن العرض المرئي والتنسيق وتجربة المستخدم والتفاعل (`UI & Animations`).
   - ترتبط بـ `ViewModel` عبر `DataBinding` و`Commands` و`Provider` دون احتواء أي منطق أعمال أو استعلامات قاعدة بيانات أو اتصال مباشر بالشبكة.
   - عزل الحوارات والنوافذ القابلة لإعادة الاستخدام في Widgets/Views مستقلة لمنع تكرار الكود.

2. **طبقة منطق العرض (`ViewModel` — VB.NET ViewModels / Flutter Providers & ViewModels):**
   - تدير الحالة (`State`) والتحقق من صحة المدخلات (`Validation`) والأوامر (`Commands`) وإدارة الانشغال والأخطاء.
   - تتواصل **حصراً** مع طبقة الخدمات (`Services`) ولا تكتب أوامر SQL أو HTTP مباشرة.

3. **طبقة الخدمات والنماذج (`Services & Models` — VB.NET Services / Python Services & Routes / Flutter Services):**
   - تمثل النماذج (`Models`) هياكل البيانات النظيفة.
   - تتولى الخدمات استدعاء الإجراءات المخزنة (`Stored Procedures`) أو نقاط نهاية الـ API فقط، مع عزل بوابات الدفع ومنصات التوصيل في كلاسات مستقلة لكل مزود (مثل `TapPaymentProvider`، `MyFatoorahProvider`، `MyFatoorahGateway`، `MyFatoorahGatewayService`).

4. **طبقة قاعدة البيانات (`SQL MVVM Layer` — Views / Stored Procedures / Event Triggers):**
   - تُفصل فيها إجراءات القراءة والحفظ (`Stored Procedures`) عن ردود الفعل والأحداث التلقائية (`Triggers`) بحيث يتخصص كل مكون في مسؤولية واحدة واضحة.

---

## 2. المصدر الوحيد لقاعدة البيانات ومنع التعديل المباشر

- **يُمنع منعاً باتاً** تنفيذ أي تعديل مباشر على قاعدة البيانات الحية من خارج السكربت المرجعي المعتمد، أو تضمين أوامر `DDL` أو استعلامات SQL نصية (`Inline SQL`) داخل أكواد التطبيقات (`VB.NET` / `Python` / `Dart`).
- **الملف المرجعي الوحيد والكامل لقاعدة البيانات هو:**
  `d:\VB.NET\backup\Vegtablity\Vegtablity\Vegtablity\SQL\SQLVegtablity.sql`
- **قاعدة الحفاظ الكامل دون أي فقد:**
  - يجب أن يعبّر ملف `SQLVegtablity.sql` بالكامل وبشكل مستقل عن كامل بنية قاعدة البيانات (جداول، إجراءات مخزنة، تريجرات، فهارس، تسلسلات، وبيانات تأسيسية).
  - **يُمنع حذف أو اقتطاع** أي أجزاء أو كائنات قائمة من الملف عند التعديل؛ يتم التعديل بالإلحاق أو التحديث الآمن القابل لإعادة التشغيل (`Idempotent`: `IF OBJECT_ID(...) IS NOT NULL DROP ...` ثم `CREATE ...`).
  - يجب فحص الملف بعد كل تعديل عبر `TSql160Parser` ومراجعة `git diff` للتأكد من عدم فقد أي سطر أو حدوث أخطاء نحوية.

---

## 3. أفضل وأسرع طرق الاتصال بقاعدة البيانات وتنفيذ الإجراءات

1. **WPF (VB.NET):**
   - جميع الإجراءات المخزنة تُسجّل كثوابت داخل `Vegtablity\Helpers\StoredProcedures.vb`.
   - يُنفّذ الاتصال عبر `_dbHelper.GetConnection()` واستخدام **Dapper** مع تمرير `commandType:=CommandType.StoredProcedure` حصراً (أعلى سرعة في تحويل النتائج مع منع الحقن وضمان إعادة استخدام خطط التنفيذ `Execution Plans`).
   - استخدام `QueryMultiple` عند الحاجة لأكثر من نتيجة في رحلة شبكة واحدة (`Single Round-Trip`).

2. **FastAPI (Python):**
   - جميع الإجراءات المخزنة تُسجّل كثوابت داخل `VegtablityApi\app\core\db_procedures.py`.
   - التنفيذ عبر `get_db_connection()` و`pyodbc` باستخدام `EXEC [Schema].[sp_Name] ...` مع معلمات مرتبطة (`Parameterized`)، وإغلاق `cursor` و`conn` دائماً في كتلة `finally` مع `commit()` الصريح عند النجاح و`rollback()` عند الخطأ.

3. **الأداء على مستوى SQL Server:**
   - إلزامية `SET NOCOUNT ON;` في بداية كل `Stored Procedure` و`Trigger` لتقليل حزم الشبكة وتحسين السرعة.
   - دعم الترقيم من الخادم (`Server-Side Pagination` عبر `OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY`) في شاشات السجلات والفواتير الكبيرة.
   - استخدام الفهارس المناسبة (`Indexes`) والـ `CURSOR LOCAL FAST_FORWARD` فقط عند الضرورة القصوى على دفعات صغيرة، وتفضيل العمليات المجموعية (`Set-Based Operations`) دائماً.

4. **Flutter (Dart):**
   - الاتصال عبر `Dio` داخل `ApiService` والخدمات المعزولة، مع دعم الكاش المحلي الآمن (`SharedPreferences`) وتنقية البيانات الحساسة، وعرض أخطاء قاعدة البيانات بوضوح للمستخدم عبر `DbErrorHelper` و`AppSnackBar`.

---

## 4. الأولوية للـ Triggers وتقسيمها إلى Stored Procedures حسب الأحداث (SQL MVVM)

1. **الأفضلية للـ Trigger في الأحداث التلقائية:**
   - أي عملية مترابطة ناتجة عن تغيير حالة أو إدخال أو حذف (مثل: القيود المحاسبية التلقائية، خصم/إرجاع المخزون، ترحيل الفواتير والسندات عند إغلاق الوردية، أرشفة الفواتير المحذوفة، عكس القيود عند الاسترداد أو التراجع) **تُنفّذ داخل `TRIGGER`** وليس مبعثرة في أكواد التطبيقات أو مكررة داخل الـ SP المُحدِّث، وذلك لضمان الذرية ووحدة المعالجة عبر جميع المنصات (WPF / API / Flutter).
   - **منع الازدواجية:** إذا كان الـ `Trigger` ينفذ أثراً محاسبياً أو ترحيلياً عند حدث معين (مثل تغيير `Status = 'Closed'` أو تغيير `LinkStatus = 'Paid'`)، يُمنع تكرار نفس المنطق داخل الـ `Stored Procedure` المُسبِّب للحدث.

2. **تقسيم التريجر حسب الأحداث إلى إجراءات مخزنة مستقلة (`Event SPs`):**
   - يعمل الـ `Trigger` كطبقة تنسيق (`Coordinator`) فقط:
     - يتحقق سريعاً من الشروط (`IF NOT UPDATE(...) RETURN;`).
     - يلتقط البيانات المتأثرة من `inserted` / `deleted`.
     - **يُقسم التنفيذ** باستدعاء `Stored Procedure` مخصص وواضح لكل حدث فرعي:
       - مثال: حدث إرجاع حالة أو أرشفة أو تسوية يستدعي إجراءً مخزناً مستقلاً مثل:
         - `[Sales].[sp_CancelledInvoice_SaveSnapshot]` داخل `[Sales].[trg_InvoiceHeader_DeleteCascade]`
         - `[Sales].[sp_InvoicePaymentLink_RevertToPending]` داخل `[Sales].[trg_InvoicePaymentLinks_OnStatusRefunded]`
   - هذا التقسيم يسهّل الصيانة، يمنع تضخم التريجرات، ويحقق مبدأ **MVVM** حتى داخل قاعدة البيانات.

---

## 5. الاستخدام الإلزامي للمعاملات (`Transactions`) في جميع أكواد SQL

كل `Stored Procedure` أو `Trigger` يتضمن عمليات تعديل بيانات (`INSERT` / `UPDATE` / `DELETE`) **يجب** أن يكون محمياً بالكامل بمعاملة ذرية (`Transaction`) ونقاط حفظ (`Savepoints`) لمنع التعديل الجزئي أو تلف البيانات أو تجميد المعاملات:

```sql
SET NOCOUNT ON;

DECLARE @TranCounter INT = @@TRANCOUNT;
IF @TranCounter > 0
    SAVE TRANSACTION SavePoint_Name;
ELSE
    BEGIN TRANSACTION;

BEGIN TRY
    -- 1. التحقق من المدخلات والصلاحيات وقواعد العمل
    -- 2. تنفيذ العمليات الذرية أو استدعاء إجراءات الأحداث

    IF @TranCounter = 0
        COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @TranCounter = 0
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END
    ELSE IF XACT_STATE() <> -1
    BEGIN
        ROLLBACK TRANSACTION SavePoint_Name;
    END

    DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE(),
            @ErrSev   INT            = ERROR_SEVERITY(),
            @ErrState INT            = ERROR_STATE();
    RAISERROR(@ErrMsg, @ErrSev, @ErrState);
END CATCH
```

### ضوابط المعاملات (`Transaction Rules`):
- لا يُترك أي `BEGIN TRANSACTION` بدون معالجة في `CATCH`.
- احترام المعاملة الخارجية (`@@TRANCOUNT > 0`) عبر `SAVE TRANSACTION` داخل الإجراءات الفرعية والتريجرات، مع الحذر عند استدعاء إجراءات تحتوي على `ROLLBACK TRANSACTION` كامل داخل تريجر.
- تمرير رسائل أخطاء إرشادية واضحة باللغة العربية عبر `RAISERROR(..., 16, 1)` أو `THROW` حتى تظهر للمستخدم بصورة مفهومة في WPF وFlutter.
- التحقق من عدم وجود معاملات أو Cursors مفتوحة في `CATCH` (`CURSOR_STATUS('local', ...)`).

---

## 6. الاستخدام الهجين والانتقائي لـ `JSON` في عمليات قواعد البيانات

يُعتمد **النهج الهجين (`Hybrid Relational + JSON`)** لتحقيق أقصى سرعة وأقل عدد من رحلات الاتصال دون التضحية بقوة الفهرسة والعلاقات:

1. **متى يُستخدم `JSON` (`OPENJSON` / `FOR JSON PATH`)؟**
   - **حفظ وتعديل البيانات المركّبة (`Master-Detail`):** عند إرسال رأس + تفاصيل أو قوائم متعددة (بنود الفواتير، توزيعات الدفع، تفاصيل الجرد، الروابط المجمعة)، يُمرّر المصفوف كمعامل `@ItemsJson NVARCHAR(MAX)` وفكّه دفعة واحدة داخل `Stored Procedure` عبر `OPENJSON(@ItemsJson) WITH (...)` (مع التحقق أولاً بـ `ISJSON(@ItemsJson) = 1`) داخل نفس الـ `Transaction` في **رحلة شبكة واحدة (`Single Round-Trip`)** بدلاً من التكرار (`Loop`) أو الـ `XML`، لضمان التوافق السريع والمباشر مع `Dapper` (VB.NET) و`pyodbc` (FastAPI).
   - **الأرشفة ولقطات التدقيق (`Snapshots` / `Audit`):** حفظ نسخة كاملة من السجلات المحذوفة أو الحمولات الخارجية بصيغة `FOR JSON PATH` في جداول أرشيف مستقلة (مثل `[Sales].[CancelledInvoicesArchive]`).

2. **متى يُمنع استخدام `JSON` وتُعتمد المعاملات العلائقية الصريحة؟**
   - **تخزين الجداول التشغيلية والتقارير:** تُحفظ الحقول الأساسية والمبالغ (`DECIMAL(18,3)`) والمفاتيح الأجنبية في أعمدة علائقية مفهرسة حصراً لضمان `Foreign Keys` و`Index Seek` وسرعة التقارير والقيود المحاسبية.
   - **عمليات البحث والترقيم (`Pagination` & `Search`) والعمليات المفردة (`GetByID`, `Post`, `Delete`):** تُمرر معاملات قياسية واضحة الأنواع (`Typed Parameters`) للحفاظ على كفاءة خطط التنفيذ (`Execution Plans`).

```sql
-- مثال معياري لحفظ تفاصيل مركبة بـ OPENJSON داخل Transaction
IF ISNULL(@DetailsJson, N'') <> N'' AND ISJSON(@DetailsJson) = 1
BEGIN
    INSERT INTO [Sales].[InvoiceDetails] (InvID, ProductID, Quantity, UnitPrice, TotalPrice)
    SELECT @InvID, j.ProductID, j.Quantity, j.UnitPrice, j.TotalPrice
    FROM OPENJSON(@DetailsJson)
    WITH (
        ProductID  INT            '$.ProductID',
        Quantity   DECIMAL(18, 3) '$.Quantity',
        UnitPrice  DECIMAL(18, 3) '$.UnitPrice',
        TotalPrice DECIMAL(18, 3) '$.TotalPrice'
    ) j;
END
```

---

## 7. قائمة التحقق قبل تسليم أي تعديل (Verification Checklist)

1. **SQL (`SQLVegtablity.sql`):**
   - فحص عبر `TSql160Parser` بنتيجة `TSQL_ERRORS=0`.
   - مراجعة `git diff --stat` للتأكد من `0 deletions` غير مقصودة والحفاظ على كامل الملف.
2. **WPF (VB.NET):**
   - البناء عبر `MSBuild.exe` بدون أخطاء، والتأكد من تسجيل أي ملف `.vb` جديد داخل `Vegtablity.vbproj` وأي إجراء جديد داخل `StoredProcedures.vb`.
3. **FastAPI (Python):**
   - التحقق عبر `py_compile` وتشغيل الاختبارات المعنية دون أي SQL نصي مضاف.
4. **Flutter (Dart):**
   - الفحص عبر `flutter analyze --no-pub` بدون أخطاء برمجية، ومراعاة الدقة العشرية (`3` خانات للعملة `KWD`) وعرض رسائل الخطأ عبر `DbErrorHelper`.

