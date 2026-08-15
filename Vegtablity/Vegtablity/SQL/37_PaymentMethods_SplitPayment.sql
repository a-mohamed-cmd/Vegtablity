-- =============================================================================================================
-- 37. Payment Methods & Split Payment Support
-- MVVM-Style Trigger Refactoring: trg_Invoice_Post → 3 Layered SPs + Thin Trigger
-- =============================================================================================================
-- الفلسفة:
--   الـ Trigger يصبح "thin coordinator" فقط:
--     1. يُحوّل inserted/deleted إلى Temp Tables مرئية للـ SPs
--     2. يستدعي 3 SPs متخصصة (Inventory / InvoiceJournals / PaymentJournals)
--     3. المنطق الكامل الأصلي موجود بالكامل في الـ SPs بدون أي حذف
--
--   sp_Invoice_Post_Inventory      → نفس منطق المخزن تماماً
--   sp_Invoice_Post_InvoiceJournals → نفس قيود A و B تماماً
--   sp_Invoice_Post_PaymentJournals → قيود C + دعم Split Payment + Fallback للقديم
--
-- BACKWARD COMPATIBILITY:
--   فواتير WPF القديمة أو فواتير بدون Splits → تعمل عبر Fallback على PaymentAccountID الفردي
--   لا يوجد أي تغيير في جداول الإنتاج، فقط إضافة
-- =============================================================================================================

-- =============================================
-- STEP 1: جدول InvoicePaymentSplits
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'InvoicePaymentSplits' AND schema_id = SCHEMA_ID('Sales'))
BEGIN
    CREATE TABLE [Sales].[InvoicePaymentSplits] (
        SplitID          INT PRIMARY KEY IDENTITY(1,1),
        InvID            INT NOT NULL,
        PaymentAccountID INT NOT NULL,      -- حساب طريقة الدفع (AccountCode LIKE '11%')
        Amount           DECIMAL(18,3) NOT NULL,
        CreatedAt        DATETIME DEFAULT GETDATE(),
        FOREIGN KEY (InvID)            REFERENCES [Sales].[InvoiceHeader](InvID)              ON DELETE CASCADE,
        FOREIGN KEY (PaymentAccountID) REFERENCES [Accounting].[ChartOfAccounts](AccountID)
    );

    CREATE NONCLUSTERED INDEX [IX_InvoicePaymentSplits_InvID]
        ON [Sales].[InvoicePaymentSplits] (InvID);

    PRINT N'[Sales].[InvoicePaymentSplits] created successfully.';
END
ELSE
    PRINT N'[Sales].[InvoicePaymentSplits] already exists — skipped.';
GO

