# خطة العمل: إنشاء شاشة الورديات (Shifts Page)

## 1. الهيكل والبيانات (Database & SQL)
### أ- جدول الورديات (Shifts Table)
```sql
CREATE TABLE [Sales].[Shifts] (
    [ShiftID] INT IDENTITY(1,1) PRIMARY KEY,
    [UserID] INT NOT NULL,
    [StartTime] DATETIME NOT NULL DEFAULT GETDATE(),
    [EndTime] DATETIME NULL,
    [StartingCash] DECIMAL(18, 3) NOT NULL DEFAULT 0,
    [EndingCash] DECIMAL(18, 3) NULL,
    [Status] NVARCHAR(20) NOT NULL DEFAULT 'Open' -- 'Open', 'Closed'
);
```
*(ملاحظة: تم جعل المبالغ `DECIMAL(18,3)` لتوحيد الصيغة مع باقي النظام).*

**العلاقات (Relationships):**
- جميع جداول الفواتير (مبيعات ومشتريات) وجداول السندات (صرف وقبض) تحتوي بالفعل على عمود `ShiftID` مربوط كـ Foreign Key بجدول `[Sales].[Shifts]`، مما يسهل جلب الحركات المرتبطة بكل وردية بدقة.

### ب- الإجراءات المخزنة (Stored Procedures)
بعد تحليل `VegtablityApi` والـ API الخاص بنقاط البيع (POS)، تبين وجود العديد من الإجراءات الجاهزة والتي سيتم إعادة استخدامها مباشرة لتوفير الوقت وضمان توافق سطح المكتب مع الموبايل:

**الإجراءات المتوفرة مسبقاً في قاعدة البيانات:**
1. `[Sales].[sp_Shift_GetSummary]`: يجلب تفاصيل الوردية وإجمالياتها (المبيعات، المشتريات، المبالغ، إلخ).
2. `[Sales].[sp_Shift_GetVouchers]`: يجلب السندات المرتبطة برقم الوردية.
3. `[Sales].[sp_Invoice_GetAll_Pos]`: يمكن استخدامه لجلب الفواتير المرتبطة بالوردية (يستقبل `ShiftID` و `InvType`).

**الإجراءات الجديدة المطلوبة فقط:**
1. `[Sales].[sp_Shift_GetAll]`: هذا الإجراء غير موجود في الـ API لأنه مخصص للإدارة (سطح المكتب) لعرض "قائمة كل الورديات" السابقة والحالية مع إمكانية الفلترة بالتواريخ أو المستخدم.

سيتم إضافة ثوابت لهذه الإجراءات في ملف `Helpers/StoredProcedures.vb`.

## 2. الطبقة الخدمية (Services Layer)
سيتم إنشاء كلاس `ShiftService.vb` يحتوي على:
- `GetAllShifts()`
- `GetShiftDetails(shiftID)` (يجلب الفواتير والسندات للوردية عن طريق استدعاء `InvoiceService` و `VoucherService`).

## 3. طبقة العرض والتحكم (UI & MVVM)
### أ- الـ ViewModel (`ShiftsViewModel.vb`)
سيحتوي على:
- `Shifts`: قائمة الورديات `ObservableCollection`.
- `SelectedShift`: الوردية المحددة.
- `ShiftInvoices`, `ShiftVouchers`: تفاصيل الحركات المرتبطة.
- أوامر الانتقال `RequestOpenInvoice`, `RequestOpenVoucher`.

### ب- الشاشة (`ShiftsPage.xaml` & `.vb`)
تصميم عصري يتكون من:
- **قائمة الورديات:** على الجانب الأيمن (رقم الوردية، وقت الفتح، الإغلاق، الحالة).
- **التفاصيل (Master-Detail):** عند الضغط على الوردية يظهر في الجانب الأيسر علامات تبويب (Tabs) تحتوي على الفواتير والسندات التي حدثت في تلك الوردية.
- **إجراءات التفاصيل:** يمكن الضغط نقراً مزدوجاً (أو زر عرض) على فاتورة أو سند لفتحه بشاشته الأصلية.

## 4. نظام الصلاحيات والأمان (Permissions System)
ستخضع شاشة الورديات لنظام الصلاحيات الموحد المبني في النظام (Role-Based Access Control):
- **معرف الشاشة (FormName):** سيتم استخدام المعرف `"Shifts"` لتمثيل الشاشة في قاعدة بيانات الصلاحيات (`RolePermissions`).
- **القائمة الجانبية (Sidebar):** سيتم إضافة الشاشة كـ `MenuItem` في `DashboardViewModel.vb`. سيقوم النظام تلقائياً باستدعاء `_permissionService.CanViewForm(RoleID, "Shifts")`، وإذا لم يمتلك المستخدم الصلاحية، سيتم إخفاء الزر تماماً من القائمة الجانبية.
- **التوجيه (Navigation):** عند النقر، سيتم تمرير توجيه لفتح `Views.ShiftsPage` فقط إذا تم التأكد من صلاحية العرض (View).

## 5. الخطوات المقترحة للتنفيذ
1. إنشاء الإجراء المخزن المتبقي `sp_Shift_GetAll`.
2. إضافة ثوابت الـ SPs الجديدة في `StoredProcedures.vb`.
3. إنشاء نموذج `Shift.vb` ومزود الخدمة `ShiftService.vb` في الـ VB.NET.
4. إنشاء وتصميم `ShiftsPage.xaml` و `ShiftsViewModel.vb`.
5. تعديل `DashboardViewModel.vb` لإضافة "الورديات" للقائمة الجانبية وربط التوجيه والصلاحيات.
