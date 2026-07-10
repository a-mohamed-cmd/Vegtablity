-- =============================================
-- Invoices Triggers (Inventory & Accounting)
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- Trigger: trg_Invoice_Post
-- Handles Both Inventory Stock Updates AND Accounting Journal Entries
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

    -- الفلترة الأساسية: العمل فقط عند تغير حالة IsPosted
    IF NOT UPDATE(IsPosted) RETURN;

    BEGIN TRY
        -- 1. متغيرات الحسابات الافتراضية
        DECLARE @InventoryAcc INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @SalesAcc     INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @COGSAcc      INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @CustomerAcc  INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1 ORDER BY AccountCode);
        DECLARE @VendorAcc    INT = (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1 ORDER BY AccountCode);

        -- ==========================================================
        -- أولاً: حالة الترحيل (POSTING: 0 -> 1)
        -- ==========================================================
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0)
        BEGIN
            
            -- أ. إدراج سجلات المنتجات المفقودة في جدول المخزون للمستودع المعين بقيم صفرية لمنع فشل التحديث
            INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
            SELECT DISTINCT D.ProductID, i.WarehouseID, 0, 0
            FROM [Sales].[InvoiceDetails] D
            JOIN inserted i ON D.InvID = i.InvID
            JOIN deleted del ON i.InvID = del.InvID
            WHERE i.IsPosted = 1 AND del.IsPosted = 0
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] S2 
                  WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
              );

            -- ب. تحديث متوسط التكلفة (للمشتريات فقط)
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
                JOIN inserted i ON D.InvID = i.InvID
                JOIN deleted d_old ON i.InvID = d_old.InvID
                WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND i.InvType = 'Purchase'
                GROUP BY D.ProductID, i.WarehouseID
            ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

            -- ج. تحديث الكميات (مشتريات تزيد / مبيعات تنقص)
            UPDATE S
            SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN i.InvType = 'Purchase' THEN T.Qty ELSE -T.Qty END)
            FROM [Inventory].[ProductStock] S
            INNER JOIN (
                SELECT D.ProductID, D.InvID, SUM(D.Quantity) as Qty 
                FROM [Sales].[InvoiceDetails] D GROUP BY D.ProductID, D.InvID
            ) T ON S.ProductID = T.ProductID
            INNER JOIN inserted i ON T.InvID = i.InvID
            INNER JOIN deleted d_old ON i.InvID = d_old.InvID
            WHERE i.IsPosted = 1 AND d_old.IsPosted = 0 AND S.WarehouseID = i.WarehouseID;

            -- د. تسجيل التكلفة في تفاصيل الفاتورة (للمبيعات) لضبط الربحية
            UPDATE D
            SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
            FROM [Sales].[InvoiceDetails] D
            JOIN inserted i ON D.InvID = i.InvID
            JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID AND S.WarehouseID = i.WarehouseID
            WHERE i.IsPosted = 1 AND i.InvType = 'Sales';

            -- هـ. القيود المحاسبية (Journals)
            DECLARE @EntryMap TABLE (InvID INT, EntryNo INT);
            INSERT INTO @EntryMap SELECT i.InvID, NEXT VALUE FOR [Accounting].[seq_EntryNo] 
            FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 1 AND d.IsPosted = 0;

            -- قيد الفاتورة (مشتريات/مبيعات)
            INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            -- المشتريات: مخزن (مدين) / مورد (دائن)
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(w.AccountID, @InventoryAcc), i.NetAmount, 0, N'مشتريات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID WHERE i.InvType = 'Purchase'
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(p.AccountID, @VendorAcc), 0, i.NetAmount, N'مشتريات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.InvType = 'Purchase'
            -- المبيعات: عميل (مدين) / مبيعات (دائن) + تكلفة (مدين) / مخزن (دائن)
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(p.AccountID, @CustomerAcc), i.NetAmount, 0, N'مبيعات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.InvType = 'Sales'
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, @SalesAcc, 0, i.NetAmount, N'مبيعات فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID WHERE i.InvType = 'Sales';

            -- و. قيد تكلفة البضاعة المباعة (للمبيعات فقط)
            -- Dr COGS / Cr Inventory
            ;WITH InvoiceCOGS AS (
                SELECT d.InvID, SUM(d.CostPrice * d.Quantity) AS TotalCost
                FROM [Sales].[InvoiceDetails] d
                INNER JOIN inserted i ON d.InvID = i.InvID
                WHERE i.InvType = 'Sales'
                GROUP BY d.InvID
            )
            INSERT INTO [Accounting].[JournalEntries] 
                (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            -- الطرف المدين: حساب تكلفة البضاعة المباعة
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, @COGSAcc, cogs.TotalCost, 0, 
                   N'تكلفة البضاعة المباعة فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i
            JOIN @EntryMap m ON i.InvID = m.InvID
            JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
            WHERE i.InvType = 'Sales' AND cogs.TotalCost > 0

            UNION ALL

            -- الطرف الدائن: حساب المخزن (الخاص بالمستودع)
            SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID, ISNULL(w.AccountID, @InventoryAcc), 0, cogs.TotalCost, 
                   N'تكلفة البضاعة المباعة فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i
            JOIN @EntryMap m ON i.InvID = m.InvID
            JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
            LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
            WHERE i.InvType = 'Sales' AND cogs.TotalCost > 0;

            -- ز. قيود السداد (Payments)
            INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, CASE WHEN i.InvType = 'Purchase' THEN ISNULL(p.AccountID, @VendorAcc) ELSE i.PaymentAccountID END, i.PaidAmount, 0, N'سداد فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL
            UNION ALL
            SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID, CASE WHEN i.InvType = 'Purchase' THEN i.PaymentAccountID ELSE ISNULL(p.AccountID, @CustomerAcc) END, 0, i.PaidAmount, N'سداد فاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
            FROM inserted i JOIN @EntryMap m ON i.InvID = m.InvID LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID WHERE i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;
        End
        
        -- ==========================================================
        -- ثانياً: حالة إلغاء الترحيل (UNPOSTING: 1 -> 0)
        -- ==========================================================
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
        BEGIN
            -- إدراج سجلات المنتجات المفقودة لمنع فشل التحديث عند إلغاء الترحيل
            INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
            SELECT DISTINCT D.ProductID, d_old.WarehouseID, 0, 0
            FROM [Sales].[InvoiceDetails] D
            JOIN deleted d_old ON D.InvID = d_old.InvID
            JOIN inserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1
              AND NOT EXISTS (
                  SELECT 1 FROM [Inventory].[ProductStock] S2 
                  WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = d_old.WarehouseID
              );

            -- أ. إعادة حساب وتخفيض متوسط التكلفة (عند إلغاء ترحيل المشتريات فقط)
            -- يجب أن تتم هذه العملية قبل تخفيض الكمية لأن المعادلة تعتمد على الكمية الحالية قبل التعديل
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
                JOIN deleted d_old ON D.InvID = d_old.InvID
                JOIN inserted i ON d_old.InvID = i.InvID
                WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND d_old.InvType = 'Purchase'
                GROUP BY D.ProductID, d_old.WarehouseID
            ) T ON S.ProductID = T.ProductID AND S.WarehouseID = T.WarehouseID;

            -- ب. عكس تأثير المخزن (المبيعات تعيد للمخزن / المشتريات تخصم من المخزن)
            UPDATE S
            SET S.CurrentQty = ISNULL(S.CurrentQty, 0) + (CASE WHEN d_old.InvType = 'Sales' THEN T.Qty ELSE -T.Qty END)
            FROM [Inventory].[ProductStock] S
            INNER JOIN (
                SELECT D.ProductID, D.InvID, SUM(D.Quantity) as Qty 
                FROM [Sales].[InvoiceDetails] D GROUP BY D.ProductID, D.InvID
            ) T ON S.ProductID = T.ProductID
            INNER JOIN deleted d_old ON T.InvID = d_old.InvID
            INNER JOIN inserted i ON d_old.InvID = i.InvID
            WHERE i.IsPosted = 0 AND d_old.IsPosted = 1 AND S.WarehouseID = d_old.WarehouseID;

            -- حذف القيود المحاسبية بالكامل
            DELETE JE FROM [Accounting].[JournalEntries] JE
            INNER JOIN deleted d_old ON JE.ReferenceID = d_old.InvID
            WHERE JE.ReferenceType IN ('Invoice', 'Payment') AND d_old.IsPosted = 1;
        END
    END TRY
    BEGIN CATCH
        -- التراجع عن العمليات الحالية وإعادة إرسال الخطأ
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