-- =============================================
-- STEP 2: SP الطبقة الأولى — تحديث المخزن (Post & Unpost مع دعم التصنيع والتوزيع التكراري)
-- يستخدم Temp Tables: #TrgInserted, #TrgDeleted (تُنشأ من الـ Trigger)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_Inventory]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_Inventory];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_Inventory]
AS
BEGIN
    SET NOCOUNT ON;

    -- جلب وضع التصنيع المسجل في إعدادات الشركة (0 = عادي / بيع مباشر، 1 = تصنيع ووصفات)
    DECLARE @ProductionMode BIT = ISNULL((SELECT TOP 1 ProductionMode FROM [Settings].[CompanySettings]), 0);

    -- ==========================================================
    -- أولاً: حالة الترحيل (POSTING: 0 -> 1)
    -- ==========================================================
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        -- أ. إدراج سجلات المنتجات المفقودة للمستودع المعين بقيم صفرية لمنع فشل التحديث (يشمل مكونات الوصفات عند التفعيل)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT DISTINCT TargetProductID, WarehouseID, 0, 0
        FROM (
            SELECT D.ProductID AS TargetProductID, i.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted del ON i.InvID = del.InvID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
            UNION
            SELECT RD.IngredientProductID AS TargetProductID, i.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted del ON i.InvID = del.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0 AND @ProductionMode = 1 AND i.InvType = 'Sales'
        ) MissingStock
        WHERE NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] S2 
            WHERE S2.ProductID = MissingStock.TargetProductID AND S2.WarehouseID = MissingStock.WarehouseID
        );

        -- ب. تحديث متوسط التكلفة الأصلي (للمشتريات فقط - قبل زيادة الكمية)
        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (ISNULL(S.CurrentQty, 0) + T.TotalQty) > 0 
            THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) + T.TotalSum) / (ISNULL(S.CurrentQty, 0) + T.TotalQty)
            ELSE T.WeightedPrice END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum,
                   SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0) as WeightedPrice
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND i.InvType = 'Purchase'
            GROUP BY D.ProductID, i.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        -- ب.1. تحديث تكاليف كافة المنتجات المصنعة عند ترحيل المشتريات (إذا كان وضع التصنيع مفعلاً)
        IF @ProductionMode = 1 AND EXISTS (SELECT 1 FROM #TrgInserted WHERE InvType = 'Purchase' AND IsPosted = 1)
        BEGIN
            DECLARE @PurchasedW INT = (SELECT TOP 1 WarehouseID FROM #TrgInserted WHERE InvType = 'Purchase' AND IsPosted = 1);
            IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
                EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @PurchasedW;
        END

        -- ج. تحديث الكميات في المخزن مع الدعم التكراري للوصفات (ExplodedPost CTE)
        ;WITH ExplodedPost AS (
            SELECT 
                D.InvID,
                i.InvType,
                i.WarehouseID,
                D.ProductID AS TargetProductID,
                CAST(D.Quantity AS DECIMAL(18, 4)) AS TargetQty,
                0 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 
              AND (@ProductionMode = 0 OR i.InvType = 'Purchase' OR NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] WHERE ProductID = D.ProductID))

            UNION ALL

            SELECT 
                D.InvID,
                i.InvType,
                i.WarehouseID,
                RD.IngredientProductID AS TargetProductID,
                CAST((D.Quantity * RD.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                1 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgInserted i ON D.InvID = i.InvID
            JOIN #TrgDeleted d_old ON i.InvID = d_old.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND @ProductionMode = 1 AND i.InvType = 'Sales'

            UNION ALL

            SELECT 
                EP.InvID,
                EP.InvType,
                EP.WarehouseID,
                RD_Sub.IngredientProductID AS TargetProductID,
                CAST((EP.TargetQty * RD_Sub.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                EP.RecLevel + 1
            FROM ExplodedPost EP
            JOIN [Inventory].[Recipes] R_Sub ON R_Sub.ProductID = EP.TargetProductID
            JOIN [Inventory].[RecipeDetails] RD_Sub ON RD_Sub.RecipeID = R_Sub.RecipeID
            WHERE EP.RecLevel > 0 
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] PS 
                  WHERE PS.ProductID = EP.TargetProductID AND PS.WarehouseID = EP.WarehouseID AND PS.CurrentQty > 0
              )
        )
        UPDATE S
        SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN T.InvType = 'Purchase' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT TargetProductID, InvID, InvType, WarehouseID, SUM(TargetQty) as Qty 
            FROM ExplodedPost 
            GROUP BY TargetProductID, InvID, InvType, WarehouseID
        ) T ON S.ProductID = T.TargetProductID AND S.WarehouseID = T.WarehouseID;

        -- د. تسجيل التكلفة المباشرة في تفاصيل الفاتورة (للمبيعات) لضبط الربحية
        UPDATE D
        SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
        FROM [Sales].[InvoiceDetails] D
        JOIN #TrgInserted i ON D.InvID = i.InvID
        JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID AND S.WarehouseID = i.WarehouseID
        WHERE i.IsPosted = 1 AND i.InvType = 'Sales';
    END

    -- ==========================================================
    -- ثانياً: حالة إلغاء الترحيل (UNPOSTING: 1 -> 0)
    -- ==========================================================
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        -- أ. إدراج سجلات المخزون المفقودة لمنع فشل التحديث عند إلغاء الترحيل
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT DISTINCT TargetProductID, WarehouseID, 0, 0
        FROM (
            SELECT D.ProductID AS TargetProductID, d_old.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
            UNION
            SELECT RD.IngredientProductID AS TargetProductID, d_old.WarehouseID
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND @ProductionMode = 1 AND d_old.InvType = 'Sales'
        ) MissingStockUnpost
        WHERE NOT EXISTS (
            SELECT 1 FROM [Inventory].[ProductStock] S2 
            WHERE S2.ProductID = MissingStockUnpost.TargetProductID AND S2.WarehouseID = MissingStockUnpost.WarehouseID
        );

        -- ب. إعادة حساب وتخفيض متوسط التكلفة (عند إلغاء ترحيل المشتريات فقط)
        UPDATE S
        SET S.AvgCostPrice = CASE 
            WHEN (ISNULL(S.CurrentQty, 0) - T.TotalQty) > 0 
            THEN (CASE 
                WHEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) > 0 
                THEN (ISNULL(S.CurrentQty, 0) * ISNULL(S.AvgCostPrice, 0) - T.TotalSum) / (ISNULL(S.CurrentQty, 0) - T.TotalQty)
                ELSE 0 END)
            ELSE 0 END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT D.ProductID, d_old.WarehouseID, SUM(D.Quantity) as TotalQty, SUM(D.Quantity * D.UnitPrice) as TotalSum
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND d_old.InvType = 'Purchase'
            GROUP BY D.ProductID, d_old.WarehouseID
        ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

        -- ب.1. إعادة حساب تكاليف المنتجات المصنعة بعد إلغاء ترحيل المشتريات
        IF @ProductionMode = 1 AND EXISTS (SELECT 1 FROM #TrgDeleted WHERE InvType = 'Purchase' AND IsPosted = 1)
        BEGIN
            DECLARE @UnpostedW INT = (SELECT TOP 1 WarehouseID FROM #TrgDeleted WHERE InvType = 'Purchase' AND IsPosted = 1);
            IF OBJECT_ID('[Inventory].[sp_Update_Manufactured_Costs]', 'P') IS NOT NULL
                EXEC [Inventory].[sp_Update_Manufactured_Costs] @WarehouseID = @UnpostedW;
        END

        -- ج. عكس تأثير المخزن عند إلغاء الترحيل (المبيعات تعيد للمخزن / المشتريات تقتطع)
        ;WITH ExplodedUnpost AS (
            SELECT 
                D.InvID,
                d_old.InvType,
                d_old.WarehouseID,
                D.ProductID AS TargetProductID,
                CAST(D.Quantity AS DECIMAL(18, 4)) AS TargetQty,
                0 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
              AND (@ProductionMode = 0 OR d_old.InvType = 'Purchase' OR NOT EXISTS (SELECT 1 FROM [Inventory].[Recipes] WHERE ProductID = D.ProductID))

            UNION ALL

            SELECT 
                D.InvID,
                d_old.InvType,
                d_old.WarehouseID,
                RD.IngredientProductID AS TargetProductID,
                CAST((D.Quantity * RD.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                1 AS RecLevel
            FROM [Sales].[InvoiceDetails] D
            JOIN #TrgDeleted d_old ON D.InvID = d_old.InvID
            JOIN #TrgInserted i ON d_old.InvID = i.InvID
            JOIN [Inventory].[Recipes] R ON R.ProductID = D.ProductID
            JOIN [Inventory].[RecipeDetails] RD ON RD.RecipeID = R.RecipeID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND @ProductionMode = 1 AND d_old.InvType = 'Sales'

            UNION ALL

            SELECT 
                EU.InvID,
                EU.InvType,
                EU.WarehouseID,
                RD_Sub.IngredientProductID AS TargetProductID,
                CAST((EU.TargetQty * RD_Sub.Qty) AS DECIMAL(18, 4)) AS TargetQty,
                EU.RecLevel + 1
            FROM ExplodedUnpost EU
            JOIN [Inventory].[Recipes] R_Sub ON R_Sub.ProductID = EU.TargetProductID
            JOIN [Inventory].[RecipeDetails] RD_Sub ON RD_Sub.RecipeID = R_Sub.RecipeID
            WHERE EU.RecLevel > 0 
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] PS 
                  WHERE PS.ProductID = EU.TargetProductID AND PS.WarehouseID = EU.WarehouseID AND PS.CurrentQty > 0
              )
        )
        UPDATE S
        SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN T.InvType = 'Sales' THEN T.Qty ELSE -T.Qty END)
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT TargetProductID, InvID, InvType, WarehouseID, SUM(TargetQty) as Qty 
            FROM ExplodedUnpost 
            GROUP BY TargetProductID, InvID, InvType, WarehouseID
        ) T ON S.ProductID = T.TargetProductID AND S.WarehouseID = T.WarehouseID;
    END
