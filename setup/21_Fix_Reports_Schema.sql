-- ======================================================================
-- Vegtablity ERP - Reports Schema Fixes
-- ======================================================================
USE [VegtablityDB]
GO

PRINT '1. Adding missing Quantity column to QuotationDetails...'
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('[Sales].[QuotationDetails]') AND name = 'Quantity')
BEGIN
    ALTER TABLE [Sales].[QuotationDetails] ADD [Quantity] DECIMAL(18, 3) NOT NULL DEFAULT 1;
END
GO

PRINT '2. Fixing sp_Report_ExpensesAnalysis in 17_Reports_Update.sql context...'
-- The previous version had a redundant join and potentially used wrong table for filtering
IF OBJECT_ID('[Reports].[sp_Report_ExpensesAnalysis]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_ExpensesAnalysis]
GO
CREATE PROCEDURE [Reports].[sp_Report_ExpensesAnalysis]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Querying consolidated JournalEntries (which only contains posted movements)
    SELECT 
        a.AccountCode,
        a.AccountName,
        SUM(je.DebitAmount - je.CreditAmount) AS TotalExpense
    FROM [Accounting].[JournalEntries] je
    INNER JOIN [Accounting].[ChartOfAccounts] a ON je.AccountID = a.AccountID
    WHERE CAST(je.EntryDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND a.AccountType = 'Expenses'
    GROUP BY a.AccountCode, a.AccountName
    HAVING SUM(je.DebitAmount - je.CreditAmount) > 0
    ORDER BY TotalExpense DESC;
END
GO

PRINT '3. Updating sp_Report_QuotationsStatus to include summary data...'
IF OBJECT_ID('[Reports].[sp_Report_QuotationsStatus]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_QuotationsStatus]
GO
CREATE PROCEDURE [Reports].[sp_Report_QuotationsStatus]
    @Status NVARCHAR(20) = 'All' -- 'All', 'Active', 'Expired'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        q.QuoteID,
        p.PartnerName AS CustomerName,
        q.QuoteDate,
        q.ExpiryDate,
        q.IsActive,
        ISNULL((SELECT SUM(qd.QuotedPrice * qd.Quantity) 
                FROM [Sales].[QuotationDetails] qd 
                WHERE qd.QuoteID = q.QuoteID), 0) AS QuoteTotalValue,
        ISNULL((SELECT SUM(qd.Quantity) 
                FROM [Sales].[QuotationDetails] qd 
                WHERE qd.QuoteID = q.QuoteID), 0) AS TotalItemsCount,
        CASE 
            WHEN q.IsActive = 0 THEN N'مغلق'
            WHEN q.ExpiryDate IS NOT NULL AND CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE) THEN N'منتهي الصلاحية'
            ELSE N'فعال (قيد الانتظار)'
        END AS QuoteStatus
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@Status = 'All')
       OR (@Status = 'Active' AND q.IsActive = 1 AND (q.ExpiryDate IS NULL OR CAST(q.ExpiryDate AS DATE) >= CAST(GETDATE() AS DATE)))
       OR (@Status = 'Expired' AND (q.IsActive = 0 OR CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE)))
    ORDER BY q.QuoteDate DESC;
END
GO


PRINT '4. Updating sp_Report_StockMovement to include purchases (QtyIn)...'
IF OBJECT_ID('[Reports].[sp_Report_StockMovement]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_StockMovement]
GO
CREATE PROCEDURE [Reports].[sp_Report_StockMovement]
    @ProductID INT,
    @WarehouseID INT = 0, -- 0 for all
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        Movement.TransactionDate,
        Movement.TransactionType,
        Movement.WarehouseName,
        Movement.QtyIn,
        Movement.QtyOut,
        Movement.UnitPrice
    FROM (
        -- Purchases (Inbound)
        SELECT
            i.InvDate AS TransactionDate,
            N'فاتورة مشتريات رقم ' + CAST(i.InvID AS NVARCHAR) AS TransactionType,
            w.WarehouseName,
            d.Quantity AS QtyIn,
            0 AS QtyOut,
            d.UnitPrice
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
        INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID 
          AND i.InvType = 'Purchase'
          AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID)
          AND i.IsPosted = 1

        UNION ALL

        -- Sales (Outbound)
        SELECT
            i.InvDate AS TransactionDate,
            N'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR) AS TransactionType,
            w.WarehouseName,
            0 AS QtyIn,
            d.Quantity AS QtyOut,
            d.UnitPrice
        FROM [Sales].[InvoiceDetails] d
        INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
        INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
        WHERE d.ProductID = @ProductID 
          AND i.InvType = 'Sales'
          AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID)
          AND i.IsPosted = 1
    ) AS Movement
    WHERE CAST(Movement.TransactionDate AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY Movement.TransactionDate DESC;
END
GO

PRINT '✅ All Report Fixes and Stock Movement Updates Completed.'
GO
