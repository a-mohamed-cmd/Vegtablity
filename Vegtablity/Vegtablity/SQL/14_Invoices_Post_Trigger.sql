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

    -- Only proceed if IsPosted changed from 0 to 1
    IF UPDATE(IsPosted)
    BEGIN
        -- ==========================================================
        -- 1. INVENTORY UPDATES
        -- ==========================================================
        -- Purchases: Increase Stock
        UPDATE S
        SET S.CurrentQty = S.CurrentQty + D.Quantity
        FROM [Inventory].[ProductStock] S
        INNER JOIN [Sales].[InvoiceDetails] D ON S.ProductID = D.ProductID
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0 
          AND i.InvType = 'Purchase' 
          AND S.WarehouseID = i.WarehouseID;

        -- Missing Stock Records for Purchases (Insert if not exists)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty)
        SELECT D.ProductID, i.WarehouseID, SUM(D.Quantity)
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0 
          AND i.InvType = 'Purchase'
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2 
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
          )
        GROUP BY D.ProductID, i.WarehouseID;

        -- Sales: Decrease Stock
        UPDATE S
        SET S.CurrentQty = S.CurrentQty - D.Quantity
        FROM [Inventory].[ProductStock] S
        INNER JOIN [Sales].[InvoiceDetails] D ON S.ProductID = D.ProductID
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0 
          AND i.InvType = 'Sales'
          AND S.WarehouseID = i.WarehouseID;

        -- Missing Stock Records for Sales (Insert negative if completely missing, to prevent failure)
        INSERT INTO [Inventory].[ProductStock] (ProductID, WarehouseID, CurrentQty)
        SELECT D.ProductID, i.WarehouseID, -SUM(D.Quantity)
        FROM [Sales].[InvoiceDetails] D
        INNER JOIN inserted i ON D.InvID = i.InvID
        INNER JOIN deleted d ON i.InvID = d.InvID
        WHERE i.IsPosted = 1 AND d.IsPosted = 0 
          AND i.InvType = 'Sales'
          AND NOT EXISTS (
              SELECT 1 FROM [Inventory].[ProductStock] S2 
              WHERE S2.ProductID = D.ProductID AND S2.WarehouseID = i.WarehouseID
          )
        GROUP BY D.ProductID, i.WarehouseID;

        -- ==========================================================
        -- 2. ACCOUNTING UPDATES (JOURNAL ENTRIES)
        -- ==========================================================
        
        -- Get generic Accounts for fallback
        DECLARE @InventoryAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '13%' AND IsTransactional = 1), 
                                           (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '13'));
        
        DECLARE @SalesAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '41%' AND IsTransactional = 1), 
                                       (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '41'));
                                       
        DECLARE @COGSAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '5101'), 
                                      ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '51%' AND IsTransactional = 1),
                                             (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '51')));

        DECLARE @CustomerAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '12%' AND IsTransactional = 1), 
                                          (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '12'));

        DECLARE @VendorAcc INT = ISNULL((SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode LIKE '21%' AND IsTransactional = 1), 
                                        (SELECT TOP 1 AccountID FROM [Accounting].[ChartOfAccounts] WHERE AccountCode = '21'));

        -- Ensure fallback accounts exist (create dummy if absolutely nothing found - though Setup_InitialAccounts should prevent this)

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
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(w.AccountID, @InventoryAcc), -- Dynamically fetch Warehouse AccountID
            i.NetAmount,  -- Debit Inventory
            0,            
            N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE i.InvType = 'Purchase';

        -- Leg 2: Cr Vendor/Supplier
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(p.AccountID, @VendorAcc),  -- Dynamically fetch Partner's AccountID
            0,
            i.NetAmount, -- Credit Supplier
            N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Purchase';

        -- ----------------------------------------------------------------
        -- B. SALES INVOICE ENTRIES
        -- ----------------------------------------------------------------
        
        -- Sales Part 1: Revenue & Receivables
        -- Leg 1: Dr Customer
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(p.AccountID, @CustomerAcc), -- Dynamically fetch Partner's AccountID
            i.NetAmount,  -- Debit Customer
            0,
            N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
        WHERE i.InvType = 'Sales';

        -- Leg 2: Cr Sales Revenue
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            @SalesAcc,
            0,
            i.NetAmount, -- Credit Sales
            N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        WHERE i.InvType = 'Sales';

        -- Sales Part 2: COGS & Inventory (بمتوسط قيمه الصنف * الكميه)
        -- Calculate Total COGS for the Invoice
        ;WITH InvoiceCOGS AS (
            SELECT 
                d.InvID, 
                SUM(d.Quantity * ISNULL(p.PurchasePrice, 0)) AS TotalCOGS
            FROM [Sales].[InvoiceDetails] d
            JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
            GROUP BY d.InvID
        )
        -- Leg 3: Dr COGS (تكلفة البضاعة المباعة)
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            @COGSAcc,
            cogs.TotalCOGS, -- Debit COGS
            0,
            N'تكلفة مبيعات للفاتورة ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
        WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

        -- Leg 4: Cr Inventory (المخزون)
        ;WITH InvoiceCOGS AS (
            SELECT 
                d.InvID, 
                SUM(d.Quantity * ISNULL(p.PurchasePrice, 0)) AS TotalCOGS
            FROM [Sales].[InvoiceDetails] d
            JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
            GROUP BY d.InvID
        )
        INSERT INTO [Accounting].[JournalEntries] (EntryNo, EntryDate, ReferenceType, ReferenceID, AccountID, DebitAmount, CreditAmount, Description, UserID)
        SELECT
            m.EntryNo,
            i.InvDate,
            'Invoice',
            i.InvID,
            ISNULL(w.AccountID, @InventoryAcc), -- Dynamically fetch Warehouse AccountID
            0,
            cogs.TotalCOGS, -- Credit Inventory
            N'تكلفة مبيعات للفاتورة ' + CAST(i.InvID AS NVARCHAR),
            i.UserID
        FROM inserted i
        JOIN @InvoiceEntryMap m ON m.InvID = i.InvID
        JOIN InvoiceCOGS cogs ON i.InvID = cogs.InvID
        LEFT JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE i.InvType = 'Sales' AND cogs.TotalCOGS > 0;

    END
END
GO
