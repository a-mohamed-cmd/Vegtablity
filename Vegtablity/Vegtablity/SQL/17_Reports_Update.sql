-- ======================================================================
-- Vegtablity ERP - Comprehensive Reports & Indexes Update Script
-- ======================================================================
-- Execute this script in SQL Server Management Studio (SSMS)
-- Target Database: [VegtablityDB]
-- ======================================================================

USE [VegtablityDB]
GO

PRINT '====================================================='
PRINT '1. CREATING MISSING INDEXES FOR PERFORMANCE OPTIMIZATION'
PRINT '====================================================='


PRINT '====================================================='
PRINT '1. CREATING MISSING INDEXES FOR PERFORMANCE OPTIMIZATION'
PRINT '====================================================='

-- 1. Inventory Schema Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_Barcode' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_Barcode] ON [Inventory].[Products] ([Barcode]) INCLUDE ([ProductName], saleprice);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Products_IsActive' AND object_id = OBJECT_ID('[Inventory].[Products]'))
    CREATE NONCLUSTERED INDEX [IX_Products_IsActive] ON [Inventory].[Products] ([IsActive]) INCLUDE ([ProductID], [ProductName], saleprice);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Stock_Warehouse_Product' AND object_id = OBJECT_ID('[Inventory].[ProductStock]'))
    CREATE NONCLUSTERED INDEX [IX_Stock_Warehouse_Product] ON [Inventory].[ProductStock] ([WarehouseID], [ProductID]) INCLUDE ([CurrentQty]);
GO

-- 2. Sales Schema Indexes (Invoices & Details)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Invoices_InvDate' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_Invoices_InvDate] ON [Sales].[InvoiceHeader] ([InvDate]) INCLUDE ([TotalAmount], [Discount], [NetAmount], [PaidAmount], [Remainder]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Invoices_Partner_Date' AND object_id = OBJECT_ID('[Sales].[InvoiceHeader]'))
    CREATE NONCLUSTERED INDEX [IX_Invoices_Partner_Date] ON [Sales].[InvoiceHeader] ([PartnerID], [InvDate]) INCLUDE ([NetAmount], [Remainder], [IsPosted]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceDetails_InvID' AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceDetails_InvID] ON [Sales].[InvoiceDetails] ([InvID]) INCLUDE ([ProductID], [Quantity], [UnitPrice], [TotalPrice], [CostPrice]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_InvoiceDetails_Product' AND object_id = OBJECT_ID('[Sales].[InvoiceDetails]'))
    CREATE NONCLUSTERED INDEX [IX_InvoiceDetails_Product] ON [Sales].[InvoiceDetails] ([ProductID]) INCLUDE ([InvID], [Quantity], [TotalPrice], [CostPrice]);
GO

-- 3. Quotations Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Quotations_Partner_IsActive' AND object_id = OBJECT_ID('[Sales].[Quotations]'))
    CREATE NONCLUSTERED INDEX [IX_Quotations_Partner_IsActive] ON [Sales].[Quotations] ([PartnerID], [IsActive]) INCLUDE ([QuoteDate], [ExpiryDate]);
GO

-- 4. Accounting Schema Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_JournalEntries_Date' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
    CREATE NONCLUSTERED INDEX [IX_JournalEntries_Date] ON [Accounting].[JournalEntries] ([EntryDate]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_JournalEntryDetails_EntryID' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
    CREATE NONCLUSTERED INDEX [IX_JournalEntryDetails_EntryID] ON [Accounting].[JournalEntries] ([EntryID]) INCLUDE ([AccountID], [Debitamount], [Creditamount]);
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_JournalEntryDetails_Account' AND object_id = OBJECT_ID('[Accounting].[JournalEntries]'))
    CREATE NONCLUSTERED INDEX [IX_JournalEntryDetails_Account] ON [Accounting].[JournalEntries] ([AccountID]) INCLUDE ([EntryID], [Debitamount], [Creditamount]);
GO

PRINT '✅ Indexes Created Successfully.'
GO

PRINT '====================================================='
PRINT '2. CREATING COMPREHENSIVE REPORTS STORED PROCEDURES'
PRINT '====================================================='

-- ======================================================================
-- REPORT 1: تقرير أرباح كل صنف خلال فترة معينة + الأصناف الأكثر ربحية
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_ProductProfits]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_ProductProfits]
GO
CREATE PROCEDURE [Reports].[sp_Report_ProductProfits]
    @StartDate DATE,
    @EndDate DATE,
    @OrderBy NVARCHAR(50) = 'ProfitDesc' -- 'ProfitDesc', 'QtyDesc', 'RevenueDesc'
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        p.ProductID,
        p.Barcode,
        p.ProductName,
        u.UnitName,
        SUM(d.Quantity) AS TotalQtySold,
        SUM(d.TotalPrice) AS TotalRevenue,
        SUM(d.Quantity * ISNULL(d.CostPrice, p.PurchasePrice)) AS TotalCost,
        SUM(d.TotalPrice) - SUM(d.Quantity * ISNULL(d.CostPrice, p.PurchasePrice)) AS NetProfit,
        CASE WHEN SUM(d.TotalPrice) > 0 
             THEN ((SUM(d.TotalPrice) - SUM(d.Quantity * ISNULL(d.CostPrice, p.PurchasePrice))) / SUM(d.TotalPrice)) * 100 
             ELSE 0 END AS ProfitMarginPercent
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
    INNER JOIN [Inventory].[Products] p ON d.ProductID = p.ProductID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND i.IsPosted = 1
    GROUP BY p.ProductID, p.Barcode, p.ProductName, u.UnitName
    ORDER BY 
        CASE WHEN @OrderBy = 'ProfitDesc' THEN SUM(d.TotalPrice) - SUM(d.Quantity * ISNULL(d.CostPrice, p.[PurchasePrice])) END DESC,
        CASE WHEN @OrderBy = 'QtyDesc' THEN SUM(d.Quantity) END DESC,
        CASE WHEN @OrderBy = 'RevenueDesc' THEN SUM(d.TotalPrice) END DESC;