END
GO

-- =============================================
-- STEP 3: SP الطبقة الثانية — قيود الفاتورة (A + B)
-- يستخدم: #TrgInserted, #TrgDeleted, #TrgEntryMap
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_InvoiceJournals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_InvoiceJournals];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_InvoiceJournals]
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── حسابات الفالباك (نفس الأصل تماماً) ─────────────────────────────────
    DECLARE @InventoryAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13'));

    DECLARE @SalesAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '41'));

    DECLARE @COGSAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5101'),
        ISNULL(
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1),
            (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '51')));

    DECLARE @CustomerAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'));

    DECLARE @VendorAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'));

    -- ─── A. قيود فواتير المشتريات ─────────────────────────────────────────────

    -- Leg 1: Dr المخزن (Inventory)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(w.AccountID, @InventoryAcc),
           i.NetAmount, 0,
           N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
    WHERE i.InvType = 'Purchase';

    -- Leg 2: Cr المورد (Vendor)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(p.AccountID, @VendorAcc),
           0, i.NetAmount,
           N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Purchase';

    -- ─── B. قيود فواتير المبيعات ──────────────────────────────────────────────

    -- Leg 1: Dr العميل (Customer)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(p.AccountID, @CustomerAcc),
           i.NetAmount, 0,
           N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Sales';

    -- Leg 2: Cr المبيعات (Sales Revenue)
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           @SalesAcc,
           0, i.NetAmount,
           N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    WHERE i.InvType = 'Sales';

    -- Leg 3: Dr تكلفة البضاعة المباعة COGS
    ;WITH InvoiceCOGS AS (
        SELECT d.InvID,
               SUM(s.AvgCostPrice * d.Quantity) AS TotalCOGS
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        LEFT JOIN [Inventory].[ProductStock] s
            ON s.ProductID = d.ProductID AND s.WarehouseID = i.WarehouseID
        GROUP BY d.InvID
    )
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           @COGSAcc,
           cogs.TotalCOGS, 0,
           N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
    WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

    -- Leg 4: Cr المخزن (Inventory — بحساب المستودع)
    ;WITH InvoiceCOGS AS (
        SELECT d.InvID,
               SUM(s.AvgCostPrice * d.Quantity) AS TotalCOGS
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        LEFT JOIN [Inventory].[ProductStock] s
            ON s.ProductID = d.ProductID AND s.WarehouseID = i.WarehouseID
        GROUP BY d.InvID
    )
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
           ISNULL(w.AccountID, @InventoryAcc),
           0, cogs.TotalCOGS,
           N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
    LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
    WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;
