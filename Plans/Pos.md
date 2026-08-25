# خطة تطوير نظام POS (Point of Sale) المتكامل
## التقنيات المستخدمة:
*   **الواجهة الأمامية (Frontend):** Flutter (لضمان العمل على Android, iOS, Windows, and Web).
*   **الواجهة الخلفية (Backend):** FastAPI (Python) لسرعة الأداء والتوافق مع الـ SQL Server.
*   **قاعدة البيانات:** SQL Server (VegtablityDB) عبر الإجراءات المخزنة (Stored Procedures) القائمة.

---

## 📌 الفهرس العام للصفحات والملفات والكلاسات المضافة حديثاً (Index of Recent Additions)

### 1. الصفحات الجديدة والمعدلة (Added & Modified Pages / Screens):
*   **نافذة التحديث التلقائي لسطح المكتب (جديدة):** [UpdateAvailableDialog.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/UpdateAvailableDialog.xaml) - نافذة عصرية لعرض تفاصيل الإصدار الجديد وملاحظات التحديث وشريط تقدم التنزيل الفوري.
*   **نافذة حوار التحديث التلقائي للموبايل (جديدة):** [UpdateDialog](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/widgets/update_dialog.dart) - نافذة تفاعلية لتنزيل حزم الـ APK وتثبيتها تلقائياً عبر `open_filex`.
*   **شاشة تسجيل الدخول والشاشة الرئيسية لسطح المكتب (معدلة):** [LoginWindow.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/LoginWindow.xaml.vb) & [DashboardWindow.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/DashboardWindow.xaml.vb) - فحص السيرفر تلقائياً عند بدء التشغيل وإظهار نافذة التحديث فوراً عند توفر إصدار أحدث.
*   **شاشة إعدادات الطابعة الحرارية (معدلة):** [PrinterSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/printer_settings_screen.dart) - إضافة خيار تحديد نمط طباعة الشبكة (النص المباشر الافتراضي vs الطباعة الصورية عالية الدقة HD Raster Canvas)، وإضافة حقل تحديد عدد نسخ الطباعة (Print Copies) لطابعات الشبكة فقط، وقصر حفظ إعدادات الطباعة كلياً على الذاكرة المحلية للجهاز (SharedPreferences).
*   **شاشة اختيار الشركاء والموردين (جديدة):** [PartnerSelectionScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_selection_screen.dart) - شاشة للبحث واختيار العملاء/الموردين عند بدء فاتورة جديدة أو التعديل من الـ POS.
*   **شاشة إدخال تفاصيل ومواعيد شحن وتوصيل الطلبات للعملاء (جديدة):** [TemporaryOrderScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/temp_order_screen.dart) - تحديد موعد التسليم والملاحظات للعملاء، وتخصيصها ديناميكياً لإخفاء بطاقة الزبون المؤقت للعملاء المسجلين.
*   **شاشة نقطة البيع والشاشات المنسدلة (معدلة):** [PosScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart) & [PartnerBillingScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_billing_screen.dart) & [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) - محاذاة باج الخصم لأقصى اليمين بكارت الصنف وتناسب الاسم عبر Expanded وتغليف الخصم بـ Flexible و FittedBox، وإلغاء تعديل سعر البيع بـ POS، إضافة زر إعادة طباعة أحدث إضافة بالنظام 🖨️ بالهيدر العلوي، وحل خطأ RenderFlex Overflow بإضافة `isExpanded: true` شمولياً.
*   **شاشة الإعدادات العامة (معدلة):** [GeneralSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart) - إضافة زر التحقق اليدوي من وجود تحديثات، إضافة خيار تخصيص معروضات الصفحة الرئيسية وخيارات تفعيل وتوجيه نظام التوصيل.
*   **شاشة الصفحة الرئيسية (معدلة):** [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) - الفحص الصامت التلقائي للتحديثات عند الإقلاع، فلترة بطاقات الاختصارات ديناميكياً بناءً على رغبة المستخدم وإضافة زر طباعة أحدث مستند مضاف.
*   **شاشة عروض مبيعات العملاء (معدلة):** [PartnerOffersScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_offers_screen.dart) - تكامل شاشة التوصيل قبل الفوترة لعروض العملاء.
*   **شاشة تقرير الفواتير اليومية (معدلة):** [DailyInvoicesScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_invoices_screen.dart) - دعم إعادة طباعة تفاصيل ومواعيد التوصيل للعملاء.
*   **شاشة إعدادات الشركة (معدلة):** [CompanySettingsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/CompanySettingsPage.xaml) - إضافة خيار تفعيل التصميم الجديد للطباعة وتفعيل التصميم المخصص الجديد (UseCustomInvoiceDesign)، وإزالة كروت تفضيلات النظام ليتم التحكم بها من الداتابيز.
*   **صفحة فاتورة المشتريات (معدلة):** [PurchaseInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseInvoicePage.xaml) - إضافة زر "تصدير PDF" في شريط الأدوات العلوي، وإضافة ميزة الفوكس التلقائي والانتقال لخانة الكمية عند تحديد الصنف.
*   **صفحة فاتورة المبيعات (معدلة):** [SalesInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml) - إضافة ميزة الفوكس التلقائي والانتقال لخانة الكمية عند تحديد الصنف.
*   **شاشة الطلبات اليومية للتوصيل (جديدة):** [DailyOrdersPage](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/DailyOrdersPage.xaml) - شاشة سطح المكتب لعرض طلبات التوصيل اليومية وجدولة أوقات الشحن على هيئة كروت مطوية.
*   **شاشة الطلبات اليومية للتوصيل للهاتف (جديدة):** [DailyOrdersScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_orders_screen.dart) - شاشة تطبيق الموبايل لمتابعة شحنات التوصيل اليومية وإعادة طباعتها حرارياً.
*   **شاشة إدارة وصفات ومكونات المنتجات لسطح المكتب (معدلة):** [RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml) - إضافة قائمة اختيار المستودع، زري تصدير PDF و Excel، إشعار Snackbar منزلق، وتحسين التنقل بين الخلايا.
*   **شاشة إدارة الوصفات للموبايل (جديدة):** [RecipeManagementScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/recipe_management_screen.dart) - شاشة تطبيق الهاتف لاستعراض الوصفات ومكوناتها.
*   **شاشة البحث السريع عن الفواتير (جديدة):** [InvoiceLookupScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/invoice_lookup_screen.dart) - شاشة الاستعلام السريع برقم الفاتورة لعرض كافة البيانات المالية والتفاصيل والدليفري وإعادة الطباعة الحرارية 🖨️.
*   **شاشة إغلاق الوردية وجرد وتسوية الكاش (معدلة):** [CloseShiftScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/close_shift_screen.dart) - إعادة تنظيم بطاقة تسوية وجرد الكاش بالدرج لعرض مبيعات ومشتريات الكاش النقدية الفعلية فقط وسندات القبض والصرف، وتقسيم بطاقة المبيعات لـ (كاش / شبكة K-Net / آجل) وبطاقة المشتريات لـ (كاش / غير نقدي / آجل)، وعرض بطاقة تفاصيل طرق الدفع.
*   **صفحة الورديات وإدارة التدفق النقدي المكتبي (معدلة):** [ShiftsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ShiftsPage.xaml) - ضبط وتوحيد رؤوس أقسام الإيرادات والمدفوعات لإظهار إجمالي المبيعات والمشتريات، وحصر مبالغ التدفق النقدي بالكاش الفعلي بالدرج.