END
GO

-- ======================================================================
-- REPORT 2: تقرير أرباح لكل فاتورة على حدة
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_InvoiceProfits]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_InvoiceProfits]
GO
CREATE PROCEDURE [Reports].[sp_Report_InvoiceProfits]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.InvID,
        i.InvDate,
        p.PartnerName AS CustomerName,
        i.TotalAmount AS GrossTotal,
        i.Discount,
        i.NetAmount,
        -- Calculate Total Cost of items in this invoice
        ISNULL((SELECT SUM(d.Quantity * ISNULL(d.CostPrice, pr.[PurchasePrice])) 
                FROM [Sales].[InvoiceDetails] d 
                INNER JOIN [Inventory].[Products] pr ON d.ProductID = pr.ProductID 
                WHERE d.InvID = i.InvID), 0) AS TotalCost,
        -- Profit = NetAmount - TotalCost
        i.NetAmount - ISNULL((SELECT SUM(d.Quantity * ISNULL(d.CostPrice, pr.[PurchasePrice])) 
                              FROM [Sales].[InvoiceDetails] d 
                              INNER JOIN [Inventory].[Products] pr ON d.ProductID = pr.ProductID 
                              WHERE d.InvID = i.InvID), 0) AS NetProfit,
        i.IsPosted
    FROM [Sales].[InvoiceHeader] i
    LEFT JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
    ORDER BY i.InvDate DESC, i.InvID DESC;
END
GO

-- ======================================================================
-- REPORT 3: تقرير المبيعات اليومية والشهرية التفصيلي
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_SalesSummaryByPeriod]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_SalesSummaryByPeriod]
GO
CREATE PROCEDURE [Reports].[sp_Report_SalesSummaryByPeriod]
    @StartDate DATE,
    @EndDate DATE,
    @PeriodType NVARCHAR(10) = 'Daily' -- 'Daily' or 'Monthly'
AS
BEGIN
    SET NOCOUNT ON;

    IF @PeriodType = 'Daily'
    BEGIN
        SELECT 
            CAST(InvDate AS DATE) AS PeriodString,
            COUNT(InvID) AS InvoiceCount,
            SUM(TotalAmount) AS TotalGrossAmount,
            SUM(Discount) AS TotalDiscount,
            SUM(NetAmount) AS TotalNetAmount,
            SUM(PaidAmount) AS TotalPaid,
            SUM(Remainder) AS TotalCredit
        FROM [Sales].[InvoiceHeader]
        WHERE CAST(InvDate AS DATE) BETWEEN @StartDate AND @EndDate
          AND IsPosted = 1
        GROUP BY CAST(InvDate AS DATE)
        ORDER BY CAST(InvDate AS DATE) DESC;
    END
    ELSE IF @PeriodType = 'Monthly'
    BEGIN
        SELECT 
            FORMAT(InvDate, 'yyyy-MM') AS PeriodString,
            COUNT(InvID) AS InvoiceCount,
            SUM(TotalAmount) AS TotalGrossAmount,
            SUM(Discount) AS TotalDiscount,
            SUM(NetAmount) AS TotalNetAmount,
            SUM(PaidAmount) AS TotalPaid,
            SUM(Remainder) AS TotalCredit
        FROM [Sales].[InvoiceHeader]
        WHERE CAST(InvDate AS DATE) BETWEEN @StartDate AND @EndDate
          AND IsPosted = 1
        GROUP BY FORMAT(InvDate, 'yyyy-MM')
        ORDER BY FORMAT(InvDate, 'yyyy-MM') DESC;
    END