END
GO

-- =============================================
-- STEP 4: SP الطبقة الثالثة — قيود السداد (C) مع دعم Split Payment
-- يستخدم: #TrgInserted, #TrgDeleted, #TrgEntryMap
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Post_PaymentJournals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Post_PaymentJournals];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Post_PaymentJournals]
AS
BEGIN
    SET NOCOUNT ON;

    -- ─── حسابات الفالباك ───────────────────────────────────────────────────────
    DECLARE @CustomerAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'));

    DECLARE @VendorAcc INT = ISNULL(
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1),
        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'));

    -- ─────────────────────────────────────────────────────────────────────────────
    -- مسار 1: SPLIT PAYMENT
    -- ─────────────────────────────────────────────────────────────────────────────

    -- ── مشتريات Split ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @VendorAcc),   -- Dr المورد
           sp.Amount, 0,
           N'سداد [' + c.AccountName + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0;

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           sp.PaymentAccountID,                -- Cr حساب طريقة الدفع
           0, sp.Amount,
           N'سداد [' + c.AccountName + N'] - مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0;

    -- ── مبيعات Split ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           sp.PaymentAccountID,                -- Dr حساب طريقة الدفع
           sp.Amount, 0,
           N'سداد [' + c.AccountName + N'] - مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    INNER JOIN [Sales].[InvoicePaymentSplits] sp ON sp.InvID = i.InvID
    INNER JOIN [Accounting].[ChartOfAccounts] c  ON c.AccountID = sp.PaymentAccountID
    WHERE i.InvType = 'Sales' AND i.PaidAmount > 0;

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @CustomerAcc), -- Cr العميل
           0, i.PaidAmount,
           N'سداد فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Sales' AND i.PaidAmount > 0
      AND EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    -- ─────────────────────────────────────────────────────────────────────────────
    -- مسار 2: FALLBACK — PaymentAccountID الفردي
    -- ─────────────────────────────────────────────────────────────────────────────

    -- ── مشتريات Fallback ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @VendorAcc),
           i.PaidAmount, 0,
           N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Purchase'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           i.PaymentAccountID,
           0, i.PaidAmount,
           N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    WHERE i.InvType = 'Purchase'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    -- ── مبيعات Fallback ──
    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           i.PaymentAccountID,
           i.PaidAmount, 0,
           N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    WHERE i.InvType = 'Sales'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);

    INSERT INTO [Accounting].[JournalEntries]
        (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
    SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
           ISNULL(p.AccountID, @CustomerAcc),
           0, i.PaidAmount,
           N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR),
           i.UserID
    FROM #TrgInserted i
    JOIN #TrgEntryMap m ON m.InvID = i.InvID
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.InvType = 'Sales'
      AND i.PaidAmount > 0
      AND i.PaymentAccountID IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM [Sales].[InvoicePaymentSplits] WHERE InvID = i.InvID);