### 2. الكلاسات ومزودات الحالة الجديدة والمعدلة (Added & Modified Classes / ViewModels / Providers):
*   **خدمة تهيئة قاعدة البيانات والتشفير (معدلة ومؤمنة):** [DatabaseHelper.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/DatabaseHelper.vb) - تشفير قالب الاتصال وبيانات السيرفر والمستخدم داخلياً، استيراد اسم قاعدة البيانات فقط مشفراً بـ AES-256 من ملف `dbconfig.dat` الخارجي، إلغاء القيم الافتراضية، وإظهار خطأ صريح عند غياب الملف.
*   **خدمة التحديث التلقائي لسطح المكتب (جديدة):** [AutoUpdateService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/AutoUpdateService.vb) - فحص السيرفر وتنزيل ملفات التثبيت وتشغيل Inno Setup صامتاً مع إغلاق وإعادة فتح التطبيق المحدث.
*   **خدمة التحديث التلقائي للموبايل (جديدة):** [UpdateService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/update_service.dart) - قراءة الإصدار و Version Code ديناميكياً عبر `package_info_plus` وتنزيل الـ APK وفتحه للتثبيت التلقائي عبر `open_filex`.
*   **مركز تحكم وإدارة التحديثات بالـ API (جديد):** [updates_manifest.json](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/data/updates_manifest.json) & [update_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/update_service.py) & [updates.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/updates.py) - مسارات التحقق `GET /updates/check` والنشر `POST /updates/publish` واستضافة الملفات الثابتة عبر `/static/updates/` مع مقارنة الإصدارات الدقيقة بـ 4 أرقام.
*   **إجراءات ملخص وإغلاق الوردية المحاسبية (معدلة):** `[Sales].[sp_Shift_GetSummary]` & `[Sales].[sp_Shift_Close]` - تثبيت حساب الصندوق الرئيسي على الحساب `1101` و `1101%` حصراً، وعزل مبيعات ومشتريات الشبكة والبنوك `1102` لحساب الكاش المتوقع بالدرج بدقة 100%.
*   **خدمة ومخطط الورديات بالـ API (معدلة):** [shift_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/shift_service.py) & [shift.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/shift.py) - دعم `TotalCashSales`, `TotalKnetSales`, `TotalCashPurchases`, `TotalNonCashPurchases` وحساب النقدية المتوقعة بالدرج.
*   **نموذج ومتحكم الورديات لسطح المكتب (معدل):** [Shift.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/Shift.vb) & [ShiftsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ShiftsViewModel.vb) - إضافة خصائص الكاش والشبكة المخصصة وتثبيت فحص حساب الكاش على `1101`.
*   **مصمم تقرير الوردية الحراري (معدل):** [ShiftReportPrintDesigner](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/shift_report_print_designer.dart) - فصل مبيعات الكاش والشبكة وخصم مشتريات الكاش من النقدية المتوقعة بالدرج.
*   **سكربتات بناء تطبيقات Flutter التلقائية (جديدة):** [build_all.bat](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/build_all.bat) & [build_all.ps1](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/build_all.ps1) - سكربتات لتحديث الحزم وبناء تطبيق Android APK و Windows Desktop EXE بضغطة زر واحدة.
*   **متحكم استعلام الفواتير (جديد):** [InvoiceLookupViewModel](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/viewmodels/invoice_lookup_viewmodel.dart) - متحكم نمط MVVM الخاص بالبحث والاستعلام عن الفواتير وتجهيز الإيصالات للطباعة.
*   **متحكم فاتورة المبيعات (معدل):** [SalesInvoiceViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/SalesInvoiceViewModel.vb) - إضافة دالة `ValidateInvoiceItemsBeforeSave` لمراجعة وتجميع الأصناف بدون كمية (`الكمية = 0`) والأصناف بدون سعر (`سعر البيع = 0`) في قسم مخصص أسفل رسالة التنبيه بفاصل مميز قبل الحفظ.
*   **متحكم فاتورة المشتريات (معدل):** [PurchaseInvoiceViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/PurchaseInvoiceViewModel.vb) - إضافة دالة `ValidateInvoiceItemsBeforeSave` لمراجعة وتجميع الأصناف بدون كمية (`الكمية = 0`) والأصناف بدون سعر (`سعر الشراء = 0`) في قسم مخصص أسفل رسالة التنبيه بفاصل مميز قبل الحفظ.
*   **خدمة الطابعة الحرارية (معدلة):** [PrinterService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) - تسجيل المستندات المضافة ودالة `printLastAddedDocument()` لطباعة أحدث مستند بالنظام فوراً، تكرار طباعة الشبكة لعدد النسخ `printCopies` محلياً، وإلغاء مزامنة الداتابيز لقصر الإعدادات على SharedPreferences الجهاز فقط.
*   **مصمم الفواتير الحرارية والـ Canvas (معدل):** [InvoicePrintDesigner](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/invoice_print_designer.dart) - إضافة وطباعة وقت الفاتورة `HH:mm:ss A` بجانب التاريخ وإدراج الإجمالي والخصم والصافي (Net Total) بكافة محركات الطباعة، اعتماد مسمى `خصم الصنف` المترجم، وحذف رمز العملة من الخصوم المطبوعة.
*   **مصمم الإيصالات الحرارية (معدل):** [ReceiptDesigner](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/receipt_designer.dart) - دعم الطباعة الديناميكية باللغة العربية والإنجليزية بحسب لغة التطبيق، وتحويل الفاتورة واللوجو والتقرير إلى صورة Canvas عالية الدقة لطابعات الشبكة POS 80.
*   **متحكم الوصفات (معدل):** [RecipeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/RecipeViewModel.vb) - دعم الربط الدقيق للمستودع `SelectedWarehouseID` مع جلب أسعار التكلفة للمواد الخام وتنشيط إشعارات الـ Snackbar والتنظيف التلقائي للصفوف الفارغة قبل الحفظ.
*   **خدمة الأصناف (معدلة):** [ProductService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/ProductService.vb) - إضافة دالة `GetProductsForRecipeIngredients` لجلب المواد الخام والوسيطة بالتكلفة المرجحة من `ProductStock`.
*   **خدمة الوصفات (معدلة):** [RecipeService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/RecipeService.vb) - تمرير `WarehouseID` لإجراء حفظ وتحديث الوصفات.
*   **كلاس تصدير التقارير (معدل):** [ReportExporter](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/ReportExporter.vb) - إضافة الدالتين `ExportRecipeToPdf` و `ExportRecipeToCsv` لطباعة وتصدير الوصفات بهيكل تفصيلي كامل.
*   **إجراء جلب المواد الخام للوصفة (جديد):** `[Inventory].[sp_Product_GetForRecipeIngredients]` - جلب المواد الخام والأصناف الوسيطة والعادية وحساب تكلفة `AvgCostPrice` من `ProductStock` حسْب المستودع المختار مع التراجع لـ 0.
*   **إجراء حفظ الوصفة (معدل):** `[Inventory].[sp_Recipe_Save_XML]` - قبول `@WarehouseID` وإدراج/تحديث المنتج المصنع بـ `ProductStock` بالتكلفة الإجمالية وحجم رصيد 0.
*   **إجراء جلب تفاصيل الوصفة (معدل):** `[Inventory].[sp_Recipe_GetByProduct]` - جلب تفاصيل المكونات والتكلفة بالربط المباشر مع `@WarehouseID` أو التراجع لأقل تكلفة.
*   **كلاس تصميم الإيصالات وتنسيق الطباعة الحرارية (جديد):** [ReceiptDesigner](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/receipt_designer.dart) - كلاس تنسيق رأس وتذييل وأصناف الإيصال وتعديل حجم الورق وطباعة الشعار.
*   **كود التحكم بالطباعة المكتبي (معدل):** [InvoicePrinter](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/InvoicePrinter.vb) - رسم الجدول ورأس وتذييل الفاتورة التفصيلية A4 مكرراً في كل صفحة وتعديل توسيط موقع رسم نوع الفاتورة `نوع الفاتورة / cash` بمنتصف الصفحة عند `gt(5.0F)` وضبط الملاحظات أسفل اسم العميل.
*   **كلاس طابعة الفواتير المخصص الجديد (جديد):** [InvoicePrinterCustom](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/InvoicePrinterCustom.vb) - كلاس طباعة مستقل مخصص لمحاكاة وتعديل مقاسات الفاتورة وتفقيطها وجدولها بمقدار 1 سم للأسفل للتصميم الرئيسي.
*   **نموذج بيانات الشركة (معدل):** [CompanyInfo](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/CompanyInfo.vb) - إضافة خاصيتي `UseDetailedInvoiceDesign` و `UseCustomInvoiceDesign`.
*   **متحكم صفحة الإعدادات (معدل):** [CompanySettingsViewModel](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/CompanySettingsViewModel.vb) - إدارة وتمرير حالتي تصميم الطباعة (المفصل والمخصص) لقاعدة البيانات.
*   **خدمة إعدادات الشركة (معدلة):** [SettingsService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/SettingsService.vb) - تضمين حقل `UseCustomInvoiceDesign` في جمل الاستعلام والحفظ.
*   **مزود حالة المبيعات والمشتريات (معدل):** [PosProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart) - حفظ إجمالي الخصم المالي بحقل `Discount` وقيم `TotalAmount` (قبل الخصم) و `NetAmount` (الصافي) بـ `InvoiceHeader` بالداتابيز، وحساب قيم المدفوع والمتبقي وتنسيق حفظ الفاتورة الآجلة.
*   **متحكم فاتورة المشتريات (معدل):** [PurchaseInvoiceViewModel](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/PurchaseInvoiceViewModel.vb) - إضافة ومعالجة أمر تصدير الفاتورة لـ PDF.
*   **كلاس تصدير التقارير (معدل):** [ReportExporter](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/ReportExporter.vb) - إضافة دالة `ExportInvoiceToPdf` المخصصة لتصدير المبيعات والمشتريات بهيكل PDF احترافي.
*   **نموذج بيانات طباعة الفاتورة (معدل):** [InvoiceReportHeader](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/InvoiceReportData.vb) - إضافة حقول `Remainder`, `PaidAmount`, `NetAmount` للطباعة.
*   **ملف الـ Trigger لقاعدة البيانات (معدل):** [14_Invoices_Post_Trigger.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/14_Invoices_Post_Trigger.sql) - ترحيل المخازن والحسابات بأمان مع معالجة السجلات المفقودة وإعادة احتساب متوسط التكلفة عند إلغاء ترحيل المشتريات.
*   **سكربت تحديث الإجراء المخزن (جديد):** [29_sp_Report_InvoicePrint_Update.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/29_sp_Report_InvoicePrint_Update.sql) - جلب حقول `Remainder`, `PaidAmount`, `NetAmount` للطباعة.
*   **ملف سكربت الـ SQL الرئيسي لقاعدة البيانات (معدل):** [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) - دمج جلب حقل المدفوع والمتبقي لتحديد نوع الفاتورة نقدي/آجل تلقائياً، وتصحيح تنشيط حسابات المبيعات والإيرادات `411` و `412` و `1201`.
*   **ملفي تشغيل خادم الـ API (معدلة):** [Run.bat / start_server.bat](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/Run.bat) - إزالة تعارض خيار `--workers 4` مع `--reload` لتفادي خطأ ويندوز `WinError 10022`.
*   **متحكم شاشة الطلبات اليومية (جديد):** [DailyOrdersViewModel](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/DailyOrdersViewModel.vb) - إدارة عمليات التصفية بالتاريخ وعرض الفاتورة وجلب البيانات.
*   **خدمة جلب وإدارة الطلبات (جديد):** [OrderService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/OrderService.vb) - استدعاء إجراءات التوصيل والطلبات اليومية من قاعدة البيانات.
*   **نموذج بيانات الطلبات المجدولة (جديد):** [DailyOrder](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/DailyOrder.vb) - تمثيل بيانات الشحن والتسجيل والتوصيل للعملاء.
*   **خدمة الـ API للتطبيق المحمول (معدلة):** [ApiService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart) - إضافة دالة جلب الطلبات اليومية `getDailyOrders(String date)`.
*   **مزود حالة الوردية للموبايل (معدل):** [ShiftProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/shift_provider.dart) - حفظ واسترجاع ومسح `active_shift_id` بالذاكرة الدائمة `SharedPreferences` عند فتح وإغلاق الوردية، وتوفير دالة `clearShiftData()` للتنظيف الشامل.
*   **مزود نقاط البيع للموبايل (معدل):** [PosProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart) - إرفاق `active_shift_id` بحقل `ShiftID` تلقائياً عند حفظ الفاتورة بالـ API أو بالذاكرة المحلية للأوفلاين.
*   **خدمة ومخطط الفواتير بالـ API (معدلة):** [invoices.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/invoices.py) & [invoice_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/invoice_service.py) - دعم إرسال واستقبال `ShiftID` في الفاتورة والاعتماد عليه مباشرة وتسهيل حفظ الفواتير بوردية الكاشير.
*   **خدمة الورديات بالـ API (معدلة):** [shift_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/shift_service.py) - التثبت الجازم من كون الوردية مفتوحة `Open` ومسح الكاش `_active_shift_cache` كلياً عند إغلاق الوردية لعدم الربط بوردية مغلقة.
*   **متحكم الورديات لسطح المكتب (معدل):** [ShiftsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ShiftsViewModel.vb) - تحسين التعرف على حساب الكاش الرئيسي `AccountCode = "1101"` ومسميات الصندوق وتصحيح خطوات الحفظ ومنع استثناءات التحويل.
*   **الإجراءات المخزنة وسكربتات قاعدة البيانات (معدلة):** [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) & [sp_Shift_GetSummary_and_Close.sql](file:///d:/VB.NET/backup/Vegtablity/SQL/sp_Shift_GetSummary_and_Close.sql) & [37_PaymentMethods_SplitPayment.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/37_PaymentMethods_SplitPayment.sql) - تصحيح وحساب ملخص إغلاق الوردية وتجميع وسائل الدفع المقسمة والمباشرة، وإضافة معامل تصفية الشريك `@PartnerID` لتقرير أعمار الديون.
*   **ملف حزمة التثبيت (معدل):** [Washa.iss](file:///d:/VB.NET/backup/Vegtablity/setup/Washa.iss) - ترقية إصدار حزمة التثبيت إلى `SetupV7` واستهداف التحديثات النهائية.
*   **شاشة طباعة ملصقات الباركود (جديدة):** [BarcodePrintScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/barcode_print_screen.dart) - شاشة جديدة مخصصة لاستعراض وتصفية طباعة ملصقات الباركود للمنتجات (عادية / تصنيع / وسيط) وتحديد عدد النسخ ومعاينة الملصق والطباعة الحرارية المباشرة.
*   **متحكم شاشة طباعة الباركود (جديد):** [BarcodePrintViewModel](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/viewmodels/barcode_print_viewmodel.dart) - متحكم النمط المعماري MVVM الخاص بشاشة طباعة ملصقات الباركود لإدارة جلب الأصناف والتصفية واقتناص أخطاء الـ API والتحقق من مصادقة المستخدم Token.
*   **الملف الرئيسي للتطبيق المحمول (معدل):** [main.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/main.dart) - تسجيل `BarcodePrintViewModel` في `MultiProvider` وإضافة `WidgetsFlutterBinding.ensureInitialized()` لتهيئة البيئة والتفضيلات المحلية.
*   **مصمم ملصقات الباركود (جديد):** [BarcodePrintDesigner](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/barcode_print_designer.dart) - مصمم ومولد ملصقات الباركود عالي الدقة (HD Canvas Raster Bitmap + Bluetooth ESC/POS Code128 + Sunmi Native Printer) لجميع أنواع طابعات الملصقات والإيصالات الحرارية.
*   **خدمة الطباعة الحرارية (معدلة):** [PrinterService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) - إضافة دالة `printBarcodeLabel()` لمعالجة وتكرار إرسال الملصق حسب عدد النسخ المطلوبة على كافة وسائط الاتصال.
*   **شاشة الإعدادات العامة (معدلة):** [GeneralSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart) - إضافة مفتاح التحكم `show_barcode_printing` لإظهار أو إخفاء الشاشة من القائمة الجانبية.
*   **القائمة الجانبية بالصفحة الرئيسية (معدلة):** [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) - إضافة بند "طباعة ملصقات الباركود" بالـ Drawer الجانبي بربط ديناميكي بشرط تفعيله من الإعدادات العامة.
*   **أداة إدخال سطر الأصناف للفواتير (جديدة):** [InvoiceItemRowControl](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/InvoiceItemRowControl.xaml) & [InvoiceItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/InvoiceItemRowControl.xaml.vb) - عنصر تحكم مخصص لحل محل DataGrid في فواتير المبيعات والمشتريات، يدعم البحث بالباركود وبالقائمة الذكية `SearchableDropdown`، وفحص عروض الأسعار بالـ SP أولاً، والتحقق الصارم من مدخلات الكمية والسعر وحماية الفاصلة العشرية، والتنقل بـ Enter.
*   **أداة إدخال سطر الأصناف لعروض الأسعار (جديدة):** [QuoteItemRowControl](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/QuoteItemRowControl.xaml) & [QuoteItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/QuoteItemRowControl.xaml.vb) - عنصر تحكم مخصص لعروض أسعار المبيعات والمشتريات (كود، اسم الصنف، وحدة، سعر العرض المقترح، حذف)، يدعم التنقل بـ Enter والبحث الذكي والتوافق مع `QuoteDetail` و `PurchaseQuoteDetail`.
*   **صفحة فواتير المبيعات (معدلة):** [SalesInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml) & [SalesInvoicePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml.vb) - إحلال DataGrid بـ ItemsControl وأداة السطور `InvoiceItemRowControl` مع ترويسة متطابقة، وإدارة إضافة وحذف وتحديث السطور بسلاسة.
*   **صفحة فواتير المشتريات (معدلة):** [PurchaseInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseInvoicePage.xaml) & [PurchaseInvoicePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseInvoicePage.xaml.vb) - إحلال DataGrid بـ ItemsControl وأداة السطور `InvoiceItemRowControl` ودعم أسعار الشراء والتنقل الفوري بالـ Enter.
*   **صفحة عروض أسعار المبيعات (معدلة):** [QuotePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/QuotePage.xaml) & [QuotePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/QuotePage.xaml.vb) - إحلال DataGrid بـ ItemsControl وأداة `QuoteItemRowControl` لسعر البيع المقترح والتنقل السريع.
*   **صفحة عروض أسعار المشتريات (معدلة):** [PurchaseQuotePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseQuotePage.xaml) & [PurchaseQuotePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseQuotePage.xaml.vb) - إحلال DataGrid بـ ItemsControl وأداة `QuoteItemRowControl` لسعر الشراء المقترح.
*   **صفحة القيود اليومية وكارت البحث والتصفية المتحرك (معدلة):** [JournalEntryPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/JournalEntryPage.xaml) & [JournalEntryPage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/JournalEntryPage.xaml.vb) - إضافة كارت بحث وتصفية متقدم متحرك (Animation) للبحث برقم القيد والبيان وحالة الترحيل ونطاق التاريخ وشريط شارة الفلتر النشط.
*   **إجراء جلب وتصفية القيود اليومية (معدل):** [38_sp_JournalEntry_GetPaged_Search.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/38_sp_JournalEntry_GetPaged_Search.sql) & [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) - دعم معايير البحث المتقدم والترقيم مع الحفاظ التام على التوافق الرجعي 100% مع الإصدارات السابقة.
*   **شجرة الحسابات الهرمية التفاعلية (جديدة):** [AccountTreeControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/AccountTreeControl.xaml) & [AccountNode.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/AccountNode.vb) - أداة شجرية متقدمة متعددة المستويات (0، 1، 2+) تدعم الفتح والطي السريع والبحث والتظليل الذكي والشارات اللونية وإضافة الحسابات الفرعية التلقائية.
*   **صفحة وتطبيق تقرير الأرباح والخسائر والتحليل المالي المقارن (معدلة):** [ProfitLossPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ProfitLossPage.xaml) & [ProfitLossViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ProfitLossViewModel.vb) - إضافة عمود النسبة من المبيعات (% of Sales)، تبويبات الاختيار بين التقرير التراكمي والمقارنة الشهرية الأفقية، رسم بياني تفاعلي LiveCharts، وتصدير PDF و Excel احترافي مع صفحة الرسوم البيانية المتجهة.
*   **أداة إدخال سطر مكونات الوصفات (جديدة):** [RecipeItemRowControl](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/RecipeItemRowControl.xaml) & [RecipeItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/RecipeItemRowControl.xaml.vb) - عنصر تحكم مخصص لحل محل DataGrid في صفحة إدارة الوصفات، يحتوي على الباركود، القائمة الذكية `SearchableDropdown` للمواد الخام، الوحدة، الكمية، سعر تكلفة الوحدة، الإجمالي، وحذف الصف ❌، مع دعم كامل لدورة التنقل بـ Enter ونقل التركيز للأسطر الجديدة.
*   **تطوير صفحة الوصفات والفلترة القابلة للطي (معدلة):** [RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml) & [RecipePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml.vb) & [RecipeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/RecipeViewModel.vb) - إضافة كارت فلترة وتصفية بالاسم والباركود قابل للطي مع Animation انسيابي، وجعل اللوحة الجانبية ككل قابلة للطي والفتح مع حركة انسحاب سلسة.
*   **أداة إدخال سطر التوالف والهوالك (جديدة):** [WastageItemRowControl](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/WastageItemRowControl.xaml) & [WastageItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/WastageItemRowControl.xaml.vb) - عنصر تحكم مخصص لسطور التوالف والهوالك يحل محل DataGrid، يضم (كود الصنف، اسم الصنف عبر `SearchableDropdown`، الكمية التالفة، الرصيد المتاح، تكلفة الوحدة، الإجمالي، الرصيد بعد الخصم، وحذف الصف 🗑️) مع دورة التنقل بـ Enter.
*   **تطوير صفحة التوالف وفلترة السجل القابلة للطي (معدلة):** [WastagePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/WastagePage.xaml) & [WastagePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/WastagePage.xaml.vb) & [WastageViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/WastageViewModel.vb) - إضافة كارت فلترة قابل للطي لسجل التوالف بالبحث برقم السند والملاحظات والمستخدم والحالة، مع حركة انسحاب انسيابية.
*   **أداة إدخال سطر الجرد الآلي (جديدة):** [StockTakeItemRowControl](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/StockTakeItemRowControl.xaml) & [StockTakeItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/StockTakeItemRowControl.xaml.vb) - عنصر تحكم مخصص لسطور الجرد الآلي يحل محل DataGrid، يضم (كود الصنف، اسم الصنف عبر `SearchableDropdown`، الكمية الدفترية، الكمية الفعلية، فرق الكمية، تكلفة الوحدة، قيمة الفرق، زر تحديث الرصيد الدفتري 🔄، وحذف الصف ❌) مع دورة التنقل بـ Enter.
*   **تطوير صفحة الجرد الآلي وترقيم صفحات سجل الجرد والتوالف (معدلة):** [StockTakePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/StockTakePage.xaml) & [WastagePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/WastagePage.xaml) - إضافة كارت فلترة قابل للطي لسجل الجرد الآلي، وتطبيق نظام ترقيم الصفحات (Pagination) بمعدل 10 سجلات في الصفحة لسجل الجرد وسجل التوالف مع أزرار التنقل (السابق / التالي / عداد الصفحات) وتحديث الـ SPs بتوافق رجعي 100%.
*   **ترقيم صفحات سجل الوصفات المسجلة (معدلة):** [RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml) & [RecipeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/RecipeViewModel.vb) - إضافة ترقيم الصفحات (Pagination) بمعدل 10 وصفات في الصفحة مع أزرار التنقل (السابق / التالي) وتحديث `[Inventory].[sp_Recipe_GetAll]` مع الحفاظ التام على التوافق الرجعي 100%.


## 1. الهيكل المعماري (System Architecture)
يتم الربط بين تطبيق Flutter وقاعدة البيانات الحالية من خلال API موحد مبني بـ FastAPI، مما يضمن أمان البيانات وتوحيد العمليات الحسابية مع نظام الـ Desktop الحالي.

---

## 2. المسارات التدفقية (Application Flows)

### أ- تسجيل دخول المستخدم (User Login)
1.  شاشة تسجيل دخول تطلب (اسم المستخدم، كلمة المرور).
2.  يتم التحقق عبر `FastAPI` من جدول `Users` في `VegtablityDB`.
3.  يتم تخزين `JWT Token` في التطبيق للجلسة الحالية.

### ب- نظام المشتريات (Purchases Flow)
1.  **القائمة الرئيسية:** اختيار "مشتريات".
2.  **صفحة الموردين:** عرض قائمة الموردين (Searchable List) المعتمدة في السيستم.
3.  **صفحة الأصناف:** 
    *   البحث عن الأصناف بالاسم أو الباركود.
    *   إدخال الكمية وسعر الشراء.
4.  **المراجعة والحفظ:** إرسال البيانات للـ API ليقوم باستدعاء `sp_Invoice_Save` بنوع `Purchase`.

### ج- نظام المبيعات (Sales Flow)
1.  **القائمة الرئيسية:** اختيار "مبيعات".
2.  **صفحة العملاء:** عرض قائمة العملاء مع إمكانية البحث السريع.
3.  **صفحة الأصناف:**
    *   واجهة سريعة لإضافة الأصناف (Grid or List).
    *   جلب سعر البيع الافتراضي أو السعر من آخر عرض سعر (Quote) نشط لهذا العميل.
    *   **ملاحظة:** يجب أن يدعم التطبيق إمكانية تعديل سعر البيع لكل صنف في الفاتورة مع تسجيل ذلك في جدول `Invoice_Details`.
    *   **ملاحظة:** فاتوره البيع يجب أن يدعم التطبيق إمكانية تعديل الكميات و حزف الاصناف من الفاتوره
    * امكانيه البحث باستخدام barcode و اسم الصنف باستخدام كاميرا الموبايل

4.  **المراجعة والتحصيل:** اختيار طريقة الدفع (كاش / آجل) والحفظ عبر `sp_Invoice_Save`.

---

## 3. خطة التنفيذ التقنية (Implementation Roadmap)

### المرحلة الأولى: Backend (FastAPI)
*   إعداد بيئة Python وربطها بـ SQL Server باستخدام `pyodbc`.
*   بناء Endpoints لـ:
    *   `POST /auth/login`: التحقق من الهوية.
    *   `GET /partners`: جلب العملاء والموردين.
    *   `GET /products`: جلب الأصناف والأسعار والمخزون.
    *   `POST /invoices`: حفظ الفواتير (نفس الـ Logic المستخدم في VB.NET).

### المرحلة الثانية: Frontend (Flutter)
*   تصميم واجهة مستخدم (UI) احترافية تدعم اللمس (Touch-friendly).
*   إعداد إدارة الحالة (State Management) باستخدام `Provider`  
*   برمجة خدمات الاتصال بالـ API باستخدام مكتبة `dio`.

### المرحلة الثالثة: التكامل والاختبار
*   اختبار مزامنة البيانات بين تطبيق الـ POS ونظام الـ Desktop.
*   تطبيق الطباعة الحرارية (Thermal Printing) للفواتير من خلال التطبيق.

---

## 4. المزايا التنافسية
*   **Offline Mode:** إمكانية العمل المؤقت عند انقطاع الإنترنت (اختياري لاحقاً).

*   **Cross-platform & Responsive UI:** العمل على أجهزة التابلت والموبايل مع تصميم "متجاوب" (Responsive) يتكيف تلقائياً مع أي حجم شاشة لضمان أفضل تجربة مستخدم (UX).

---

## 5. ما تم إنجازه في الـ API (VegtablityApi)

تم بناء هيكل الـ Backend بالكامل باستخدام **FastAPI** ليكون جاهزاً للربط مع تطبيق Flutter. أهم النقاط التقنية:

### أ- المعمارية البرمجية (Layered Architecture):
*   **Schemas:** تعريف البيانات في `app/schemas` لضمان صحة المدخلات من تطبيق الموبايل.
*   **Services:** فصل منطق العمل في `app/services` لاستدعاء الإجراءات المخزنة مباشرة.
*   **Routes:** توزيع المسارات في `app/routes` (Auth, Partners, Products, Invoices).

### ب- المسارات الجاهزة للربط (Endpoints):
*   `POST /auth/login`: للتحقق من هوية المستخدم وإصدار Token.
*   `GET /partners?type=Customer`: جلب قائمة العملاء أو الموردين.
*   `GET /products?search=...`: البحث عن الأصناف بالاسم أو الباركود.
*   `POST /invoices`: حفظ فاتورة كاملة (رأس وتفاصيل) في عملية واحدة مؤمنة.

### ج- نقاط هامة للصيانة المستقبلية:
*   **الربط بقاعدة البيانات:** يتم عبر ملف `app/core/database.py`. يعتمد حالياً على `Trusted_Connection=yes`.
*   **التشفير:** يتم استخدام **JWT** لتأمين الجلسات، والمفتاح السري موجود في ملف `.env`.
*   **توافق كلمات المرور:** يتم تشفير كلمات المرور بأسلوب SHA256 (Upper Case) ليتطابق مع نسخة الـ Desktop الحالية.
*   **سلامة البيانات:** يتم استخدام `Transaction` (Rollback) في خدمة الفواتير لضمان عدم حفظ رأس الفاتورة دون تفاصيلها في حال حدوث خطأ.
*   **الإعدادات:** يتم التحكم في السيرفر وقاعدة البيانات عبر ملف `.env` الخارجي دون الحاجة لتعديل الكود.

---

## 6. قسم عروض المشتريات (Purchase Quotations)

سيتم إضافة نظام لإدارة عروض الأسعار المقدمة من الموردين، لمحاكاة دورة المشتريات بشكل احترافي، مع اتباع نفس نمط الـ MVVM المستخدم في عروض المبيعات.

### أ- هيكل البيانات (Models):
*   **PurchaseQuoteHeader:** يحتوي على (ID العرض، ID المورد، تاريخ العرض، تاريخ الانتهاء، ملاحظات).
*   **PurchaseQuoteDetail:** يحتوي على (ID الصنف، الكمية المطلوبة، السعر المعروض من المورد).

### ب- الإجراءات المخزنة المطلوبة (Stored Procedures):
*   `[Purchases].[sp_PurchaseQuote_Save]`: لحفظ رأس وتفاصيل عرض المشتريات.
*   `[Purchases].[sp_PurchaseQuote_GetAll]`: لجلب تاريخ عروض المشتريات مع البحث.
*   `[Purchases].[sp_PurchaseQuote_GetDetails]`: لجلب تفاصيل عرض معين عند التعديل أو التحويل لفاتورة شراء.

### ج- منطق العمل (ViewModel Logic):
*   **مزامنة التواريخ:** استخدام نفس منطق `SyncDateText` و `LostFocus` لضمان مرونة إدخال التواريخ (مثل 11052026).
*   **البحث عن الموردين:** تصفية تلقائية للموردين فقط (PartnerType = 'Supplier').
*   **التحويل لمشتريات:** ميزة مستقبلية لتحويل عرض سعر المورد المقبول إلى "فاتورة مشتريات" بضغطة زر واحدة لتوفير الوقت.

### د- الإضافات المطلوبة في الـ API:
*   `GET /purchase-quotes`: لجلب قائمة عروض المشتريات للموبايل.
*   `POST /purchase-quotes`: لإرسال عرض مشتريات جديد تم تصويره أو إدخاله يدوياً من مندوب المشتريات عبر تطبيق الـ POS.

### هـ- واجهة المستخدم (UI):
*   تصميم مشابه لـ `QuotePage.xaml` ولكن بألوان تميز قسم المشتريات (مثلاً اللون البرتقالي أو الأزرق الداكن).
*   إدراج حقل "سعر الشراء الأخير" بجانب كل صنف للمقارنة مع السعر الجديد المعروض.---

## 7. التحديثات والتحسينات المنجزة (مايو 2026)

تم تنفيذ مجموعة من التحديثات الجوهرية لضمان استقرار النظام وتحسين تجربة المستخدم:

### أ- تحديثات قاعدة البيانات (Database):
*   **تغيير الاسم:** تم توحيد اسم قاعدة البيانات لتصبح `zatterDB` في كافة إعدادات النظام (Desktop + API).
*   **عروض المشتريات:** تم بناء الجداول والإجراءات المخزنة لقسم عروض المشتريات، مع اعتماد تقنية **XML** بدلاً من JSON لضمان التوافق التام مع إصدارات SQL Server القديمة (2014 وما قبلها).

### ب- تطوير واجهة المستخدم (UI/UX):
*   **السايد بار التفاعلي (Collapsible Sidebar):** 
    *   إضافة خاصية التصغير والتكبير للقائمة الجانبية لتوفير مساحة عمل أكبر.
    *   تطبيق **Animations** سلسة باستخدام Storyboards للتحكم في العرض (من 260 إلى 75).
    *   إخفاء النصوص والبيانات التعريفية تلقائياً عند التصغير والاكتفاء بالأيقونات.
*   **هيكلة المشتريات:** إعادة تنظيم قائمة المشتريات لتصبح قائمة منسدلة تحتوي على (فاتورة مشتريات، عروض المشتريات).

### ج- التوافق التقني (Compatibility):
*   تعديل منطق حفظ الفواتير في الـ SPs ليعمل بنظام استخراج البيانات من الـ XML باستخدام `.nodes()` و `.value()`، مما يحل مشكلة عدم التعرف على دالة `JSON_VALUE` في السيرفرات القديمة.

---

## 8. تحسينات لوحة المفاتيح والتنقل (Keyboard & Navigation)

لضمان سرعة فائقة في إدخال البيانات (Data Entry)، تم اعتماد نمط تنقل متقدم يعتمد كلياً على مفتاح **Enter** في جميع جداول الأصناف (DataGrids).

### أ- دورة حياة مفتاح Enter (Enter Key Cycle):
عند ضغط المفتاح في أي خلية، يتم الانتقال آلياً للخلية التالية حسب الترتيب المنطقي:
1.  **كود الصنف:** يقوم بالبحث عن الصنف وتعبئة بياناته ثم ينتقل لـ **الكمية**.
2.  **الكمية:** يثبت القيمة وينتقل لـ **السعر**.
3.  **السعر:** يثبت القيمة وينتقل لـ **الإجمالي**.
4.  **الإجمالي:** يقوم بإضافة **سطر جديد** فارغ وينقل التركيز لـ **كود الصنف** في السطر الجديد.

### ب- التقنيات المستخدمة:
*   **Template Columns:** استخدام `DataGridTemplateColumn` للتحكم الكامل في أحداث `PreviewKeyDown`.
*   **Visual Tree Navigation:** استخدام دوال برمجية للبحث في شجرة العناصر المرئية للوصول للـ `TextBox` المطلوب داخل خلايا الجدول.
*   **Product Pre-loading:** تحميل كافة الأصناف في الـ ViewModel عند فتح الصفحة لضمان استجابة لحظية للبحث بالكود.

### ج- التنقل بالأسهم (Excel-style Navigation):
تم تفعيل التنقل بمفاتيح الأسهم (↑ ↓ ← →) داخل الجدول حتى أثناء وضع التعديل، مع مراعاة اتجاه الكتابة العربي (RTL)، مما يسهل مراجعة وتعديل البيانات المدخلة بسرعة.

---

## 9. تحديثات نظام عروض المشتريات (مايو 2026 - المرحلة الثانية)

تم الانتهاء من تطوير وحدة "عروض المشتريات" لتصبح أداة احترافية لإدارة قوائم الأسعار، مع التركيز على الأداء العالي وتجربة المستخدم.

### أ- تبسيط البيانات (Data Simplification):
*   **إزالة الكمية والإجمالي:** تم تعديل فلسفة الوحدة لتصبح "قوائم أسعار" (Price Lists) فقط، حيث تم حذف أعمدة الكمية والعمليات الحسابية من الواجهة وقاعدة البيانات لتبسيط عملية مقارنة الأسعار.
*   **التركيز على السعر:** أصبح تدفق البيانات يركز على (الباركود -> اسم الصنف -> الوحدة -> السعر) فقط.

### ب- محرك التصدير والاستيراد (Export/Import Engine):
*   **تصدير PDF:** تصميم جدول ديناميكي بـ 5 أعمدة مع توزيع مساحات ذكي وتنسيق احترافي.
*   **تصدير CSV:** توفير ميزة استخراج البيانات بصيغة نصية خفيفة.
*   **قالب Excel:** إنشاء قالب موحد (Template) يحتوي على الأصناف المطلوبة لإرسالها للموردين.
*   **الاستيراد الذكي:** تطوير محرك استيراد من ملفات Excel يقوم بربط الأصناف آلياً عبر الباركود مع معالجة الأصناف غير الموجودة (Unmatched Items).

### ج- الأداء العالي والـ Pagination:
*   **تقسيم الصفحات (History Pagination):** تطبيق نظام تقسيم الصفحات في سجل العروض التاريخية باستخدام `sp_PurchaseQuote_GetPaged` لضمان سرعة التحميل حتى مع وجود آلاف السجلات.
*   **البحث اللحظي (Real-time Search):** إضافة مربع بحث في سجل العروض يدعم البحث باسم المورد أو رقم العرض مع تحديث النتائج فور الكتابة.
*   **تحميل التفاصيل الذكي:** استخدام `sp_PurchaseQuote_GetDetails` لجلب تفاصيل العرض عند الاختيار من السجل بشكل منفصل لتقليل استهلاك موارد السيرفر.

### د- تحسينات واجهة المستخدم (UI/UX):
*   **دورة الـ Enter المختصرة:** تعديل التنقل ليصبح (اسم الصنف -> سعر الشراء -> سطر جديد) لتسريع عملية إدخال قوائم الأسعار الطويلة.
*   **التحقق من الصلاحيات:** ربط أزرار التحكم (حفظ، تصدير، استيراد) بنظام الصلاحيات (Role-Based Access) لضمان أمن البيانات.

---

## 10. تحديثات وهيكلة تطبيق الموبايل والربط بـ APIs (مايو 2026)

تمت إعادة هيكلة وتطوير تطبيق الموبايل (`Vegtablity_App`) بنجاح بالاعتماد على أفضل الممارسات في مشاريع Flutter لضمان الفصل التام بين منطق العمل (Business Logic) وواجهات العرض (UI).

### أ- عزل وهيكلة طبقة الـ APIs (خادم الاتصال):
*   **مركزية الاتصالات (`ApiService`):** تجميع كافة استدعاءات الخادم في فئة منفصلة ومعزولة كلياً باستخدام عميل HTTP القوي `Dio` مع إعداد المهلات الزمنية للتأمين.
*   **حقن ترويسات الأمان تلقائياً:** إضافة آلية تحديث وحقن رمز التحقق (`updateToken`) تلقائياً في الترويسات (Headers) بعد تسجيل الدخول الناجح أو إعادة تشغيل التطبيق، مما يلغي تماماً التكرار اليدوي لتمرير الـ Token في دوال التطبيق المختلفة.
*   **دعم عمليات الفواتير والباركود:** تضمين مسارات ديناميكية لقراءة الأصناف بواسطة الباركود ومسار حفظ الفاتورة النهائية بالخادم الخلفي.

### ب- استخدام نمط المتحكمات (Controllers) عبر حزمة `Provider`:
تم عزل منطق تشغيل الشاشات في فئات تحكم (Providers) منفصلة لضمان الكفاءة البرمجية وقابلية التوسع:
*   **`AuthProvider` (متحكم الهوية والجلسات):** يتولى معالجة طلب الدخول، التفاعل التلقائي مع الذاكرة المحلية (`SharedPreferences`) لتمكين الدخول التلقائي، وتأمين عمليات تسجيل الخروج ومسح بيانات الجلسة.
*   **`ShiftProvider` (متحكم الوردية المالية):** يدير حالة فتح الوردية وإقرار مبلغ العهدة الافتتاحية للكاشير.
*   **`PosProvider` (متحكم سلة المبيعات والعمليات):** 
    *   يدير محتويات سلة الفاتورة بدقة (إضافة، زيادة كمية، وتصفير).
    *   يرتبط بنظام فحص الباركود بالـ API لجلب الصنف وتحديث السلة لحظياً.
    *   **وضع التلاشي والتحول الآمن (Fallback/Mock mode):** تمت إضافة آلية ذكية تقوم بإدراج صنف تجريبي تلقائياً في حال فقدان الاتصال بالشبكة لضمان بقاء التطبيق حياً وقابلاً للاختبار الكامل من قبل المطور والمستخدم في بيئة التطوير.
    *   حفظ الفواتير محلياً أو إرسالها للخادم بالكامل.

### ج- تفعيل وتحديث واجهات المستخدم (UI/UX Integration):
*   **شاشة تسجيل الدخول (`LoginScreen`):** ربط الحقول وعملية التأكيد بـ `AuthProvider` مع إبراز مؤشرات التحميل والتحقق من صحة المدخلات.
*   **شاشة الوردية (`ShiftScreen`):** ربط إقرار العهدة الافتتاحية بـ `ShiftProvider` وتفعيل الحماية من النقر المزدوج أثناء التحميل.
*   **شاشة نقطة البيع (`PosScreen`):** ربط السلة ومتحكم الباركود بـ `PosProvider` لتحديث الإجمالي لحظياً، وعرض تفاصيل السلة، وتفعيل زر الدفع والطباعة مع التنبيهات اللازمة باللغة العربية.
*   **الواجهة الرئيسية (`HomeScreen`):** تعديل قائمة الخيارات الجانبية لتستمع لعملية تسجيل الخروج من `AuthProvider` وإعادة توجيه الكاشير لصفحة الدخول الآمن.

---

## 11. الميزات البرمجية المتقدمة في تطبيق الموبايل (مايو 2026 - المرحلة الثالثة)

تم بنجاح كامل تطبيق ميزات تشغيلية متقدمة لضمان أداء تجاري مستقر تحت كافة ظروف الشبكة:

### أ- نظام الدخول التلقائي الذكي (Auto-Login System):
*   **بوابة التوجيه الافتتاحية (`AuthWrapper`):** تم تطوير ويدجت مستقل يتحقق عند تشغيل التطبيق من صلاحية رمز التحقق (Token) والبيانات المحفوظة في الذاكرة الدائمة (`SharedPreferences`).
*   **التوجيه الفوري:** في حال وجود جلسة صالحة ومفتوحة، يتم توجيه الكاشير صامتاً ومباشرة إلى صفحة الوردية (`ShiftScreen`) دون الحاجة لإعادة كتابة اسم المستخدم وكلمة المرور، مما يوفر وقتاً تشغيلياً مهماً.

### ب- نظام العمل بدون اتصال بالشبكة (Offline Engine & Local Sync):
*   **التخزين والبيانات المحلية:** في حال انقطاع الشبكة أو تعثر خادم الـ API، يقوم `PosProvider` بتخزين الفاتورة كـ JSON محلياً في الذاكرة الدائمة لملفات الهاتف، وتصفير السلة فوراً للسماح للكاشير بمتابعة عمليات البيع.
*   **مؤشر المزامنة المعلقة:** تصميم شريط تنبيه برتقالي في الشاشة الرئيسية يظهر آلياً في حال وجود فواتير محلية غير متزامنة، مع تزويده زر "مزامنة الآن" لإعادة إرسالها دفعة واحدة للخادم الخلفي فور استقرار جودة الشبكة.
*   **مؤشر جودة الاتصال:** إدراج شارة مرئية دائرية في شريط التطبيق العلوي توضح حالة اتصال السيرفر وجودة المزامنة باللونين الأخضر والبرتقالي.

### ج- تكامل ومحرك الطباعة الحرارية للفواتير (Thermal POS Printing Service):
*   **إدارة وتنسيق الإيصالات (`PrinterService`):** صياغة وتنسيق الأوامر الحرارية القياسية لإخراج إيصال البيع بشكل احترافي ومنسق (Store Info, Date, Items table, Total amount, VAT, footer).
*   **واجهة إعدادات الطابعة (`PrinterSettingsScreen`):** واجهة مخصصة تتيح للكاشير أو المشرف التحكم في خيارات اتصال طابعة الفواتير وحفظ إعداداتها محلياً:
    *   **اتصال شبكي (Network IP Printer):** كتابة الـ IP والمنفذ المخصص (Port 9100).
    *   **اتصال بلوتوث (Bluetooth Printer):** كتابة اسم الطابعة أو عنوان الـ MAC الخاص بها.
    *   **اختبار الطابعة:** زر مخصص لطباعة إيصال تجريبي (Test Receipt) للتأكد من نجاح الاتصال.
*   **الطباعة التلقائية:** تم ربط زر "دفع وطباعة (F12)" باستدعاء محرك الطباعة الحرارية فور نجاح الحفظ الفعلي (الشبكي أو المحلي الأوفلاين) لضمان خروج الفاتورة فورياً للكاشير.

---

## 12. نظام ترخيص الأجهزة ومسبق التشغيل (مايو 2026 - المرحلة الرابعة)

تم دمج نظام ترخيص مسبق ومستقل كأول شاشة تنطلق في تطبيق الموبايل لتعطيل استخدام التطبيق على الأجهزة غير المصرح بها:

### أ- تحديد هوية الجهاز الفريدة (`MachineHWID`):
*   **البصمة الفريدة المستقرة:** يتم توليد بصمة عشوائية ومستقرة ممثلة برمز هيكساديسيمال فريد بطول 16 حرفاً (مثال: `F888D91A03E6D92F`) وحفظه محلياً في الذاكرة الدائمة (`SharedPreferences`) لتمثيل هوية العميل البرمجية للجهاز.

### ب- التحقق والربط بالخادم الخلفي:
*   **مسار استعلام الترخيص:** استدعاء API مخصص `/security/check-license` لتشغيل الإجراء المخزن `sp_License_Check` في قاعدة البيانات.
*   **التحكم والتوجيه التلقائي:**
    *   **في حال الترخيص النشط:** ينتقل التطبيق تلقائياً وبشكل سلس لبوابة تسجيل الدخول الذاتية `AuthWrapper`.
    *   **في حال عدم الترخيص/انتهائه:** يتم تحويل المستخدم فوراً لشاشة الأمان المانعة.

### ج- شاشة منع الأجهزة غير المرخصة (`LicenseCheckScreen`):
*   **الواجهة الرسومية:** تصميم فاخر باللونين الأحمر والرمادي الداكن ليعلن حجب الجهاز بوضوح.
*   **تسهيل الترخيص والتواصل:**
    *   **بصمة الجهاز القابلة للنسخ:** عرض بصمة الجهاز الـ `HWID` بوضوح مع توفير زر لنسخ البصمة بلمسة واحدة للحافظة.
    *   **بيانات التواصل والمبرمج:** عرض رقم هاتف التواصل مع المبرمج لطلب تفعيل الترخيص: **55381505**.
    *   **إرسال البصمة الفوري (WhatsApp Integration):** زر أخضر تفاعلي يقوم بفتح تطبيق WhatsApp تلقائياً وإنشاء رسالة مهيأة مسبقاً تحتوي على رقم البصمة الفريد لإرساله للدعم الفني بضغطة زر واحدة.
    *   **زر إعادة التحقق:** يتيح للكاشير إعادة اختبار حالة ترخيص الجهاز فوراً بعد قيام المشرف بتفعيله بسجل قاعدة البيانات دون إعادة تشغيل التطبيق.

---

## 13. تكامل وتحديثات خادم الـ APIs الخلفي المنجزة (FastAPI Backend - مايو 2026)

تم بنجاح كامل بناء وتكامل وتفعيل كافة الـ APIs المكملة والضرورية لدورة تشغيل نقطة البيع المحمولة والربط المستقر مع قاعدة البيانات `VegtablityDB`:

### أ- نظام فحص أمان وترخيص الأجهزة (`POST /security/check-license`):
*   **النموذج البرمجي (Schema):** إنشاء نموذج التحقق `LicenseCheckRequest` في [security.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/security.py) لاستلام المعرف الفريد للجهاز `MachineHWID`.
*   **الخدمة البرمجية (Service):** بناء الخدمة `SecurityService` في [security_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/security_service.py) والتي تنفذ بدقة الإجراء المخزن:
    ```sql
    EXEC [Security].[sp_License_Check] @MachineHWID = ?
    ```
*   **المسار (Route):** تشييد المسار `POST /security/check-license` في [security.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/security.py) لإجراء عملية الفحص وإرجاع نتيجة موحدة ومطابقة للهاتف بالصيغة: `{"IsLicensed": true/false}`.
*   **التسجيل المركزي:** تسجيل موجه التراخيص الجديد في ملف التشغيل الرئيسي [main.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/main.py).

### ب- البحث والاستعلام الفوري عن الأصناف بالباركود (`GET /products/barcode/{barcode}`):
*   **الخدمة البرمجية (Service):** إضافة تابع مخصص `get_product_by_barcode` داخل [product_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/product_service.py) يستدعي الإجراء المخزن الجاهز بالسيستم:
    ```sql
    EXEC [Inventory].[sp_Product_GetByBarcode] @Barcode = ?
    ```
    مع تحويل وتنسيق أسعار الشراء والبيع بشكل معنوي دقيق لـ `float` لتفادي أخطاء التحقق.
*   **المسار (Route):** إدراج المسار المخصص `GET /products/barcode/{barcode}` داخل [products.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/products.py) لتلبية الطلبات اللحظية لقارئ الباركود بالتطبيق وإرجاع بيانات الصنف بالكامل أو خطأ 404 في حال عدم توفره.

### ج- التوجيه التوافقي لحفظ الفواتير (Sales Invoice Compatibility Mapping):
*   **الملف المعدل:** [main.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/main.py)
*   **التفاصيل الفنية:** لضمان التشغيل المتوافق والكامل لتطبيق الموبايل، تم إدراج موجه توافقي بديل (Alias Router) تحت بادئة `/sales` يربط تلقائياً طلبات الهاتف الموجهة لـ `POST /sales/invoice` بدالة الحفظ المركزية للفواتير بالخلفية (`create_invoice`). يضمن هذا التوافق المطلق وتخطي أخطاء الـ HTTP 404 دون إدخال تعديلات إضافية على تطبيق الموبايل.

---

## 14. نظام الترويسة الديناميكية للفواتير وإصلاحات الطباعة (مايو 2026 - المرحلة الخامسة)

تم بنجاح ربط ترويسة الفاتورة المطبوعة بقاعدة البيانات وتعميمها على جميع منافذ الطباعة لتسهيل التخصيص وإصلاح التحذيرات البرمجية:

### أ- السيرفر الخلفي (FastAPI Backend):
*   **إضافة مسار إعدادات الشركة (`GET /settings/company`):**
    *   إنشاء مسار مخصص في [settings.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/settings.py) وجدولته تحت البادئة `/settings` في ملف التشغيل الرئيسي [main.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/main.py).
    *   بناء خدمة `SettingsService` في [settings_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/settings_service.py) لتنفيذ الإجراء المخزن:
        ```sql
        EXEC [Settings].[sp_CompanySettings_Get]
        ```
    *   **التحويل التلقائي للبيانات الثنائية (Logo binary decoding):** إضافة منطق ذكي يقوم باكتشاف البيانات الثنائية (مثل لوجو الشركة) وتحويلها ديناميكياً لـ Base64 لضمان توافق الـ JSON وتفادي توقف الاتصال بالـ API.

### ب- تطبيق الهاتف (Flutter App):
*   **عنونة الطباعة الديناميكية:**
    *   إضافة دالة `getCompanySettings()` في [api_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart) لاستجلاب البيانات من السيرفر.
    *   تعديل [printer_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) لاستقبال `ApiService` وحفظ حالة ترويسة الفاتورة محلياً (`_companySettings`) عند بدء تشغيل التطبيق.
    *   تطبيق الترويسة المحدثة (اسم الشركة، العنوان، ورقم الهاتف) بشكل متناسق وممركز في كافة أنماط الطباعة:
        *   **محاكي الكونسول (Console Simulator):** يطبع الترويسة الجديدة بدلاً من الاسم الثابت.
        *   **طابعة Sunmi الحرارية:** طباعة اسم الشركة ووسم العنوان والهاتف في المنتصف (`SunmiPrintAlign.CENTER`).
        *   **طابعات الشبكة (Network IP Printers):** إرسال أوامر المحاذاة للمنتصف عبر منفذ الـ Socket وكتابة ترويسة الشركة الجديدة.
    *   **آلية التراجع الآمنة (Fallback Mechanism):** إعداد قيم افتراضية متطابقة مع تفاصيل الشركة الحالية لتعمل كتراجع آمن وفوري في حال عدم توفر اتصال بالشبكة أو تعطل السيرفر.

### ج- تحسينات الجودة البرمجية وإصلاح الـ Lint:
*   إصلاح تحذير تحليل الكود الخاص بـ `unnecessary_string_interpolations` في ملف الطباعة عن طريق استبدال `buffer.writeln('$name')` بـ `buffer.writeln(name)` لتتوافق بنسبة 100% مع قواعد التحليل الساكن لـ Flutter.

### د- تحسينات الطباعة العامة والتشغيل (POS Printing Improvements):
*   **اختصار الدفع والطباعة السريع (F12):**
    *   تزويد شاشة البيع `PosScreen` بمستمع لوحة المفاتيح `KeyboardListener` لربط المفتاح الفيزيائي `F12` مباشرة بعملية الدفع والطباعة، مما يتيح للكاشير إتمام عملية البيع فوراً دون الحاجة للمس الشاشة أو الماوس.
*   **المزامنة وحماية عمليات البيع أوفلاين:**
    *   تحسين آلية `saveInvoice` في `PosProvider` لحفظ الفاتورة محلياً في الذاكرة الدائمة عند تعثر خادم الـ API، مع إرجاع استجابة إيجابية تتيح طباعة الفاتورة للعميل فوراً دون تعطيل العمل التجاري.
*   **توحيد رسائل الإعلام والتنبيه:**
    *   تبسيط نص تنبيه نجاح الطباعة في شريط التنبيهات السفلي للتطبيق ليظهر بعبارة مخصصة وواضحة: **`"تم الطباعة"`** لمطابقة طلب المستخدم وتحسين مظهر واجهة نقطة البيع.
*   **شاشة الإعدادات والطباعة التجريبية (Test Print):**
    *   إعادة برمجة زر **"طباعة تجريبية"** ليقوم بإرسال أمر طباعة حقيقي للرأس الفيزيائي للطابعة النشطة بدلاً من المحاكاة فقط.
    *   إدراج إشعارات ذكية ملونة تبين نجاح الاتصال الفعلي بالطابعة (أخضر)، أو محاكاة الكونسول لعدم تحديد طابعة (رمادي)، أو التنبيه بفشل الاتصال لإعادة التحقق من الكابلات أو البلوتوث (أحمر).

---

## 15. المكتبات والحزم المستخدمة في تطبيق الهاتف (App Dependencies & Packages)

لضمان كفاءة تشغيل عالية وأمان تام، تم اختيار مجموعة من أفضل الحزم البرمجية والمكتبات مفتوحة المصدر وتكاملها في تطبيق الموبايل (`Vegtablity_App`):

### 1. إدارة الحالة وهيكلة البيانات (State Management):
*   **`provider` (الإصدار: `^6.1.1`):**
    *   **الاستخدام:** الحزمة الرسمية المعتمدة لإدارة حالة التطبيق وضمان عزل منطق العمل (Business Logic) عن واجهات العرض (UI). 
    *   **المهام الأساسية:** تغذية حقول الهوية وفتح الوردية ومشتريات/مبيعات الفواتير لحظياً للشاشات وإشعار الواجهات بالتحديثات عبر منطق `ChangeNotifier`.

### 2. الاتصال بالشبكة وخادم الـ APIs:
*   **`dio` (الإصدار: `^5.4.0`):**
    *   **الاستخدام:** عميل HTTP قوي وسريع جداً لإدارة اتصالات الشبكة مع خادم FastAPI.
    *   **المهام الأساسية:** إرسال طلبات الـ HTTP (تسجيل الدخول، التحقق من التراخيص، حفظ الفواتير، الاستعلام عن الأصناف بالباركود) مع دعم ضبط المهلات الزمنية وحقن ترويسات الأمان (JWT Token Interceptors) بشكل آلي ومستقر.

### 3. التخزين المحلي والذاكرة الدائمة (Local Persistence):
*   **`shared_preferences` (الإصدار: `^2.2.2`):**
    *   **الاستخدام:** لحفظ وتخزين البيانات الخفيفة والبسيطة بشكل دائم ومحلي على القرص الصلب للجهاز.
    *   **المهام الأساسية:** الاحتفاظ ببيانات جلسة المستخدم (Token)، بصمة الجهاز الفريدة (`MachineHWID`)، تخزين الفواتير محلياً للعمل بدون إنترنت (Offline Mode)، وحفظ إعدادات اتصال طابعة الفواتير (نوع الاتصال، عنوان IP، اسم البلوتوث).

### 4. واجهة المستخدم المتجاوبة والممتازة (Responsive Layouts):
*   **`responsive_builder` (الإصدار: `^0.7.0`):**
    *   **الاستخدام:** لتوفير تخطيط متجاوب وسلس يتوافق مع مختلف قياسات الشاشات والأجهزة.
    *   **المهام الأساسية:** تكييف واجهة نقاط البيع (POS Grid/List) لتظهر بشكل احترافي وجذاب على أجهزة التابلت الذكية، الهواتف المحمولة، وشاشات الـ Sunmi المخصصة.

### 5. محرك قراءة الرموز البصرية وقارئ الباركود:
*   **`mobile_scanner` (الإصدار: `^3.5.5`):**
    *   **الاستخدام:** لاستخدام كاميرا الهاتف كقارئ باركود فائق السرعة والاستجابة.
    *   **المهام الأساسية:** قراءة الرموز الخطية (Barcodes/QR Codes) للمنتجات وعكسها مباشرة لجلب بيانات الصنف من الـ API وإضافته فوراً لسلة المبيعات.

### 6. الربط والاتصالات الخارجية (System Integration):
*   **`url_launcher` (الإصدار: `^6.2.5`):**
    *   **الاستخدام:** للتفاعل مع نظام التشغيل وفتح التطبيقات والروابط الخارجية.
    *   **المهام الأساسية:** فتح تطبيق WhatsApp تلقائياً وإنشاء رسالة منسقة بالكامل تحمل كود بصمة الجهاز لإرسالها مباشرة لخدمة الدعم الفني بلمسة واحدة لطلب التنشيط.

### 7. الطباعة الحرارية الفيزيائية (Thermal Printing Engine):
*   **`sunmi_printer_plus` (الإصدار: `4.1.1` - إصدار حديث ومستقر):**
    *   **الاستخدام:** المحرك الأساسي للتحكم والتكامل البرمجي مع طابعة الإيصالات الحرارية المدمجة في أجهزة Sunmi V2s.
    *   **المهام الأساسية:** تهيئة رأس الطباعة الحراري، إرسال وتنسيق النصوص والجداول باللغة العربية (ترويسة الشركة، تفاصيل الفاتورة، المجاميع)، التحكم في حجم الخط والخط العريض والمحاذاة، وتنفيذ القطع التلقائي للورق (`cutPaper`).

---

## 16. نظام المزامنة السحابية لإعدادات الطابعات الحرارية (مايو 2026 - المرحلة السادسة)

تم بنجاح ربط إعدادات الطابعات ديناميكياً بقاعدة البيانات المركزية وحفظها بالربط مع بصمة الجهاز الفريدة `MachineHWID`. يضمن ذلك استرداد الإعدادات الصحيحة تلقائياً في أي وقت ومنع فقدانها محلياً:

### أ- قاعدة البيانات والـ Stored Procedures:
* **الجدول (`[Settings].[PrinterSettings]`):** جدول مخصص يربط كل بصمة جهاز `MachineHWID` بنوع الاتصال (`ConnectionType`) والـ IP والمنفذ (`Port`) واسم جهاز البلوتوث (`BluetoothDevice`).
* **إجراء الحفظ والمزامنة (`[Settings].[sp_PrinterSettings_Save]`):** يفحص وجود البصمة، ويقوم بعمل تحديث (Update) للإعدادات الحالية أو إدراج سجل جديد (Insert) للجهاز.
* **إجراء الاسترجاع (`[Settings].[sp_PrinterSettings_Get]`):** يجلب إعدادات الجهاز المطابقة للبصمة عند بداية تشغيل التطبيق.

### ب- السيرفر الخلفي (FastAPI Backend):
* **التحقق من البيانات (Schema):** إعداد النموذج `PrinterSettingsSaveRequest` في [settings.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/settings.py) للتحقق من صحة الحقول المرسلة من تطبيق الهاتف.
* **الخدمة والمسارات (Service & Routes):**
  * `POST /settings/printer` في [settings.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/settings.py): لحفظ ومزامنة إعدادات الطابعة.
  * `GET /settings/printer/{machine_hwid}` في [settings.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/settings.py): لاسترجاع التهيئة السحابية الخاصة بـ `HWID` للجهاز الحالي.

### ج- تطبيق الهاتف (Flutter App):
* **تحديث خادم الاتصالات (`api_service.dart`):** إدراج توابع الاتصال `getPrinterSettings` و `savePrinterSettings` لطلب واستقبال إحصائيات الطابعات مباشرة من الـ API.
* **هيكلة مزامنة وإدارة الحالة (`printer_service.dart`):**
  * ترقية الفئة لتستخدم **`ChangeNotifier`** بدلاً من الفئات الساكنة العادية، مع دمج الميثود `notifyListeners()` لتنبيه الواجهات عند المزامنة أو الحفظ.
  * **استراتيجية المزامنة الهجينة (Hybrid Sync Model):** استخدام الذاكرة المحلية `SharedPreferences` ككاش افتراضي وسريع جداً للعمل دون تأخير، مع استعلام الخادم الخلفي بشكل متوازي عند الإطلاق لتحديث الكاش تلقائياً.
  * إضافة الميثود العام `refreshSettings()` لإعادة سحب وتنزيل أحدث تهيئة محفوظة على قاعدة البيانات وإقرارها.
* **تطوير شاشة الإعدادات وتزامن البيانات (`printer_settings_screen.dart`):**
  * إدراج مؤشر تحميل رسومي ودائري (`CircularProgressIndicator`) لحجب الواجهة بنعومة عند سحب وتنزيل البيانات لأول مرة من قاعدة البيانات.
  * **شارة المزامنة السحابية الذكية (Cloud Sync Status Badge):** شارة تفاعلية فائقة الجمال تظهر حالة الاتصال والتزامن بدقة:
    * باللون **الأخضر** مع أيقونة السحابة النشطة: تعلن للمستخدم `"مزامنة نشطة مع السيرفر"` (أن البيانات محفوظة في قاعدة البيانات السحابية).
    * باللون **البرتقالي** مع أيقونة غير متصل: تعلن للمستخدم `"حفظ محلي فقط (أوفلاين)"` (عند انقطاع الاتصال بالسيرفر أو تعثر الاستعلام).

---

## 17. نظام عروض الشركاء وتعدد واجهات الشاشة الرئيسية (مايو 2026 - المرحلة السابعة)

تم بنجاح إضافة نظام كامل ومنفصل لفواتير عروض الشركاء المعتمدة مع إمكانية تبديل واجهة الشاشة الرئيسية لحظياً:

### أ- تعدد واجهات الشاشة الرئيسية (Dynamic Layout Switching):
* **شاشة الإعدادات العامة (`GeneralSettingsScreen`):** تم بناء شاشة حديثة كلياً تتيح للمستخدم التبديل بنقرة واحدة بين:
  * **النمط الكلاسيكي (الافتراضي):** الواجهة الأصلية للـ POS المباشر وإدارة الحسابات.
  * **نمط عروض الشركاء (الجديد):** واجهةPOS مخصصة بالكامل لعروض أسعار الموردين والعملاء النشطة.
* **الحفظ الفوري والتبديل اللحظي:** يتم حفظ الخيار محلياً بـ `SharedPreferences` وتحديث الواجهة فورياً عند العودة دون الحاجة لإعادة تشغيل التطبيق.

### ب- نظام فواتير عروض الشركاء المخصص والمنفصل:
* **شاشة "عروض الشركاء النشطة" (`PartnerOffersScreen`):** تعرض قائمة تفاعلية بالشركاء الذين يمتلكون عروضاً نشطة بالاعتماد على الـ APIs الجديدة:
  * للعملاء (Sales): بالاعتماد على `[Sales].[sp_SalesQuote_GetActivePartners]`.
  * للموردين (Purchases): بالاعتماد على `[Purchases].[sp_PurchaseQuote_GetActivePartners]`.
* **كتالوج الأصناف المسموح بها فقط (`PartnerBillingScreen`):**
  * شاشة كاشير معزولة ومخصصة لا تعرض سوى الأصناف المسموح بها والأسعار المعتمدة داخل عرض الشريك المختار.
  * **منع التلاعب:** يُمنع تماماً إضافة أو إدخال أي صنف خارج العرض لضمان الالتزام بأسعار وقوائم العروض.

### ج- مسح الباركود ثنائي المصدر (كود يدوي + كاميرا الهاتف):
* **مسح الكاميرا الذكي:** دمج حزمة `mobile_scanner` لتشغيل كاميرا الهاتف والتابلت كقارئ باركود فائق السرعة مع واجهة مستخدم منسقة وخط ليزر متحرك.
* **التحقق والتحذير المطور:** عند مسح باركود صنف، يتم التحقق فوراً:
  * إذا كان معتمداً في العرض: يُضاف تلقائياً مع اهتزاز خفيف (`HapticFeedback.lightImpact()`).
  * إذا كان غير معتمد: يمنع النظام الإضافة ويطلق اهتزازاً قوياً (`HapticFeedback.heavyImpact()`) مع نافذة تنبيه مرئية باللون الأحمر توضح عدم اعتماد الصنف.

### د- خيارات الدفع والطباعة المزدوجة:
* **حفظ ودفع نقدي (كاش):** يرسل الفاتورة للـ API بقيمة `PaidAmount = NetAmount` و `Remainder = 0` (مفتاح F12 السريع).
* **حفظ آجل (Credit):** يرسل الفاتورة بقيمة `PaidAmount = 0` و `Remainder = NetAmount` لتسجيل الذمم.
* **الطباعة التلقائية:** فور نجاح الحفظ، يستدعي النظام تلقائياً خدمة الطابعة الحرارية `PrinterService` لإخراج إيصال الفاتورة المنسق شاملاً حالة الدفع وتفاصيل الشريك والترويسة المحدثة.

---

## 18. تطوير نظام حماية وتراخيص الأجهزة والاشتراكات (مايو 2026 - المرحلة الثامنة)

تم بنجاح ترقية وتأمين نظام ترخيص الأجهزة المتصلة بقاعدة البيانات بشكل كامل ليتأكد من فحص صلاحية الدخول وتاريخ انتهاء اشتراك الجهاز بشكل متكامل وتقديم استجابة دقيقة:

### أ- تطوير طبقة الخدمات بالخلفية (FastAPI Backend):
* **تعديل الاستعلام لـ `DeviceLicenses`:** تم تحديث ملف `security_service.py` ليقوم بطلب مباشر لجدول `[Security].[DeviceLicenses]` للاستعلام عن الخصائص التالية بشكل كامل وتفصيلي:
  * `IsActive`: لتحديد حالة صلاحية الدخول للجهاز وما إذا كان مفعلاً من قبل الإدارة.
  * `ExpiryDate`: تاريخ انتهاء الاشتراك الفعلي الخاص بالجهاز.
* **تحديد حالة الترخيص الديناميكية:**
  * مقارنة تاريخ اليوم الفعلي بالتوقيت المحلي مع تاريخ انتهاء الاشتراك `ExpiryDate`.
  * إقرار عدم الصلاحية وتفعيل شارة انتهى الاشتراك `IsExpired = true` إذا تجاوز تاريخ اليوم تاريخ الانتهاء.
  * إرجاع استجابة تفصيلية للـ API بهيئة JSON:
    ```json
    {
      "IsLicensed": true/false,
      "ExpiryDate": "YYYY-MM-DD" or null,
      "IsActive": true/false,
      "IsExpired": true/false
    }
    ```

### ب- ترقية موفر التراخيص بالتطبيق (`LicenseProvider`):
* **تحديث وإدراج حقول المراقبة:** إضافة خصائص المراقبة `expiryDate`, `isActive`, و `isExpired` داخل `LicenseProvider` لتمكين واجهات العرض من التفاعل اللحظي مع حالة الاشتراك.
* **فك ترميز وقراءة تفاصيل الاستجابة:** ترقية المعالج لقراءة الاستجابة العائدة من خادم الـ API بكفاءة ومرونة عالية، مع الحفاظ على آليات الحماية والتجربة التجريبية للمطورين.

### ج- ترقية شاشة فحص التراخيص والاشتراكات (`LicenseCheckScreen`):
* **واجهات مستخدم مخصصة وتفاعلية للأخطاء:** تم استبدال رسالة الخطأ العامة بواجهات تفصيلية ورسومية جذابة باللغة العربية تبين سبب رفض الترخيص بدقة:
  * **شاشة انتهى الاشتراك (Expiry Warning):** تعرض أيقونة المؤقت المتوقف `Icons.history_toggle_off` باللون البرتقالي الجذاب، وتوضح للمستخدم تاريخ انتهاء الاشتراك بدقة، وتوجهه لتجديده.
  * **شاشة ترخيص غير نشط (Inactive Warning):** تعرض أيقونة الحجب `Icons.block` باللون الأحمر، وتبين أن الجهاز مسجل في النظام ولكن تم إلغاء تفعيل صلاحية الدخول الخاصة به من قبل الإدارة.
  * **شاشة جهاز غير مسجل (Unregistered ID):** تعرض بصمة الإصبع `Icons.fingerprint` باللون الأحمر لتوضيح أن معرّف الجهاز جديد وغير مسجل لدعم ترخيصه.
  * **شاشة انقطاع الاتصال (Connection Error):** تعرض أيقونة الواي فاي المتوقف `Icons.wifi_off` باللون الأصفر لتوجيه المستخدم للتحقق من جودة الإنترنت.

---

## 19. تكامل ودعم حفظ الفواتير بنظام الـ XML (مايو 2026 - المرحلة التاسعة)

تم بنجاح ربط وتأمين منطق حفظ الفواتير (المبيعات والمشتريات) بالاعتماد الكامل على المعالجة المتقدمة بنظام الـ XML عبر الاستجابة المباشرة للإجراء المخزن الجديد `[Sales].[sp_Invoice_Save_XML]`:

### أ- تحليل وتأمين معالجة الـ XML بالخلفية:
* **بناء هيكل البيانات الرأسي والفرعي:** يقوم ملف `invoice_service.py` ببناء مستند الـ XML بشكل تفصيلي ديناميكي يحتوي على كافة تفاصيل المنتجات المشتراة أو المباعة بالهيكل التالي:
  ```xml
  <Details>
    <Item ProductID="1" UnitPrice="10.00" Quantity="5.00" TotalPrice="50.00" CostPrice="8.00" />
  </Details>
  ```
* **تفكيك البيانات برمجياً:** يتكفل الإجراء المخزن `sp_Invoice_Save_XML` بقراءة هذا المستند دفعة واحدة وتخزينه في جدول تفاصيل الفواتير `[Sales].[InvoiceDetails]` مستخدماً `.nodes('//Item')`.

### ب- التغلب على قيود معاملات المخرجات (pyodbc OUTPUT Parameter Resolution):
  * **الحل المعماري الذكي:** قمنا بإعادة صياغة استدعاء الاستعلام برمجياً داخل الخلفية باستخدام **تكتل الإعلان المباشر (T-SQL DECLARE)**، حيث يتم إسناد المعامل محلياً وتمريره كـ `OUTPUT` داخل جملة EXEC:
  ```sql
  DECLARE @InvID INT = 0;
  EXEC [Sales].[sp_Invoice_Save_XML] 
      @InvID = @InvID OUTPUT,
      -- باقي المعاملات...
  ```
  يضمن هذا التحديث إتمام عملية الحفظ الكامل للفواتير وسرعة الاسترجاع التلقائي لرقم الفاتورة الجديد بشكل مستقر وآمن 100%.

---

## 20. شاشة تقرير الفواتير اليومية والمستخدم (مايو 2026 - المرحلة العاشرة)

تم بنجاح إضافة وتكامل شاشة جديدة بالكامل مخصصة لعرض **تقرير الفواتير اليومية والمستخدم**، مع تزويدها بمدخل مباشر وتفاعلي من القائمة الجانبية (Sidebar):

### أ- هيكلة الواجهات وتوزيع الفواتير اليومية (Dual Split Layout):
* **ترويسة المستخدم الحالي والتاريخ:** يعرض الجزء العلوي من الشاشة تفاصيل المستخدم النشط حالياً وجلسة عمله، وتاريخ التقرير اليومي الفعلي بالصيغة المحلية المقروءة.
* **قسم المشتريات اليومية (Daily Purchases):**
  * يعرض في النصف العلوي للشاشة بلون برتقالي جذاب.
  * يدرج كافة فواتير المشتريات الصادرة للموردين في اليوم الحالي مع تفاصيل معرّف الفاتورة، اسم المورد، التوقيت المحلي الفعلي، وقيم المبالغ والآجل.
  * يحسب تلقائياً إجمالي المشتريات اليومية داخل صندوق مالي glowing مخصص.
* **قسم المبيعات اليومية (Daily Sales):**
  * يعرض في النصف السفلي للشاشة بلون أزرق/أخضر نابض بالحياة.
  * يدرج كافة فواتير المبيعات الصادرة للعملاء في اليوم الحالي بتفاصيلها الكاملة والآجل منها.
  * يحسب تلقائياً إجمالي المبيعات اليومية داخل صندوق مالي glowing مخصص.
* **التمييز البصري واللوني الفوري للفواتير (Paid vs Credit Invoices):**
  * **الفواتير المدفوعة بالكامل (نقدي):** تُميز بشارة خضراء براقة مكتوب عليها `"نقدي / مدفوع"`، ويُعرض إجمالي الفاتورة باللون الأخضر المضيء مع سطر فرعي يوضح `"مدفوع بالكامل"`.
  * **الفواتير غير المدفوعة أو الآجلة (Credit):** تُميز بشارة حمراء مكتوب عليها `"آجل"`، ويُعرض إجمالي الفاتورة باللون البرتقالي التحذيري مع سطر فرعي تفصيلي يوضح قيمة المبلغ المتبقي الفعلي بدقة: `"متبقي آجل: XX.XX د.ك"` باللون الأحمر الفاتح لسهولة الحصر.

### ب- التلخيص المالي الذكي وعرض تفاصيل الأصناف (Cash Flow & Bottom Sheet Details):
* **تذييل التدفق المالي الكلي (Net Cash Flow Footer):** لوحة تذييل تفاعلية تعرض في أسفل الشاشة لحساب وتوضيح **صافي التدفق اليومي** (إجمالي المبيعات - إجمالي المشتريات) باللون الأخضر في حال الفائض المالي والأحمر في حال العجز.
* **نافذة التفاصيل التفاعلية (Detailed Bottom Sheet):**
  * عند النقر على أي فاتورة يومية، ينبثق نموذج سفلي متطور للغاية وذو طراز تقني فاخر.
  * يستدعي الـ API المحدث `GET /invoices/{inv_id}` لجلب كامل رأس الفاتورة وتفاصيل جدول الأصناف المشتراة أو المباعة (الصنف، سعر الوحدة, الكمية، الإجمالي، والخصم المالي والمدفوع والآجل) وعرضها بطريقة منسقة كلياً.

### ج- الأمان وتوافق البيئة البرمجية (Analyzer Compatibility & Package-Free Design):
* **التنسيق المحلي الخالي من الحزم:** تم تصميم وتطوير معالجات التاريخ والوقت والتنسيق المالي كدوال Dart برمجية ذاتية بالكامل دون الاعتماد على حزمة `intl` الخارجية، مما يضمن خفة وزن التطبيق، ومنع أي مشاكل مستندة لتثبيت الحزم في بيئة الإنتاج.
* **سلامة الأكواد وموثوقيتها:** يمر كود الشاشة بالكامل بنسبة 100% من اختبارات أداة Flutter للتحليل البرمجي التلقائي مع تسجيل **صفر أخطاء أو تحذيرات**.

---

## ١٢. تطوير معمارية إدارة الورديات وتسوية القيود النقدية (Shift Architecture & Cash Flow Settlement)

في المرحلة الأخيرة، تم إعادة تصميم جوهر عمل الورديات ونظام الإغلاق المالي بالكامل ليكون مستقلاً عن قيود الوقت (التاريخ والساعة) وأكثر دقة ومركزية في ربط الفواتير.

### أ- فك ارتباط الفواتير بالوقت والاعتماد المباشر على (ShiftID):
* **إضافة عمود `ShiftID` لجدول الفواتير:** تم إضافة عمود `ShiftID` إلى جدول `[Sales].[InvoiceHeader]` لربط كل فاتورة مباعة أو مشتراة بشكل مباشر وأكيد برقم الوردية التي تمت خلالها، بدلاً من الاعتماد السابق على حصر الفواتير داخل نطاق زمني (`StartTime` و `EndTime`). 
* **الدقة المالية (حل مشكلة الفواتير الآجلة):** أدى هذا التعديل المعماري إلى حل خلل كان يتسبب في عدم ظهور الفواتير الآجلة (غير المسددة) بشكل دقيق ضمن ملخص الوردية. الآن أصبح جلب المبالغ (`TotalSales` و `TotalPurchases`) يعتمد على الربط الصريح للـ `ShiftID` ويجمع إجمالي `NetAmount` الذي يعبر عن القيمة الكاملة للفاتورة (مسدد + آجل) بشكل مضمون.

### ب- التخزين المؤقت الذكي في الذاكرة (In-Memory Shift Caching):
* **صفر استعلامات SQL إضافية:** لتجنب إرهاق قاعدة البيانات أثناء الضغط وذروة العمل عند إصدار كل فاتورة جديدة لمعرفة "الوردية النشطة" للكاشير، تم بناء نظام كاش (Cache) في طبقة `ShiftService` بلغة Python (`_active_shift_cache`).
* **دورة حياة الكاش:** يُسجل الـ `ShiftID` في ذاكرة الخادم فور فتح الكاشير لورديته، ويُستدعى مباشرةً وفي أجزاء من الثانية مع كل عملية حفظ فاتورة عن طريق `invoice_service` دون الحاجة لاستعلام قاعدة البيانات، ويتم محوه آلياً عند إغلاق الوردية للحفاظ على استقرار الذاكرة.

### ج- تحديث هندسة تسجيل السداد وإغلاق الورديات (Payment & Shift Close Logic):
* **تعديل إجراء السداد (`sp_Invoice_AddPayment_pos`):** تم تطويره ليقوم بتحديث مباشر وديناميكي للمبالغ المدفوعة والمتبقية (`PaidAmount`, `Remainder`)، مع شرط ذكي يضمن **إنشاء القيود المحاسبية المزدوجة (Journal Entries)** فقط إذا كانت الفاتورة "مرحلّة" (Posted).
* **قيد تسوية الفروقات:** أثناء إغلاق الوردية عبر `sp_Shift_Close`، يقوم النظام بحساب (الكاش المتوقع = كاش الافتتاح + إجمالي مبيعات مسددة - إجمالي مشتريات مسددة)، ثم يقارنه بالكاش الفعلي الذي أدخله الكاشير. إذا وجد عجزاً أو فائضاً أكبر من (0.001 د.ك)، يتم أوتوماتيكياً إنشاء قيد محاسبي مزدوج بين حساب "الصندوق" وحساب "الإيرادات الأخرى (412)" لتسوية العهدة بالمليم.

---

## ١٣. تطوير السندات (Vouchers) والطباعة ومزامنة البيانات

تم التركيز في هذه المرحلة على تمكين التطبيق من معالجة السندات (صرف/قبض) المرتبطة بالفواتير، وتقوية نظام العمل دون اتصال، وترتيب بنية الخادم.

### أ- نظام السندات المجمعة والدقة المالية (Bulk Payment Vouchers):
* **الإجراءات المخزنة للسندات:** تم إنشاء `sp_Partner_GetUnpaidInvoices` و `sp_Partner_BulkPayment_pos` لتسديد فواتير مجمعة للعملاء والموردين. يعتمد النظام على استقبال بيانات توزيع المبالغ (Allocations) على شكل `XML` لضمان التوافقية والأمان المالي للفواتير.
* **الارتباط الدقيق بالورديات:** تم إضافة عمود `ShiftID` لجدول `[Accounting].[Vouchers]` لربط جميع السندات المنشأة عبر التطبيق بوردية الكاشير الحالية، مما ينعكس مباشرة في تقرير ملخص إغلاق الوردية.
* **إصلاحات PyODBC (Multiple Result Sets):** تم حل مشكلة الإرجاع الفارغ (NoneType Error 500) عند تنفيذ السندات باستخدام بايثون، وذلك بإضافة آلية التخطي `cursor.nextset()` لتجاوز أي رسائل قواعد إلحاقية (Triggers) والوصول للجدول الفعلي.

### ب- واجهات العرض والطباعة (UI & Printing):
* **استعراض وتفاصيل السندات:** تم تحديث شاشة "الفواتير اليومية" (`DailyInvoicesScreen`) لتعرض السندات مع الفواتير. وأصبح بإمكان المستخدم الضغط على أي سند لرؤية نافذة سفلية (Bottom Sheet) توضح **الفواتير المدفوعة داخل هذا السند** ومقدار السداد لكل فاتورة.
* **الطباعة الحرارية:** تمت إضافة زر "طباعة" من داخل تفاصيل كل سند وفاتورة، وهو متصل بالـ `ThermalPrinterService` لطباعة إيصال السند مباشرة متضمناً أرقام الفواتير التي تمت تسويتها.
* **استعلام الفواتير بالـ ShiftID:** تم التعديل الجذري على استعلام الفواتير اليومية `sp_Invoice_GetAll_Pos` والـ API ليقوم بالفلترة بناءً على معرّف الوردية `ShiftID` المفتوحة، بدلاً من الفلترة غير الدقيقة عبر التاريخ.

### ج- العمل دون اتصال وإدارة المزامنة (Offline Mode & Sync Management):
* **حماية إغلاق الوردية:** إضافة نظام قفل ذكي يمنع المستخدم من إغلاق الورديات في حال وجود (سندات أو فواتير غير متزامنة) محفوظة محلياً. وتظهر نافذة تفصيلية تطلب من الكاشير إجراء "المزامنة مع الخادم" أولاً لضمان عدم ضياع البيانات.
* **معالجة أخطاء السندات (Clear Offline Data):** تمت برمجة دالة `clearOfflineVouchers` في مزود الحالة `VoucherProvider` للتعامل مع السيناريوهات المعقدة (مثل حجب التزامن بسبب نقص حساب مالي للمورد/العميل)، مما يوفر مرونة للتعامل مع البيانات المعلقة.
* **تتبع أخطاء الـ API العميق:** تزويد الـ Backend بخاصية إرجاع تتبع الأخطاء التفصيلي (Traceback) في حالة انهيار الخادم (Error 500)، وعرضها داخل الكونسول في فلاتر `DioException` لتسريع عملية الصيانة واكتشاف الخلل.

### د- معمارية الخادم (Backend Clean Code):
* **كلاس الإجراءات المركزية (`StoredProcedures`):** تم إنشاء ملف `app/core/db_procedures.py` ليجمع كافة الإجراءات المخزنة كمتغيرات ثابتة (Constants) مصنفة ومنظمة لتفادي الأخطاء الإملائية وتنظيف شفرة الخدمات (`Services`) الخاصة بـ FastAPI.

---

## 14. نظام الترجمة المتعددة اللغات وإصلاحات التخطيط (مايو 2026 - المرحلة الرابعة عشرة)

تم تطبيق نظام متكامل للتوطين والترجمة (i18n) على شاشات التطبيق المختلفة، مع إصلاح مشاكل تخطيط العرض الناجمة عن الـ Overflow.

### أ- نظام التوطين (`AppLocalizations`):
* **الهيكل المعتمد:** نظام ترجمة مركزي معتمد على مفاتيح نصية (String Keys) في `lib/core/localization/app_localizations.dart`، يدعم العربية والإنجليزية.
* **آلية التطبيق:** استدعاء الترجمة عبر `context.tr('key')` في جميع واجهات العرض.
* **قاعدة الترجمة:** النصوص القادمة من API لا تُترجم وتُحتفظ بها كما هي.
* **حل مشكلة `const` widgets:** استبدال `const Text(...)` بـ `Text(context.tr(...))` لأن `context.tr()` لا يصلح `const expression`.

### ب- ترجمة شاشة إغلاق الوردية (`close_shift_screen.dart`):
* إضافة مجموعة مفاتيح `cs_*` بالعربية والإنجليزية تغطي عناوين الأقسام، رسائل التأكيد والخطأ، وأسماء الحقول المالية.
* **إصلاح Overflow:** تطبيق `Expanded` على عناصر `Row` لتوزيع المساحة وحل `RenderFlex overflow`.

### ج- ترجمة شاشة الفواتير اليومية (`daily_invoices_screen.dart`):
* إضافة مجموعة مفاتيح `di_*` شاملة تغطي:
  * تبويبات الشاشة والملخصات المالية.
  * أعمدة جدول التفاصيل: `di_item_col`، `di_price_col`، `di_qty_col`، `di_total_col`.
  * مفاتيح حوارات السداد الآجل: `di_payment_dialog_title`، `di_payment_remaining`، `di_confirm_payment`، ...
  * أزرار الـ BottomSheet: `di_reprint`، `di_close_popup`، `di_register_payment`.

---

## 15. تنسيق الأرقام في المطبوعات (مايو 2026 - المرحلة الخامسة عشرة)

تم تطبيق معيار موحد لتنسيق الأرقام في جميع المطبوعات دون الاستعانة بحزم خارجية.

### أ- دالة تنسيق العملة `_formatCurrency` في `printer_service.dart`:
* **الصيغة المعتمدة:** `0,000.00` — فاصل آلاف مع رقمين عشريين ثابتين.
* **التقنية:** RegEx مخصص `(\d{1,3})(?=(\d{3})+(?!\d))` بدلاً من حزمة `intl` المرفوضة.
* **التطبيق:** استبدال `.toStringAsFixed(2)` في كل المجاميع بـ `_formatCurrency()` عبر جميع دوال الطباعة.

### ب- دالة تنسيق الكمية `_formatQuantity` في `printer_service.dart`:
تم إعادة بناء `_InvoiceDetailsBottomSheet` بالكامل لإصلاح الـ Overflow وتحسين التجربة.

### أ- إصلاح مشكلة الـ Overflow:
* **المشكلة:** `Column` ذو `mainAxisSize: min` يتجاوز ارتفاع الـ BottomSheet عند كثرة الأصناف (`RenderFlex overflowed`).
* **الحل:**
  * تغليف المحتوى بـ `Flexible + SingleChildScrollView`.
  * استبدال `ConstrainedBox + ListView.builder` بـ `spread operator` لعرض الأصناف مباشرةً داخل Column بلا scroll متداخل.
  * تثبيت أزرار الإجراءات خارج منطقة التمرير لتبقى دائمة الظهور.

### ب- تحسين جدول الأصناف:
* جدول منسق بـ `Row + Expanded` بأربعة أعمدة: **الصنف** (flex:3) | **السعر** (flex:1) | **الكمية** (flex:1) | **الإجمالي** (flex:2).
* عرض الكمية مع رمز الوحدة (`كيلو 2`، `حبة 10`) بنفس منطق `_formatQuantity`.
* تلوين عمود الإجمالي بـ `Colors.tealAccent` للتمييز البصري.
* إضافة عنوان ثابت للنافذة (`di_invoice_details`) فوق منطقة التمرير.

### ج- الترجمة الكاملة للنافذة:
* استبدال جميع النصوص الثابتة بمفاتيح `context.tr(...)` للعربية والإنجليزية.
* استخدام `builder: (ctx)` في `showDialog` بدلاً من `(context)` لتفادي تعارض المتغير.

### د- إصلاحات جودة الكود:
* إضافة `mounted` check في `_reprintInvoice` لتفادي `use_build_context_synchronously`.
* حذف دالة `_formatDateTime` الغير مستخدمة لإزالة تحذير `unused_element`.
* تعطيل زر الطباعة (`onPressed: null`) عند غياب بيانات الفاتورة لمنع الـ null crash.


---

## 17. تحسينات التنقل وواجهة المستخدم في لوحة التحكم (يونيو 2026 - المرحلة السابعة عشرة)

تم تنفيذ مجموعة من التحسينات الهامة على نظام التنقل وواجهة المستخدم لتسهيل وسرعة العمل اليومي:

### أ- التنقل الذكي من شاشة الورديات (Smart Navigation from Shifts):
* **النقر المزدوج (Double-Click):** تم ربط كافة الجداول في شاشة الورديات (`ShiftsPage`) بخاصية النقر المزدوج لفتح تفاصيل الحركة مباشرة. يشمل ذلك:
  * فواتير المبيعات (`SalesInvoicePage`).
  * فواتير المشتريات (`PurchaseInvoicePage`).
  * سندات القبض (`ReceiptVoucherPage`).
  * سندات الصرف (`PaymentVoucherPage`).
* **التحميل التلقائي:** بمجرد النقر المزدوج، يقوم النظام باستنساخ الشاشة المطلوبة، وتمرير الـ `ID`، وتعبئة البيانات تلقائياً للمراجعة أو التعديل.

### ب- دعم التراجع في السندات (Navigation Stack Back Support):
* **تخزين حالة الشاشة:** تم تعديل أوامر فتح الفواتير والسندات لتستخدم `NavigateTo(page, True)` مما يحفظ شاشة "الورديات" الحالية في الذاكرة (Navigation Stack).
* **زر الرجوع السريع:** تمت إضافة زر **"← رجوع"** في أعلى شاشات سندات القبض والصرف، ليتيح للمستخدم العودة الفورية لشاشة الورديات بنفس حالتها السابقة دون فقدان البيانات.

### ج- أزرار الإضافة السريعة للشركاء (Quick Add Partner Buttons):
* **اختصارات شاشة الشركاء (`PartnersPage`):** 
  * إضافة زر **"➕ إضافة عميل"** في الترويسة العلوية لتبويب العملاء.
  * إضافة زر **"➕ إضافة مورد"** في الترويسة العلوية لتبويب الموردين.
* **الاستجابة الفورية:** ترتبط هذه الأزرار بالأوامر `NewCustomerCommand` و `NewSupplierCommand` لتقوم بتصفير الحقول وفتح اللوحة الجانبية الجاهزة للإدخال مباشرة، مما يحل مشكلة الإضافة السريعة دون الحاجة للبحث أو تحديد شريك موجود مسبقاً.


---

## 18. نظام إدارة الهوالك والتوالف (يونيو 2026 - Wastage Management)

تم بناء نظام متكامل لإدارة هوالك البضاعة والتوالف يشمل واجهة المستخدم وطبقة الخدمات وقاعدة البيانات والمحاسبة بشكل كامل.

### أ- هيكل ملفات الوحدة (Module Structure):

| النوع | الملف | الوصف |
|---|---|---|
| **Model** | `Models/WastageModel.vb` | يحتوي على `WastageHeader` و `WastageDetails` |
| **ViewModel** | `ViewModels/WastageViewModel.vb` | منطق العمل الكامل لصفحة الهالك |
| **View XAML** | `Views/WastagePage.xaml` | واجهة المستخدم (MVVM Binding) |
| **Code-Behind** | `Views/WastagePage.xaml.vb` | معالجة أحداث لوحة المفاتيح والـ Visual Tree |
| **Service** | `Services/WastageService.vb` | طبقة الوصول لقاعدة البيانات عبر Dapper |

### ب- الإجراءات المخزنة (Stored Procedures):

| الإجراء | الوصف |
|---|---|
| `[Inventory].[sp_Wastage_GetAll]` | جلب سجلات الهالك مع Pagination |
| `[Inventory].[sp_Wastage_GetDetails]` | جلب تفاصيل الأصناف مع كود الصنف |
| `[Inventory].[sp_Wastage_Save_XML]` | حفظ/تعديل مستند الهالك (XML للتفاصيل) |
| `[Inventory].[sp_Wastage_Post]` | اعتماد الهالك (IsPosted = 1) |
| `[Inventory].[sp_Wastage_Unpost]` | إلغاء الاعتماد (IsPosted = 0) |

### ج- الـ Trigger المحاسبي:

**`[Inventory].[trg_Wastage_Post]`** يعمل على AFTER UPDATE لجدول WastageHeader:

- **ترحيل (0→1):** خصم الكمية من ProductStock + قيد مدين حساب 6401 / دائن حساب المخزن
- **إلغاء (1→0):** إعادة الكمية + حذف قيود ReferenceType = 'Wastage'
- محاط بـ BEGIN TRY/CATCH مع ROLLBACK لضمان الـ Atomicity

### د- الأوامر (Commands) في WastageViewModel:

| الأمر | الشرط | الوصف |
|---|---|---|
| `PostCommand` | Not IsPosted AND WastageID > 0 | اعتماد وخصم المخزون |
| `UnpostCommand` | IsPosted AND CanUnpostAllowed | إلغاء الاعتماد (بصلاحية CanDelete) |
| `SaveCommand` | Not IsPosted | حفظ كمسودة أو حفظ التعديلات |

### هـ- وظائف Code-Behind (WastagePage.xaml.vb):

| الدالة | الوصف |
|---|---|
| `ShowSnackbar` | إشعار سفلي مع إخفاء تلقائي بعد 3 ثوان |
| `FocusLastRowBarcode` | تحريك التركيز لخانة الكود في آخر صف |
| `Barcode_PreviewKeyDown` | Enter في الكود → بحث + انتقال للكمية |
| `ProductComboBox_DropDownClosed` | اختيار الصنف → تعبئة الكود + انتقال |
| `Quantity_PreviewKeyDown` | Enter في الكمية → صف جديد + تركيز |
| `MoveFocusToNextColumn` | تنقل بين الأعمدة بصرياً عبر Visual Tree |
| `FindVisualChild<T>` | بحث نزولاً في الشجرة البصرية |
| `FindVisualParent<T>` | بحث صعوداً في الشجرة البصرية |

### و- حسابات شجرة الحسابات المضافة:

| الكود | الاسم | النوع |
|---|---|---|
| `64` | مصروف الهالك والتوالف | رئيسي (Expenses) |
| `6401` | هالك وتوالف بضاعة | تفصيلي - قابل للترحيل |

### ز- نظام الصلاحيات لصفحة الهالك:

| صلاحية RolePermissions | الوظيفة |
|---|---|
| `CanView` | عرض الصفحة |
| `CanAdd` | إضافة هالك جديد |
| `CanEdit` | تعديل المسودات |
| `CanDelete` | إلغاء الترحيل (زر إلغاء الترحيل) |

### ح- ثوابت StoredProcedures.vb المضافة:

| الثابت | القيمة |
|---|---|
| `SP_WASTAGE_GETALL` | `[Inventory].[sp_Wastage_GetAll]` |
| `SP_WASTAGE_GETDETAILS` | `[Inventory].[sp_Wastage_GetDetails]` |
| `SP_WASTAGE_SAVE_XML` | `[Inventory].[sp_Wastage_Save_XML]` |
| `SP_WASTAGE_POST` | `[Inventory].[sp_Wastage_Post]` |
| `SP_WASTAGE_UNPOST` | `[Inventory].[sp_Wastage_Unpost]` |

---

## قاموس النظام (System Dictionary) — تحديث يونيو 2026

### الجداول المضافة:

| الجدول | المخطط | الوصف |
|---|---|---|
| `WastageHeader` | `[Inventory]` | رؤوس مستندات الهالك |
| `WastageDetails` | `[Inventory]` | تفاصيل أصناف كل مستند |

### الـ Triggers المضافة:

| الـ Trigger | الجدول | الوصف |
|---|---|---|
| `trg_Wastage_Post` | `[Inventory].[WastageHeader]` | خصم المخزون + قيود محاسبية عند الترحيل وعكسهما عند الإلغاء |

### الملفات المضافة (Desktop - VB.NET):

| الملف | النوع | الوصف |
|---|---|---|
| `Models/WastageModel.vb` | Model | WastageHeader و WastageDetails |
| `ViewModels/WastageViewModel.vb` | ViewModel | منطق العمل الكامل |
| `Views/WastagePage.xaml` | UserControl | واجهة المستخدم |
| `Views/WastagePage.xaml.vb` | Code-Behind | أحداث لوحة المفاتيح والـ Visual Tree |
| `Services/WastageService.vb` | Service | CRUD عبر Dapper |

---

## 19. نظام الجرد والهالك لتطبيق الموبايل والـ APIs (FastAPI & Flutter - يونيو 2026)

تم بنجاح ربط وتفعيل نظام **الجرد (Stock Take)** و **الهالك (Wastage)** لتطبيق الهاتف المحمول (`Vegtablity_App`) والواجهة الخلفية الموحدة (`VegtablityApi`). تضمن التعديلات حفظ المستندات كـ **مسودات معلقة** فقط مع إتاحة طباعتها حرارياً.

### أ- هيكل ملفات السيرفر الخلفي (FastAPI Backend Structure):

| المسار | النوع | الوصف |
|---|---|---|
| [schemas/inventory.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/inventory.py) | Schema (Pydantic) | نماذج التحقق للمستندات وتفاصيلها (`WastageSaveRequest`, `StockTakeSaveRequest`) |
| [services/inventory_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/inventory_service.py) | Service | بناء الـ XML والتواصل مع قاعدة البيانات عبر `pyodbc` |
| [routes/inventory.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/inventory.py) | Route | مسارات الـ API لحفظ الجرد والهالك وجلب كمية مخزون وتكلفة المواد |
| [core/db_procedures.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures.py) | Database Procedures | إضافة الثوابت النصية للاستدعاء المركزي للإجراءات المخزنة |

### ب- الإجراءات المخزنة والمسارات المفعلة (SP & APIs Mapping):

| نوع العملية | مسار الـ API | الإجراء المخزن (Stored Procedure) |
|---|---|---|
| **حفظ الهالك** | `POST /inventory/wastage` | `[Inventory].[sp_Wastage_Save_XML]` |
| **حفظ الجرد** | `POST /inventory/stocktake` | `[Inventory].[sp_StockTake_Save_XML]` |
| **معلومات المادة** | `GET /inventory/stock-cost` | `[Inventory].[sp_Stock_GetByProduct]` و `[Inventory].[sp_Inventory_GetAvgCostByProduct]` |
| **المستودعات** | `GET /settings/warehouses` | `[Settings].[sp_Warehouse_GetAll]` |

### ج- هيكل ملفات تطبيق الموبايل (Flutter POS App Structure):

| المسار | النوع | الوصف |
|---|---|---|
| [models/inventory_model.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/models/inventory_model.dart) | Model | تمثيل بيانات الأصناف المحسوبة بالهالك والجرد (`WastageItem`, `StockTakeItem`) |
| [providers/wastage_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/wastage_provider.dart) | Provider (State) | إدارة السلة واحتساب التكاليف وحفظ البيانات احتياطياً أوفلاين |
| [providers/stocktake_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/stocktake_provider.dart) | Provider (State) | إدارة السلة واحتساب الفروقات والكميات الدفترية والفعلية أوفلاين |
| [widgets/product_entry_scanner.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/widgets/product_entry_scanner.dart) | Widget | شريط إدخال مدمج يدعم الكاميرا والبحث اليدوي والكتالوج |
| [screens/inventory/wastage_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/wastage_screen.dart) | UI Screen | شاشة إعداد وحفظ مسودة الهالك وتعديل التكلفة والكميات |
| [screens/inventory/stocktake_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/stocktake_screen.dart) | UI Screen | شاشة إعداد وحفظ مسودة جرد المخزون الفعلي ومقارنته بالدفترية |
| [services/printer_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) | Service | إضافة دوال الطباعة الحرارية للمسودات (`printWastageReceipt`, `printStockTakeReceipt`) |

### د- قواعد وضوابط الجرد والهالك المعتمدة بالهاتف:
1. **قفل المستودع المالي:** يمنع التطبيق تغيير مستودع الجرد أو الهالك بمجرد البدء بإضافة صنف واحد داخل السلة لضمان تماسك البيانات.
2. **استجلاب المخزون والتكلفة ديناميكياً:** يرتبط التطبيق بمسار جلب معلومات المادة لجلب الكمية الدفترية الحالية للفرع والـ Average Cost بناءً على المستودع المحدد.
3. **طباعة المسودات:** عند إتمام الحفظ، يتم استدعاء أوامر الطباعة الحرارية (طابعة Sunmi أو طابعة الشبكة) تلقائياً لطباعة إيصال مخصص وموسوم بـ `"مسودة معلقة للاعتماد"` أو `"مسودة إهلاك بضاعة"`.

---

## 20. تحسينات وتعديلات نظام الجرد والهالك وإصلاحات الطباعة (يوليو 2026)

تم إجراء مجموعة من التحسينات الفنية والبرمجية لضمان تماسك البيانات وسلامة مخرجات الطباعة واستقرار واجهة مستخدم الجرد والهالك:

### أ- تدفق حفظ رصيد الصنف قبل الهالك (StockBefore):
لضمان دقة الرصد المحاسبي وحفظ كمية الصنف المتوفرة في المستودع لحظة إهلاك البضاعة، تم إدراج وحفظ حقل `StockBefore` في كافة طبقات النظام وفق التسلسل التالي:

1. **قاعدة البيانات (SQL Server):**
   * تم تعديل جدول تفاصيل الهوالك `[Inventory].[WastageDetails]` بإضافة عمود `StockBefore DECIMAL(18,3) NULL`.
   * تم تحديث الإجراء المخزن `[Inventory].[sp_Wastage_Save_XML]` ليقوم باستخراج وتخزين قيمة `@StockBefore` من عقد الـ XML الممررة كالتالي:
     ```sql
     INSERT INTO [Inventory].[WastageDetails] (WastageID, ProductID, Quantity, CostPrice, StockBefore)
     SELECT @WastageID,
            x.item.value('@ProductID', 'INT'),
            x.item.value('@Quantity', 'DECIMAL(18,3)'),
            x.item.value('@CostPrice', 'DECIMAL(18,3)'),
            ISNULL(x.item.value('@StockBefore', 'DECIMAL(18,3)'), 0)
     FROM @DetailsXml.nodes('/Details/Item') AS x(item);
     ```

2. **الواجهة الخلفية (FastAPI API):**
   * تحديث نموذج التحقق للبيانات في [schemas/inventory.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/inventory.py) لدعم الحقل:
     ```python
     class WastageDetailRequest(BaseModel):
         ProductID: int
         Quantity: float
         CostPrice: float
         StockBefore: float = 0.0
     ```
   * تحديث بناء الـ XML في [services/inventory_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/inventory_service.py) لإدراج السمة التلقائية في التفاصيل:
     ```python
     "StockBefore": f"{detail.StockBefore:.3f}"
     ```

3. **تطبيق الموبايل (Flutter App):**
   * **تحديث النموذج:** إضافة حقل `stockBefore` إلى كلاس `WastageItem` داخل [inventory_model.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/models/inventory_model.dart) وتجهيز عمليات التحويل من وإلى JSON.
   * **الاستعلام التلقائي:** تحديث منطق إضافة الأصناف بالـ Barcode أو الاختيار اليدوي في `WastageProvider` ليستدعي API جلب الكمية والتكلفة بالخلفية للفرع المحدد، وتعبئة حقل `stockBefore` بالقيمة المرتجعة من قاعدة البيانات (`StockQuantity`).

---

### ب- إصلاح احتساب فروقات الجرد الإجمالية بالطباعة:
* **المشكلة:** عند طباعة إيصال مسودة الجرد، كان يظهر إجمالي الفروقات بقيمة `0.00 KWD` بالرغم من احتواء السلة على أصناف بفروقات مالية.
* **السبب:** كان التطبيق يستدعي حفظ البيانات أولاً والذي يقوم بتصفير عناصر السلة في الـ Provider عند النجاح، ومن ثم يتم جلب قيمة الفروقات الإجمالية للطباعة من السلة الفارغة.
* **الحل:** تم تحديث الكود في [stocktake_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/stocktake_screen.dart) ليقوم بالتقاط وتخزين قيمة `provider.totalDifferenceValue` في متغير مؤقت `totalDiffValue` **قبل** استدعاء دالة الحفظ وتصفير القائمة، وتمرير القيمة المخزنة للطباعة.

---

### ج- تنسيق العملات في طباعة المسودة:
* **المشكلة:** ظهور رمز العملة بجانب فروقات كل صنف فردي في الإيصال كان يسبب تكدس النصوص وصعوبة قراءتها.
* **التعديل:** تم تعديل منطق صياغة الإيصال الحراري في [printer_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) (لطابعات Sunmi والـ Network) لإزالة رمز العملة `_currencySymbol` من سطر تفاصيل الصنف الواحد والإبقاء عليه فقط في سطر إجمالي الفروقات النهائي كالتالي:
  * **سطر الصنف:** `الفرق: 2.00 حبه (قيمة: 5.00)`
  * **سطر الإجمالي:** `إجمالي قيمة الفرق: 5.00 KWD`

---

### د- تحسينات التصميم والتمرير (Scroll & UI Layout):
* **المشكلة:** كانت شاشات الجرد والهالك تتوقف وتسبب أخطاء تجاوز الأبعاد المرئية (RenderFlex Overflow) بسبب استخدام `Expanded` لقائمة الأصناف داخل شاشات تحتوي على مدخلات وحقول ملاحظات متعددة.
* **الحل:**
  1. قمنا بالتخلص من عناصر الـ `Expanded` حول الـ `ListView` الخاصة بالسلة.
  2. تم دمج كافة مكونات الصفحة (المستودع، حقل المسح، قائمة السلة، وحقل الملاحظات مع زر الحفظ) داخل `SingleChildScrollView` رئيسي واحد ممتد.
  3. إعداد الـ `ListView.builder` لتأخذ الخواص التالية لمنع تعارض التمرير:
     * `shrinkWrap: true` لتمتد القائمة ديناميكياً بحسب حجم العناصر.
     * `physics: const NeverScrollableScrollPhysics()` لإسناد مهمة التمرير الكلي للـ `ScrollView` الخارجي.
  4. إصلاح خلل تطابق الأقواس المفقودة في نهاية إرجاع خلايا الـ `Card` و `Padding` لاستعادة إمكانية البناء بنجاح.

---

## 21. دمج الجرد والهلاك في حركة الصنف (Product Card) وتنسيق الصفحة والعملات (يوليو 2026)

تم دمج حركات الجرد المخزني وهلاك البضاعة بشكل كامل داخل واجهة **بطاقة الصنف (Product Card)** لتتبع الكميات بدقة، بالإضافة لتحديث المظهر البصري لبطاقة الصنف وتهيئة العملة ديناميكياً:

### أ- دمج حركات الجرد والهلاك في سجل حركة الصنف:
1. **قاعدة البيانات (SQL Server Stored Procedures):**
   * تحديث `[Inventory].[sp_ProductCard_GetSummary]`: تم دمج كميات الجرد بالزيادة ضمن "إجمالي الوارد"، وتضمين كميات الجرد بالعجز وكميات الهلاك ضمن "إجمالي الصادر" لتحديث قيم متوسط التكلفة وحسابات الأرباح الإجمالية بدقة.
   * تحديث `[Inventory].[sp_ProductCard_GetStockByWarehouse]`: لحساب إجمالي الوارد، الصادر، والهالك الخاص بالصنف مفرزاً لكل مستودع بشكل مستقل.
   * تحديث `[Inventory].[sp_ProductCard_GetMovements]`: تم استخدام `UNION ALL` لضم حركات الهوالك المرحلة والجرود المعتمدة في كشف حركات الصنف الموحد، مع جلب رقم الفاتورة `InvID` مباشرة كـ `ReferenceNo` لعرضه للمستخدم في عمود "رقم السند".
   * تحديث `[Inventory].[sp_ProductCard_GetChartData]`: لتضمين كميات الجرد والهلاك في الرسم البياني للرصيد التراكمي وتحديث التقارير.
2. **النماذج وطبقة منطق العمل (VB.NET):**
   * تحديث [ProductCardModels.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/ProductCardModels.vb): إدراج الحقول `IncomingQty` و `OutgoingQty` و `WastageQty` ضمن كلاس `WarehouseStock`.
   * تحديث [ProductCardViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ProductCardViewModel.vb):
     * تحديث الدالة `ExecuteOpenInvoice` لتوجيه المستخدم لصفحة الجرد أو الهالك الأصلية (الكود 3 للهلاك والكود 4 للجرد).
     * زيادة حجم الصفحة الافتراضي `_pageSize` إلى 20 حركة، مع تهيئة الكوماند `NextPageCommand` للتنقل السلس.
     * تعريف حقل `CurrencySymbol` واستدعاء `GetCompanyInfo` عبر الـ `SettingsService` لتمرير الرمز للواجهة ديناميكياً.
   * تحديث [InventoryPage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/InventoryPage.xaml.vb): استيراد مساحة الأسماء `Vegtablity.Models` وتوسيع معالج `RequestNavigateToInvoiceAction` للتوجيه وعرض تفاصيل مستندات الهالك والجرد المحددة.

### ب- التنسيق البصري وعرض العملات الديناميكية:
1. **المظهر الرأسي الممتد (UI Layout):**
   * في [ProductCardControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ProductCardControl.xaml), تم إعادة توزيع العناصر لتنصيف الصفحة عمودياً:
     * تم وضع **الرسم البياني (Cumulative Chart)** ممتداً بعرض الصفحة بالكامل في الجزء العلوي لتسهيل التتبع والتحليل.
     * تم وضع **جدول الحركات (DataGrid)** ممتداً بعرض الصفحة بالكامل في الجزء السفلي أسفل الرسم البياني لتوفير عرض مريح وخالٍ من الانضغاط لكافة أعمدة الحركات.
2. **العملة الديناميكية من إعدادات قاعدة البيانات:**
   * تم استبدال رمز العملة الثابت `KWD` في واجهة بطاقة الصنف بالرابط ديناميكياً `{Binding CurrencySymbol}` بجميع بطاقات الإحصائيات (متوسط سعر التكلفة، آخر سعر شراء، إجمالي قيمة الوارد، وإجمالي قيمة الصادر).

---

## 22. ربط وتعميم المستودعات في الوردية وتطوير الطباعة وواجهة التقرير اليومي بالـ Flutter (يوليو 2026)

تم إدخال تحديثات جوهرية على تطبيق الهاتف المحمول (Flutter) لتعزيز التحكم بالمستودعات، وتسهيل الفوترة، وتحسين المظهر البصري لتقارير الفواتير اليومية وإيصالات الطباعة:

### أ- ربط المستودع بالوردية وتعميمه في الفواتير (Warehouse & Shift Integration):
1. **مزود الوردية ([shift_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/shift_provider.dart)):**
   * إدخال دوال تحميل وتخزين المستودعات `loadWarehouses()` عبر الـ API.
   * ربط اختيار المستودع بذاكرة الجهاز المؤقتة والدائمة `SharedPreferences` تحت مفاتيح `selected_warehouse_id` و `selected_warehouse_name` ليبقى المستودع فعالاً طوال فترة فتح الوردية.
   * استرجاع المستودع تلقائياً عند فحص حالة الوردية الفعالة `checkActiveShiftStatus()`.
2. **واجهة فتح الوردية ([shift_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/shift_screen.dart)):**
   * إضافة قائمة منسدلة (DropdownButtonFormField) لاختيار المستودع المناسب قبل فتح الوردية، ومنع المستخدم من فتح الوردية دون تحديد المستودع.
3. **مزود الحسابات ([account_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/account_provider.dart)):**
   * تحديث دالة `fetchGeneralPartnerId()` لحفظ معرف العميل العام (كاش / سند مباشر) في الـ `SharedPreferences` بعد جلبه من الـ API، مع استدعائها في الخلفية فور تحميل الصفحة الرئيسية ([home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)).
4. **مزود نقطة البيع ([pos_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart)):**
   * تعديل منطق مسح الأصناف للاحتفاظ بالمعرف الحقيقي للصنف `ProductID` قادماً من السيرفر.
   * إعادة تصميم دالة `saveInvoice` لبناء حزمة بيانات كاملة متوافقة 100% مع نموذج التحقق بالـ Backend (`InvoiceCreate` Schema)، لتضمين المستودع الفعال للوردية ومعرف العميل كاش والكميات وتفاصيل الأسعار بشكل سليم.
5. **شاشة فواتير الشركاء ([partner_billing_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_billing_screen.dart)):**
   * تعديل حقل المستودع لقراءة معرف المستودع ديناميكياً من الـ `SharedPreferences` بدلاً من استخدام القيمة الثابتة (`1`).

### ب- تطوير تقرير إيصال الطباعة الموحد (Receipt Print Layout Updates):
1. **ترويسة المستودع المفتوح ([printer_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart)):**
   * إضافة كود قراءة اسم المستودع المختار للوردية وطباعته بوضوح في رأس التقارير للفواتير (`printReceipt`)، وتقرير إغلاق الوردية اليومي (`printDailyReport`)، وسندات القبض والصرف الفردية والعامة (`printVoucher` و `printGeneralVoucher`).
2. **تبسيط وحذف تكرار العملة:**
   * تعديل أسطر تفاصيل الأصناف المطبوعة وحذف تكرار رمز العملة (`د.ك` أو `KWD`) من جانب أسعار الوحدات وإجماليات السطور في الفواتير ومسودات الهالك (`printWastageReceipt`)، والاكتفاء فقط بعرض رمز العملة في تذييل التقرير والمجاميع المالية النهائية لسهولة القراءة وترتيب التصميم.

### ج- تنظيم واجهة تقرير الفواتير اليومية وتخطيط الوضع الكلاسيكي:
1. **شاشة تقرير الفواتير اليومية ([daily_invoices_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_invoices_screen.dart)):**
   * التخلص من تكرار رمز العملة بجوار كل معاملة فردية في قوائم المبيعات والمشتريات والسندات، والإبقاء عليها فقط في الإجماليات وملخصات الصندوق والتدفق النقدي أسفل الشاشة لإراحة عين المستخدم.
2. **ترتيب وتناسق الوضع الكلاسيكي ([home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)):**
   * إعادة بناء واجهة الوضع الكلاسيكي بالكامل لتعمل بنظام شبكي متجاوب (`GridView.count`) بدلاً من الـ `Wrap` القديم.
   * تترتب البطاقات تلقائياً بجانب بعضها البعض كصفين متتاليين (2 في كل صف على الهواتف، و3 في كل صف على الأجهزة اللوحية الكبيرة).
   * إلغاء كرت "إدارة الموردين / العملاء" وكرت "استدعاء عرض مبيعات" بالكامل لتبسيط الواجهة وتركيز العمل على المبيعات الجديدة، والجرد، والهالك.



---

## 23. تطوير نظام السداد في الوردية وبدء المشتريات وتفصيل نموذج الفاتورة المكتبي (يوليو 2026)

تم تصميم وتطوير الميزات التالية لضمان تلبية طلبات التحكم بطرق السداد في شاشة الوردية والـ POS بالـ Flutter، ودعم نموذج طباعة تفصيلي للفواتير A4 بالـ WPF المكتبي:

### أ- خيار نوع السداد (نقدي / آجل) بالـ POS والـ Flutter:
1. **مزود نقطة البيع ([pos_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart)):**
   * إدخال معامل نوع الدفع (`paymentType` بـ 'Cash' أو 'Credit').
   * تعديل حساب المدفوع (`PaidAmount`) والمتبقي (`RemainingAmount`) ديناميكياً بناءً على الخيار المختار.
   * إرسال معالم الدفع للـ API بطريقة صحيحة لحفظ السندات والحركات بشكل دقيق.
2. **واجهة نقطة البيع ([pos_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart)):**
   * إدراج `ChoiceChip` للتبديل السريع والواضح بين مبيعات كاش ومبيعات آجلة.
   * التحكم في إظهار وإخفاء قائمة الخزائن وحسابات السداد تبعاً لنوع السداد لمنع إدخال خاطئ.
   * إدراج زر ديناميكي لتغيير العميل أو المورد المختار حالياً للفاتورة مباشرة من شاشة الـ POS لتسجيل الفاتورة على حسابه الآجل.

### ب- واجهة الموردين وبدء المشتريات من الوضع الكلاسيكي:
1. **شاشة اختيار الشركاء والموردين ([partner_selection_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_selection_screen.dart)) - [جديدة]:**
   * ملف جديد تماماً يعرض قائمة للعملاء والموردين ويدعم البحث الفوري بالاسم أو برقم الحساب.
   * تحتوي الشاشة على باني يقبل متغير `isSelectionOnly` و `type`.
     - **الحالة الأولى (`isSelectionOnly = false`):** عند النقر على المشتريات بالوضع الكلاسيكي، تفتح الشاشة لاختيار المورد، وعند اختياره توجه المستخدم تلقائياً لـ `PosScreen` الخاص بالمشتريات لبدء الفوترة محملة بالـ `partnerID` والاسم.
     - **الحالة الثانية (`isSelectionOnly = true`):** عند النقر لتغيير العميل/المورد من داخل شاشة الـ POS، تعود الشاشة بالـ `Pop` محملة بالبيانات فقط لتحديث حالة الـ POS النشط.

### ج- نموذج الفاتورة التفصيلي الجديد بالـ WPF (Desktop App):
1. **إعدادات قاعدة البيانات (Stored Procedures):**
   * تم إدراج العمود الجديد `UseDetailedInvoiceDesign` بقيمة افتراضية `0` في جدول `CompanySettings`.
   * تحديث إجراء الجلب `[Settings].[sp_CompanySettings_Get]` لترقية قراءة الحقل الجديد صراحةً.
   * تحديث إجراء الحفظ `[Settings].[sp_CompanySettings_Save]` لحفظ حالة التفعيل في النظام.
2. **تعديل الـ Models والـ ViewModels:**
   * **[CompanyInfo.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/CompanyInfo.vb):** إضافة الخاصية `UseDetailedInvoiceDesign`.
   * **[CompanySettingsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/CompanySettingsViewModel.vb):** إدارة تحميل وتخزين الخاصية وربطها بالواجهة.
   * **[CompanySettingsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/CompanySettingsPage.xaml):** إضافة CheckBox بالواجهة للسماح للمستخدم بتفعيل أو إلغاء تفعيل التصميم التفصيلي للفاتورة.
3. **تطوير محرك الطباعة المكتبي ([InvoicePrinter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/InvoicePrinter.vb)):**
   * يدعم المحرك فحص حالة `UseDetailedInvoiceDesign`:
     * **حالة False:** رسم الفاتورة بالتصميم الكلاسيكي القديم لضمان ثباته بالكامل.
     * **حالة True:** تشغيل التصميم التفصيلي الجديد:
       - **ترويسة مكررة:** رسم شعار الشركة موسطاً بالأعلى، تحته اسم وعنوان الشركة موسطين، ثم عنوان الفاتورة وصناديق معلومات العميل والفاتورة الموحدة في رأس **كل صفحة**.
       - **حدود الجدول (Gridlines):** رسم خطوط الجدول الرأسية والأفقية التي تقسم وتحدد خانات الأصناف السبعة بجمالية عالية.
       - **تذييل مكرر:** رسم معلومات التواصل (الهاتف والإيميل) موسطة بالأسفل مع أرقام الصفحات ورقم الفاتورة في أسفل **كل صفحة**.



---

## 24. إضافة خيار تصميم الطباعة المخصص الجديد وتنسيق أبعاد الفاتورة (يوليو 2026)

تم تصميم وتطوير وإدراج خيار جديد كلياً للطباعة المخصصة لتمكين إدارة وتخصيص هوامش وأبعاد فواتير المبيعات والمشتريات المكتبية بشكل منفصل وتفادي التأثير على التصميم القديم الثابت للبرنامج.

### أ- التعديلات على مستوى قاعدة البيانات (SQL Server):
1. **جدول الإعدادات:** تم إضافة عمود `UseCustomInvoiceDesign` من نوع `BIT` بقيمة افتراضية `0` في جدول الإعدادات.
2. **الإجراءات المخزنة (SPs):**
   * تحديث الإجراء `[Settings].[sp_CompanySettings_Get]` ليتضمن جلب الحقل الجديد.
   * تحديث الإجراء `[Settings].[sp_CompanySettings_Save]` لحفظ حالة التفعيل في جدول الإعدادات.
   * تحديث الإجراء `[Sales].[sp_Report_InvoicePrint]` ليقوم بجلب حقول `Remainder` 
و `PaidAmount` لتحديد نوع الفاتورة تلقائياً (نقدي / آجل).

### ب- التعديلات على كلاسات ونموذج الإعدادات (VB.NET):
1. **الـ Model والـ Service:**
   * تم تعديل [CompanyInfo.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/CompanyInfo.vb) لإدراج الخاصية `UseCustomInvoiceDesign`.
   * تم تعديل [SettingsService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/SettingsService.vb) لتضمين الحقل في جمل استعلام وحفظ بيانات الشركة عبر Dapper.
2. **واجهة الإعدادات والـ ViewModel:**
   * تم إضافة CheckBox مخصص بصفحة [CompanySettingsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/CompanySettingsPage.xaml) لربط القيمة برمجياً بـ `UseCustomInvoiceDesign`.
   * تم تحديث [CompanySettingsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/CompanySettingsViewModel.vb) لإرسال واستقبل القيمة ومزامنتها مع الخادم.

### ج- كلاس طابعة الفواتير المخصصة [InvoicePrinterCustom.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/InvoicePrinterCustom.vb):
تم إنشاء كلاس طابعة جديد ومستقل تماماً لحمل التصميم المخصص للفاتورة والتحكم بكافة أبعاده ومقاساته بدقة:
1. **تعديل أبعاد الترويسة والصفحة بالكامل للأسفل بمقدار 1 سم:**
   * أسطر الترويسة باليسار: اسم العميل (`gt(4.0F)`)، نوع الفاتورة (`gt(5.0F)`)، الملاحظات (`gt(6.0F)`).
   * أسطر الترويسة باليمين: رقم الفاتورة (`gt(4.0F)`)، التاريخ (`gt(5.0F)`)، رقم الحساب (`gt(6.0F)`).
   * بداية جدول الأصناف `ITEM_START_CM` تم تحديدها بـ `8.0F`.
   * نهاية جدول الأصناف `ITEM_END_CM` تم تحديدها بـ `22.0F`.
   * إزاحة سطر التفقيط الإجمالي والمجموع ليصبح عند الارتفاع `footerY = gt(21.0F)`.
   * إزاحة سطر رقم الصفحة (السطر التالي) ليصبح عند الارتفاع `pageRect = gt(25F)`.
2. **إزاحة نصوص الترويسة اليمين (رقم الفاتورة، التاريخ، رقم الحساب) إلى اليسار بمقدار 2 سم:**
   * ملصق وقيمة رقم الفاتورة: `gl(12.5F)` و `gl(16.0F)`.
   * ملصق وقيمة تاريخ الفاتورة: `gl(12.0F)` و `gl(16.0F)`.
   * ملصق وقيمة رقم الحساب: `gl(12.0F)` و `gl(16.0F)`.
3. **تحديث إحداثيات أعمدة الأصناف بجدول الأصناف:**
   * **الوحدة:** إزاحة إلى اليمين بمقدار 1 سم لتصبح عند `gl(11.7F)`.
   * **الكمية:** إزاحة إلى اليمين بمقدار 0.5 سم لتصبح عند `gl(13.7F)`.
   * **السعر:** إزاحة إلى اليمين بمقدار 0.5 سم لتصبح عند `gl(15.9F)`.
   * **الإجمالي:** إزاحة إلى اليسار بمقدار 0.5 سم لتصبح عند `gl(18.0F)`.
4. **تحديد نوع الفاتورة تلقائياً:** يتم فحص المتبقي `Remainder` في الفاتورة؛ فإذا كان مساوياً أو أقل من الصفر يتم طباعة نوع الفاتورة كـ `cash` (نقدي)، وإلا يتم طباعتها كـ `credit` (آجل) بشكل ديناميكي مدمج تحت سطر اسم العميل.

### د- توجيه منطق الطباعة بـ [SalesInvoiceViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/SalesInvoiceViewModel.vb):
* تم تعديل تابع الطباعة `ExecutePrint` لفحص حالة الإعدادات:
  * **إذا كان خيار التصميم المخصص نِشطاً:** يتم إنشاء كائن من `InvoicePrinterCustom` لطباعة الفاتورة بالتصميم الجديد.
  * **إذا كان غير نشط:** يتم التراجع تلقائياً لتشغيل `InvoicePrinter` الكلاسيكي القديم لضمان عدم حدوث أي تغيير مفاجئ للمستخدمين الآخرين.



---

## 25. تعديل واجهة المورد والعميل ورقم الحساب المالي بالـ POS (يوليو 2026)

تم حل مشكلة رصيد الشركاء وعرض أرقام الحسابات المالية الخاصة بهم كالتالي:

### أ- جعل رصيد المورد/العميل ديناميكياً:
- تم تعديل شاشة اختيار الشريك [supplier_selection_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/supplier_selection_screen.dart) في تطبيق الـ Flutter.
- تم استبدال الكود الثابت للعلامة بحيث يفحص قيمة الرصيد `balance`:
  - إذا كان الرصيد موجباً (`balance >= 0`): يعرض النص **"مستحق له"** باللون الأخضر.
  - إذا كان الرصيد سالباً (`balance < 0`): يعرض النص **"مستحق عليه"** باللون الأحمر.

### ب- عرض رقم الحساب المالي [AccountCode] من شجرة الحسابات:
- **المشكلة:** كانت الواجهة تعرض معرف الحساب `AccountID` بدلاً من رقم الحساب المالي `AccountCode` عند فتح الواجهة لأول مرة (قبل البحث).
- **السبب:** الإجراء المخزن `sp_Partner_GetAll` لم يكن يدمج جدول شجرة الحسابات `ChartOfAccounts` ولا يرجع الحقل `AccountCode` في جملة التحديد `SELECT`؛ كما أن الـ Schema الخاص بـ `Partner` في FastAPI لم يكن يحتوي على حقل `AccountCode` لتمثيل وتمرير البيانات.
- **الحل:**
  1. تحديث الإجراء المخزن `[Sales].[sp_Partner_GetAll]` في ملف السكربت الموحد [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) ليدمج جدول `[Accounting].[ChartOfAccounts]` ويرجع `c.AccountCode`.
  2. تحديث الإجراء نفسه في ملف السكربت الفرعي [05_StoredProcedures_Partners.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/05_StoredProcedures_Partners.sql) لضمان اتساق السكربتات بجميع مجلدات المشروع.
  3. تحديث الـ API Schema بملف [partners.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/partners.py) لإدراج الحقول `AccountID` و `AccountCode` لكي يقوم السيرفر بإرجاعها إلى التطبيق بنجاح.


---

## 26. دمج عروض وسندات الشركاء بالواجهة الكلاسيكية للشاشة الرئيسية (يوليو 2026)

تم نقل شاشات عروض الشركاء وسندات الصرف والقبض إلى الواجهة الكلاسيكية الرئيسية في [home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) لتسهيل إدارتها:
* **مجموعات البطاقات الجديدة بالشبكة (Classic Grid Layout):**
  1. **مجموعة المبيعات ونقاط البيع:** 
     - *فاتورة مبيعات جديدة* (`PosScreen(type: 'Sales')`)
     - *مبيعات العملاء - عروض الأسعار* (`PartnerOffersScreen(type: 'Sales')`)
  2. **مجموعة المشتريات:** 
     - *فاتورة مشتريات جديدة* (`PartnerSelectionScreen(type: 'Purchase')`)
     - *مشتريات الموردين - عروض الأسعار* (`PartnerOffersScreen(type: 'Purchases')`)
  3. **مجموعة الصندوق والمالية:** 
     - *تحصيل العملاء - سند قبض* (`ReceiptVoucherScreen`)
     - *دفع الموردين - سند صرف* (`PaymentVoucherScreen`)
  4. **مجموعة المخازن:** 
     - *جرد المخزون* (`StockTakeScreen`)
     - *إهلاك بضاعة* (`WastageScreen`)


---

## 27. إدارة المبيعات السريعة والمسجلة بنقاط البيع (يوليو 2026)

تم تحسين تدفق بدء فاتورة مبيعات جديدة ليتيح اختيار العميل أولاً (بين المبيعات السريعة كاش أو العملاء المسجلين):
* **توجيه شاشة المبيعات:** عند الضغط على "فاتورة مبيعات جديدة" بالشاشة الرئيسية، يتم توجيه الكاشير أولاً لشاشة اختيار الشريك `PartnerSelectionScreen(type: 'Sales')` عوضاً عن الدخول المباشر.
* **البطاقة السريعة للعميل العام (نقدي عام):** تم إضافة بطاقة ثابتة ومميزة باللون الأخضر الفاتح لـ **"نقدي عام"** في مقدمة قائمة العملاء (تظهر كأول عنصر دائماً).
* **دورة العمل المحسنة:**
  - **مبيعات سريعة (walk-in):** يضغط الكاشير على بطاقة "نقدي عام" مباشرة للدخول لشاشة الـ POS وبدء الفوترة مباشرة.
  - **مبيعات لعميل مسجل:** يبحث الكاشير عن اسم العميل أو هاتفه أو حسابه المالي بالأسفل ويختاره ليتم فتح الـ POS بالاسم المحدد للتسجيل المالي.


---

## 28. تسريع أداء شاشات نقاط البيع وتخفيض استهلاك المعالج والذاكرة (يوليو 2026)

تم تنفيذ باقة تحسينات للأداء للتخلص من أي ثقل أو تباطؤ (Lag) وتخفيض حرارة واستهلاك طاقة أجهزة الأندرويد الضعيفة (مثل Sunmi V2s) كالتالي:
* **تخزين كتالوج الأصناف بالذاكرة (Product Catalog Caching):**
  - تم إزالة الـ `FutureBuilder` المباشر الذي كان يعيد تحميل الأصناف وفك ترميز JSON لآلاف الأصناف عند كل رسم للواجهة.
  - تم إنشاء مصفوفة كاش بذاكرة الشاشة `_allProducts` وتحميل قائمة الأصناف وفرزها برمجياً لمرة واحدة فقط عند الدخول لشاشة الـ POS. أصبح رسم المنتجات يعتمد بالكامل على قراءة الذاكرة الفورية ($O(1)$) مما جعل التحرك والتصفح سلساً جداً وبدون استخدام للإنترنت أو الشبكة.
* **زر تحديث المنتجات اليدوي (Refresh Catalog Button):**
  - تم إضافة زر تحديث دائري مميز في ترويسة الكتالوج، يتيح للكاشير النقر عليه يدوياً لتحديث قائمة المنتجات والأسعار من السيرفر عند اللزوم (Force Refresh).
* **إدارة دورة حياة كاميرا الباركود (Mobile Scanner Controller Management):**
  - تم تعريف الـ `MobileScannerController` خارج البناء المستمر، وضمان عمل `dispose()` له فور إغلاق نافذة المسح لتحرير مستشعرات الكاميرا بالكامل وتوفير طاقة بطارية ومعالج الجهاز.
* **تخفيف المعالجة وفك الترميز (Optimized JSON Processing):**
  - بالاعتماد على معالجة الخلفية بـ Dio 5.4 (`BackgroundTransformer`) ونقل حلقات تصنيف وتجميع الأصناف لتتم مرة واحدة فقط عند استقبال البيانات، تم تحرير المسار الرسومي بالكامل (UI Thread) من أي عمليات جرد حسابية متكررة مما يوفر 60 إطاراً بالثانية (FPS) مستقرة.


---

## 29. نقل واجهة إجمالي ودفع الفواتير إلى نافذة منبثقة أسفل الشاشة (يوليو 2026)

تم إعادة تصميم طريقة إنهاء الفواتير للمبيعات والمشتريات على الهواتف لتصبح أكثر انسيابية وتوفر مساحة عرض أكبر لقائمة أصناف السلة:
* **شريط الإجمالي المضغوط (Compact Bottom Bar):** تم استبدال لوحة الدفع الثابتة الكبيرة بأسفل الشاشة بشريط مضغوط وأنيق يعرض فقط (الإجمالي الكلي بالدينار الكويتي) و(زر "إنهاء الطلب").
* **نافذة الدفع المنبثقة (Checkout Popup BottomSheet):** عند الضغط على "إنهاء الطلب":
  - تظهر نافذة منبثقة بتأثير حركي سلس من أسفل الشاشة.
  - تعرض النافذة الإجمالي بوضوح، مع خيارات تحديد نوع الفاتورة (نقدي / آجل).
  - عند اختيار "نقدي / كاش"، يظهر بشكل تفاعلي قائمة اختيار حساب الدفع / الصندوق.
  - عند الضغط على زر الدفع النهائي بالنافذة، يتم إغلاقها تلقائياً ثم استدعاء دالة الحفظ والطباعة فوراً.
* **التعميم الكامل:** تعمل هذه النافذة بشكل متوافق وتلقائي مع فواتير المبيعات وفواتير المشتريات على حد سواء، مع تلوين الأزرار والعمليات ديناميكياً لتطابق طبيعة الشاشة (أخضر للمبيعات، برتقالي للمشتريات).


---

## 30. إضافة دعم أحجام الورق الحراري (58 ملم و 80 ملم) لطباعة الفواتير (يوليو 2026)

تم دعم ميزة اختيار حجم ورق الطباعة الحراري وتعديل أطوال الخطوط الفاصلة والمحتوى تلقائياً:
* **تخزين الإعداد محلياً (Paper Size Preference):**
  - تم إضافة الحقل `_paperSize` وقيمته الافتراضية `80`.
  - يتم قراءة الإعداد محلياً من الذاكرة (`printer_paper_size`) وتحديث قيمته فور الحفظ.
* **المرونة وتكامل الفواصل (Adaptive Separators):**
  - تم تعريف خطوط فاصلة ديناميكية `_separator` و `_dashedSeparator` تتغير تلقائياً حسب حجم الورق المحدد:
    * **80 ملم (Desktop/Standard):** يعطي فاصل بـ 48 حرفاً (`================================================`).
    * **58 ملم (Mobile/Sunmi):** يعطي فاصل بـ 32 حرفاً (`================================`).
* **شاشة إعدادات الطابعة (Printer Settings Screen):**
  - تم إضافة حقل اختيار منسدل (Dropdown) لاختيار حجم الورق (58 ملم أو 80 ملم) أسفل خيار تحديد نوع الاتصال.
  - يتم تحميل الخيار وحفظه وتطبيقه مباشرة على الطباعة الحرارية المتصلة بالشبكة أو البلوتوث.


---

## 31. تنفيذ ميزة طلبات الزبائن المؤقتة والتوصيل بنقاط البيع (يوليو 2026)

تم تطبيق واجهة ودورة عمل متكاملة لحفظ طلبات الزبائن المؤقتة وتفاصيل التوصيل:
* **التخزين وقاعدة البيانات (SQL Database):**
  - تم إنشاء جدول مستقل `Sales.TempOrderInfo` لتخزين معلومات التوصيل والزبون المؤقت مع ربط `InvID` كـ `UNIQUE FOREIGN KEY` لحمايتها وتجنب تعديل جدول `InvoiceHeader` الأساسي.
  - تم تحديث الإجراء المخزن `sp_Invoice_Save_XML` لإضافة المعاملات الجديدة بقيم افتراضية `NULL` لضمان التوافق المطلق، وحفظ البيانات بالجدول الجديد تحت نفس الـ Transaction بنهج `XACT_STATE` الآمن.
* **الخادم الخلفي (FastAPI Backend):**
  - تم تحديث مخطط `InvoiceCreate` في `app/schemas/invoices.py` لإضافة المعاملات الجديدة اختيارياً.
  - تم تحديث ملفات `db_procedures.py` و`invoice_service.py` لتمرير المعطيات إلى الإجراء المخزن.
* **تطبيق الموبايل (Flutter App):**
  - تم إضافة خيار **نمط عمل العميل النقدي العام** في شاشة الإعدادات `printer_settings_screen.dart` لحفظ التفضيل محلياً بـ `SharedPreferences` (البيع المباشر الفوري أو طلب لزبون مؤقت وتوصيل).
  - تم إنشاء شاشة `TemporaryOrderScreen` لجمع (الاسم، الهاتف، العنوان، تاريخ التوصيل، وقت التسليم، والملاحظات) مع توفير خيار للتخطي والمتابعة المباشرة.
  - تم تحديث `supplier_selection_screen.dart` لتوجيه المستخدم للشاشة الجديدة عند النقر على "نقدي عام" وبشرط تفعيل الخيار من الإعدادات.
  - تم تحديث `printer_service.dart` لطباعة تفاصيل الزبون والتوصيل ديناميكياً على الفواتير الحرارية (لـ Sunmi والشبكة).


---

## 32. تصميم الفاتورة الجديد وفصل التنسيق ودعم طباعة الشعار (يوليو 2026)

تم تحسين وتسهيل صيانة كود الطباعة عبر إدخال كلاس تصميم فواتير مخصص وإدماج طباعة الشعارات:
* **فصل التنسيق وتطوير ReceiptDesigner:**
  - تم إنشاء كلاس مستقل `ReceiptDesigner` في `lib/services/receipt_designer.dart` ليحوي كامل منطق تنسيق وحساب المحاذاة والخطوط الفاصلة متأقلمة مع حجم الورقة المحددة (58 ملم أو 80 ملم).
  - تم تقليص حجم ملف `printer_service.dart` بأكثر من 300 سطر وتفويض طباعة الفواتير بشكل كامل إلى الكلاس الجديد.
* **دعم طباعة الشعار (Company Logo) تكيفياً:**
  - **طابعات Sunmi:** قراءة الشعار الـ Base64 من إعدادات الشركة وفك تشفيره وطباعته بالمنتصف عبر `SunmiPrinter.printImage`.
  - **طابعات الشبكة IP:** استخدام خوارزمية ذكية مدمجة لتحويل وفك تشفير وتحجيم الشعار باستخدام `dart:ui` والـ Canvas وإنتاج الأوامر النقطية الناتجة المتوافقة مع بروتوكول `ESC/POS` بأمر `GS v 0` ليعمل على كافة أجهزة الطباعة المكتبية بنجاح ودون مكاتب إضافية.
  - تم تطبيق طباعة الشعار على الفواتير، وسندات المقبوضات والمدفوعات العامة، وملخص إغلاق الوردية وكافة المطبوعات.


---

## 33. إزالة نمط عروض الشركاء الجديد والصفحات التابعة له نهائياً (يوليو 2026)

بناءً على طلب المستخدم، تم إيقاف وإلغاء ميزة نمط عروض الشركاء الجديد كلياً من الكود والواجهات:
* **حذف خيارات التخصيص والواجهات:**
  - تعديل شاشة الإعدادات العامة `settings_screen.dart` لإلغاء قسم "تخصيص الواجهة" بالكامل ليعود التطبيق إلى استخدام النمط الكلاسيكي الشبكي بشكل دائم ومستقر.
  - إزالة خيارات وتوابع تخزين `pref_home_layout` وتطهير الكود منها.
* **تنظيف الشاشة الرئيسية وحذف الملفات:**
  - تعديل الشاشة الرئيسية `home_screen.dart` لإلغاء دالة بناء واجهة عروض الشركاء `_buildPartnersOffersLayout` ودالة البطاقات المتوهجة التابعة لها.
  - إزالة أزرار عروض الأسعار النشطة للعملاء والموردين من الشبكة الكلاسيكية لعدم الحاجة إليها.
  - حذف الملف البرمجي بالكامل من النظام: `lib/screens/partner_offers_screen.dart`.


---

## 33. إزالة نمط عروض الشركاء الجديد والصفحات التابعة له مع الحفاظ على بطاقات عروض الأسعار بالوضع الكلاسيكي (يوليو 2026)

بناءً على طلب المستخدم، تم إيقاف وإلغاء ميزة نمط عروض الشركاء الجديد كلياً مع استعادة بطاقات العروض في النمط الكلاسيكي:
* **تحديث شاشة الإعدادات العامة:**
  - تعديل شاشة الإعدادات العامة `settings_screen.dart` لإلغاء قسم "تخصيص الواجهة" بالكامل ليعود التطبيق إلى استخدام النمط الكلاسيكي الشبكي بشكل دائم ومستقر.
* **تنظيف الشاشة الرئيسية واستعادة شاشة العروض:**
  - تعديل الشاشة الرئيسية `home_screen.dart` لإلغاء دالة بناء واجهة عروض الشركاء `_buildPartnersOffersLayout` ودالة البطاقات المتوهجة التابعة لها.
  - إبقاء وإعادة بطاقتي "مبيعات عروض العملاء" و"مشتريات عروض الموردين" داخل واجهة الشبكة الكلاسيكية لتعمل بصورة طبيعية.
  - استعادة ملف الشاشة [partner_offers_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_offers_screen.dart) لضمان عدم وجود أخطاء في مسارات البطاقات.


---

## 34. إضافة قسم لتخصيص معروضات الصفحة الرئيسية في شاشة الإعدادات العامة (يوليو 2026)

تم تمكين المستخدم من اختيار وتخصيص البطاقات والاختصارات التي تظهر في الصفحة الرئيسية بالتطبيق:
* **تخزين وتعديل التفضيلات:**
  - تعديل شاشة الإعدادات العامة `settings_screen.dart` لإضافة قسم جديد "تخصيص معروضات الصفحة الرئيسية" ويحتوي على مفاتيح تبديل (`SwitchListTile`) لكل بطاقة من بطاقات المظهر الكلاسيكي الثمانية.
  - يتم حفظ وتخزين التفضيلات مباشرة في الذاكرة المحلية `SharedPreferences` باستخدام مفاتيح `show_new_invoice`, `show_new_purchase`, `show_customer_sales`, `show_supplier_purchases`, `show_customer_receipts`, `show_supplier_payments`, `show_stocktake`, `show_wastage` بقيمة افتراضية `true`.
* **فلترة الصفحة الرئيسية ديناميكياً:**
  - تعديل الشاشة الرئيسية `home_screen.dart` لتحميل التفضيلات ديناميكياً داخل دالة `_loadHomeLayout()`.
  - تطبيق الفلترة البرمجية في `_buildClassicLayout()` لبناء مصفوفة البطاقات بشكل ديناميكي كامل.
  - إظهار رسالة تحذيرية منسقة في حال قام المستخدم بتعطيل ظهور كافة البطاقات لإعلامه بالذهاب إلى الإعدادات العامة وتفعيل بطاقة واحدة على الأقل.


---

## 35. إعادة طباعة تفاصيل الزبون المؤقت والشحن في تقرير الفواتير اليومية (يوليو 2026)

تم تعديل كود الخادم والتطبيق لإتاحة إعادة طباعة بيانات الزبون المؤقت والتوصيل عند معاينة أو إعادة طباعة الفاتورة من تقرير اليومية:
* **الإجراء المخزن المحدث:**
  - تعديل الإجراء المخزن `[Sales].[sp_Invoice_GetByID]` ليتضمن عملية ربط يساري `LEFT JOIN` مع جدول `[Sales].[TempOrderInfo]` لاستخراج حقول `CustomerName`, `Phone`, `Address`, `DeliveryDate`, `DeliveryTime` كأعمدة مستقلة في المخرجات في حال توفرها.
* **تحديث تطبيق الهاتف (Flutter Application):**
  - تعديل دالة إعادة الطباعة `_reprintInvoice()` في [daily_invoices_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_invoices_screen.dart) لتأمين خريطة البيانات `printData` بالمتغيرات المستلمة من السيرفر كحقول مؤقتة (`temp_customer_name`, `temp_phone`, `temp_address`, `temp_delivery_date`, `temp_delivery_time`).
  - في حال لم تتوفر هذه البيانات، يتابع البرنامج الطباعة العادية دون تغيير.


---

## 36. تعميم إدخال موعد وبيانات التوصيل لجميع العملاء وتكاملها مع عروض مبيعات الشركاء (يوليو 2026)

تم تعميم شاشة تفاصيل وموعد التوصيل لتغطي كافة العملاء وتتكامل مع عروض مبيعات العملاء:
* **تعديل التطبيق المحمول (Flutter Application):**
  - تعديل [supplier_selection_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/supplier_selection_screen.dart) لتعميم التوجيه إلى شاشة التوصيل `TemporaryOrderScreen` عند اختيار أي عميل (وليس فقط الزبون النقدي العام) عند تفعيل خيار `temp_order` من الإعدادات.
  - تعديل [temp_order_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/temp_order_screen.dart) لملء وتعبئة الاسم والهاتف وعنوان التوصيل ديناميكياً ببيانات العميل المختار، وجعل خيارات التخطي والتسميات مرنة وتكيفية.
  - تعديل [partner_offers_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_offers_screen.dart) لتوجيه المستخدم لشاشة التوصيل قبل فتح شاشة الفوترة.
  - تعديل [partner_billing_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_billing_screen.dart) لاستلام حقول تفاصيل الشحن والتوصيل وإضافتها إلى حمولة البيانات المرسلة للسيرفر (`payload`) وبيانات الطباعة للمشترين.


---

## 37. إخفاء تفاصيل الزبون المؤقت للعملاء العاديين وتلقائية حفظ الاسم (يوليو 2026)

تم تخصيص شاشة التوصيل لتعرض فقط خيارات الجدولة للعملاء المسجلين، مع تعيين اسم العميل الفعلي تلقائياً في قاعدة البيانات:
* **تصفية بطاقة الزبون المؤقت برمجياً:**
  - تعديل [temp_order_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/temp_order_screen.dart) ليعرف ما إذا كان العميل نقدي عام (`نقدي عام` أو `سند مباشر` أو معرف الشريك فارغ).
  - إذا كان العميل مسجلاً (وليس نقدي عام)، يتم إخفاء بطاقة *"معلومات الزبون المؤقت"* (التي تسأل عن الاسم والهاتف والعنوان) تلقائياً، والاحتفاظ ببطاقة *"موعد التسليم والملاحظات"* فقط لتحديد تاريخ ووقت الشحن.
* **التعيين التلقائي للاسم الفعلي:**
  - في حال كان العميل مسجلاً، تقوم دالة `_proceedToPOS` بتعيين اسم العميل، هاتفه، وعنوانه المسجلين تلقائياً وتمريرهم كمعاملات توصيل لشاشة البيع/عروض الشركاء.
  - يضمن هذا التعديل حفظ وتخزين اسم العميل الفعلي في عمود `CustomerName` ضمن جدول `[Sales].[TempOrderInfo]` في قاعدة البيانات فور حفظ الفاتورة.


---

## 38. إضافة شاشة الطلبات اليومية وجدولة التوصيل في القائمة الجانبية والصلاحيات (يوليو 2026)

تم إدخال واجهة مستخدم متكاملة على نظام سطح المكتب (WPF / VB.NET) لمتابعة وتسيير طلبات التوصيل اليومية وجدولة أوقات الشحن:
* **واجهات وتصميم العرض (WPF Views):**
  - إنشاء صفحة المستخدم [DailyOrdersPage](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/DailyOrdersPage.xaml) لتنسيق وعرض الطلبات اليومية على شكل كروت (Cards) بطريقة الـ Expander القابل للطي والفرد مع أنميشن انسيابي سلس.
  - **رأس الكارت (Header):** يعرض رقم الهاتف، ومبلغ الطلب الإجمالي، وميعاد التوصيل، وحالة الفاتورة (مسددة/آجلة) ملونة، وعنوان الشحن.
  - **تفاصيل الكارت (Details):** تحتوي على قائمة الأصناف والكميات المطلوبة، واسم المستلم، والملاحظات، وزر لعرض تفاصيل الفاتورة.
  - **تصنيف الأوقات الفائتة:** كروت الطلبات التي مضى وقت تسليمها عن التوقيت الحالي للنظام يتم تلوينها تلقائياً بلون مختلف مميز (رمادي داكن أو أحمر فاتح منبه) للدلالة على فوات وقت تسليمها.
  - **صندوق إدخال التاريخ:** تطبيق صندوق نصوص TextBox منسق بستايل `ModernTextBoxStyle` المعتمد في بقية صفحات المشروع مع تلميح مائي "يوم/شهر/سنة" وربطه بالتحقق البرمجي التلقائي.
* **التحكم والمنطق وقاموس الصلاحيات (Sidebar & Permissions):**
  - تعديل [DashboardViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/DashboardViewModel.vb) لإضافة بند "الطلبات اليومية" برمز شاحنة التوصيل `🚚` في قائمة الـ Sidebar وتفعيل التوجيه لصفحة `DailyOrdersPage` عند التنقل.
  - تعديل [UserManagementViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/UserManagementViewModel.vb) بإضافة الصلاحية `"DailyOrders"` باسم "الطلبات اليومية" ضمن القاموس البرمجي `AvailableForms` لتمكين إدارتها وتخصيصها لمختلف الأدوار والمسؤولين.

* **تطوير الـ API ومسارات البيانات (FastAPI Backend):**
  - إضافة الثابت `TEMPORDER_GETDAILYDELIVERIES` في [db_procedures.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures.py) لربط استدعاء الإجراء المخزن.
  - إضافة دالة `get_daily_orders` في [invoice_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/invoice_service.py) لتعبئة رؤوس الطلبات والتفاصيل التفصيلية للأصناف المجدولة.
  - إضافة مسار الـ API الموثق `GET /invoices/daily-orders` في [invoices.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/invoices.py).
* **شاشة وتجهيزات تطبيق الموبايل (Flutter App):**
  - إنشاء الشاشة الكاملة [daily_orders_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_orders_screen.dart) لعرض الطلبات اليومية في شكل كروت ExpansionTile مطوية، مع إبراز وتلوين المواعيد الفائتة باللون الأحمر/الوردي للتنبيه، وزر مدمج لإعادة طباعة الإيصال الحراري.
  - تعديل [api_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart) لإضافة دالة جلب الطلبات اليومية.
  - تعديل [settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart) لإضافة خيار التخصيص وإظهار/إخفاء بطاقة الطلبات بالصفحة الرئيسية.
  - تعديل [home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) لعرض الاختصار الجديد بالصفحة الرئيسية كبطاقة أرجوانية مميزة وأيقونة شاحنة التوصيل `Icons.local_shipping`.
  - إضافة الترجمات ومفاتيح التعريب كاملة بملف التوطين [app_localizations.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/core/localization/app_localizations.dart).


## 39. تحسين الواجهات المتجاوبة للتطبيق على شاشات التابلت والأجهزة اللوحية (يوليو 2026)

تم إجراء مراجعة شاملة لجميع واجهات وشاشات تطبيق الموبايل (Flutter) لضمان تفاعليتها وتجاوبها التام (Adaptive / Responsive Design) مع مقاسات الشاشات اللوحية (Tablets & iPads) مقارنة بشاشات الهواتف الذكية الصغيرة، وتجنب التمدد المفرط للنصوص والحقول:

* **إضافة حاويات الاحتواء والتموضع الموسط (Constrained Layouts):**
  - **شاشة الطلبات اليومية للتوصيل ([daily_orders_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_orders_screen.dart)):** تغليف الواجهة بـ `ConstrainedBox` بحد أقصى للعرض `800` بكسل موسطاً في منتصف الشاشة.
  - **شاشة الإعدادات العامة ([settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart)):** تقييد عرض قائمة الإعدادات بحد أقصى `700` بكسل موسطاً.
  - **شاشات سندات الصرف والقبض للشركاء ([payment_voucher_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/payment_voucher_screen.dart)، [receipt_voucher_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/receipt_voucher_screen.dart)):** تغليف الجسم الرئيسي بـ `ConstrainedBox` بعرض أقصى `800` بكسل.
  - **شاشات السندات العامة ([general_payment_voucher_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/general_payment_voucher_screen.dart)، [general_receipt_voucher_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/general_receipt_voucher_screen.dart)):** تغليف نموذج الإدخال بـ `ConstrainedBox` بحد أقصى للعرض `700` بكسل موسطاً.
  - **شاشات تقرير الفواتير والسندات اليومية ([daily_invoices_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_invoices_screen.dart)):** تقييد عرض التقارير والإجماليات بحد أقصى `850` بكسل موسطاً.
  - **شاشات جرد المخازن وإهلاك البضاعة ([stocktake_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/stocktake_screen.dart)، [wastage_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/wastage_screen.dart)):** تغليف جداول وعمليات الجرد بـ `ConstrainedBox` بحد أقصى للعرض `800` بكسل.
* **آلية التجاوب:** تتمدد الواجهات تلقائياً لتملأ الشاشة بالكامل (Edge-to-Edge) على شاشات الهواتف المحمولة وتتوسط بشكل عائم ومريح جداً للقراءة والضغط على الشاشات الكبيرة واللوحية.

---

## 40. حل مشكلة ترحيل فواتير المبيعات بشجرة الحسابات وتصحيح تهيئة حسابات الإيرادات (يوليو 2026)

تم حل مشكلة الفشل في ترحيل الفواتير (`IsPosted = 1`) نتيجة تعذر إدخال قيمة فارغة `NULL` في حقل `AccountID` بجدول قيود اليومية المحاسبية:
*   **سبب المشكلة:** كان الـ Trigger المحاسبي يبحث عن حساب إيرادات المبيعات الافتراضي للفرع `41` بشرط أن يكون حساب حركة نشط (`IsTransactional = 1`). وبسبب خطأ في تهيئة قاعدة البيانات الجديدة، أُدخلت الحسابات الفرعية `411` (إيرادات المبيعات) و `412` (إيرادات أخرى) بقيمة `IsTransactional = 0` (حساب رئيسي غير نشط)، مما تسبب في إرجاع القيمة فارغة وفشل الترحيل بالكامل.
*   **التعديل المنجز:**
    *   تعديل السكربت الرئيسي لقاعدة البيانات [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) لتهيئة الحسابات `411` و `412` بقيمة `IsTransactional = 1` بشكل دائم.
    *   تنفيذ جمل تحديث مباشرة على قاعدة البيانات النشطة `WashaDB` لتنشيط الحسابات `411` و `412` و `1201` وتصحيح شجرة الحسابات الحالية.

---

## 41. ميزة الفوكس والانتقال التلقائي لخانة الكمية عند اختيار الصنف بفاتورتي المبيعات والمشتريات (WPF) (يوليو 2026)

تم تحسين سرعة وسلاسة إدخال البيانات بجدول الأصناف في شاشتي فواتير المبيعات والمشتريات عن طريق تفعيل انتقال تلقائي وتظليل فوري لخانة الكمية عند تحديد الصنف:
*   **فاتورة المبيعات ([SalesInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml)):**
    *   ربط حدث `SelectionChanged` للـ ComboBox الخاص باختيار الصنف بـ `ProductComboBox_SelectionChanged`.
    *   إنشاء معالج الحدث في كود الخلفية للتحقق من تفاعل المستخدم الفعلي ثم تفعيل التركيز التلقائي لعمود الكمية وتظليل القيمة بالكامل لتسهيل وتعديل الكمية مباشرة بدون استخدام الفأرة.
    *   تبسيط معالج `DropDownClosed` وإلغاء تداخل التركيز التلقائي منه لمنع حدوث قفز مكرر للمؤشر.
*   **فاتورة المشتريات ([PurchaseInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseInvoicePage.xaml)):**
    *   تطبيق نفس المنطق التفاعلي البرمجي تماماً لحدث `SelectionChanged` للـ ComboBox لنقل الفوكس وتظليل خانة الكمية في جدول المشتريات بالتزامن.

---

## 42. حل تعارض خيارات التشغيل وتصحيح خطأ 10022 لخادم الـ API على نظام Windows (يوليو 2026)

تم تصحيح مشكلة فشل تشغيل خادم الـ API بظهور خطأ المقابس `WinError 10022` (Invalid argument) عند استدعاء uvicorn على نظام تشغيل ويندوز:
*   **سبب المشكلة:** كان سكربت التشغيل يعتمد على تشغيل خادم uvicorn بتمرير معاملين متعارضين وهما `--reload` (المطورين) و `--workers 4` (الإنتاج). في بيئة ويندوز، تحاول بايثون مشاركة ونسخ نفس المقبس عبر العمليات المتعددة (Socket Duplication under spawn start method) وهو ما يرفضه نظام التشغيل ويؤدي لتعطل تشغيل السيرفر.
*   **التعديل المنجز:**
    *   تحديث ملفي التشغيل [Run.bat](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/Run.bat) و [start_server.bat](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/start_server.bat) بإزالة المعامل المتعارض والمسبب للخطأ `--workers 4` ليعمل الخادم بـ Worker افتراضي واحد مدعوم بالكامل على نظام ويندوز.


---

## 43. نظام الوصفات والتصنيع الشامل ومتعدد المستويات (Multi-Level Recipe & Manufacturing System) (يوليو 2026)

تم تصميم وتطوير نظام تصنيع ووصفات منتجات متعدد المستويات (Raw Materials -> Semi-Finished -> Finished Manufactured Products) لحساب تكلفة المخزون بدقة متناهية ودون إجهاد أداء كاشير الـ POS:

### 🛠️ 1. مستوى قواعد البيانات (SQL Server - `SQLVegtablity.sql`):
* **جداول الوصفات:**
  - إنشاء جدول رأس الوصفة `[Inventory].[Recipes]` وجدول التفاصيل `[Inventory].[RecipeDetails]`.
* **الأعمدة الجديدة والحماية:**
  - إضافة عمود `ProductType INT DEFAULT 1` لجدول المنتجات `[Inventory].[Products]` لتحديد نوع المنتج (0: مادة خام، 1: صنف عادي، 2: منتج مصنع، 3: منتج وسيط).
  - إضافة عمود `ProductionMode BIT DEFAULT 0` لجدول إعدادات الشركة `[Settings].[CompanySettings]`.
* **التريجر الشامل `[Sales].[trg_Invoice_Post]`:**
  - يدعم النمط القياسي `ProductionMode = 0` والنمط المصنع `ProductionMode = 1`.
  - تحويل صريح للكميات `CAST(TargetQty AS DECIMAL(18, 4))` لتوحيد أنواع البيانات ومنع خطأ `Msg 240`.
  - تفكيك وإعادة تجميع تكراري متناظر للترحيل وإلغاء الترحيل (Posting & Unposting Symmetry).
* **إجراء التحديث المتسلسل للتكاليف `[Inventory].[sp_Update_Manufactured_Costs]`:**
  - يعمل بتسلسل تصاعدي (Bottom-Up) حتى 5 مستويات تداخل لتحديث تكاليف المنتجات الوسيطة والمنتجات النهائية تلقائياً فور شراء مادة خام جديدة أو حفظ وصفة.
* **فهارس منع القفول المتبادلة (Deadlock Prevention Indexes):**
  - إنشاء فهارس `IX_ProductStock_ProductID_WarehouseID`, `IX_RecipeDetails_RecipeID_Ingredient`, `IX_Recipes_ProductID`, `IX_InvoiceDetails_InvID_ProductID`.
* **إجراءات فلترة أصناف الفواتير (حسْب وضع التصنيع `ProductionMode`):**
  - `[Inventory].[sp_Product_GetForPurchase]`: جلب المواد الخام والأصناف العادية واستثناء الأصناف المصنعة عند تفعيل `ProductionMode`.
  - `[Inventory].[sp_Product_GetForSales]`: جلب الأصناف المباعة والمصنعة واستثناء المواد الخام عند تفعيل `ProductionMode`.
* **إجراءات الوصفات المخزنة:**
  - `sp_Recipe_GetAll`, `sp_Recipe_GetByProduct`, `sp_Recipe_Save_XML`, `sp_Recipe_Delete`.
* **إجراءات إعدادات الشركة:**
  - تحديث `sp_CompanySettings_Get` و `sp_CompanySettings_Save` بقيم افتراضية لجميع المعاملات الاختيارية لضمان سلامة الاستدعاءات القديمة 100%.

---

### 💻 2. تطبيق الـ Desktop (WPF VB.NET - `Vegtablity`):
* **ثوابت الإجراءات المخزنة ([StoredProcedures.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/StoredProcedures.vb)):**
  - إضافة كافة ثوابت الوصفات والفلترة `SP_RECIPE_*` و `SP_PRODUCT_GETFOR*`.
* **تحديث النماذج والخدمات:**
  - تحديث [CompanyInfo.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/CompanyInfo.vb) وتحديث [CompanySettingsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/CompanySettingsViewModel.vb) و [CompanySettingsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/CompanySettingsPage.xaml) لإضافة خيار زر التفعيل التفاعلي لـ `ProductionMode`.
  - تحديث [Product.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/Product.vb) بإضافة `ProductType` و `ProductTypeName`.
  - تحديث [ProductService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/ProductService.vb) بإضافة `GetProductsForPurchase` و `GetProductsForSales`.
  - تحديث [InventoryViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/InventoryViewModel.vb) و [InventoryPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/InventoryPage.xaml) لإضافة اختيار وعرض نوع المنتج شرطياً حسْب `ProductionMode`.
  - إنشاء [Recipe.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/Recipe.vb) و [RecipeService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/RecipeService.vb) لإدارة بيانات الوصفات بالـ Dapper والـ XML.
  - إنشاء واجهة [RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml)، [RecipePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml.vb) و [RecipeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/RecipeViewModel.vb) مع حساب التكلفة الدقيقة حياً وتحديث المخزون.
  - تحديث [UserManagementViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/UserManagementViewModel.vb) لإضافة صلاحية `"Recipes"` ("وصفات المنتجات") شرطياً بحسب `ProductionMode`.
  - تحديث [DashboardViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/DashboardViewModel.vb) لإظهار بند **"وصفات المنتجات"** `📜` تحت قائمة **إدارة المخزون** بالشريط الجانبي شرطياً بحسب `ProductionMode`.
  - تسجيل كافة الملفات بملف المشروع [Vegtablity.vbproj](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Vegtablity.vbproj).

---

### 🐍 3. خادم الـ API (FastAPI Backend - `VegtablityApi`):
* **تعاريف الإجراءات ([db_procedures.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures.py)):** إضافة ثوابت إجراءات الوصفات والفلترة.
* **الخدمات والراوتر:**
  - إنشاء [recipe_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/recipe_service.py) لمعالجة الـ XML والاستدلالات.
  - إنشاء [recipes.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/recipes.py) بجميع نقاط الـ API (`GET /recipes/`, `GET /recipes/{id}`, `POST /recipes/`, `DELETE /recipes/{id}`).
  - تسجيل الـ Router في [main.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/main.py).

---

### 📱 4. تطبيق الموبايل (Flutter Client - `Vegtablity_App`):
* **النموذج ومزود الحالة:**
  - إنشاء [recipe_model.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/models/recipe_model.dart) لتمثيل `RecipeHeader` و `RecipeDetailItem`.
  - إنشاء [recipe_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/recipe_provider.dart) لاستدعاء الـ API عبر Dio.
  - تسجيل `RecipeProvider` في [main.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/main.dart).
* **شاشة العرض:**
  - إنشاء [recipe_management_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/recipe_management_screen.dart) لاستعراض الوصفات وعرض تفاصيل مكوناتها عبر نافذة Bottom Sheet تفاعلية.


---

## 44. التوثيق النهائي لتطوير وتحسينات شاشة الوصفات وتصنيع المخزون (Recipe & Manufacturing Enhancements) (يوليو 2026)

تم إنجاز التوثيق الكامل والتحديثات الهيكلية لشاشة الوصفات والتصنيع متعدد المستويات لضمان دقة التكاليف وسلاسة تجربة المستخدم:

### 🛠️ 1. مستوى قاعدة البيانات والإجراءات المخزنة (SQL Server - `SQLVegtablity.sql`):
* **الإجراء المخزن الجديد `[Inventory].[sp_Product_GetForRecipeTarget]`:**
  - يستقبل المعامل الاختياري `@WarehouseID INT = NULL`.
  - يستجلب حصرياً المنتجات المصنعة (ProductType = 2) والمنتجات الوسيطة (ProductType = 3) التي ليس لها وصفة مسجلة سابقاً في جدول `[Inventory].[Recipes]` (`NOT EXISTS`) مع توليد التراجع لـ (1, 2, 3) غير المسجلة بالوصفات، لاستبعاد المنتجات ذات الوصفات المسجلة سابقاً والمواد الخام من قائمة اختيار إضافة وصفة جديدة.
* **الإجراء المخزن الجديد `[Inventory].[sp_Product_GetForRecipeIngredients]`:**
  - يستقبل المعامل الاختياري `@WarehouseID INT = NULL`.
  - يجلب الأصناف ذات الأنواع (0: مادة خام، 1: قياسي، 3: شبه مصنع).
  - يحسب تكلفة `PurchasePrice` المرجحة حصرياً من جدول `[Inventory].[ProductStock]` للمستودع المحدد (`PS.AvgCostPrice`)، وفي حال عدم تحديد مستودع يجلب أقل سعر تكلفة متاح بين المستودعات (`MIN(AvgCostPrice) WHERE AvgCostPrice > 0`) مع التراجع التلقائي لـ 0 عند انعدام التكلفة.
* **تحديث الإجراء `[Inventory].[sp_Recipe_Save_XML]`:**
  - استقبال البرامتر الاختياري `@WarehouseID INT = NULL`.
  - بعد نجاح حفظ التفاصيل وحساب التكلفة الكلية للوصفة (`@RecipeTotalCost`)، يتم فحص وجود المنتج المصنع في جدول `ProductStock`:
    - إن كان جديداً: يُدرج تلقائياً برصيد كمية صفر `CurrentQty = 0` وتكلفة `AvgCostPrice = @RecipeTotalCost`.
    - إن كان موجوداً: تُحدث تكلفته المرجحة بـ `@RecipeTotalCost`.
  - استدعاء التحديث المتسلسل `sp_Update_Manufactured_Costs` ممرراً `@WarehouseID`.
* **تحديث الإجراء `[Inventory].[sp_Recipe_GetByProduct]`:**
  - جلب بيانات رأس الوصفة ومكوناتها بالربط المباشر مع `@WarehouseID` لإرجاع التكلفة الدقيقة الخاصة بالمستودع المحدد بدلاً من إظهار أقل سعر تكلفة عبر المخازن بالخطأ في الـ UI.

---

### 💻 2. تطبيق الـ Desktop (WPF VB.NET - `Vegtablity`):
* **فهرس الإجراءات والثوابت ([StoredProcedures.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/StoredProcedures.vb)):**
  - تسجيل الثابت `SP_PRODUCT_GETFORRECIPEINGREDIENTS`.
* **خدمة الأصناف والوصفات ([ProductService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/ProductService.vb) & [RecipeService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/RecipeService.vb)):**
  - إضافة دالة `GetProductsForRecipeIngredients(Optional warehouseID As Integer? = Nothing)`.
  - تحديث `SaveRecipe` و `GetRecipeByProduct` لتمرير البرامتر `@WarehouseID`.
* **ربط المستودع برأس الوصفة ([RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml) & [RecipeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/RecipeViewModel.vb)):**
  - إضافة قائمة اختيار المستودع `Warehouses` برأس الوصفة.
  - عند اختيار أو تغيير المستودع `SelectedWarehouseID` يتم تلقائياً:
    1. إعادة جلب أسعار تكلفة المواد الخام الخاصة بهذا المستودع عبر `GetProductsForRecipeIngredients`.
    2. إعادة تحميل تفاصيل الوصفة المفتوحة وتحديث التكلفة المعروضة في الـ UI للتطابق 100% مع الـ PDF وقاعدة البيانات.
* **التحكم بالتنقل بخلية الباركود ([RecipePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml.vb)):**
  - عند الضغط على Enter في خلية الباركود: يتم الانتقال لخلية الكمية **فقط في حال مطابقة العثور على الصنف**، وإلا يظل التركيز في خلية الباركود ويُظلل النص لتسهيل تعديله.
* **إشعار الحفظ المنزلق (Snackbar Notification):**
  - إضافة عنصر `SnackbarBorder` بأسفل الصفحة برسم أنيق وربطه بحدث `RequestSnackbar` لعرض إشعار الحفظ نجاحاً لمدة 3 ثوانٍ واختفائه تلقائياً دون تعطيل شاشات النظام.
* **التنظيف التلقائي قبل الحفظ:**
  - تصفية وحذف الصفوف غير المكتملة تلقائياً قبل تنفيذ عملية الحفظ (الصفوف بدون صنف، أو بدون باركود/اسم، أو بكمية أقل من أو تساوي 0).
* **تصدير التقارير ([ReportExporter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/ReportExporter.vb)):**
  - إضافة دالتي `ExportRecipeToPdf` و `ExportRecipeToCsv` وتزويدهما بالبيانات الكاملة عبر `sp_Recipe_GetByProduct` لطباعة وتصدير جميع أعمدة الوصفة (الباركود، الاسم، الوحدة، الكمية، تكلفة الوحدة، التكلفة الإجمالية) بهيكل احترافي كلياً.

---

### 🐍 3. خادم الـ API (FastAPI Backend - `VegtablityApi`):
* **فهرس الإجراءات ([db_procedures.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures.py)):**
  - إضافة `PRODUCT_GET_FOR_RECIPE_INGREDIENTS = "EXEC [Inventory].[sp_Product_GetForRecipeIngredients] @WarehouseID=?"`.
  - تحديث `RECIPE_SAVE_XML` لتمرير البرامتر `@WarehouseID`.
* **مسارات المنتجات والفلترة ([product_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/product_service.py) & [products.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/products.py)):**
  - إضافة مسارات الـ API: `GET /products/for-purchase` و `GET /products/for-sales` و `GET /products/for-recipe-ingredients`.
* **خدمة الوصفات ([recipe_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/recipe_service.py) & [recipes.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/recipes.py)):**
  - استقبال وتمرير `WarehouseID` في استدعاءات جلب وحفظ الوصفات لتشغيل التحديث المتسلسل للتكلفة بنجاح.

---

### 📱 4. تطبيق الموبايل (Flutter Client - `Vegtablity_App`):
* **خدمة الـ API ([api_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart)):**
  - إضافة استدعاءات `getProductsForPurchase`, `getProductsForSales`, `getProductsForRecipeIngredients`, `getAllRecipes`, `getRecipeByProduct`, `saveRecipe`, `deleteRecipe`.
* **تصميم الإيصالات الحرارية ([receipt_designer.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/receipt_designer.dart)):**
  - إضافة دالة `printRecipeReceipt` لطباعة بطاقات الوصفات حرارياً على طابعات Sunmi وطابعات ESC/POS.
* **مزود حالة الوصفات ([recipe_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/recipe_provider.dart)):**
  - دعم جلب وحفظ الوصفات ومكوناتها ممررة بـ `warehouseId` (المستودع المختار عند بداية الوردية) والتنظيف التلقائي للكونات الفارغة قبل التمرير.
* **واجهة إدارة الوصفات ([recipe_management_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/recipe_management_screen.dart)):**
  - الاعتماد التلقائي على المستودع المحدد في بداية الوردية من الـ `SharedPreferences`.
  - إلغاء زر إضافة + العلوي وإلغاء قلم التعديل من الكروت لتوفير المساحة، والاكتفاء بالضغط المباشر على الكارت أو الزر العائم (FAB).
  - مسح باركود الكاميرا المتقدم لمنتجات التصنيع (2) والوسيطة (3):
    1. منتج له وصفة مسجلة ⬅️ فتح التعديل مباشرة.
    2. منتج موجود وليس له وصفة ⬅️ فتح شاشة الإدخال ممرراً المنتج مع تلميح (Snap Bar): *"هذا المنتج ليس له وصفة مسجلة بعد"*.
    3. باركود غير موجود بالنظام ⬅️ فتح حوار الحفظ السريع المنبثق للحفظ التلقائي مقتصراً في خيار تصنيف المنتج حصرياً على نوعين: (**منتج مصنع نهائي 🏭** أو **منتج وسيط ⚙️**) واستدعاء الإجراء `sp_Product_QuickAdd`.
* **واجهة إدخال وحفظ الوصفات الجديدة ([add_recipe_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/add_recipe_screen.dart)):**
  - شاشة مخصصة لإدخال/تعديل الوصفات تتيح اختيار المنتج المصنع/الوسيط وإظهاره بوضوح في الـ ComboBox العلوي.
  - إلغاء مربع البحث اليدوي للمواد الأولية والاكتفاء بزر وقائمة الباركود بالكاميرا الشاملة.
  - تنسيق وإعادة ترتيب أدوات الصفحة واستغلال المساحة بجمالية عالية.
  - **تعديل وتوحيد ترويسة إيصال الوصفة ودعم مقاسات الورق (58mm و 80mm) ([receipt_designer.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/receipt_designer.dart) & [printer_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart)):** 
    - تم مطابقة ترويسة بطاقة الوصفة مع الترويسة القياسية لفواتير النظام: (**شعار الشركة الديناميكي** ⬅️ **اسم الشركة** ⬅️ **العنوان** ⬅️ **رقم الهاتف**)، متبوعاً بالفاصل، ثم عنوان المستند (`بطاقة وصفة ومكونات صنف`)، وتفاصيل المنتج والمستودع والمكونات والتكلفة الكلية مع رمز العملة الديناميكية المعتمدة بالخادم (`_getCurrencySymbol`).
    - دعم طباعة الوصفة عبر جميع أنواع الطابعات (Sunmi POS، Bluetooth، والطابعات الشبكية Network IP) بكافة مقاسات الورق (80mm و 58mm).
    - إصلاح وتحديث زر الطباعة السريعة في كارت الوصفة بشاشة إدارة الوصفات ([recipe_management_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/recipe_management_screen.dart)) ليمرر بيانات الشركة والشعار والعملة ديناميكياً فوراً ودون الحاجة للدخول للوصفة.
* **ماسح الباركود وقائمة المنتجات والمواد ([product_entry_scanner.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/widgets/product_entry_scanner.dart)):**
  - **الفصل الكلي والديناميكي بين قوائم البحث الكتالوجية (`CatalogSearchMode`):**
    1. **نمط فواتير المشتريات (`CatalogSearchMode.purchase`):** يفرز عبر الإجراء المخزن المحدث `sp_Product_GetForPurchase` المواد الأولية (0) والمواد العادية (1) فقط دون عرض المصنعة (2) أو الوسيطة (3). وهو النمط المربوط حكراً وفورياً بكل من شاشة فواتير المشتريات الرئيسية ([pos_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart) عند اختيار نوع `Purchase`) وشاشة فواتير الموردين ([partner_billing_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_billing_screen.dart))، حيث يستدعي الماسح والكتالوج الإجراء المخزن `sp_Product_GetForPurchase` مباشرة.
    2. **نمط فواتير المبيعات (`CatalogSearchMode.sales`):** يفرز عبر الإجراء المخزن المحدث `sp_Product_GetForSales` المنتجات المصنعة النهائية (2) والأصناف العادية (1) لضمان دعم نظامي البيع المباشر والتصنيع معاً.
    3. **نمط مكونات الوصفة (`CatalogSearchMode.ingredients`):** يفرز عبر `sp_Product_GetForRecipeIngredients` المواد الخام (0)، العادية (1)، والوسيطة (3).
    4. **نمط هدف الوصفة (`CatalogSearchMode.targetProducts`):** يفرز عبر `sp_Product_GetForRecipeTarget` (مع `@IncludeAll = 1`) المنتجات المصنعة (2) والوسيطة (3).
  - إضافة زر **`+`** علوي بجوار العنوان لفتح الحفظ السريع `sp_Product_QuickAdd` مباشرة، مع تخصيص الخيارات المتاحة لتصنيف المنتج في نافذة الحفظ السريع وفق النمط الفعال:
    - **في نمط إضافة المواد/المكونات (`CatalogSearchMode.ingredients`):** يقتصر التصنيف حصرياً على 3 اختيارات: **مادة أولية (0)**، **مادة عادية (1)**، **مادة مؤقتة/وسيطة (3)**.
    - **في نمط المنتجات المستهدفة (`CatalogSearchMode.targetProducts`):** يقتصر التصنيف حصرياً على اختيارين: **منتج مصنع نهائي (2)**، **منتج وسيط (3)**، وعند حفظ المنتج الجديد بالضغط على "حفظ وفتح الوصفة ⚡"، يتم إغلاق الحوار المنبثق وقائمة الكاميرا السفلية فوراً، والانتقال التلقائي لشاشة الوصفة ([AddRecipeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/add_recipe_screen.dart)) ممرراً المنتج الجديد بالـ ComboBox للبدء في إضافة المكونات مباشرة.
  - **منطق الباركود التلقائي واليدوي:** يظهر مربع إدخال الباركود اليدوي حصرياً عند الإضافة اليدوية (بدون مسح بالكاميرا)، ويكون محقوناً تلقائياً بباركود فريد تم إنتاجه عشوائياً بدون تكرار مع المنتجات السابقة (`29XXXXXXXX`)، مع إمكانية تعديل الباركود يدوياً أو التوليد الجديد بضغطة زر.
* **إصلاح وحل مشكلة الشاشة البيضاء في شاشتي الجرد والهلاك ([stocktake_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/stocktake_screen.dart) & [wastage_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/inventory/wastage_screen.dart)):**
  - **سبب الشاشة البيضاء:** كان عنصر `ProductEntryScanner` المحتوي على كاميرا المسح والـ `Expanded` المباشر يُدرج داخل قائمة التمرير غير المحدودة الارتفاع `SingleChildScrollView` بدون تحديد ارتفاع ثابث، مما يسبب استثناء `RenderFlex / Unbounded Height Exception` وينتج عنه شاشة بيضاء.
  - **الحل المطبق:**
    1. تقييد ارتفاع مكون مسح وإدخال المنتجات بداخل `SizedBox` بارتفاع ثابت (380px) وحوايا دائرية أنيقة `ClipRRect(borderRadius: 12)` ليعمل الكاميرا والكتالوج بسلاسة بدون استثناءات layout.
    2. إلغاء الـ `DropdownButton` اليدوي بالكامل واستبداله ببطاقة وشارة عرض تظهر اسم المستودع النشط المعتمد تلقائياً من ذاكرة الوردية `SharedPreferences` دون إتاحة التعديل اليدوي العشوائي لضمان سلامة قيد الجرد والإهلاك.
* **ربط إظهار ووصفات المنتجات والتصنيع بقيمة `[ProductionMode]`:**
  - تم ربط إظهار أيقونة وعنصر "وصفات المنتجات والتصنيع" في كل من **الشاشة الرئيسية (الشبكة الرئيسية)**، **القائمة الجانبية (Sidebar Drawer)**، و**شاشة الإعدادات العامة (General Settings)** بشرط تفعيل خيار `ProductionMode == 1` في إعدادات الشركة (`CompanySettings`).
  - في حال تعطيل `ProductionMode` بالشركة، يتم إخفاء أزرار وقوائم الوصفات والتصنيع تلقائياً من التطبيق لتبسيط الواجهة وحظر الدخول غير المصرح به للنظام الإنتاجي.
  - إزالة مربع الاختيار الخاص بوضع التصنيع (`ProductionMode CheckBox`) من شاشة إعدادات المؤسسة بالكمبيوتر ([CompanySettingsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/CompanySettingsPage.xaml)) بناءً على الطلب، ليتم التحكم بالقيمة مباشرة من قواعد البيانات دون تدخل المستخدم.
* **إضافة خيار وزر طباعة سند الجرد في تطبيق سطح المكتب WPF ([StockTakePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/StockTakePage.xaml)):**
  - تخصيص وتثبيت زر **`طباعة`** بأسفل الصفحة بجانب زر اعتماد التقرير مباشرة مع حذف الزر العلوي لتبسيط الواجهة وتجنب التكرار.
  - ربط الزر مع الأمر `PrintCommand` في [StockTakeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/StockTakeViewModel.vb).
  - إضافة الدالة المخصصة `ExportStockTakeVoucherToPdf` بالملف [ReportExporter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/ReportExporter.vb) لطباعة وتصدير سند تسوية الجرد بصيغة PDF الرسمية موثقة بترويسة الشركة، حالة السند (معتمد / مسودة)، تفاصيل الأصناف والكميات الدفترية والفعلية ومبالغ الفروقات وإجمالي التسوية الختامي.
* **إضافة تبويب وإمكانية التحكم في جدول `CompanySettings` بتطبيق التراخيص ([LicenseManagerApp](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp)):**
  - إضافة واجهة التحكم في إعدادات وتفضيلات النظام وتغيير قواعد البيانات ديناميكياً حسب اختيار الـ ComboBox.
  - إضافة مفاتيح تفعيل/تعطيل (`SwitchListTile`) للتحكم في أعمدة `ProductionMode` و`UseCustomInvoiceDesign` و`UseDetailedInvoiceDesign` و`UnifiedPartnerSearch`.
  - اعتماد خيار **زر الحفظ المباشر 💾 (Save Button)** لحفظ التغييرات بأمان بعد المعاينة والتأكد، وتجنب التعديلات العشوائية السريعة لقواعد بيانات الشركات والعملاء.
* **تحديث واجهات وتنظيم تطبيق المشرف والتراخيص ([LicenseManagerApp](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp)):**
  - **تخصيص الشاشة الرئيسية ([DashboardHomeScreen](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp/lib/screens/dashboard_home_screen.dart)):** إزالة كروت المعاينة القديمة وحذف صفحة الميزات والتحديثات، والاعتماد على كارتين صغيرين مخصصين:
    1. **كارت إدارة تراخيص الأجهزة 🔐:** يحمل شعار لوحة التحكم ويوجه لصفحة التراخيص دون المساس بها ([LicenseManagerScreen](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp/lib/screens/license_manager_screen.dart)).
    2. **كارت الخصائص وتفضيلات النظام 🔑:** يحمل رمز المفتاح ويوجه لصفحة التفضيلات وإعدادات قواعد البيانات المستقلة ([CompanySettingsScreen](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp/lib/screens/company_settings_screen.dart)).
  - **فصل صفحة الخصائص وتفضيلات النظام ([CompanySettingsScreen](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp/lib/screens/company_settings_screen.dart)):** إنشاء شاشة مخصصة منفصلة كلياً للتحكم بقواعد البيانات وخيارات `ProductionMode` وتصاميم الفواتير والعملة دون الاعتماد على التبويبات المتداخلة.
* **إصلاح زر وسلوك الرجوع بشاشات تحصيل العملاء وسداد الموردين ([ReceiptVoucherScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/receipt_voucher_screen.dart) & [PaymentVoucherScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/payment_voucher_screen.dart)):**
  - إضافة `PopScope` وتطوير سهم الرجوع `leading: IconButton` في كلا الشاشتين.
  - عند اختيار عميل أو مورد والدخول لقائمة الفواتير المستحقة، يتولى الضغط على زر الرجوع (أو زر الجهاز) تصفير العميل/المورد المحدد `_selectedPartner = null` للعودة لقائمة العملاء والموردين بدلاً من الخروج المفاجئ للشاشة الرئيسية.
* **إضافة Stored Procedures للتحكم في إعدادات الشركة ([SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql)):**
  - إضافة `[Settings].[sp_CompanySettings_Get_Ctrl]` لقراءة وتصدير إعدادات وتفضيلات النظام.
  - إضافة `[Settings].[sp_CompanySettings_Save_Ctrl]` لتحديث وخزن خيارات `ProductionMode` والتصميم والبيانات العامة بأمان.
  - ربط الإجراءات في [db_procedures_controls.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures_controls.py) واستدعائها من [license_control_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/license_control_service.py).
* **دعم الطباعة الديناميكية بحسب لغة التطبيق ونمط طباعة الشبكة المخصص للجهاز (Dynamic Print Language & Device-Specific Network Print Mode):**
  - **الطباعة بحسب لغة التطبيق الحالية:** فحص لغة التطبيق المحددة (`ar` أو `en`) عند طباعة الفواتير والتقارير والسندات، وطباعة الترويسات والمسميات والإجماليات تلقائياً باللغة العربية عند اختيار اللغة العربية، أو باللغة الإنجليزية (`SALES INVOICE`, `GRAND TOTAL`, `Paid Amount`, `Balance Due`) عند اختيار اللغة الإنجليزية.
  - **نمط طباعة الشبكة المخصص لكل جهاز (Network Engine Mode):** الإبقاء على النظام القديم المباشر (`direct`) كخيار افتراضي تلقائي لكافة الأجهزة، مع إضافة خيار مخصص في شاشة [PrinterSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/printer_settings_screen.dart) لتمكين نمط الطباعة الصورية عالية الدقة (`raster` / Canvas Image) محلياً للجهاز المتصل بطابعة POS 80 عبر الشبكة لحل مشكلة الحروف العربية المتداخلة واللوجو على هذا الجهاز فقط دون التأثير على بقية أجهزة النظام.







* **مراجعة وتدقيق الكميات الصفرية عند حفظ الفواتير (Zero Quantity Validation Before Save):**
  - عند الضغط على زر الحفظ في شاشة المبيعات أو المشتريات، يتم فحص كامل الأصناف المضافة.
  - في حال وجود صنف أو أكثر كميته تسادي صفر (0)، يتم تجميع قائمة تفصيلية تتضمن: رقم الصف داخل الجدول + اسم الصنف + قيمة الكمية (0).
  - يتم عرض رسالة تحذيرية للمستخدم تتضمن القائمة الكاملة مع السؤال: *"هل تريد الاستمرار والحفظ على أي حال؟"*
  - عند اختيار **نعم**: تكتمل عملية الحفظ بأمان.
  - عند اختيار **لا**: تتوقف عملية الحفظ ويعود المستخدم إلى الجدول لتعديل أو تصحيح الكميات.


* **ربط صلاحية شاشة الطلبات اليومية بإعداد تصميم الفواتير المخصص (UseCustomInvoiceDesign):**
  - **تطبيق سطح المكتب (WPF):** في شاشة إدارة المستخدمين [UserManagementViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/UserManagementViewModel.vb)، أصبحت صلاحية `الطلبات اليومية (DailyOrders)` تظهر في قائمة الصلاحيات فقط عندما تكون قيمة `UseCustomInvoiceDesign` في جدول `CompanySettings` تساوي `True`. إذا كانت `False` تختفي الصلاحية تماماً من شاشة إدارة المستخدمين.
  - **تطبيق الهاتف/المحمول (Flutter):**
    1. تم إضافة الخاصية `useCustomInvoiceDesign` إلى [SettingsProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/settings_provider.dart).
    2. في شاشة الإعدادات العامة [GeneralSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart)، لا يظهر مفتاح تفعيل/إخفاء الطلبات اليومية إلا إذا كانت `UseCustomInvoiceDesign` تساوي `true`. إذا كانت `false` يختفي خيار التفعيل تماماً من الإعدادات.
    3. في الشاشة الرئيسية [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)، يختفي زر/أيقونة الطلبات اليومية للمستخدم إذا كانت `UseCustomInvoiceDesign` تساوي `false` وتظهر فقط إذا كانت `true` مع تفعيل الخيار في الإعدادات.


* **إحلال وتخصيص عمودين جديدين لخاصية الطلبات اليومية ونظام التوصيل (EnableDailyOrders & DeliverySystemMode):**
  - **إلغاء الاعتماد على `UseCustomInvoiceDesign`:** تم تخصيص العمود المستقل `EnableDailyOrders` (نوع `BIT DEFAULT 0`) لتكون هي المسؤولة عن تفعيل خاصية الطلبات اليومية والتوصيل.
  - **عمود نظام ومواعيد التوصيل (`DeliverySystemMode`):** تم إضافة عمود جديد بقيمة افتراضية `NULL` لربط نظام التوصيل ومواعيد التسليم مباشرةً من إعدادات الشركة بالسيرفر.
  - **تحديث برنامج سطح المكتب (WPF):**
    1. تحديث [CompanyInfo.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/CompanyInfo.vb) و [SettingsService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/SettingsService.vb) لإدراج وتمرير `EnableDailyOrders` و `DeliverySystemMode`.
    2. تحديث [UserManagementViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/UserManagementViewModel.vb) لربط إظهار صلاحية "الطلبات اليومية" بـ `EnableDailyOrders`.
    3. تحديث [CompanySettingsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/CompanySettingsViewModel.vb) و [CompanySettingsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/CompanySettingsPage.xaml) لإتاحة التحكم بـ `EnableDailyOrders` و `DeliverySystemMode`.
  - **تحديث خادم الـ API (VegtablityApi):**
    1. ترقية النماذج في [settings.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/settings.py).
    2. ترقية الاستدعاءات والإجراءات في [license_control_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/license_control_service.py) و [db_procedures_controls.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures_controls.py).
  - **تحديث تطبيق الهاتف (Flutter App):**
    1. تحديث [SettingsProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/settings_provider.dart) بالخاصيتين `enableDailyOrders` و `deliverySystemMode` مع التخزين المحلي والبحث المرن عن المفاتيح.
    2. تحديث [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) لتعتمد على `enableDailyOrders`.
    3. تحديث [GeneralSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart) لتعتمد على `enableDailyOrders` وتربط نظام التوصيل بـ `deliverySystemMode`.


* **تحديث تطبيق لوحة تحكم التراخيص (LicenseManagerApp):**
  - تم تحديث [company_settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp/lib/screens/company_settings_screen.dart) ليشمل خيارات التحكم المباشرة بالعمودين الجديدين `EnableDailyOrders` و `DeliverySystemMode`.
  - إضافة مفتاح التفعيل `SwitchListTile` لـ `EnableDailyOrders` وحقل النص `TextFormField` لـ `DeliverySystemMode` وإرسالهما ضمن الـ payload إلى الـ API عند الحفظ.


* **إزالة خيار التحكم المحلي بنظام التوصيل ومواعيد التسليم من الإعدادات العامة بتطبيق الهاتف (`Vegtablity_App`):**
  - تم حذف قسم القائمة المنسدلة للتحكم الفردي بنظام التوصيل من شاشة [GeneralSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart).
  - تم ربط الشاشات المختلفة مثل [supplier_selection_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/supplier_selection_screen.dart) و [partner_offers_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_offers_screen.dart) مباشرةً بـ `SettingsProvider.deliverySystemMode` المسجل بالسيرفر والداتابيز (`DeliverySystemMode`).


* **🕒 طباعة وقت وحفظ الفاتورة (Invoice Date & Time Printing):**
  - تم التحديث في [InvoicePrintDesigner](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/invoice_print_designer.dart) لطباعة وقت الفاتورة بصيغة `HH:mm:ss A` بجانب التاريخ `YYYY-MM-DD` في ترويسة جميع فواتير المبيعات والمشتريات عبر جميع محركات الطباعة الثلاثة (Sunmi, Direct ESC/POS, Canvas ESC/POS).

* **🖨️ زر علوي موحد لطباعة أحدث إضافة بالنظام (Global Reprint Last Added Document Button):**
  - تم إضافة زر علوي ثابت بأعلى شريط التطبيقات (AppBar) برمز الطابعة 🖨️ في شاشات [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)، [PosScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart)، و[PartnerBillingScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_billing_screen.dart).
  - يرتبط الزر بـ [PrinterService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) لإعادة طباعة أحدث مستند تم إضافته بالنظام (سواء كان فاتورة مبيعات، مشتريات، أو سندات) فوراً كنسخة إضافية.

* **🔢 ضبط عدد نسخ طباعة الشبكة (Network Print Copies):**
  - تم إضافة خيار تحديد عدد النسخ المطبوعة (من 1 إلى 5 نسخ) في شاشة [PrinterSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/printer_settings_screen.dart) بحيث يظهر ويُفعل **فقط** عند اختيار طابعة شبكة (`Network`).
  - تقوم دالة الطباعة بالربط مع [PrinterService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart) لتكرار أمر الطباعة لعدد النسخ المحددة.

* **📱 قصر حفظ إعدادات الطباعة على الذاكرة المحلية للجهاز فقط (`Shared Storage`):**
  - تم الغاء مزامنة وحفظ إعدادات الطباعة مع قاعدة البيانات في [PrinterService](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printer_service.dart)، وقصرها تماماً على ذاكرة الجهاز المحلية (`SharedPreferences`) لضمان استقلالية كل جهاز بالشبكة دون تضارب.

* **🛠️ معالجة وتفادي خطأ الطفح الأفقي (RenderFlex Overflow Fix):**
  - تم إضافة خاصية `isExpanded: true` شمولياً لكافة القوائم المنسدلة `DropdownButtonFormField` عبر كافة شاشات التطبيق لتقييد العرض وتفادي خطأ `RenderFlex OVERFLOWING: Row ← InputDecorator`.

* **🏷️ مراجعة الكميات الصفرية والأسعار الصفرية قبل الحفظ بفواتير WPF (Zero Qty & Zero Price Validation):**
  - تم إضافة الدالة الموحدة `ValidateInvoiceItemsBeforeSave` في كل من [SalesInvoiceViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/SalesInvoiceViewModel.vb) و[PurchaseInvoiceViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/PurchaseInvoiceViewModel.vb).
  - تقوم الدالة بجمع الأصناف بدون كمية (`الكمية = 0`) بالأعلى، وإدراج الأصناف بدون سعر (`سعر البيع = 0` / `سعر الشراء = 0`) بقسم خاص أسفل الرسالة التنبيهية بفاصل مميز قبل تخيير المستخدم بين الحفظ أو التعديل.

* **🖨️ نقل وتوسيط نوع الفاتورة بترويسة الطباعة التلقائية (InvoicePrinter.vb Header Layout):**
  - تم تعديل وتوسيط موقع رسم نوع الفاتورة (`نوع الفاتورة / cash` أو `credit`) في [InvoicePrinter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/InvoicePrinter.vb) ليرسم موسطاً بمنتصف الصفحة تماماً عند المستوى الرأسي (`gt(5.0F)`).
  - ضبط واستكمال رسم الملاحظات أسفل اسم العميل مباشرة (`gt(4.0F)`) لمنع أي تداخل بصري بالترويسة.

* **🛒 اعتماد وإرسال سعر الشراء للصنوف الجديدة وتعديله بكارت الفاتورة (Purchase Invoice Unit Price Persistence & Card Editor):**
  - تم تحديث [pos_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart) لدعم نمط فواتير المشتريات (`invoiceType: 'Purchase'`) والاعتماد على `PurchasePrice` كـ `price` لوحدة الشراء بسلة المشتريات، وإرساله بحقل `UnitPrice` للـ API عند حفظ الفاتورة.
  - تخصيص نوابض الحفظ السريع للأصناف غير المعروفة عند مسح الباركود بفواتير المشتريات لتطلب **"سعر الشراء الافتراضي"** وإرسال `PurchasePrice` لـ `quickAddProduct`.
  - إضافة مكون محرر السعر `_PriceEditor` بكارت الصنف في [pos_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart) لإتاحة تعديل سعر الشراء مباشرة بنقرة واحدة عند اختلافه عن السعر المسجل بالسيرفر، وتحديث الإجمالي الجزئي والكلي آلياً.

* **🏷️ نظام خصومات وباقات المبيعات الشامل (Sales Discounts & Product Bundles System):**
  - **قاعدة البيانات (`SQLVegtablity.sql`)**:
    - إضافة العمود `EnableSalesDiscounts` في جدول `[Settings].[CompanySettings]`.
    - إضافة جدول الخصومات `[Sales].[ProductDiscounts]` وجدول الربط بالأصناف `[Sales].[ProductDiscountItems]`.
    - إضافة 5 إجراءات مخزنة جديدة: `sp_Products_GetForDiscounts`, `sp_ProductDiscounts_GetAll`, `sp_ProductDiscounts_GetActiveForPos`, `sp_ProductDiscounts_GetProductIDs`, `sp_ProductDiscounts_Save_XML`, `sp_ProductDiscounts_Delete`.
  - **تطبيق المشرف (`LicenseManagerApp`)**:
    - إضافة `SwitchListTile` لتفعيل/تعطيل خاصية `EnableSalesDiscounts` بشاشة [company_settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/LicenseManagerApp/lib/screens/company_settings_screen.dart).
  - **برنامج سطح المكتب (`Vegtablity` - WPF)**:
    - إضافة النموذج `ProductDiscount.vb` والخدمة `ProductDiscountService.vb` ومتحكم `SalesDiscountsViewModel.vb` والصفحة `SalesDiscountsPage.xaml`.
    - إدراج صلاحية `SalesDiscounts` ("خصومات المبيعات") بشرط التفعيل بقيمتها الافتراضية `False` في [UserManagementViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/UserManagementViewModel.vb).
    - إضافة الخيار لقائمة "المبيعات" بـ Sidebar في [DashboardViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/DashboardViewModel.vb).
  - **خادم الـ API (`VegtablityApi`)**:
    - إضافة الروت `app/routes/discounts.py` والخدمة `app/services/discount_service.py` مع مسارات `GET/POST/DELETE /discounts/` و `GET /discounts/pos/active`.
  - **تطبيق الموبايل (`Vegtablity_App`)**:
    - إضافة النموذج [product_discount.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/models/product_discount.dart) والدالة `getActiveDiscountsForPos()` بـ [api_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart).
    - إضافة منطق **الخصم الحصري (Exclusive Toggle)** بـ [pos_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart).
    - عرض أزرار الخصومات (ChoiceChips) بكارت الصنف بشاشة [pos_screen.dart](file:///d:/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart) وتحديث السعر وإجماليات الخصوم آلياً.
    - طباعة تفاصيل خصم كل صنف وإجمالي الخصم والصافي النهائي بعد الخصم بـ [invoice_print_designer.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/invoice_print_designer.dart).


---

## 45. التوثيق الشامل لنظام الخصومات وحفظ الإجماليات وتطوير الطباعة الحرارية للفواتير (أغسطس 2026)

تم بحمد الله إنجاز التحديثات الهيكلية الشاملة لنظام الخصومات وحفظ بيانات الفواتير وتنسيق الطباعة الحرارية لضمان الدقة المالية والجمالية:

### 💾 1. حفظ وتوثيق الخصم في قاعدة البيانات (Database Persistence):
* **حفظ الخصم بحقل `[Sales].[InvoiceHeader].[Discount]`:**
  - تم ربط وتمرير قيمة إجمالي الخصوم المطبقة بـ [pos_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart) ضمن كائن الفاتورة المعتمد بالـ API والخادم:
    - `TotalAmount`: الإجمالي الكلي للمنتجات قبل الخصومات (`totalOriginalAmount`).
    - `Discount`: إجمالي مبلغ الخصم المستقطع بالفاتورة (`totalDiscountAmount`).
    - `NetAmount`: الصافي النهائي المستحق بعد الخصم (`totalAmount`).
  - يتم تمرير الخصم للإجراء المخزن `[Sales].[sp_Invoice_Save_XML]` عبر المعامل `@Discount` وحفظه في الجدول الأصلي للفواتير دون التأثير على الإصدارات القديمة أو تداول السجلات.

### 🎨 2. تطوير واجهة كارت الصنف بشاشة نقطة البيع (`pos_screen.dart`):
* **إلغاء تعديل سعر البيع بـ POS:** تم حظر وتوجيه تعديل أسعار بيع الوحدات من فاتورة المبيعات والاكتفاء بإتاحتها حصرياً في فاتورة المشتريات.
* **إعادة تموضع باج الخصم في أقصى اليمين:** تم تعديل ترتيب عناصر السطر الموجه لليمين في عنوان كارت المنتجات بـ [pos_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart) ليكون باج الخصم هو العنصر الأول (أقصى اليمين `اقصي اليمين`).
* **التناسب ومنع خطأ الـ RenderFlex Overflow:**
  - وضع مسمى الصنف بداخل ويدجت `Expanded` وتحديده بـ `maxLines: 1` و `TextOverflow.ellipsis`.
  - تغليف باج الخصم بـ `Flexible` ودالة الاحتواء الذكي `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight)` لتقليص حجم الباج تلقائياً في الشاشات الصغيرة ومنع خطأ الطفح البكسلي الأصفر والأسود نهائياً.

### 🖨️ 3. تطوير تقرير وطباعة الفواتير المطبوعة (`invoice_print_designer.dart`):
* **طباعة الإجماليات الثلاثة بالفاتورة والتقرير:** تم تحديث كافة محركات الطباعة (Sunmi POS Thermal, Direct ESC/POS, Canvas HD Raster Image) بـ [invoice_print_designer.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/invoice_print_designer.dart) لطباعة:
  1. **الإجمالي (Gross Total):** المبلغ قبل الخصومات (مثال: `الإجمالي: 10.000 د.ك`).
  2. **الخصم (Total Discount):** إجمالي الخصم المالي المقتطع (مثال: `الخصم: -1.000`).
  3. **الصافي النهائي (Net Total):** المبلغ الصافي المستحق للدفع (مثال: `الصافي (Net Total): 9.000 د.ك`).
* **اعتماد المسمى المترجم (`خصم الصنف`):** ربط طباعة مسمى خصم الصنف بـ `خصم الصنف` للغة العربية و `Item Discount` للغة الإنجليزية.
* **حذف إلغاء العملة من بنود الخصم:** تم حذف رمز العملة (`د.ك` / `KWD`) من أسطر الخصومات المطبوعة (سواء تحت الصنف أو في إجمالي الخصوم) لتظهر كقيمة مقتطعة مجردة بدون رمز عملة (مثل: `(خصم الصنف: -1.000)` و `الخصم: -1.000`).

### 🏷️ 4. إضافة مربع الخصم الإضافي اليدوي على الفاتورة (Extra Manual Discount):
* **إدارة الحالة (`pos_provider.dart`):** إضافة متغير `_extraDiscountAmount` والدالة `setExtraDiscount(amount)` لتحديث الخصم اليدوي. يجمع الخصم اليدوي آلياً على خصومات الأصناف `totalItemDiscountAmount` ليكوّنا إجمالي الخصم `totalDiscountAmount` والنعكاس التلقائي على الصافي `totalAmount`.
* **مكون الواجهة (`pos_screen.dart`):** إضافة المكون `_ExtraDiscountInputField` بداخل لوحة إتمام الفاتورة للشاشات الكبيرة والموبايل، مع التحديث اللحظي المباشر وحفظ وطباعة إجمالي الخصوم الكلية بالداتابيز والإيصال المطبوع.

### 🔍 5. شاشة البحث السريع عن الفواتير والطباعة الحرارية المباشرة (Invoice Lookup & Quick Re-Print):
* **البنية المعمارية (MVVM):**
  - **الـ API وخادم البيانات:** اعتماد استدعاء `[Sales].[sp_Invoice_GetByID]` و `[Sales].[sp_InvoiceDetails_GetByInvID]` بالـ `VegtablityApi` عبر المسار `GET /invoices/{inv_id}` وإرجاع كائن الفاتورة الشامل.
  - **خدمة الـ API ([api_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart)):** إضافة الدالة `getInvoiceById(invId)`.
  - **متحكم الـ ViewModel ([invoice_lookup_viewmodel.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/viewmodels/invoice_lookup_viewmodel.dart)):** كلاس ViewModel مخصص للتحكم بالبحث وجلب البيانات وتجهيز الفاتورة للطباعة.
  - **شاشة العرض ([invoice_lookup_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/invoice_lookup_screen.dart)):** استعراض تماثيل وبيانات الفاتورة، تاريخها، الكاشير، الإجماليات الثلاثة، وبيانات التوصيل (الدليفري) عند توفرها (الاسم، الهاتف، العنوان، موعد التسليم، والملاحظات).
  - **زر القائمة الجانبية ([home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)):** إضافة أيقونة "البحث عن فاتورة (مبيعات / مشتريات)" في الـ Drawer Sidebar.
  - **الطباعة الحرارية السريعة 🖨️:** تزويد الفاتورة بزر طباعة حرارية يستدعي `PrinterService.instance.printReceipt(invoiceData, isReprint: true)` لإعادة الطباعة الحرارية بنفس التصميم الرسمي للفواتير دون أي تغيير أو فقدان للبيانات.

---

## 46. تحديثات شاشة البحث عن الفاتورة وتخصيص رأس بطاقة الدفع وطباعة الدليفري (أغسطس 2026)

* **تنسيق التاريخ والوقت (Date & Time Format):**
  - تم تحسين دالة التنسيق `_formatDateTime` بشاشة [invoice_lookup_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/invoice_lookup_screen.dart) لتعرض التاريخ والوقت بصيغة `dd-MM-yyyy HH:mm`.

* **تخصيص رأس حقل الدفع (Payment Account Metadata Header):**
  - تحديث الدالة `_resolvePaymentAccountName` لتعرض في رأس بطاقة الفاتورة إما **`مدفوع`** (Paid) أو **`آجل`** (Credit) حصراً.
  - في حال كانت الفاتورة تتضمن تقسيم وسائل دفع متعددة (`Split Payments`)، يتم عرض **`مدفوع`** في رأس الفاتورة دون إدراج أسطر التفاصيل في الخلية العلوية، اعتماداً على وجود البطاقة المستقلة المخصصة للتقسيم بالأسفل.

* **بطاقة وسجلات تقسيم الدفع (`Split Payments Card`):**
  - تم تبسيط عنوان بطاقة تفاصيل طرق الدفع ليصبح **`Split Payments`** فقط دون أي نصوص أو إضافات أخرى.

* **بيانات التوصيل والدليفري (`[Sales].[TempOrderInfo]`):**
  - تحديث الإجراء المخزن `[Sales].[sp_Invoice_GetByID]` بـ [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) لربط جدول الطلبات المؤقتة `LEFT JOIN [Sales].[TempOrderInfo]`.
  - جلب وعرض بيانات الدليفري الحقيقية (`TempCustomerName`, `TempPhone`, `TempAddress`, `TempDeliveryDate`, `TempDeliveryTime`) بداخل كارت منفصل باللون الأزرق بشاشة البحث عن فاتورة، وطباعتها حرارياً بقسم `*** بيانات التوصيل والشحن ***` دون الاعتماد على الملاحظات المالية العامة.

* **تنظيف واجهة الشاشة (UI Button Cleanup):**
  - تم إزالة زر الطباعة الصغير العلوي بشرائح الهيدر بشاشة البحث عن فاتورة، والاعتماد حصراً على زر إعادة الطباعة الحرارية السفلي العريض **`إعادة طباعة الفاتورة 🖨️`**.

---

## 47. تحديثات صفحة الورديات بتطبيق WPF وكروت التدفق النقدي وطرق الدفع الأخرى (أغسطس 2026)

* **إجراء قاعدة البيانات المخزن (`sp_Shift_GetPaymentMethodTotals`):**
  - تم تحديث الإجراء المخزن `[Sales].[sp_Shift_GetPaymentMethodTotals]` بـ [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) و [37_PaymentMethods_SplitPayment.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/37_PaymentMethods_SplitPayment.sql) ليجمع مبالغ المقبوضات والمدفوعات من الفواتير **المسددة مباشرة عبر `InvoiceHeader` (مثل الكي نت المباشر أو الكاش المباشر عند `PaidAmount > 0`) بالإضافة إلى الفواتير المسددة بالتجزئة عبر `InvoicePaymentSplits`** والسندات المالية، مع تجميع الشروط بشرط مانع للتكرار (`NOT EXISTS`) لضمان صحة الأرقام المالية ودقتها بنسبة 100%.

* **نموذج البيانات وتسجيل الملف بالمشروع (`PaymentMethodSummary.vb` & `Vegtablity.vbproj`):**
  - إنشاء نموذج البيانات [PaymentMethodSummary.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/PaymentMethodSummary.vb) لتمثيل إجماليات وسيلة الدفع.
  - تسجيل الملف في مشروع الـ Visual Studio بـ [Vegtablity.vbproj](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Vegtablity.vbproj#L204) تحت العنصر `<Compile Include="Models\PaymentMethodSummary.vb" />` لتفادي أخطاء التجميع BC30002.

* **طبقة الخدمات والمتحكمات (`ShiftService.vb` & `ShiftsViewModel.vb`):**
  - إضافة الثابت `SP_SHIFT_GETPAYMENTMETHODTOTALS` في [StoredProcedures.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/StoredProcedures.vb).
  - إضافة الدالة `GetShiftPaymentMethodTotals` في [ShiftService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/ShiftService.vb).
  - تحديث [ShiftsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ShiftsViewModel.vb) لإضافة الخاصية `NetCashFlow` وتصفية وإضافة وسائط الدفع الإلكترونية إلى القائمة `NonCashPaymentSummaries` وحساب إجمالي باقي طرق الدفع `TotalNonCashAmount`.

* **تصميم واجهة المستخدم بـ XAML (`ShiftsPage.xaml`):**
  - **كارت إجمالي صافي الكاش (Net Cash Flow Card):** إضافة حقل إبراز `إجمالي صافي الكاش` المحسوب كـ `(مبيعات كاش محصلة + سندات قبض) - (مشتريات كاش مدفوعة + سندات صرف)` بشرائح كارت التدفق النقدي [ShiftsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ShiftsPage.xaml#L187).
  - **كارت منفصل لباقي طرق الدفع (`💳 باقي طرق الدفع (K-Net / فيزا / بنك)`):** تصميم كارت مستقل بـ [ShiftsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ShiftsPage.xaml#L254) يعرض جدولاً كاملاً لوسائل الدفع الأخرى غير الكاش والعمليات المحصلة بها مع إدراج إجمالي باقي طرق الدفع بوضوح.

---

## 48. تخصيص أيقونة تطبيق الويندوز وبنائه بنجاح (`Windows App Icon & Release Build`) (أغسطس 2026)

* **توليد أيقونة الويندوز (`app_icon.ico`):**
  - تم تحديث ملف التكوين [pubspec.yaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/pubspec.yaml) وتفعيل خيار بناء أيقونة منصة الويندوز بـ `flutter_launcher_icons` باستخدام الأيقونة الرسمية للتطبيق `lettuce.png` بحجم 256 بكسل.
  - تم توليد الملف المستهدف `windows/runner/resources/app_icon.ico` بنجاح واستبدال الأيقونة الافتراضية.

* **تجميع وبناء تطبيق الويندوز (`Release Executable`):**
  - تم تنفيذ وبناء النسخة النهائية التنفيذية بنجاح بنتيجة سليمة 100%:
    `√ Built build\windows\x64\runner\Release\vegtablity_app.exe`.

---

## 49. تقييد صلاحيات الإعدادات للآدمن وتحليل الحفظ الذاتي بـ `SharedPreferences` (أغسطس 2026)

* **تحليل الحفظ الدائم بـ `SharedPreferences` (Device-Level Persistence Analysis):**
  - الإعدادات العامة وإعدادات الطباعة المتمثلة بـ `PrinterService` و `SettingsProvider` تحفظ وتعمل على **مستوى الجهاز الفيزيائي (Device Scope)** في ملف الذاكرة الدائمة `SharedPreferences`.
  - عند خروج المستخدم الأدمن وتسجيل الدخول بمستخدم جديد عادي، يتم مسح بيانات الـ Token فقط من الذاكرة بـ `logout()` بـ [AuthProvider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/auth_provider.dart#L93)، **وتظل إعدادات الشبكة والطباعة والإعدادات العامة محفوظة 100% وتعمل آلياً لخدمة الكاشير**.

* **ترقية خادم الـ API لتمرير اسم الدور (`RoleName`):**
  - تم تحديث [auth.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/auth.py) و [auth.py Schema](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/auth.py) لإرجاع `role_name` مستخرجاً من الإجراء المخزن `sp_User_Login` في استجابة تسجيل الدخول.

* **إدارة الصلاحية والتحقق (`AuthProvider.dart`):**
  - إضافة الخاصية `isAdmin` بـ [AuthProvider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/auth_provider.dart#L28) للتحقق مما إذا كان المستخدم هو `admin` أو أن دور حسابه ينتمي لـ `admin`.
  - حفظ الـ `role_name` في `SharedPreferences` وتحديثه عند الدخول/الخروج.

* **تقييد واجهة القائمة الجانبية (`HomeScreen.dart`):**
  - تغليف عنصري القائمة الجانبية "الإعدادات العامة" و "إعدادات الطباعة" بشرط `if (authProvider.isAdmin) ...[...]` بـ [HomeScreen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart#L209) لإخفائهما تماماً عن المستخدمين غير المصرح لهم.

* **حماية الشاشات الداخلية (`GeneralSettingsScreen` & `PrinterSettingsScreen`):**
  - تزويد دالة `build` بكل من [settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart#L143) و [printer_settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/printer_settings_screen.dart#L144) بشرط حماية داخلي يمنع فتح الشاشات لغير الأدمن ويعرض لوحة تنبيه: **`غير مسموح بالوصول: هذه الشاشة مخصصة للمدير (Admin) فقط`**.

---

## 50. التصحيح المالي وتخصيص مبيعات الكاش النقدية الفعلية بملخص الوردية (`Physical Cash Flow Optimization`) (أغسطس 2026)

* **تصحيح الإجراء المخزن (`sp_Shift_GetSummary`):**
  - تم تحديث الإجراء المخزن `[Sales].[sp_Shift_GetSummary]` بـ [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) ليفصل **مبيعات الكاش النقدي الورقي (`TotalPaidSales`)** و **مشتريات الكاش النقدي (`TotalPaidPurchases`)** و **سندات القبض/الصرف النقدية** عن عمليات الـ K-Net والفيزا والبنك.
  - إدراج حقل مخصص جديد `TotalNonCashSales` لإرجاع إجمالي المقبوضات غير النقدية (كي نت / فيزا / تحويل بنكي) بشكل مستقل دون خلطها بصندوق الكاش الورقي.

* **ضبط معادلة نهاية الوردية المتوقع وجرد النقدية (`Expected Ending Cash`):**
  - **تطبيقات الـ Flutter (`CloseShiftScreen.dart` & `ShiftReportPrintDesigner.dart`):** أصبح حساب المبلغ المتوقع في الدرج يعتمد حصراً على النقدية الكاش الورقية `Starting Cash + Cash Sales + Cash Receipts - Cash Purchases - Cash Payments` ليظهر للكاشير الجرد الفعلي الدقيق المطابق للدرج، وإبراز مبيعات الكي نت والفيزا في خانات مستقلة بالتقرير والشاشة والطباعة دون أي عجز وهمي.
  - **تطبيقات الـ WPF (`ShiftsViewModel.vb` & `ShiftsPage.xaml`):** مطابقة تامة للمعادلة واستعراض صافي الكاش الحقيقي بالصندوق وإبراز جدول باقي طرق الدفع بشكل منفصل.

---

## 51. تحديث وتأمين نظام الورديات وتزامن الـ ShiftID بين الجوال والـ API والـ Desktop (أغسطس 2026)

* **تزامن واستدامة معرف الوردية بالجوال (`SharedPreferences & ShiftProvider`):**
  - **التخزين المحلي المستمر:** تم تحديث [ShiftProvider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/shift_provider.dart) لتخزين `ShiftID` الخاص بالوردية المفتوحة حالياً في الذاكرة الدائمة `SharedPreferences` تحت مفتاح `active_shift_id` فور فتح الوردية أو التحقق من وجود وردية نشطة.
  - **مسح بيانات الوردية:** إضافة دالة `clearShiftData()` ومسح مفتاح `active_shift_id` من الذاكرة المحلية والـ Provider عند تسجيل الخروج بـ [AuthProvider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/auth_provider.dart) وعند إغلاق الوردية لتفادي استخدام وردية منتهية.

* **تمرير `ShiftID` بالفواتير المحفوظة (`PosProvider` & `PartnerBillingScreen`):**
  - تم تحديث [PosProvider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart) و [PartnerBillingScreen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/partner_billing_screen.dart) ليتم جلب `active_shift_id` وإرفاقه تلقائياً بحقل `ShiftID` بداخل جسم الفاتورة (`JSON Payload`) سواء عند الحفظ المباشر عبر الـ API أو التخزين الأوفلاين.

* **تحديث نماذج وخدمات الـ API (`FastAPI Backend`):**
  - **مخطط البيانات ([invoices.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/invoices.py)):** إضافة حقل `ShiftID: Optional[int] = None` بداخل نموذج `InvoiceCreate`.
  - **خدمة الفواتير ([invoice_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/invoice_service.py)):** اعتماد `ShiftID` القادم مباشرة من تطبيق الجوال بداخل جسم الفاتورة `invoice.ShiftID` لتقليل زمن الاستعلام، مع التراجع التلقائي لاستدعاء `get_active_shift_id(user_id)`.
  - **خدمة الورديات ([shift_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/shift_service.py)):** تعديل دالة `get_active_shift_id` للتأكد الجازم من أن حالة الوردية المسترجعة هي `Open` حصراً ومسح `_active_shift_cache` كلياً عند إغلاق الوردية لمنع ربط أي فاتورة بوردية مغلقة نهائياً.

* **تصحيح خطوات حفظ أرقام الورديات والتدفق النقدي بـ WPF:**
  - **متحكم الورديات ([ShiftsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ShiftsViewModel.vb)):** تحسين التعرف على حسابات الكاش `AccountCode = "1101"` أو المسمى `صندوق`/`كاش` بشكل دقيق، ومعالجة تحويلات الأرقام والخطوات عند حفظ وإغلاق الوردية لمنع حدوث استثناءات التحويل `Format Exceptions`.
  - **الإجراءات المخزنة ([SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql)):** تحديث `[Sales].[sp_Shift_GetSummary_and_Close]` لتجميع إجماليات الكاش والمبيعات والـ Split Payments وحساب مبيعات النقدية بدقة.
  - **تقرير أعمار الديون ([SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql)):** إضافة المعامل `@PartnerID` للإجراء `[Reports].[sp_Report_UnpaidInvoicesAging]` لتصفية ديون عميل محدد.

* **تحديث ملف حزمة التثبيت (`Washa.iss`):**
  - تحديث ثوابت السكربت بـ [Washa.iss](file:///d:/VB.NET/backup/Vegtablity/setup/Washa.iss) لرفع رقم الإصدار إلى `MyAppVersion "7"` وإنتاج ملف التثبيت باسم `WhashaApp_SetupV7`.

---

## 52. إضافة شاشة طباعة ملصقات الباركود للمنتجات مع تكامل الإعدادات العامة والسايدبار والمحرك المزدوج (أغسطس 2026)

* **التحكم والربط بالإعدادات العامة (`GeneralSettingsScreen & HomeScreen`):**
  - تم تحديث [settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart) لإدراج مفتاح `show_barcode_printing` وحفظ تفضيلات المستخدم محلياً بـ `SharedPreferences`.
  - تم تحديث [home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart) لإضافة خيار "طباعة ملصقات الباركود" بأيقونة `Icons.qr_code_2` بالقائمة الجانبية (Drawer)، يظهر ويختفي تلقائياً حسب تفضيل المستخدم.

* **محرك طباعة ملصقات الباركود الحرارية المزدوج (`BarcodePrintDesigner & PrinterService`):**
  - **طريقة Canvas HD Raster:** بناء [barcode_print_designer.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/barcode_print_designer.dart) لرسم ملصق الباركود بـ `ui.Canvas` بترميز Code 128 الصريح ومصفوفة بكسلات عالية الوضوح تناسب طابعات الـ IP والشبكة وطابعات الملصقات.
  - **طريقة Bluetooth & Direct Thermal:** دعم إرسال أوامر Code 128 النقطية والنسيجية المباشرة وطباعة الباركود بنجاح وقراءته بجميع ماسحات الباركود على طابعات البلوتوث المربوطة حالياً.
  - **خدمة الطباعة (`PrinterService.dart`):** إضافة الدالة `printBarcodeLabel({required Map<String, dynamic> product, required int copies})` لطباعة وتكرار الملصقات بعدد النسخ المحدد.

* **شاشة طباعة الباركود وتصفية الأصناف (`BarcodePrintScreen.dart`):**
  - بناء الشاشة التفاعلية [barcode_print_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/barcode_print_screen.dart) لاستدعاء `[Inventory].[sp_Product_GetForSales]` عبر `ApiService` لجلب كافة الأصناف (العادية، المصنعة، والوسيطة).
  - شريط بحث بالاسم ورقم الباركود وشريط تصفية الفئات (Category Chips).
  - شبكة الأصناف (Grid View) مع شارات توضح نوع المنتج والسعر والباركود.
  - نافذة تحديد عدد النسخ `Print Copies Dialog` مع معاينة حية للملصق وزر الطباعة الحرارية المباشرة.

* **تطبيق نمط المعمارية MVVM وتصحيح استثناء 401 Unauthorized (`BarcodePrintViewModel` & `main.dart`):**
  - إنشاء [barcode_print_viewmodel.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/viewmodels/barcode_print_viewmodel.dart) لإدارة حالة وجلب الأصناف بالـ MVVM واقتناص أخطاء الاتصال، وحقن كائن `ApiService` المعتمد بالـ JWT Token المحدث عند الدخول لتفادي أخطاء الـ `401 Unauthorized`.
  - تحديث [main.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/main.dart) وتسجيل الـ ViewModel بـ `MultiProvider` وإضافة `WidgetsFlutterBinding.ensureInitialized()` في أول دالة `main()`.

* **حل استثناءات طفح البكسلات (`RenderFlex OVERFLOWING`) بـ [barcode_print_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/barcode_print_screen.dart):**
  - تعديل كروت الأصناف بالشبكة وإحاطة المكونات بـ `Expanded` واستخدام `FittedBox` للسعر والتصنيف وتعديل نسبة التناسب إلى `childAspectRatio: 0.95` لمنع أخطاء الطفح البصري كلياً.

* **تكامل دالة الطباعة الحرارية لطابعات الإيصالات و Sunmi (`barcode_print_designer.dart` & `printer_service.dart`):**
  - دعم الطباعة المباشرة لطابعات Sunmi والإيصالات الحرارية عبر `SunmiPrinter.printText` وطباعة رمز الـ 2D/QR Code عبر `SunmiPrinter.printQRCode` وتمرير شفرات Code 128 / Code 39 الهاردويرية.

---

## 53. تطوير وتحديث منظومة القيود المحاسبية اليدوية (Journal Entries System) وتكامل الطباعة والتصدير والـ MVVM (أغسطس 2026)

* **الواجهات والأدوات التفاعلية المخصصة (Views & Custom UserControls):**
  - **صفحة القيود اليومية ([JournalEntryPage.xaml / .vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/JournalEntryPage.xaml)):**
    - بناء واجهة متقدمة لإدارة القيود المحاسبية بنمط MVVM كامل.
    - **شريط علوي متكامل:** أزرار قيد جديد (`F2`)، تحديث (`F5`)، حفظ (`Ctrl + S`)، ترحيل (`Ctrl + D`)، إلغاء الترحيل، موازنة تلقائية، طباعة مباشرة مع اختيار الطابعة (`Ctrl + P`)، وتصدير PDF (`📤`).
    - **قائمة القيود الجانبية (Collapsible Sidebar):** قائمة جانبية قابلة للطي والإظهار السلس لعرض القيود المسجلة مع شارات الحالة (مرحل / قيد الانتظار) والترقيم الصفحي (Pagination).
    - **محرر القيد والجدول:** ترويسة التاريخ والبيان العام، جدول تفاصيل السطور التفاعلي، وصندوق إجماليات المدين والدائن الموزون مع مؤشر فرق الاتزان الملون لحظياً.
  - **أداة سطر القيد المخصصة ([JournalRowControl.xaml / .vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/JournalRowControl.xaml)):**
    - تحويل سطور القيد إلى `UserControl` مخصص فائق الاستجابة والخفة دون الاعتماد على مشاكل DataGrid الافتراضية.
    - تثبيت عرض حقل الحساب على `Width="280"` لمنح وضوح تام للاسم ورقم الحساب، وجعل حقل البيان متمدداً تلقائياً (`Width="*"`) لاستغلال كامل المساحة عند تكبير الشاشة.
    - توسيط مبالغ المدين والدائن في منتصف الخانات (`TextAlignment="Center"` و `HorizontalContentAlignment="Center"`).
    - ضبط الهوامش والبادينج الداخلي (`Padding="8,4"` و `MinHeight="46"`) لحل مشكلة تآكل الحروف والأرقام من الأسفل نهائياً.
    - دعم التنقل السلس بمفتاح `Enter` بين خانات السطر وإضافة سطر جديد تلقائياً عند الضغط على `Enter` في خانة البيان.
  - **أداة البحث المنسدلة السريعة ([SearchableDropdown.xaml / .vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/SearchableDropdown.xaml)):**
    - توفير بحث فوري ذكي برقم واسم الحساب مع نافذة منبثقة تفاعلية ودعم الاختيار بالأسهم و `Enter` والانتقال المباشر للخانة التالية.

* **نمط المعمارية ومنطق الأعمال ([JournalEntryViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/JournalEntryViewModel.vb)):**
  - تطبيق نمط MVVM بالكامل مع ربط الأوامر التفاعلية: `NewCommand`, `SaveCommand`, `PostCommand`, `UnpostCommand`, `AutoBalanceCommand`, `AddLineCommand`, `DeleteLineCommand`, `PrintCommand`, `ExportPdfCommand`, `RefreshCommand`, `NextPageCommand`, `PreviousPageCommand`.
  - حساب فوري وتحديث حي لإجماليات المدين والدائن وفارق الاتزان ولون الحالة (`DifferenceFormatted`, `DifferenceColor`).
  - التحقق الصارم من قواعد القيود المحاسبية قبل الحفظ (سطرين على الأقل، اتزان المدين والدائن، اختيار الحسابات لكافة الأسطر، ومنع القيود الصفرية، وتنظيف الأسطر الفارغة تلقائياً).
  - معالجة التحديث السلس لتفادي تجميد الواجهة أثناء التحميل وإعادة جلب البيانات.

* **محرك الطباعة المباشرة واختيار الطابعة ([JournalPrinter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/JournalPrinter.vb)):**
  - بناء محرك طباعة مستقل لسندات القيود اليومية بالاعتماد على `System.Drawing.Printing.PrintDocument` و `System.Windows.Forms.PrintDialog`.
  - إظهار نافذة إعدادات وخيارات الطابعة القياسية لتحديد الطابعة وعدد النسخ وخيارات الورق.
  - تخطيط هندسي دقيق لسند القيد على ورق A4 يشمل:
    1. ترويسة وشعار الشركة وبيانات التواصل.
    2. صندوق عنوان السند ورقم القيد والتاريخ والحالة والبيان العام.
    3. جدول الحسابات والبيان والمدين والدائن بتنسيق عالي الدقة يدعم اللغة العربية (RTL).
    4. صندوق الإجماليات وحالة اتزان القيد.
    5. صناديق الاعتماد والتوقيعات الرسمية (المحاسب، المراجعة والتدقيق، اعتماد المدير).
    6. دعم الترقيم والطباعة متعددة الصفحات تلقائياً للقيود الطويلة.

* **تصدير ملفات PDF ([ReportExporter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/ReportExporter.vb)):**
  - تخصيص زر التصدير `📤` لحفظ واستخراج القيد كملف PDF رقمي عبر `SaveFileDialog` باستخدام مكتبة `PdfSharp`.

* **تحسين الستايل العام والقوالب ([Styles.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Resources/Styles.xaml)):**
  - تحديث `ModernTextBoxStyle` و `ModernPasswordBoxStyle` بربط `Padding="{TemplateBinding Padding}"` و `VerticalAlignment="{TemplateBinding VerticalContentAlignment}"` على `PART_ContentHost` لضمان توسيط النصوص ومنع اقتطاع الخطوط السفلية في جميع حقول النظام.

* **اختصارات لوحة المفاتيح المعتمدة:**
  - **`F2`**: قيد جديد فارغ.
  - **`F5`**: تحديث البيانات وإعادة تحميل قائمة القيود.
  - **`Ctrl + S`**: حفظ القيد المحاسبي.
  - **`Ctrl + D`**: ترحيل القيد إلى الدفتر العام.
  - **`Ctrl + P`**: فتح نافذة إعدادات واختيار الطابعة والطباعة المباشرة.

---

## 54. تحديثات وتوحيد جرد وتسوية الكاش للوردية وتثبيت حساب الصندوق على 1101 (أغسطس 2026)

* **تثبيت وتحديد حساب الكاش الرئيسي (Cash Account Anchoring):**
  - تم توجيه وتثبيت حساب الصندوق النقدي حصراً على كود الحساب **`1101`** و **`1101%`** في كافة الإجراءات المخزنة ونظام الـ API وواجهات الديسكتوب وتطبيق الفلاتر، بصرف النظر عن اختلاف وتغيير اسم الحساب (سواء كان اسمه `Cash` أو `الصندوق الرئيسي` أو `كاش الخزينة`).
  - تم عزل الحسابات البنكية وحسابات الشبكة K-Net (مثل الحساب `1102` أو الحسابات غير النقدية) ومنع احتسابها ضمن الكاش الورقي للدرج، لضمان تطابق الجرد الفعلي مع النقدية الملموسة في الدرج.

* **تعديلات قاعدة البيانات (`SQL Server Stored Procedures`):**
  - **الإجراءان المخزنان ([sp_Shift_GetSummary_and_Close.sql](file:///d:/VB.NET/backup/Vegtablity/SQL/sp_Shift_GetSummary_and_Close.sql) & [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql)):**
    - تم تحديث `[Sales].[sp_Shift_GetSummary]` و `[Sales].[sp_Shift_Close]` ليحصرا المبيعات والمشتريات النقدية المسددة بالدرج `@TotalPaidSalesCash` و `@TotalPaidPurchasesCash` على الحساب `1101` ومشتقاته حصراً.
    - تم عزل مبيعات ومشتريات الشبكة والبطاقات في `@TotalPaidSalesNonCash` و `@TotalPaidPurchasesNonCash`.
    - ضبط معادلة الكاش المتوقع بالدرج بدقة:
      $$\text{ExpectedCash} = \text{StartingCash} + \text{TotalPaidSalesCash} - \text{TotalPaidPurchasesCash} + \text{ReceiptVouchers} - \text{PaymentVouchers}$$
    - قيد تسوية فرق الكاش (العجز / الزيادة) عند إغلاق الوردية يرحل آلياً إلى حساب الصندوق `1101` وحساب الأرباح/الإيرادات `412`.

* **تحديثات الواجهة الخلفية (`FastAPI Backend`):**
  - **خدمة الورديات ([shift_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/shift_service.py)):**
    - تحديث دالة `get_shift_summary` لتعيين كاش المبيعات `TotalCashSales`، ومبيعات الشبكة `TotalKnetSales` / `TotalNonCashSales`، وكاش المشتريات `TotalCashPurchases`، والمشتريات غير النقدية `TotalNonCashPurchases`.
    - ربط وتطبيق معادلة الكاش المتوقع `ExpectedCash` بدقة واحتساب فارق الجرد `Difference`.
  - **مخطط البيانات ([shift.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/shift.py)):**
    - تحديث نموذج الاستجابة `ShiftSummaryResponse` ليتضمن الحقول المالية الجديدة مع قيم افتراضية متوافقة.

* **تحديثات تطبيق الفلاتر (`Flutter App`):**
  - **شاشة إغلاق الوردية ([close_shift_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/close_shift_screen.dart)):**
    - **بطاقة تسوية وجرد الكاش بالدرج (`cs_cash_drawer_calc`)**: أصبحت تعرض كاش المبيعات المحصل فقط `(+) مبيعات كاش محصلة`، وكاش المشتريات `(-) مشتريات كاش مدفوعة`، وسندات القبض `(+)` والصرف `(-)`، ومبلغ الكاش المتوقع بالدرج وحقل إدخال الكاش الفعلي واحتساب العجز/الفائض لحظياً.
    - **بطاقة ملخص المبيعات (`cs_sales_summary`)**: تعرض إجمالي المبيعات، وتفصيل المبيعات النقدية (كاش)، ومبيعات الشبكة والبطاقات (K-Net)، والآجل المتبقي.
    - **بطاقة ملخص المشتريات (`cs_purchases_summary`)**: تعرض إجمالي المشتريات، والمشتريات النقدية (كاش)، والمشتريات غير النقدية، والآجل المتبقي.
    - **بطاقة تفاصيل طرق الدفع**: تعرض التقسيم المفصل لجميع وسائل الدفع بالوردية.
  - **ملف الترجمة واللغات ([app_localizations.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/core/localization/app_localizations.dart)):**
    - إضافة النصوص ومفاتيح الترجمة `cs_cash_sales_label`, `cs_knet_sales_label`, `cs_cash_purchases_label`, `cs_non_cash_purchases_label`, `cs_add_cash_sales`, `cs_sub_cash_purchases` باللغتين العربية والإنجليزية.
  - **مصمم تقرير الوردية الحراري ([shift_report_print_designer.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/printing/shift_report_print_designer.dart)):**
    - تحديث منطق الطباعة الحرارية (لطابعات Sunmi وطابعات ESC/POS المكتبية) لخصم مشتريات الكاش من النقدية المتوقعة وفصل مبيعات الكاش عن مبيعات الشبكة.

* **تحديثات تطبيق سطح المكتب (`WPF Desktop App`):**
  - **نموذج البيانات ([Shift.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/Shift.vb)):**
    - إضافة خصائص `TotalCashSales`, `TotalNonCashSales`, `TotalKnetSales`, `TotalCashPurchases`, `TotalNonCashPurchases`.
  - **متحكم الورديات ([ShiftsViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/ShiftsViewModel.vb)):**
    - تحديث معالجة ملخص الوردية، وتثبيت فحص حساب الكاش على كود الحساب `1101` واستبعاد حسابات البنوك والشبكة.
  - **واجهة العرض ([ShiftsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ShiftsPage.xaml)):**
    - تحديث ترويسة أقسام الإيرادات والمدفوعات لعرض إجمالي المبيعات وإجمالي المشتريات، مع إبراز كارت التدفق النقدي الفعلي بالدرج.

---

## 55. سكربتات بناء جميع نسخ Flutter دفعة واحدة (`Android APK + Windows Desktop Build Scripts`) (أغسطس 2026)

* **سكربت الدُفعات التنفيذي ([build_all.bat](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/build_all.bat)):**
  - بناء سكربت تنفيذي بنقرة واحدة (Double Click) يقوم بـ:
    1. تحديث وجلب حزم المشروع عبر `flutter pub get`.
    2. بناء نسخة أندرويد واشا `flutter build apk --flavor washa --release` لإنتاج `app-washa-release.apk`.
    3. بناء نسخة أندرويد الجوهرة `flutter build apk --flavor jawhara --release` لإنتاج `app-jawhara-release.apk`.
    4. بناء نسخة الويندوز `flutter build windows --release` لإنتاج `vegtablity_app.exe`.
    5. فتح مجلدات المخرجات تلقائياً بعد اكتمال البناء.

* **سكربت PowerShell المتقدم ([build_all.ps1](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/build_all.ps1)):**
  - سكربت PowerShell يدعم بناء نسختي الأندرويد والويندوز مع مخرجات ملونة وتنسيق UTF-8 وفتح المجلدات تلقائياً.

---

## 56. إعداد نظام الـ Product Flavors لشركتي واشا والجوهرة (`Washa & Jawhara App Variants`) (أغسطس 2026)

* **تهيئة Gradle للأندرويد ([build.gradle.kts](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/android/app/build.gradle.kts)):**
  - إضافة `flavorDimensions += "default"` وتعريف نسختين منفصلتين:
    1. **نسخة `washa`:**
       - **Application ID:** `com.example.vegtablity_app` (الاحتفاظ بالمعرف الأصلي لمنع تعارض التثبيت والتحديثات).
       - **App Name (`@string/app_name`):** "واشا POS".
    2. **نسخة `jawhara`:**
       - **Application ID:** `com.jawhara.vegtablity_app` (معرف مستقل تماماً يتيح التثبيت جنباً إلى جنب على نفس الجهاز).
       - **App Name (`@string/app_name`):** "الجوهرة POS".
  - تحديث [AndroidManifest.xml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/android/app/src/main/AndroidManifest.xml) لاعتماد `android:label="@string/app_name"`.

* **توجيه الـ API التلقائي حسب الـ Flavor ([api_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/api_service.dart)):**
  - اعتماد المتغير `appFlavor` من `package:flutter/services.dart` لتحديد سيرفر الاتصال ديناميكياً:
    - نسخة **`jawhara`** تتصل تلقائياً بسيرفر الجوهرة: `185.216.203.50:8001`.
    - نسخة **`washa`** (والافتراضي) تتصل بسيرفر واشا: `185.216.203.50:8000`.

* **أوامر التشغيل والبناء لكل شركة:**
  - **تشغيل في بيئة التطوير (Debug Run):**
    - تشغيل واشا: `flutter run --flavor washa`
    - تشغيل الجوهرة: `flutter run --flavor jawhara`
  - **بناء حزمة APK النهائية (Release APK):**
    - بناء واشا: `flutter build apk --flavor washa --release`
    - بناء الجوهرة: `flutter build apk --flavor jawhara --release`
  - **بناء حزمة Windows Desktop النهائية:**
    - بناء واشا: `flutter build windows --release --dart-define=FLAVOR=washa`
    - بناء الجوهرة: `flutter build windows --release --dart-define=FLAVOR=jawhara`

---

## 57. ديناميكية عنوان القائمة الجانبية (اسم الشركة + POS) وعرض رقم الوردية المفتوحة (أغسطس 2026)

* **عرض اسم الشركة ديناميكياً في الـ Sidebar ([home_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)):**
  - استبدال العنوان الثابت `Vegtablity POS` بعنوان ديناميكي يستقبل اسم الشركة المحفوظ من `SettingsProvider` المحمل مسبقاً من `CompanySettings` (`<CompanyName> POS`) دون استدعاءات إضافية متكررة للـ API.
  - إضافة خاصية `companyName` والتخزين المحلي `cached_company_name` في [SettingsProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/settings_provider.dart) للظهور الفوري حتى في وضع عدم الاتصال.

* **عرض رقم الوردية المفتوحة أسفل اسم المستخدم:**
  - إضافة بادج تفاعلي أنيق داخل `DrawerHeader` يعرض:
    - في حال وجود وردية مفتوحة: أيقونة خضراء مع نص `الوردية رقم: #X` (`Shift No: #X`).
    - في حال عدم وجود وردية: أيقونة تنبيه مع نص `لا توجد وردية مفتوحة` (`No Active Shift`).
  - تحديث [ShiftProvider](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/shift_provider.dart) لتحميل رقم وحالة الوردية من الذاكرة المحلية `active_shift_id` فورياً عند بدء التطبيق والتحقق من السيرفر في الخلفية.

* **تعريب عناصر القائمة الجانبية والشاشة الرئيسية بالكامل ([app_localizations.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/core/localization/app_localizations.dart)):**
  - إضافة مفاتيح الترجمة لعناصر السايد بار وبطاقات الشاشة الرئيسية باللغتين العربية والإنجليزية:
    - `home_drawer_stocktake`: "جرد المخزون (مسودة)" / "Stock Take (Draft)"
    - `home_drawer_wastage`: "إهلاك بضاعة (الهالك)" / "Wastage / Damaged Goods"
    - `home_drawer_recipes`: "وصفات المنتجات والتصنيع" / "Product Recipes & Manufacturing"
    - `home_classic_recipes`: "وصفات المنتجات" / "Product Recipes"

---

## 58. تفعيل وتخصيص تعديل الفواتير غير المرحلة (Sales & Purchases) وإدارتها في التطبيق (أغسطس 2026)

* **خيار جديد في الإعدادات العامة ([settings_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart)):**
  - إضافة خيار `pref_allow_edit_unposted_invoices` (تفعيل تعديل الفواتير غير المرحلة لهذا الجهاز).
  - يُحفظ الإعداد محلياً في `SharedPreferences` للتحكم في الصلاحية على مستوى كل جهاز كاشير.

* **تعديل الفواتير من شاشة البحث ([invoice_lookup_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/invoice_lookup_screen.dart)):**
  - عند البحث عن فاتورة، إذا كان الإعداد مفعلاً والفاتورة غير مرحلة (`IsPosted != true`)، يظهر زر "تعديل الفاتورة ✏️" ليتم فتح الفاتورة بكافة أصنافها وكمياتها وبياناتها في شاشة الـ POS.
  - عند حفظ التعديل، يتم تحديث بيانات الفاتورة وإعادة عرضها في شاشة البحث فورياً.

* **تعديل الفواتير من تقرير الفواتير اليومية ([daily_invoices_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/daily_invoices_screen.dart)):**
  - في نافذة تفاصيل الفاتورة، يظهر زر "تعديل الفاتورة ✏️" إذا كانت الفاتورة غير مرحلة، مع فتحها للتعديل وتحديث إجماليات التقرير اليومي تلقائياً.

* **دعم وضع التعديل وتقسيم طرق الدفع في شاشة الـ POS ([pos_screen.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/pos_screen.dart) & [pos_provider.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/providers/pos_provider.dart)):**
  - استقبال `editingInvoice` وتعبئة السلة `loadInvoiceIntoCart` بالأصناف والكميات والأسعار والخصومات والعميل/المورد.
  - دعم استرجاع وتعديل تقسيم طرق الدفع السابقة (`PaymentSplits`) داخل حوار الدفع.
  - إرسال المعامل `InvID` إلى الـ API لحفظ التعديل تحت نفس رقم الفاتورة دون إنشاء فاتورة مكررة.

* **تحديث الـ Backend و SQL بالتوافق الكامل مع كافة الإصدارات السابقة ([SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) & [db_procedures.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/core/db_procedures.py)):**
  - الإجراء المخزن `[Sales].[sp_Invoice_Save_XML]` يدعم تحديث الرأس والتفاصيل وحذف وإعادة إدراج `[Sales].[InvoicePaymentSplits]` عند تمرير `@InvID > 0`.
  - تحديث [invoice_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/invoice_service.py) و [invoices.py Schema](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/schemas/invoices.py) لدعم `InvID: Optional[int] = 0`.

---

## 59. منظومة التحديث التلقائي الشاملة (In-App Auto Update) وتشفير بيانات الاتصال بـ AES-256 (أغسطس 2026)

تم بناء منظومة تحديث تلقائي سحابية موحدة وذكية لكافة المنصات والأنظمة (WPF Desktop، Flutter Android APK، و Windows Flutter) مع تشفير مشدد لبيانات الاتصال بقواعد البيانات لمنع أي تسريب أو وصول غير مصرح به.

### أ- تشفير بيانات الاتصال واستيراد اسم قاعدة البيانات خارجياً بـ AES-256 ([DatabaseHelper.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/DatabaseHelper.vb)):
* **تشفير قالب السيرفر داخلياً:** تم تشفير وإخفاء عنوان السيرفر (`185.216.203.50,1422`) واسم المستخدم وكلمة المرور داخلياً في ثابت مشفر (`ENCODED_CONN_TEMPLATE`) لحمايتها من الاستخراج.
* **استيراد اسم قاعدة البيانات فقط من الخارج:** ملف `dbconfig.dat` الخارجي يحتوي **فقط على اسم قاعدة البيانات** (مثل `WashaDB` أو `JawharaDB` أو `VegtablityDB` أو `zatterDB` أو `OmanCustmerDB`) مشفراً بخوارزمية AES-256 (Key 32 bytes + IV 16 bytes).
* **إلغاء القيم الافتراضية (Strict Error Handling):**
  - إذا لم يوجد ملف `dbconfig.dat` بجوار ملف التشغيل، يرمي النظام فوراً `FileNotFoundException` صريح يمنع تشغيل البرنامج ويطلب ملف التهيئة الخاص بالشركة.
  - تم تجهيز المجلد `d:\VB.NET\backup\Vegtablity\TenantConfigs\` بكافة ملفات التهيئة المشفرة الجاهزة للشركات.

### ب- التحديث التلقائي لبرنامج الـ WPF مع Inno Setup ([AutoUpdateService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/AutoUpdateService.vb)):
* **الفحص والمقارنة التلقائية:** عند فتح شاشة تسجيل الدخول [LoginWindow.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/LoginWindow.xaml.vb) أو الشاشة الرئيسية [DashboardWindow.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/DashboardWindow.xaml.vb)، يتصل البرنامج بـ `GET /updates/check?platform=wpf&flavor=<Flavor>&current_version=<Version>`.
* **واجهة التحديث التفاعلية ([UpdateAvailableDialog.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/UpdateAvailableDialog.xaml)):** عرض رقم الإصدار الجديد وملاحظات التحديث وشريط تقدم التحميل بالنسبة المئوية.
* **التثبيت الصامت الذكي:** يقوم بتنزيل ملف الـ `Setup.exe` إلى `%TEMP%` وتشغيله بالوضع الصامت `/SILENT /CLOSEAPPLICATIONS` واستبدال الملفات دون مساس بملف `dbconfig.dat` الخاص بالعميل.
* **تكامل Inno Setup:** استخدام خاصية `Flags: onlyifdoesntexist uninsneveruninstall` لملف `dbconfig.dat` في سكريبت التثبيت لضمان الحفاظ على قاعدة بيانات العميل للأبد أثناء التحديثات التلقائية.

### ج- التحديث التلقائي لتطبيق Flutter للموبايل والويندوز ([update_service.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/services/update_service.dart)):
* **قراءة الإصدار الديناميكي:** استخدام حزمة `package_info_plus` لقراءة `version` و `version_code` تلقائياً من [pubspec.yaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/pubspec.yaml) دون الحاجة لتعديل الكود البرمجي عند كل إصدار.
* **تنزيل وتثبيت الـ APK مباشرة ([update_dialog.dart](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/widgets/update_dialog.dart)):** تنزيل حزمة الـ APK مع شريط تقدم تفاعلي وتشغيل معالج التثبيت فوراً عبر مكتبة `open_filex`.
* **الفحص الصامت واليدوي:** فحص صامت مع تأخير ثانيتين عند تشغيل [HomeScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/home_screen.dart)، وزر فحص يدوي في شاشة الإعدادات العامة [GeneralSettingsScreen](file:///d:/VB.NET/backup/Vegtablity/Vegtablity_App/lib/screens/settings_screen.dart).

### د- مركز التحكم والتحديثات بالخادم الخلفي ([VegtablityApi](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi)):
* **قاعدة بيانات التحديثات ([updates_manifest.json](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/data/updates_manifest.json)):** ملف JSON مركزي يحدد الإصدارات ورابط التنزيل وملاحظات التحديث لكل منصة (`wpf`, `android`, `windows_flutter`) ولكل شركة (`washa`, `jawhara`, `vegtablity`, `zatter`, `oman`).
* **مقارنة الإصدارات الدقيقة ([update_service.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/services/update_service.py)):** خوارزمية تطبيع أرقام الإصدارات لـ 4 خانات عددية (`2.1.0` vs `2.1.0.0`) لمنع تكرار طلب التحديث بعد التثبيت.
* **مسارات الـ API المباشرة ([updates.py](file:///d:/VB.NET/backup/Vegtablity/VegtablityApi/app/routes/updates.py)):**
  - `GET /updates/check`: فحص التحديثات والمقارنة.
  - `GET /updates/manifest`: جلب ملف الـ Manifest الكامل.
  - `POST /updates/publish`: نشر تحديث جديد بضغطة زر.
  - استضافة ملفات التثبيت الثابتة عبر مسار `/static/updates/`.

---

## 60. أداة تفاصيل سطور الأصناف الجديدة (InvoiceItemRowControl) وإحلالها في فواتير المبيعات (أغسطس 2026)

تم إنشاء وتطوير عنصر تحكم مخصص حديث `InvoiceItemRowControl` يحل محل جدول الـ `DataGrid` القديم في صفحة فواتير المبيعات [SalesInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml)، مدمجاً بكافة آليات البحث الذكي والتحقق الصارم والتنقل السريع.

### أ- البنية المعمارية للأداة ([InvoiceItemRowControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/InvoiceItemRowControl.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/InvoiceItemRowControl.xaml.vb)):
* **كود الصنف (الباركود):** `TextBox` مخصص للبحث الفوري؛ عند الضغط على Enter يتم البحث في قائمة الأصناف:
  - إذا تم العثور على الصنف، يتم تعبئة بياناته فوراً ونقل المؤشر إلى خانة **الكمية**.
  - إذا لم يتم العثور عليه بالباركود، يتم نقل التركيز تلقائياً إلى خانة **اسم الصنف** لإتاحة البحث بالاسم.
* **اسم الصنف ([SearchableDropdown.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/SearchableDropdown.xaml)):** أداة البحث المنسدلة الذكية للبحث الفوري بالاسم أو الكود، وتعبئة بيانات الصنف والانتقال إلى **الكمية**.
* **عروض الأسعار المخصصة أولاً عبر Stored Procedure:**
  - يتم استدعاء الإجراء المخزن المعتمد `sp_Quotation_GetActivePrice` لفحص وتطبيق سعر عرض السعر النشط الخاص بالعميل أولاً، مع إشعار المستخدم عبر Snackbar. وفي حال عدم وجود عرض سعر، يتم اعتماد السعر الافتراضي `SalePrice`.
* **الوحدة:** حقل قراءة فقط لعرض وحدة قياس الصنف.
* **الكمية:** 
  - دعم الكسور العشرية دون فرض أصفار وهمية إجبارية (`StringFormat=\{0:0.###\}`).
  - تحديد النص بالكامل `SelectAll()` عند الدخول للخلية `GotFocus` لاستبدال القيمة فور بدء الكتابة ومنع تكرار الفاصلة العشرية.
  - منع كتابة أي حروف غير رقمية مع السماح بفاصلة عشرية واحدة فقط عبر `PreviewTextInput`.
  - الضغط على Enter ينقل المؤشر إلى **سعر الوحدة**.
* **سعر الوحدة:** إدخال رقمي مرن، والضغط على Enter ينقل المؤشر إلى **الإجمالي**.
* **الإجمالي:** حقل قراءة فقط بخط عريض، والضغط على Enter يطلق حدث `RequestAddNewRow` لإنشاء سطر جديد والتركيز على الباركود فيه.
* **زر الحذف:** زر أحمر `❌` لحذف السطر وإعادة احتساب الإجماليات فورياً.

### ب- الدمج في صفحة فواتير المبيعات ([SalesInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/SalesInvoicePage.xaml.vb)):
* تم استبدال الـ `DataGrid` بـ ترويسة أنيقة ثابتة وقائمة مرنة `ItemsControl` تحتوي على `InvoiceItemRowControl`.
* معالجة أحداث إضافة السطور والحذف وإعادة الحساب والتحقق من الكميات والأسعار الصفرية قبل الحفظ عبر `ValidateInvoiceItemsBeforeSave`.

---

## 61. تعميم أدوات تفاصيل الأصناف المخصصة على فواتير المشتريات وعروض الأسعار (أغسطس 2026)

تم بنجاح تعميم نمط عناصر التحكم المخصصة `UserControls` بدلاً من جداول الـ `DataGrid` القديمة عبر جميع شاشات الفواتير وعروض الأسعار في نظام سطح المكتب:

### أ- إحلال الأداة في فاتورة المشتريات ([PurchaseInvoicePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseInvoicePage.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseInvoicePage.xaml.vb)):
* تم إحلال الأداة المعتمدة `InvoiceItemRowControl` في صفحة فواتير المشتريات بدلاً من جدول الـ `DataGrid` القديم.
* ربط ترويسة الأعمدة المتناسقة [كود الصنف / الباركود | اسم الصنف | الوحدة | الكمية | سعر الشراء | الإجمالي | حذف].
* ربط أحداث `InvoiceItemRow_RequestAddNewRow` و `InvoiceItemRow_RequestDeleteRow` و `InvoiceItemRow_AmountChanged`، وتحديث دالة `FocusLastRowBarcode()` لنقل التركيز لخانة الباركود في السطر الجديد فوراً.
* الاحتفاظ الكامل بآليات التحقق من الكميات وأسعار الشراء قبل الحفظ وتحديث الإجماليات اللحظية.

### ب- إنشاء أداة عروض الأسعار المخصصة ([QuoteItemRowControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/QuoteItemRowControl.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/QuoteItemRowControl.xaml.vb)):
* تم تصميم عنصر تحكم مخصص خفيف وسريع يلبي متطلبات عروض الأسعار بدون حقول كمية أو إجمالي زائدة:
  - **الأعمدة:** [كود الصنف (160px) | اسم الصنف عبر `SearchableDropdown` (*) | الوحدة (100px) | سعر العرض المقترح (140px) | زر الحذف ❌ (40px)].
  - **التوافقية المزدوجة:** دعم التزامن الآلي مع نموذجي `QuoteDetail` (عروض أسعار المبيعات - `SalePrice`) و `PurchaseQuoteDetail` (عروض أسعار المشتريات - `PurchasePrice`).
  - **دورة التنقل بـ Enter:**
    - الباركود $\rightarrow$ سعر العرض (إذا وُجد الصنف) أو قائمة البحث عن الصنف (إذا لم يوجد).
    - اسم الصنف $\rightarrow$ سعر العرض.
    - سعر العرض $\rightarrow$ إطلاق حدث `RequestAddNewRow` لإنشاء سطر جديد والتركيز التلقائي على الباركود الجديد.

### ج- إحلال الأداة في عروض أسعار المبيعات ([QuotePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/QuotePage.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/QuotePage.xaml.vb)):
* استبدال جدول الـ `DataGrid` بـ `ItemsControl` و `QuoteItemRowControl` مع ترويسة واضحة.
* ربط أزرار الإضافة والتنقل وإدارة السطور بدقة وسلاسة.

### د- إحلال الأداة في عروض أسعار المشتريات ([PurchaseQuotePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseQuotePage.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PurchaseQuotePage.xaml.vb)):
* استبدال جدول الـ `DataGrid` بـ `ItemsControl` و `QuoteItemRowControl` مع ترويسة [سعر الشراء المقترح].
* دعم نموذج `PurchaseQuoteDetail` وتعيين سعر الشراء الافتراضي والتنقل السريع بالـ Enter.

---

## 62. كارت البحث والتصفية المتحرك وتطوير إجراء القيود اليومية (أغسطس 2026)

تم بنجاح تزويد قائمة القيود اليومية في شاشة القيود المحاسبية [JournalEntryPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/JournalEntryPage.xaml) بكارت بحث وتصفية متقدم وتفاعلي يدعم الحركة الانسيابية (`Animation`)، مع تحديث وتطوير الإجراء المخزن المعتمد في SQL Server مع الحفاظ الكامل على التوافق الرجعي 100%:

### أ- تطوير الإجراء المخزن ([38_sp_JournalEntry_GetPaged_Search.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/38_sp_JournalEntry_GetPaged_Search.sql)):
* تحديث الإجراء `[Accounting].[sp_JournalEntry_GetPaged]` في [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) و [setup/SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/setup/SQLVegtablity.sql).
* إضافة معاملات اختيارية بـ `= NULL` (`@JournalNo`, `@SearchText`, `@IsPosted`, `@StartDate`, `@EndDate`) مع الحفاظ على الترقيم `OFFSET / FETCH NEXT` وحساب `@TotalCount OUTPUT`.
* دعم البحث الجزئي برقم القيد والبيان العام والفلترة بحالة الترحيل ونطاق التواريخ مع الاحتفاظ بالتوافقية الرجعية الكاملة للنسخ القديمة.

### ب- تطوير الخدمات ونموذج العرض ([JournalEntryViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/JournalEntryViewModel.vb) & [AccountingService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/AccountingService.vb)):
* تحديث دالة `AccountingService.GetPagedJournalHeaders` لتمرير المعاملات الاختيارية.
* تزويد الـ ViewModel بخصائص وأوامر الفلترة: `SearchJournalNo`, `SearchDescription`, `SearchStatusIndex`, `SearchDateFrom`, `SearchDateTo`, `IsDateFilterEnabled`, `IsFilterActive`, `ActiveFilterSummaryText`, `ApplyFilterCommand`, `ClearFilterCommand`, `ToggleFilterCardCommand`.

### ج- واجهة المستخدم والتحريك الانسيابي ([JournalEntryPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/JournalEntryPage.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/JournalEntryPage.xaml.vb)):
* زر تصفية أنيق `🔍 تصفية` في ترويسة القائمة مع شارة حمراء `نشط` عند تفعيل أي معيار تصفية.
* كارت تحكم قابل للطي والفتح مع `DoubleAnimation` انسيابي للارتفاع والشفافية (`CubicEase`).
* إدخال رقم القيد، البيان، حالة الترحيل، فلترة التاريخ، وزري تطبيق ومسح التصفية، مع دعم البحث بالضغط على `Enter`.
* شريط تنبيه النتائج النشطة أعلى قائمة القيود مع زر إلغاء سريع.

---

## 63. شجرة الحسابات الهرمية التفاعلية وترقيم السندات بالصفحات (أغسطس 2026)

تم ابتكار وبناء عنصر تحكم تفاعلي هرمي متكامل لشجرة دليل الحسابات `AccountTreeControl` ليحل محل الجداول المسطحة التقليدية، لتمثيل الشجرة المحاسبية بأسلوب هرمي بديهي متعدد المستويات (المستوى 0: الرئيسي، المستوى 1: الفرعي، المستوى 2: المجموعات، والمستويات التفصيلية اللاحقة):

### أ- البنية الهيكلية والبرمجية لشجرة الحسابات ([AccountTreeControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/AccountTreeControl.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/AccountTreeControl.xaml.vb)):
* **كائن العقدة الهرمية ([AccountNode.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/AccountNode.vb)):**
  - بناء كائن `AccountNode` المرن الذي يحمل بيانات الحساب، ومستوى الحساب `AccountLevel`، وقائمة الأبناء `Children As ObservableCollection(Of AccountNode)`، وحالة الطي/الفتح `IsExpanded`، وحالة الرؤية والتظليل `IsVisible` و `IsHighlighted`، وعقدة الأب `ParentNode`.
  - خوارزمية ذكية لاحتساب الإجماليات التراكمية للحسابات الرئيسية `TotalBalance` تلقائياً من مجموع أرصدة الحسابات الفرعية التابعة لها.
* **التحكم بالطي والتوسيع (Expand & Collapse):**
  - زر طي وتوسيع فردي بجانب كل عقدة حساب رئيسي أو فرعي يحتوي على حسابات تابعة.
  - زران علويان في شريط أدوات الشجرة: `🔽 توسيع الكل` لفتح كامل فروع الشجرة، و `🔼 طي الكل` لطي كافة المستويات وإبقاء الحسابات الرئيسية فقط لسهولة التصفح.
* **البحث والتصفية والتظليل الذكي (Smart Search & Highlighting):**
  - حقل بحث فوري بالكود أو الاسم؛ عند كتابة أي كلمة يتم تظليل العقد المطابقة تلقائياً باللون الأصفر الفاتح وتوسيع مسار الآباء التابعين لها فورياً لتسهيل الوصول للحساب المطلوب.
* **الشارات والأيقونات المحاسبية:**
  - تمييز نوع الحساب بألوان قياسية (الأصول: أزرق، الالتزامات: أحمر، الملكية: بنفسجي، الإيرادات: أخضر، المصروفات: برتقالي).
  - زر مخصص لإضافة حساب فرعي `+ فرعي` يقوم بتوليد الكود التالي واختيار الحساب الأب تلقائياً، وزر تعديل الحساب `✏️`.
* **إحلال الأداة في صفحة دليل الحسابات ([AccountsPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/AccountsPage.xaml)):**
  - استبدال جدول الـ DataGrid القديم بأداة `AccountTreeControl` مع المحافظة على لوحة تفاصيل وإدخال الحساب في النصف الأيسر والتزامن اللحظي عند التحديد `SelectedItemChanged`.

### ب- ترقيم وتصفح السندات بالصفحات ([PaymentVoucherPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/PaymentVoucherPage.xaml) & [ReceiptVoucherPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ReceiptVoucherPage.xaml)):
* إضافة شريط تحكم بالصفحات (Pagination) أسفل قائمة السندات في سندات الصرف وسندات القبض:
  - أزرار التنقل السريع: `⏮ الأولى`، `◀ السابق`، `التالي ▶`، `الأخيرة ⏭`.
  - تقسيم السجلات إلى 15 سندا لكل صفحة لتسريع استجابة الواجهة ومنع ثقل التمرير.
  - مؤشر واضح لرقم الصفحة الحالية وإجمالي عدد الصفحات وإجمالي عدد السندات المسجلة.

---

## 64. تطوير تقرير الأرباح والخسائر والمقارنة الشهرية الأفقية والرسوم البيانية المتقدمة (أغسطس 2026)

تم إنجاز ترقية شاملة لمنظومة تقارير الأرباح والخسائر والتحليل المالي لتقديم تحليلات مالية متقدمة تفيد الإدارة في اتخاذ القرارات:

### أ- عمود النسبة المئوية من المبيعات (% of Sales - التحليل المالي الرأسي):
* **منهجية الاحتساب المحاسبي:**
  - **الإيرادات:** نسبة كل بند إيراد = `(قيمة البند / إجمالي المبيعات) * 100%` (حيث إجمالي المبيعات = 100.0%).
  - **المصروفات:** نسبة كل بند مصروف = `(قيمة المصروف / إجمالي المبيعات) * 100%` لتوضيح نسبة استهلاك كل بند مصروف من إجمالي الإيرادات المحققة.
  - **صافي الربح:** نسبة صافي الربح = `(صافي الربح / إجمالي المبيعات) * 100%` (هامش صافي الربح Net Margin).
  - حماية كاملة ضد القسمة على صفر بعرض `0.0%` بأمان في حال كانت المبيعات صفراً.
* **العرض والتنسيق:** إدراج عمود `% من المبيعات` في جدولي الإيرادات والمصروفات وشريط الإجماليات وبطاقة صافي الربح في [ProfitLossPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ProfitLossPage.xaml).

### ب- التصدير المالي المتقدم للـ PDF مع ورقة الرسوم البيانية المتجهة:
* تم تطوير دالة `ExportProfitLossToPdf` في [ReportExporter.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Helpers/ReportExporter.vb) لإنشاء ملف PDF من صفحتين احترافيتين:
  - **الصفحة 1 (الجدول المالي الرسمي):** ترويسة الشركة، عنوان التقرير والفترة، جدول الإيرادات مع عمود النسبة، جدول المصروفات مع عمود النسبة، وبطاقة صافي الربح/الخسارة الملونة.
  - **الصفحة 2 (ورقة التحليل والرسوم البيانية المتجهة عالية الدقة Vector Graphics):**
    1. **بطاقات المؤشرات المالية الرئيسية (KPI Cards):** بطاقة إجمالي المبيعات، بطاقة إجمالي المصروفات ونسبتها، وبطاقة صافي الربح وهامش الربح.
    2. **مخطط بياني شريطي (Revenues vs Expenses vs Net Profit Bar Chart):** رسم بياني يقارن بين الإيرادات والمصروفات وصافي الربح مع الأرقام التوضيحية.
    3. **مخطط دائري (Donut/Pie Chart) لتوزيع المصروفات التشغيلية:** تجزئة أهم بنود المصروفات كقطاعات دائرية ملونة مع وسيلة إيضاح (Legend) ونسب مئوية.

### ج- التصدير الاحترافي لـ Excel / CSV:
* إضافة دالة `ExportProfitLossToExcel` لإنشاء ملفات `.csv` معيارية مدمجة بترميز `UTF-8 BOM` لتفتح مباشرة في Microsoft Excel باللغة العربية مع الحفاظ التام على الأعمدة والنسب المئوية والإجماليات ودون أي اعتماد على مكتبات خارجية.
* حماية البيانات وتهريب الفواصل والنصوص `EscapeCsv` وتنسيق الأرقام والنسب المئوية.

### د- تقرير المقارنة الشهرية الأفقي (Horizontal Monthly Comparative P&L Report):
* **البنية البرمجية والموديلات ([ReportModels.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Models/ReportModels.vb) & [AccountingService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/AccountingService.vb)):**
  - موديلات `MonthlyPeriodHeader`، `MonthlyComparativeRow`، و `MonthlyComparativeReport`.
  - دالة `GetMonthlyComparativeProfitLoss`: تقسم الفترة المحددة تلقائياً إلى شهور تقويمية متتابعة، وتجمع قيم كل حساب شهراً بشهر، وتحسب الإجماليات الشهرية للإيرادات والمصروفات وصافي الربح لكل شهر.
* **التبويبات واختيار طريقة العرض ([ProfitLossPage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ProfitLossPage.xaml)):**
  - إتاحة التقرير التراكمي والمقارنة الشهرية عبر تبويبات علوية أنيقة:
    1. **📊 قائمة الأرباح والخسائر التراكمية**.
    2. **📅 المقارنة الشهرية الأفقية (شهور الفترة)**.
  - توليد ديناميكي لأعمدة الشهور في الـ DataGrid في كود الواجهة [ProfitLossPage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/ProfitLossPage.xaml.vb).
* **الرسم البياني التفاعلي الحي (LiveCharts):**
  - مخطط بياني تفاعلي يدمج أعمدة الإيرادات (الأخضر)، أعمدة المصروفات (الأحمر)، ومنحنى صافي الربح (البنفسجي) عبر شهور الفترة.
* **تصدير المقارنة الشهرية (PDF بالعرض Landscape & Excel / CSV):**
  - `ExportMonthlyComparativeToPdf`: صفحة جدول أفقي عريض (Landscape) لجميع الشهور + صفحة ثانية مخصصة للرسم البياني لمسار الأداء الشهري ومقارنة نمو الأرباح.
  - `ExportMonthlyComparativeToExcel`: ملف CSV / Excel كامل بالأعمدة الشهرية وإجمالي الفترة ونسب المبيعات بترميز UTF-8.

---

## 65. تطوير صفحة إدارة الوصفات ومكونات المنتجات وأداة السطور المخصصة والفلترة التفاعلية (أغسطس 2026)

تم تنفيذ تطوير شامل لصفحة إدارة وتحديد وصفات المنتجات المصنعة والوسيطة ([RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml)) يشمل الآتي:

### أ- أداة إدخال سطر مكونات الوصفة المخصصة ([RecipeItemRowControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/RecipeItemRowControl.xaml) & [.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/RecipeItemRowControl.xaml.vb)):
* **الأعمدة والمكونات:**
  1. **الباركود (`BarcodeBox`):** حقل نصي؛ عند إدخال الباركود والضغط على Enter يقوم بمطابقة الصنف من المواد الخام المتاحة تلقائياً، وتعبئة كافة الحقول، ونقل التركيز مباشرة لحقل الكمية (أو إلى قائمة البحث الذكية في حال عدم وجود الباركود).
  2. **اسم الصنف عبر القائمة الذكية (`SearchableDropdown`):** أداة بحث منسدلة ذكية تتيح البحث الفوري بالاسم أو الباركود، وعند الاختيار والضغط على Enter تنتقل مباشرة لحقل الكمية.
  3. **الوحدة (`UnitBox`):** حقل للقراءة فقط يعرض وحدة المادة الخام.
  4. **الكمية (`QuantityBox`):** حقل نصي يدعم التحقق الصارم من الأرقام والفاصلة العشرية، وعند الضغط على Enter ينتقل لسعر تكلفة الوحدة.
  5. **سعر تكلفة الوحدة (`UnitCostBox`):** حقل نصي يعرض سعر شراء وتكلفة الوحدة مع إمكانية التعديل، وعند الضغط على Enter ينتقل للإجمالي.
  6. **إجمالي تكلفة المكون (`TotalPriceBox`):** حقل للقراءة فقط يعرض ناتج (الكمية × التكلفة)؛ وعند الضغط على Enter يطلق حدث `RequestAddNewRow`.
  7. **حذف الصف ❌ (`DeleteButton`):** زر حذف السطر يطلق حدث `RequestDeleteRow`.
* **دورة التنقل التلقائي وتوليد السطور الجديدة:**
  - الانتقال التلقائي بين الخلايا بمفتاح `Enter`.
  - عند الضغط على Enter في نهاية السطر يتم توليد سطر جديد فوراً ونقل التركيز التلقائي لباركود السطر الجديد عبر `FocusLastRowBarcode()`.
  - تحديد النص بالكامل عند التركيز `SelectAll` لمنع تداخل الأرقام.

### ب- كارت الفلترة والتصفية القابل للطي للوحة الوصفات المسجلة:
* **التصفية المزدوجة بالاسم والباركود:**
  - حقل بحث فوري باسم المنتج وحقل بحث فوري بالباركود.
  - زر تفريغ التصفية السريع لإعادة عرض كامل الوصفات.
  - عداد ذكي يعرض عدد الوصفات المفلترة لحظياً في شارة ملونة.
* **الطي والفتح مع التحريك الانسيابي (DoubleAnimation & CubicEase):**
  - إمكانية طي وفتح صندوق الفلترة مع حركة شفافة انسيابية عبر زر `🔍 تصفية ▼`.
  - إمكانية طي وفتح اللوحة الجانبية ككل (Sidebar) مع حركة انسحاب كاملة للعرض والشفافية عبر زر الهمبرجر `☰`.

### ج- إحلال الـ DataGrid في واجهة التحرير:
* استبدال جدول الـ `DataGrid` القديم بـ `ItemsControl` مع ترويسة متناسقة تماماً مع أعمدة `RecipeItemRowControl` وتمرير سلس `ScrollViewer` وتصميم عصري متناسق مع هوية النظام.

---

## 66. تطوير صفحة إدارة التوالف والهوالك وأداة السطور WastageItemRowControl والفلترة القابلة للطي

تم تحديث وتطوير صفحة إدارة التوالف والهوالك ([WastagePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/WastagePage.xaml) & [WastagePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/WastagePage.xaml.vb)) ونموذج العرض ([WastageViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/WastageViewModel.vb))، وإنشاء عنصر التحكم المخصص لسطور التوالف ([WastageItemRowControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/WastageItemRowControl.xaml) & [WastageItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/WastageItemRowControl.xaml.vb)) وفقاً للنمط المعماري الموحد المعمول به في النظام:

### أ- أداة السطور المخصصة لسطور التوالف (WastageItemRowControl):
* **الأعمدة المدعومة:**
  1. `ProductCodeBox` (110px): كود الصنف / الباركود مع البحث الفوري ومطابقة الصنف في المخزون.
  2. `ProductDropdown` (*): أداة `SearchableDropdown` المنسدلة للبحث الذكي عن الأصناف والمواد التالفة بالاسم أو الباركود.
  3. `QuantityBox` (85px): الكمية التالفة مع التحقق الصارم من الأرقام، وتنبيه تجاوز الرصيد المتاح.
  4. `AvailableQtyBox` (85px): الرصيد المتاح للصنف في المستودع المختار للقراءة فقط (لون أزرق مميز `#2563EB`).
  5. `CostPriceBox` (95px): تكلفة الوحدة (تُجلب تلقائياً بناءً على متوسط التكلفة أو سعر الشراء مع إمكانية التعديل).
  6. `TotalCostBox` (105px): إجمالي التكلفة للقراءة فقط (تنسيق `N3` ولون وردي عريض `#E11D48`).
  7. `BalanceAfterBox` (95px): الرصيد بعد الخصم (الرصيد المتاح - الكمية التالفة) للقراءة فقط بلون أحمر `#DC2626`.
  8. `DeleteButton` (40px): زر الحذف ❌ لحذف السطر وإعادة احتساب الإجمالي تلقائياً.
* **دورة التنقل التلقائي بمفتاح `Enter`:**
  - `الباركود` ⬅️ `Enter` ⬅️ مطابقة الصنف وجلب التكلفة والرصيد المتاح ونقل التركيز لـ `الكمية التالفة`.
  - `SearchableDropdown` ⬅️ `Enter` / ConfirmedAndMoveNext ⬅️ نقل التركيز لـ `الكمية التالفة`.
  - `الكمية التالفة` ⬅️ `Enter` ⬅️ تحديث الإجمالي ونقل التركيز لـ `تكلفة الوحدة`.
  - `تكلفة الوحدة` ⬅️ `Enter` ⬅️ نقل التركيز لـ `الإجمالي`.
  - `الإجمالي` ⬅️ `Enter` ⬅️ إطلاق حدث `RequestAddNewRow`، إضافة سطر جديد ونقل التركيز تلقائياً لباركود السطر الجديد عبر `FocusLastRowBarcode()`.
* **خاصية القفل التلقائي `IsLocked`:**
  - قفل كافة حقول السطر تلقائياً عند اعتماد وترحيل السند (`IsPosted = True`) لمنع التعديل غير المصرح به.

### ب- كارت الفلترة والتصفية القابل للطي لسجل التوالف:
* **البحث المزدوج والمتعدد في سجل التوالف:**
  - `HistorySearchText`: بحث تفاعلي فوري برقم السند، اسم المستخدم، الملاحظات، التاريخ، أو القيمة الإجمالية.
  - `HistoryStatusFilter`: تصفية حسب حالة السند (الكل / مسودة فقط / مرحل ومعتمد فقط).
  - زر تفريغ التصفية السريع `ClearHistoryFilterCommand` 🔄.
  - شارة ذكية لعرض عدد السجلات المفلترة لحظياً.
* **الطي والفتح مع التحريك الانسيابي (Animations):**
  - طي وفتح كارت التصفية مع حركة انسيابية شفافة عبر زر `🔍 تصفية ▼`.
  - طي وفتح اللوحة الجانبية ككل (Sidebar) مع حركة انسحاب كاملة للعرض والشفافية (`DoubleAnimation` و `CubicEase`) عبر زر `☰`.

### ج- إحلال الـ DataGrid في واجهة التحرير:
* استبدال جدول الـ `DataGrid` القديم بـ `ItemsControl` و `ScrollViewer` وأداة `WastageItemRowControl` مع ترويسة متطابقة، وتصميم عصري متناسق مع هوية النظام.

---

## 67. تطوير إدارة الجرد الآلي وترقيم صفحات سجل الجرد وسجل التوالف (10 سجلات / صفحة)

تم تطوير وتحديث صفحة إدارة الجرد الآلي ([StockTakePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/StockTakePage.xaml) & [StockTakePage.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/StockTakePage.xaml.vb)) ونموذج العرض ([StockTakeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/StockTakeViewModel.vb))، وإنشاء عنصر التحكم المخصص لسطور الجرد ([StockTakeItemRowControl.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/StockTakeItemRowControl.xaml) & [StockTakeItemRowControl.xaml.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Controls/StockTakeItemRowControl.xaml.vb))، وتطبيق نظام ترقيم الصفحات في سجل الجرد وسجل التوالف:

### أ- أداة السطور المخصصة لسطور الجرد (StockTakeItemRowControl):
* **الأعمدة المدعومة:**
  1. `ProductCodeBox` (100px): كود الصنف / الباركود مع البحث الفوري ومطابقة الصنف في المخزون.
  2. `ProductDropdown` (*): أداة `SearchableDropdown` للبحث الذكي عن الأصناف بالاسم أو الباركود.
  3. `RefreshStockBtn` (32px): زر تحديث الرصيد الدفتري الحالي والتكلفة من المخزون 🔄.
  4. `SystemQtyBox` (85px): الكمية الدفترية الحالية في المستودع المختار للقراءة فقط (`#2563EB`).
  5. `ActualQtyBox` (85px): الكمية الفعلية مع التحقق الصارم من الأرقام، وتحديث الفروقات المالية والكمية فوراً.
  6. `DiffQtyBox` (80px): فرق الكمية (الكمية الفعلية - الكمية الدفترية) ملون (أخضر إذا 0، رمادي/أحمر إذا غير ذلك).
  7. `CostPriceBox` (85px): تكلفة الوحدة مع إمكانية التعديل.
  8. `DiffValueBox` (95px): قيمة الفرق المالي (فرق الكمية × التكلفة) للقراءة فقط (`#E11D48`).
  9. `DeleteButton` (36px): زر الحذف ❌ لحذف السطر وإعادة احتساب إجمالي الفروقات المالية.
* **دورة التنقل التلقائي بمفتاح `Enter`:**
  - `الباركود` ⬅️ `Enter` ⬅️ مطابقة الصنف وجلب الرصيد الدفتري والتكلفة ونقل التركيز لـ `الكمية الفعلية`.
  - `SearchableDropdown` ⬅️ `Enter` ⬅️ نقل التركيز لـ `الكمية الفعلية`.
  - `الكمية الفعلية` ⬅️ `Enter` ⬅️ تحديث الفروقات ونقل التركيز لـ `تكلفة الوحدة`.
  - `تكلفة الوحدة` ⬅️ `Enter` ⬅️ نقل التركيز لـ `قيمة الفرق`.
  - `قيمة الفرق` ⬅️ `Enter` ⬅️ إطلاق حدث `RequestAddNewRow`، إضافة سطر جديد ونقل التركيز لباركود السطر الجديد تلقائياً.
* **خاصية القفل التلقائي `IsLocked`:**
  - قفل كافة حقول السطر تلقائياً عند اعتماد تسوية الجرد النهائية لمنع التعديل.

### ب- الفلترة القابلة للطي وترقيم الصفحات (Pagination) في سجل الجرد وسجل التوالف:
* **الفلترة القابلة للطي لسجل الجرد:**
  - كارت تصفية قابل للطي والفتح بالبحث برقم المستند، المستودع، اسم المستخدم، الملاحظات، أو التاريخ.
  - تصفية الحالة: الكل / مسودة فقط (قيد المراجعة) / معتمد فقط.
  - زر تفريغ التصفية السريع وشارة ذكية لعدد السجلات المفلترة.
  - طي وفتح اللوحة الجانبية ككل بحركة انسحاب ناعمة عبر زر `☰`.
* **نظام ترقيم الصفحات (Pagination) بمعدل 10 سجلات في الصفحة:**
  - تم تقليص حجم الصفحة من 20 إلى **10 سجلات في الصفحة الواحدة** في سجل الجرد وفي سجل التوالف.
  - إضافة شريط تنقل متقدم في أسفل القائمة الجانبية يضم:
    - زر `◀ السابق` (PreviousPageCommand).
    - عداد الصفحات الذكي `صفحة X من Y (إجمالي: N)`.
    - زر `التالي ▶` (NextPageCommand).
  - تحديث الإجراءات المخزنة `[Inventory].[sp_StockTake_GetAll]` و `[Inventory].[sp_Wastage_GetAll]` في [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql) بتوافق رجعي تام 100%.

### ج- إحلال الـ DataGrid في واجهة تحرير الجرد:
* استبدال جدول الـ `DataGrid` في مسودة الجرد بـ `ItemsControl` و `ScrollViewer` وأداة `StockTakeItemRowControl` مع ترويسة متطابقة، وتصميم عصري متناسق مع هوية النظام.

---

## 68. تطبيق ترقيم الصفحات (Pagination) في سجل الوصفات المسجلة (10 وصفات / صفحة)

تم تطوير وتحديث صفحة إدارة الوصفات ([RecipePage.xaml](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Views/RecipePage.xaml)) ونموذج العرض ([RecipeViewModel.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/ViewModels/RecipeViewModel.vb)) وخدمة الوصفات ([RecipeService.vb](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/Services/RecipeService.vb)) والإجراء المخزن `[Inventory].[sp_Recipe_GetAll]` في [SQLVegtablity.sql](file:///d:/VB.NET/backup/Vegtablity/Vegtablity/Vegtablity/SQL/SQLVegtablity.sql):

### أ- ترقيم الصفحات في واجهة المستخدم (RecipePage.xaml):
* إضافة شريط ترقيم الصفحات أسفل القائمة الجانبية لسجل الوصفات المسجلة يضم:
  - زر `◀ السابق` (PreviousPageCommand).
  - عداد الصفحات التفاعلي `صفحة X من Y (إجمالي: N)`.
  - زر `التالي ▶` (NextPageCommand).
* دعم كامل للفلترة المزدوجة بالاسم والباركود والربط مع الترقيم.

### ب- نموذج العرض والخدمات (RecipeViewModel & RecipeService):
* إضافة خصائص الترقيم: `CurrentPage` (افتراضي 1)، `PageSize = 10`، `TotalRecords`، `TotalPages`، `HasPreviousPage`، `HasNextPage`، و `PageInfo`.
* إضافة دالة `GetRecipesPaged(pageNumber, pageSize)` في `RecipeService.vb` لجلب البيانات مع العدد الإجمالي عبر `Dapper.QueryMultiple`.

### ج- ترقية الإجراء المخزن مع التوافق الرجعي 100% (sp_Recipe_GetAll):
* الإجراء المخزن `[Inventory].[sp_Recipe_GetAll]` يدعم الآن معاملات اختيارية:
  ```sql
  CREATE PROCEDURE [Inventory].[sp_Recipe_GetAll]
      @PageNumber INT = NULL,
      @PageSize   INT = NULL
  ```
  - عند تمرير `@PageNumber` و `@PageSize`، يقوم بإرجاع نتيجتين (إجمالي العدد `TotalCount` والسجلات المفلترة مع `OFFSET .. FETCH NEXT`).
  - عند استدعائه بدون معاملات (كما في الاستخدامات السابقة للنسخ القديمة)، يقوم بإرجاع كامل السجلات في جدول واحد دون أي تغيير، مما يضمن توافقاً رجعياً تاماً 100%.






