END
GO

-- ======================================================================
-- REPORT 4: تقرير مبيعات العملاء (أعلى العملاء شراءً)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_TopCustomers]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_TopCustomers]
GO
CREATE PROCEDURE [Reports].[sp_Report_TopCustomers]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.PartnerID,
        p.PartnerName,
        p.Phone,
        COUNT(i.InvID) AS TotalInvoices,
        SUM(i.NetAmount) AS TotalPurchases,
        SUM(i.PaidAmount) AS TotalPaid,
        SUM(i.Remainder) AS TotalCreditBalance
    FROM [Sales].[Partners] p
    INNER JOIN [Sales].[InvoiceHeader] i ON p.PartnerID = i.PartnerID
    WHERE p.PartnerType = 'Customer'
      AND CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND i.IsPosted = 1
    GROUP BY p.PartnerID, p.PartnerName, p.Phone
    ORDER BY SUM(i.NetAmount) DESC;
END
GO

-- ======================================================================
-- REPORT 5: تقرير فواتير المبيعات الآجلة (أعمار الديون)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_UnpaidInvoicesAging]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_UnpaidInvoicesAging]
GO
CREATE PROCEDURE [Reports].[sp_Report_UnpaidInvoicesAging]
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @AsOfDate IS NULL SET @AsOfDate = GETDATE();

    SELECT 
        i.InvID,
        i.InvDate,
        p.PartnerName AS CustomerName,
        i.NetAmount AS InvoiceTotal,
        i.PaidAmount,
        i.Remainder AS UnpaidBalance,
        DATEDIFF(DAY, i.InvDate, @AsOfDate) AS DaysOverdue,
        CASE 
            WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 30 THEN '1_0_to_30_Days'
            WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 60 THEN '2_31_to_60_Days'
            WHEN DATEDIFF(DAY, i.InvDate, @AsOfDate) <= 90 THEN '3_61_to_90_Days'
            ELSE '4_Over_90_Days'
        END AS AgingBucket
    FROM [Sales].[InvoiceHeader] i
    INNER JOIN [Sales].[Partners] p ON i.PartnerID = p.PartnerID
    WHERE i.Remainder > 0 
      AND i.IsPosted = 1
      AND CAST(i.InvDate AS DATE) <= @AsOfDate
    ORDER BY DaysOverdue DESC;
END
GO

-- ======================================================================
-- REPORT 6: تقرير تقييم المخزون (Inventory Valuation)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_InventoryValuation]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_InventoryValuation]
GO
CREATE PROCEDURE [Reports].[sp_Report_InventoryValuation]
    @WarehouseID INT = 0 -- 0 means all warehouses
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        w.WarehouseName,
        p.ProductID,
        p.Barcode,
        p.ProductName,
        u.UnitName,
        s.[CurrentQty] AS CurrentStock,
        p.[PurchasePrice] AS UnitCost,
        p.[SalePrice] AS UnitSellingPrice,
        (s.[CurrentQty] * p.[PurchasePrice]) AS TotalCostValue,
        (s.[CurrentQty] * p.[SalePrice]) AS TotalRetailValue
    FROM [Inventory].[ProductStock] s
    INNER JOIN [Inventory].[Products] p ON s.ProductID = p.ProductID
    INNER JOIN [Settings].[Warehouses] w ON s.WarehouseID = w.WarehouseID
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    WHERE (@WarehouseID = 0 OR s.WarehouseID = @WarehouseID)
      AND s.[CurrentQty] > 0
    ORDER BY w.WarehouseName, p.ProductName;
END
GO

-- ======================================================================
-- REPORT 7: تقرير الأصناف الراكدة (Dead/Slow-Moving Stock)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_SlowMovingStock]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_SlowMovingStock]
GO
CREATE PROCEDURE [Reports].[sp_Report_SlowMovingStock]
    @MonthsInactive INT = 3 -- Default 3 months
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CutoffDate DATE = DATEADD(MONTH, -@MonthsInactive, GETDATE());

    SELECT 
        p.ProductID,
        p.Barcode,
        p.ProductName,
        c.[CatName],
        u.UnitName,
        ISNULL(SUM(s.[CurrentQty]), 0) AS CurrentTotalStock,
        p.[PurchasePrice],
        MAX(i.InvDate) AS LastSoldDate,
        DATEDIFF(DAY, ISNULL(MAX(i.InvDate),GETDATE()), GETDATE()) AS DaysSinceLastSale
    FROM [Inventory].[Products] p
    LEFT JOIN [Settings].[Categories] c ON p.CategoryID = c.[CatID]
    LEFT JOIN [Settings].[Units] u ON p.UnitID = u.UnitID
    LEFT JOIN [Inventory].[ProductStock] s ON p.ProductID = s.ProductID
    LEFT JOIN [Sales].[InvoiceDetails] d ON p.ProductID = d.ProductID
    LEFT JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
    GROUP BY p.ProductID, p.Barcode, p.ProductName, c.[CatName], u.UnitName, p.[PurchasePrice]
    HAVING ISNULL(SUM(s.[CurrentQty]), 0) > 0 
       AND (MAX(i.InvDate) IS NULL OR MAX(i.InvDate) < @CutoffDate)
    ORDER BY DaysSinceLastSale DESC;