END
GO

-- =============================================
-- STEP 5: الـ Trigger الجديد (Thin Coordinator)
-- ينشئ Temp Tables ويستدعي الـ SPs للترحيل وإلغاء الترحيل
-- =============================================
IF OBJECT_ID('[Sales].[trg_Invoice_Post]', 'TR') IS NOT NULL
    DROP TRIGGER [Sales].[trg_Invoice_Post];
GO

CREATE TRIGGER [Sales].[trg_Invoice_Post]
ON [Sales].[InvoiceHeader]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- فحص: هل تم تغيير IsPosted؟
    IF NOT UPDATE(IsPosted) RETURN;

    -- تحميل inserted/deleted إلى Temp Tables مرئية للـ SPs
    SELECT * INTO #TrgInserted FROM inserted;
    SELECT * INTO #TrgDeleted  FROM deleted;

    -- ─── 1. حالة الترحيل (POSTING: 0 -> 1) ──────────────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
    BEGIN
        SELECT i.InvID, i.InvType,
               NEXT VALUE FOR [Accounting].[seq_EntryNo] AS EntryNo
        INTO #TrgEntryMap
        FROM #TrgInserted i
        INNER JOIN #TrgDeleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0;

        -- أ. تحديث المخزن المباشر ومكونات الوصفات عند التفعيل
        EXEC [Sales].[sp_Invoice_Post_Inventory];

        -- ب. إنشاء قيود الفاتورة (إيرادات + تكلفة البضاعة المباعة)
        EXEC [Sales].[sp_Invoice_Post_InvoiceJournals];

        -- ج. إنشاء قيود السداد (Split + Fallback)
        EXEC [Sales].[sp_Invoice_Post_PaymentJournals];

        DROP TABLE #TrgEntryMap;
    END

    -- ─── 2. حالة إلغاء الترحيل (UNPOSTING: 1 -> 0) ──────────────────────────
    IF EXISTS (SELECT 1 FROM #TrgInserted i JOIN #TrgDeleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        -- أ. عكس تأثير المخزن وإعادة حساب التكلفة المرجحة وتكلفة المصنعات (مباشر + تصنيع ووصفات)
        EXEC [Sales].[sp_Invoice_Post_Inventory];

        -- ب. حذف كافة القيود المحاسبية بالفاتورة والمدفوعات التابعة لها بالكامل
        DELETE JE FROM [Accounting].[JournalEntries] JE
        INNER JOIN #TrgDeleted d ON JE.ReferenceID = d.InvID
        INNER JOIN #TrgInserted i ON d.InvID = i.InvID
        WHERE i.IsPosted = 0 AND d.IsPosted = 1
          AND JE.ReferenceType IN ('Invoice', 'Payment');
    END

    -- تنظيف Temp Tables
    DROP TABLE #TrgInserted;
    DROP TABLE #TrgDeleted;
END
GO

-- =============================================
-- STEP 6: SPs API — حفظ وجلب Splits
-- =============================================

IF OBJECT_ID('[Sales].[sp_InvoicePaymentSplits_Save]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_InvoicePaymentSplits_Save];
GO
CREATE PROCEDURE [Sales].[sp_InvoicePaymentSplits_Save]
    @InvID            INT,
    @PaymentAccountID INT,
    @Amount           DECIMAL(18,3)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [Sales].[InvoicePaymentSplits] (InvID, PaymentAccountID, Amount)
    VALUES (@InvID, @PaymentAccountID, @Amount);
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS SplitID;
END
GO

IF OBJECT_ID('[Sales].[sp_InvoicePaymentSplits_GetByInvID]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_InvoicePaymentSplits_GetByInvID];
GO
CREATE PROCEDURE [Sales].[sp_InvoicePaymentSplits_GetByInvID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        s.SplitID,
        s.InvID,
        s.PaymentAccountID,
        s.Amount,
        s.CreatedAt,
        c.AccountName AS PaymentMethodName,
        c.AccountCode
    FROM [Sales].[InvoicePaymentSplits] s
    INNER JOIN [Accounting].[ChartOfAccounts] c ON s.PaymentAccountID = c.AccountID
    WHERE s.InvID = @InvID
    ORDER BY s.SplitID;
END
GO

-- =============================================
-- STEP 7: تعديل sp_Invoice_AddPayment لإضافة Split عند سداد الآجل
-- (نفس المنطق الأصلي + INSERT في InvoicePaymentSplits)
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_AddPayment]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_AddPayment];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_AddPayment]
    @InvID            INT,
    @PaymentAmount    DECIMAL(18,2),
    @PaymentAccountID INT,
    @UserID           INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @InvType   NVARCHAR(20), @PartnerID INT,
                @Remainder DECIMAL(18,2), @IsPosted  BIT;

        SELECT @InvType   = InvType,
               @PartnerID = PartnerID,
               @Remainder = Remainder,
               @IsPosted  = IsPosted
        FROM [Sales].[InvoiceHeader]
        WHERE InvID = @InvID;

        IF @IsPosted = 0
        BEGIN RAISERROR(N'لا يمكن إضافة سداد لفاتورة غير مرحّلة', 16, 1); RETURN; END

        IF @PaymentAmount <= 0 OR @PaymentAmount > @Remainder
        BEGIN RAISERROR(N'مبلغ السداد غير صحيح أو يتجاوز المتبقي', 16, 1); RETURN; END

        -- 1. تحديث الأرصدة في الفاتورة (كما هو بالضبط)
        UPDATE [Sales].[InvoiceHeader]
        SET PaidAmount = PaidAmount + @PaymentAmount,
            Remainder  = Remainder  - @PaymentAmount
        WHERE InvID = @InvID;

        -- 2. ✅ [جديد] تسجيل طريقة الدفع في جدول الـ Splits
        INSERT INTO [Sales].[InvoicePaymentSplits] (InvID, PaymentAccountID, Amount)
        VALUES (@InvID, @PaymentAccountID, @PaymentAmount);

        -- 3. حساب الشريك (كما هو بالضبط)
        DECLARE @PartnerAccountID INT;
        SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

        -- 4. القيود المحاسبية (كما هي بالضبط)
        DECLARE @EntryNo   INT           = NEXT VALUE FOR [Accounting].[seq_EntryNo];
        DECLARE @EntryDate DATE          = CAST(GETDATE() AS DATE);
        DECLARE @AccName   NVARCHAR(100) = ISNULL((SELECT AccountName FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @PaymentAccountID), N'');
        DECLARE @Desc      NVARCHAR(255) = N'سداد [' + @AccName + N'] - فاتورة رقم ' + CAST(@InvID AS NVARCHAR);

        IF @InvType = 'Sales'
        BEGIN
            -- Dr Cash / Cr Customer
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID, @PaymentAmount, 0,             @Desc, @UserID),
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  0,             @PaymentAmount, @Desc, @UserID);
        END
        ELSE
        BEGIN
            -- Dr Vendor / Cr Cash
            INSERT INTO [Accounting].[JournalEntries]
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            VALUES
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  @PaymentAmount, 0,             @Desc, @UserID),
                (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID,  0,             @PaymentAmount, @Desc, @UserID);
        END

        COMMIT TRANSACTION;
        SELECT 1 AS Success;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('[Sales].[sp_Invoice_AddPayment_pos]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_AddPayment_pos];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_AddPayment_pos]
    @InvID            INT,
    @PaymentAmount    DECIMAL(18,2),
    @PaymentAccountID INT,
    @UserID           INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @InvType   NVARCHAR(20), @PartnerID INT,
                @Remainder DECIMAL(18,2), @IsPosted  BIT;

        SELECT @InvType   = InvType,
               @PartnerID = PartnerID,
               @Remainder = Remainder,
               @IsPosted  = IsPosted
        FROM [Sales].[InvoiceHeader]
        WHERE InvID = @InvID;

        IF @InvID IS NULL OR @Remainder IS NULL
        BEGIN RAISERROR(N'الفاتورة غير موجودة', 16, 1); RETURN; END

        IF @PaymentAmount <= 0 OR @PaymentAmount > @Remainder
        BEGIN RAISERROR(N'مبلغ السداد غير صحيح أو يتجاوز المتبقي', 16, 1); RETURN; END

        -- 1. تحديث الأرصدة وحساب السداد المختار
        UPDATE [Sales].[InvoiceHeader]
        SET PaidAmount = PaidAmount + @PaymentAmount,
            Remainder  = Remainder  - @PaymentAmount,
            PaymentAccountID = @PaymentAccountID
        WHERE InvID = @InvID;

        -- 2. ✅ تسجيل طريقة الدفع في جدول الـ Splits
        INSERT INTO [Sales].[InvoicePaymentSplits] (InvID, PaymentAccountID, Amount)
        VALUES (@InvID, @PaymentAccountID, @PaymentAmount);

        -- 3. إضافة قيود محاسبية فقط إذا كانت الفاتورة مرحّلة
        IF @IsPosted = 1
        BEGIN
            DECLARE @PartnerAccountID INT;
            SELECT @PartnerAccountID = AccountID FROM [Sales].[Partners] WHERE PartnerID = @PartnerID;

            DECLARE @EntryNo   INT           = NEXT VALUE FOR [Accounting].[seq_EntryNo];
            DECLARE @EntryDate DATE          = CAST(GETDATE() AS DATE);
            DECLARE @AccName   NVARCHAR(100) = ISNULL((SELECT AccountName FROM [Accounting].[ChartOfAccounts] WHERE AccountID = @PaymentAccountID), N'');
            DECLARE @Desc      NVARCHAR(255) = N'سداد [' + @AccName + N'] - فاتورة رقم ' + CAST(@InvID AS NVARCHAR);

            IF @InvType = 'Sales'
            BEGIN
                INSERT INTO [Accounting].[JournalEntries]
                    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
                VALUES
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID, @PaymentAmount, 0,              @Desc, @UserID),
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  0,              @PaymentAmount, @Desc, @UserID);
            END
            ELSE
            BEGIN
                INSERT INTO [Accounting].[JournalEntries]
                    (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
                VALUES
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PartnerAccountID,  @PaymentAmount, 0,              @Desc, @UserID),
                    (@EntryNo, @EntryDate, 'InvoicePayment', @InvID, @PaymentAccountID,  0,              @PaymentAmount, @Desc, @UserID);
            END
        END

        COMMIT TRANSACTION;
        SELECT 1 AS Success;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO


-- =============================================
-- STEP 8: SP الإجماليات حسب طريقة الدفع في الوردية
-- =============================================
IF OBJECT_ID('[Sales].[sp_Shift_GetPaymentMethodTotals]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Shift_GetPaymentMethodTotals];
GO
CREATE PROCEDURE [Sales].[sp_Shift_GetPaymentMethodTotals]
    @ShiftID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DefaultCashID INT;
    DECLARE @DefaultCashCode NVARCHAR(50) = '1101';
    DECLARE @DefaultCashName NVARCHAR(100) = N'نقدي (كاش)';

    SELECT TOP 1 
        @DefaultCashID = AccountID,
        @DefaultCashCode = AccountCode,
        @DefaultCashName = AccountName
    FROM [Accounting].[ChartOfAccounts]
    WHERE (AccountCode = '1101' OR AccountName LIKE N'%صندوق%' OR AccountName LIKE N'%كاش%' OR AccountCode LIKE '110%')
      AND IsTransactional = 1;

    SELECT 
        AccountID,
        AccountCode,
        PaymentMethodName,
        InvType,
        SUM(TotalAmount) AS TotalAmount,
        MAX(SourceType)  AS SourceType
    FROM (
        -- 1. إجماليات طرق الدفع من فواتير المبيعات/المشتريات المقسمة (Splits)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            h.InvType,
            SUM(CAST(sp.Amount AS DECIMAL(18,3)))   AS TotalAmount,
            'InvoiceSplit' AS SourceType
        FROM [Sales].[InvoicePaymentSplits] sp
        INNER JOIN [Sales].[InvoiceHeader]          h ON sp.InvID = h.InvID
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON sp.PaymentAccountID = c.AccountID
        WHERE h.ShiftID = @ShiftID
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), h.InvType

        UNION ALL

        -- 2. إجماليات طرق الدفع المباشرة من فواتير المبيعات/المشتريات (غير المقسمة / Direct)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            h.InvType,
            SUM(CAST(h.PaidAmount AS DECIMAL(18,3))) AS TotalAmount,
            'InvoiceDirect' AS SourceType
        FROM [Sales].[InvoiceHeader]                h
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON h.PaymentAccountID = c.AccountID
        WHERE h.ShiftID = @ShiftID
          AND h.PaidAmount > 0
          AND NOT EXISTS (
              SELECT 1 FROM [Sales].[InvoicePaymentSplits] sp WHERE sp.InvID = h.InvID
          )
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), h.InvType

        UNION ALL

        -- 3. إجماليات طرق الدفع من السندات المالية (قبض وصرف)
        SELECT
            ISNULL(c.AccountID, @DefaultCashID)     AS AccountID,
            ISNULL(c.AccountCode, @DefaultCashCode) AS AccountCode,
            ISNULL(c.AccountName, @DefaultCashName) AS PaymentMethodName,
            v.VoucherType  AS InvType,
            SUM(CAST(v.Amount AS DECIMAL(18,3))) AS TotalAmount,
            'Voucher'      AS SourceType
        FROM [Accounting].[Vouchers]                v
        LEFT JOIN [Accounting].[ChartOfAccounts]    c ON v.AccountID = c.AccountID
        WHERE v.ShiftID = @ShiftID
          AND (c.AccountCode LIKE '11%' OR c.AccountID IS NULL)
        GROUP BY ISNULL(c.AccountID, @DefaultCashID), ISNULL(c.AccountCode, @DefaultCashCode), ISNULL(c.AccountName, @DefaultCashName), v.VoucherType
    ) CombinedPaymentTotals
    GROUP BY AccountID, AccountCode, PaymentMethodName, InvType
    ORDER BY AccountCode, InvType;
