-- =============================================
-- 25. Unpost Invoice Support
-- إعادة إنشاء trg_Invoice_Post (النسخة الكاملة) + sp_Invoice_Unpost
-- =============================================
USE VegtablityDB;
GO

-- =============================================
-- STEP 1: trg_Invoice_Post (النسخة الكاملة المُحكمة)
-- يتعامل فقط مع الترحيل الجديد (0 → 1)
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

    -- Only proceed if IsPosted changed from 0 to 1
    IF UPDATE(IsPosted)
    BEGIN
        -- ==========================================================
        -- 1. INVENTORY UPDATES
        -- ==========================================================

        -- STEP A: Update AvgCostPrice BEFORE touching CurrentQty (weighted average formula)
        UPDATE S
        SET S.AvgCostPrice =
            CASE
                WHEN (S.CurrentQty + T.TotalQty) > 0
                THEN (S.CurrentQty * ISNULL(S.AvgCostPrice, 0) + T.TotalSum)
                     / (S.CurrentQty + T.TotalQty)
                ELSE T.WeightedPrice
            END
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) as TotalQty, SUM(Quantity * UnitPrice) as TotalSum,
                   SUM(Quantity * UnitPrice) / NULLIF(SUM(Quantity), 0) as WeightedPrice
            FROM [Sales].[InvoiceDetails]
            GROUP BY ProductID, InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN inserted i ON T.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0
          AND i.InvType = 'Purchase'
          AND S.WarehouseID = i.WarehouseID;

        -- STEP B: Increase CurrentQty (after AvgCostPrice is already updated)
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + T.TotalQty
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) as TotalQty
            FROM [Sales].[InvoiceDetails]
            GROUP BY ProductID, InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN inserted i ON T.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0
          AND i.InvType = 'Purchase'
          AND S.WarehouseID = i.WarehouseID;

        -- Missing Stock Records for Purchases (Insert if not exists)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty, AvgCostPrice)
        SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity),
               SUM(D.Quantity * D.UnitPrice) / NULLIF(SUM(D.Quantity), 0)
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0
          AND i.InvType = 'Purchase'
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID)
        GROUP BY D.ProductID, i.WarehouseID;

        -- Sales: Decrease Stock
        UPDATE S
        SET S.CurrentQty = S.CurrentQty - T.TotalQty
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) as TotalQty
            FROM [Sales].[InvoiceDetails]
            GROUP BY ProductID, InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN inserted i ON T.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0
          AND i.InvType = 'Sales'
          AND S.WarehouseID = i.WarehouseID;

        -- STEP D: Update CostPrice in InvoiceDetails matching current AvgCostPrice (for Sales)
        UPDATE D
        SET D.CostPrice = ISNULL(S.AvgCostPrice, 0)
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN [Inventory].[ProductStock] S ON D.ProductID = S.ProductID
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0
          AND i.InvType = 'Sales'
          AND S.WarehouseID = i.WarehouseID;

        -- Missing Stock Records for Sales (Insert negative)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty)
        SELECT D.ProductID, i.WarehouseID, -SUM(D.Quantity)
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted F ON i.InvID = F.InvID
        WHERE i.IsPosted = 1 AND F.IsPosted = 0
          AND i.InvType = 'Sales'
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID)
        GROUP BY D.ProductID, i.WarehouseID;

        -- ==========================================================
        -- 2. ACCOUNTING UPDATES (JOURNAL ENTRIES)
        -- ==========================================================

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

        DECLARE @InvoiceEntryMap TABLE (InvID INT, InvType NVARCHAR(20), EntryNo INT);

        INSERT INTO @InvoiceEntryMap (InvID, InvType, EntryNo)
        SELECT i.InvID, i.InvType, NEXT VALUE FOR [Accounting].[seq_EntryNo]
        FROM inserted i
        INNER JOIN deleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0;

        -- ----------------------------------------------------------------
        -- A. PURCHASE INVOICE ENTRIES
        -- ----------------------------------------------------------------

        -- Leg 1: Dr Inventory
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
               ISNULL(w.AccountID, @InventoryAcc), i.NetAmount, 0,
               N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE i.InvType = 'Purchase';

        -- Leg 2: Cr Vendor
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
               ISNULL(p.AccountID, @VendorAcc), 0, i.NetAmount,
               N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Purchase';

        -- ----------------------------------------------------------------
        -- B. SALES INVOICE ENTRIES
        -- ----------------------------------------------------------------

        -- Leg 1: Dr Customer
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
               ISNULL(p.AccountID, @CustomerAcc), i.NetAmount, 0,
               N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Sales';

        -- Leg 2: Cr Sales Revenue
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
               @SalesAcc, 0, i.NetAmount,
               N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Sales';

        -- COGS: استخدام قيمة CostPrice التي تم تحديثها للتو لتسجيل تكلفة المبيعات
        ;WITH InvoiceCOGS AS (
            SELECT d.InvID, SUM(d.CostPrice * d.Quantity) AS TotalCOGS
            FROM [Sales].[InvoiceDetails] d
            INNER JOIN inserted i ON d.InvID = i.InvID
            GROUP BY d.InvID
        )
        -- Leg 3: Dr COGS
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
               @COGSAcc, cogs.TotalCOGS, 0,
               N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
        WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

        ;WITH InvoiceCOGS AS (
            SELECT d.InvID, SUM(d.CostPrice * d.Quantity) AS TotalCOGS
            FROM [Sales].[InvoiceDetails] d
            INNER JOIN inserted i ON d.InvID = i.InvID
            GROUP BY d.InvID
        )
        -- Leg 4: Cr Inventory (Warehouse)
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Invoice', i.InvID,
               ISNULL(w.AccountID, @InventoryAcc), 0, cogs.TotalCOGS,
               N'تكلفة بضاعة مباعة للفاتورة ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
        LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

        -- ==========================================================
        -- C. PAYMENT JOURNAL ENTRIES
        -- قيد السداد الجزئي عند الترحيل (إذا كان PaidAmount > 0)
        -- ==========================================================

        -- Purchase: Dr Vendor / Cr Cash
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               ISNULL(p.AccountID, @VendorAcc), i.PaidAmount, 0,
               N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               i.PaymentAccountID, 0, i.PaidAmount,
               N'سداد جزئي - فاتورة مشتريات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Purchase' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

        -- Sales: Dr Cash / Cr Customer
        INSERT INTO [Accounting].[JournalEntries]
            (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT m.EntryNo, i.InvDate, 'Payment', i.InvID,
               ISNULL(p.AccountID, @CustomerAcc), 0, i.PaidAmount,
               N'سداد جزئي - فاتورة مبيعات ' + CAST(i.InvID AS NVARCHAR), i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Sales' AND i.PaidAmount > 0 AND i.PaymentAccountID IS NOT NULL;

    END

    -- 3. UNPOSTING (IsPosted 1 -> 0)
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON i.InvID = d.InvID WHERE i.IsPosted = 0 AND d.IsPosted = 1)
    BEGIN
        -- A. Purchases: Revert Stock Increase (Grouped)
        UPDATE S
        SET S.CurrentQty = S.CurrentQty - T.TotalQty
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) as TotalQty FROM [Sales].[InvoiceDetails] GROUP BY ProductID, InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN deleted d ON T.InvID = d.InvID
        INNER JOIN inserted i ON d.InvID = i.InvID
        WHERE i.IsPosted = 0 AND d.IsPosted = 1 AND d.InvType = 'Purchase' AND S.WarehouseID = d.WarehouseID;

        -- B. Sales: Revert Stock Decrease (Grouped)
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + T.TotalQty
        FROM [Inventory].[ProductStock] S
        INNER JOIN (
            SELECT ProductID, SUM(Quantity) as TotalQty FROM [Sales].[InvoiceDetails] GROUP BY ProductID, InvID
        ) T ON S.ProductID = T.ProductID
        INNER JOIN deleted d ON T.InvID = d.InvID
        INNER JOIN inserted i ON d.InvID = i.InvID
        WHERE i.IsPosted = 0 AND d.IsPosted = 1 AND d.InvType = 'Sales' AND S.WarehouseID = d.WarehouseID;

        -- C. Remove Journal Entries
        DELETE JE FROM [Accounting].[JournalEntries] JE
        INNER JOIN deleted d ON JE.ReferenceID = d.InvID AND JE.ReferenceType IN ('Invoice', 'Payment')
        WHERE d.IsPosted = 1;
    END