END
GO

-- ======================================================================
-- REPORT 8: تقرير حركة المخزون لكل صنف على حدة (Stock Movement)
-- ======================================================================
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
    
    -- This relies on Journal Entries or Invoice Details if you don't have a dedicated Transactions table.
    -- Since Vegtablity uses Invoices for sales right now:
    SELECT 
        i.InvDate AS TransactionDate,
        'فاتورة مبيعات رقم ' + CAST(i.InvID AS NVARCHAR) AS TransactionType,
        w.WarehouseName,
        0 AS QtyIn,
        d.Quantity AS QtyOut,
        d.UnitPrice
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] i ON d.InvID = i.InvID
    INNER JOIN [Settings].[Warehouses] w ON i.WarehouseID = w.WarehouseID
    WHERE d.ProductID = @ProductID
      AND (@WarehouseID = 0 OR i.WarehouseID = @WarehouseID)
      AND CAST(i.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
      AND i.IsPosted = 1
    ORDER BY i.InvDate DESC;
    
    -- NOTE: In a full ERP, you would UNION ALL with Purchase Invoices, Adjustments, and Transfers here.
END
GO

-- ======================================================================
-- REPORT 9: تقرير تحليل المصروفات (Expenses Analysis)
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_ExpensesAnalysis]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_ExpensesAnalysis]
GO
CREATE PROCEDURE [Reports].[sp_Report_ExpensesAnalysis]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Expenses are accounts located in the P&L as Debit balances (usually starts with 3 or 5 depending on the chart)
    -- We will query all transactions for Accounts marked as IncomeStatement where BalanceType = Debit
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


-- ======================================================================
-- REPORT 10: تقرير عروض الأسعار (المعلقة والفعالة)
-- ======================================================================
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
        ISNULL((SELECT SUM(QuotedPrice) 
                FROM [Sales].[QuotationDetails] 
                WHERE QuoteID = q.QuoteID), 0) AS QuoteTotalValue,
        CASE 
            WHEN q.IsActive = 0 THEN 'مغلق'
            WHEN q.ExpiryDate IS NOT NULL AND CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE) THEN 'منتهي الصلاحية'
            ELSE 'فعال (قيد الانتظار)'
        END AS QuoteStatus
    FROM [Sales].[Quotations] q
    INNER JOIN [Sales].[Partners] p ON q.PartnerID = p.PartnerID
    WHERE (@Status = 'All')
       OR (@Status = 'Active' AND q.IsActive = 1 AND (q.ExpiryDate IS NULL OR CAST(q.ExpiryDate AS DATE) >= CAST(GETDATE() AS DATE)))
       OR (@Status = 'Expired' AND (q.IsActive = 0 OR CAST(q.ExpiryDate AS DATE) < CAST(GETDATE() AS DATE)))
    ORDER BY q.QuoteDate DESC;
END
GO

-- ======================================================================
-- REPORT 11: تقرير الموردين (أعلى الموردين مشتريات)
-- *Placeholder - Assuming Purchase module structure matches Sales*
-- ======================================================================
IF OBJECT_ID('[Reports].[sp_Report_TopSuppliers]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Report_TopSuppliers]
GO
CREATE PROCEDURE [Reports].[sp_Report_TopSuppliers]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Note: Since the Purchase Invoices tables are not fully clear yet, 
    -- this relies on Journal Entries linking to supplier accounts if applicable,
    -- or if a [Purchases].[Invoices] schema exists.
    -- For now, this returns a scaffold. You will need to adjust table names if Purchases module is implemented.
    
    PRINT 'Top Suppliers Report created (Requires Purchase Invoices table to be active).'
    
    /* Example query if Purchase Invoices exist:
    SELECT 
        p.PartnerID, p.PartnerName, SUM(pi.NetAmount) AS TotalPurchases
    FROM [Sales].[Partners] p
    INNER JOIN [Purchases].[Invoices] pi ON p.PartnerID = pi.PartnerID
    WHERE p.PartnerType = 'Supplier' AND CAST(pi.InvDate AS DATE) BETWEEN @StartDate AND @EndDate
    GROUP BY p.PartnerID, p.PartnerName
    ORDER BY TotalPurchases DESC;
    */
END
GO

PRINT '✅ All Report Stored Procedures Created Successfully.'
GO