END
GO
GO

-- =============================================
-- STEP 9: تحديث استعلامات الفواتير لإرجاع اسم حساب الدفع ديناميكياً
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_GetByID]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_GetByID];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetByID]
    @InvID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName,
        acc.AccountName AS PaymentAccountName,
        acc.AccountCode AS PaymentAccountCode
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
    WHERE h.InvID = @InvID;
END
GO

IF OBJECT_ID('[Sales].[sp_Invoice_GetAll_Pos]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_GetAll_Pos];
GO
CREATE PROCEDURE [Sales].[sp_Invoice_GetAll_Pos]  
    @InvType NVARCHAR(20),
    @ShiftID int = null
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.*,
        p.PartnerName,
        w.WarehouseName,
        u.FullName AS UserName,
        acc.AccountName AS PaymentAccountName,
        acc.AccountCode AS PaymentAccountCode
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    LEFT JOIN [Settings].[Warehouses] w ON h.WarehouseID = w.WarehouseID
    LEFT JOIN [Security].[Users] u ON h.UserID = u.UserID
    LEFT JOIN [Accounting].[ChartOfAccounts] acc ON h.PaymentAccountID = acc.AccountID
    WHERE h.InvType = @InvType AND (@ShiftID IS NULL OR h.ShiftID = @ShiftID)
    ORDER BY h.InvID DESC;
END
GO

PRINT N'=== [37] Payment Methods & Split Payment — All Objects Created Successfully ===';