END
GO

PRINT N'✅ تم إنشاء/تحديث trg_Invoice_Post بنجاح';
GO

-- =============================================
-- STEP 2: sp_Invoice_Unpost
-- إلغاء ترحيل فاتورة مرحّلة بشكل كامل:
--   1. عكس حركة المخزون (مع استعادة AvgCostPrice التقريبية)
--   2. حذف جميع القيود المحاسبية (Invoice + Payment)
--   3. تعيين IsPosted = 0
-- بعدها يعدّل المستخدم ويُرحّل من جديد بالطريقة المعتادة
-- =============================================
IF OBJECT_ID('[Sales].[sp_Invoice_Unpost]', 'P') IS NOT NULL
    DROP PROCEDURE [Sales].[sp_Invoice_Unpost];
GO

CREATE PROCEDURE [Sales].[sp_Invoice_Unpost]
    @InvID  INT,
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. التحقق من وجود الفاتورة وأنها مرحّلة
        IF NOT EXISTS (
            SELECT 1 FROM [Sales].[InvoiceHeader]
            WHERE InvID = @InvID AND IsPosted = 1
        )
        BEGIN
            RAISERROR(N'الفاتورة غير موجودة أو غير مرحّلة.', 16, 1);
            RETURN;
        END

        DECLARE @InvType     NVARCHAR(20);
        DECLARE @WarehouseID INT;
        SELECT @InvType = InvType, @WarehouseID = WarehouseID
        FROM [Sales].[InvoiceHeader]
        WHERE InvID = @InvID;

        -- 2. عكس حالة الترحيل (هذا سيشغل trg_Invoice_Post للتعامل مع المخزون والقيود تلقائياً)
        UPDATE [Sales].[InvoiceHeader]
        SET IsPosted = 0
        WHERE InvID = @InvID;

        COMMIT TRANSACTION;
        SELECT @InvID AS InvID, N'تم إلغاء ترحيل الفاتورة بنجاح' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @ErrMsg NVARCHAR(500) = ERROR_MESSAGE();
        RAISERROR(@ErrMsg, 16, 1);
    END CATCH
END
GO

PRINT N'✅ تم إنشاء sp_Invoice_Unpost بنجاح';
GO
