-- =============================================
-- Dashboard Schema & Procedures
-- =============================================
USE VegtablityDB;
GO

-- Create Reports Schema if not exists (we'll use this for Dashboard)
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Reports') EXEC('CREATE SCHEMA [Reports]');
GO

-- =============================================
-- 1. Dashboard Summary (Sales today, Purchases today, Products, Customers)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetSummary]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetSummary];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetSummary]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TodaySales DECIMAL(18,2) = 0;
    DECLARE @TodayPurchases DECIMAL(18,2) = 0;
    DECLARE @TotalProducts INT = 0;
    DECLARE @TotalCustomers INT = 0;
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    -- 1. Today's Sales
    SELECT @TodaySales = ISNULL(SUM(NetAmount), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Sales' 
      AND IsPosted = 1 
      AND CAST(InvDate AS DATE) = @Today;

    -- 2. Today's Purchases
    SELECT @TodayPurchases = ISNULL(SUM(NetAmount), 0)
    FROM [Sales].[InvoiceHeader]
    WHERE InvType = 'Purchase' 
      AND IsPosted = 1 
      AND CAST(InvDate AS DATE) = @Today;

    -- 3. Total Products 
    SELECT @TotalProducts = COUNT(*)
    FROM [Inventory].[Products]
    WHERE IsActive = 1;

    -- 4. Total Customers
    SELECT @TotalCustomers = COUNT(*)
    FROM [Settings].[Partners]
    WHERE PartnerType IN ('Customer', 'Both') AND IsActive = 1;

    -- Output
    SELECT 
        @TodaySales AS TodaySales,
        @TodayPurchases AS TodayPurchases,
        @TotalProducts AS TotalProducts,
        @TotalCustomers AS TotalCustomers;
END
GO

-- =============================================
-- 2. Sales Chart (Last 7 Days)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetSalesChart]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetSalesChart];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetSalesChart]
    @Days INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = CAST(DATEADD(DAY, -(@Days - 1), GETDATE()) AS DATE);

    -- CTE to generate the last N dates
    WITH DateRange AS (
        SELECT @StartDate AS DateValue
        UNION ALL
        SELECT DATEADD(DAY, 1, DateValue)
        FROM DateRange
        WHERE DATEADD(DAY, 1, DateValue) <= CAST(GETDATE() AS DATE)
    )
    SELECT 
        d.DateValue,
        ISNULL(SUM(h.NetAmount), 0) AS TotalSales
    FROM DateRange d
    LEFT JOIN [Sales].[InvoiceHeader] h 
        ON CAST(h.InvDate AS DATE) = d.DateValue 
        AND h.InvType = 'Sales' 
        AND h.IsPosted = 1
    GROUP BY d.DateValue
    ORDER BY d.DateValue;
END
GO

-- =============================================
-- 3. Low Stock Alerts
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetAlertProducts]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetAlertProducts];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetAlertProducts]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.ProductID,
        p.ProductName,
        ISNULL(SUM(s.CurrentQty), 0) AS CurrentQty,
        ISNULL(p.AlertQty, 0) AS AlertQty
    FROM [Inventory].[Products] p
    LEFT JOIN [Inventory].[ProductStock] s ON p.ProductID = s.ProductID
    WHERE p.IsActive = 1
    GROUP BY p.ProductID, p.ProductName, p.AlertQty
    HAVING ISNULL(SUM(s.CurrentQty), 0) <= ISNULL(p.AlertQty, 0)
       AND ISNULL(p.AlertQty, 0) > 0
    ORDER BY CurrentQty ASC;
END
GO

-- =============================================
-- 4. Customer Debts (مديونيات العملاء)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetCustomerDebts]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetCustomerDebts];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetCustomerDebts]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 50
        p.PartnerID,
        p.PartnerName,
        ISNULL(SUM(JE.DebitAmount - JE.CreditAmount), 0) AS Balance
    FROM [Sales].[Partners] p
    INNER JOIN [Accounting].[JournalEntries] JE ON JE.AccountID = p.AccountID
    WHERE p.PartnerType IN ('Customer', 'Both')
    GROUP BY p.PartnerID, p.PartnerName
    HAVING ISNULL(SUM(JE.DebitAmount - JE.CreditAmount), 0) > 0
    ORDER BY Balance DESC;
END
GO

-- =============================================
-- 5. Supplier Debts (مديونيات الموردين)
-- =============================================
IF OBJECT_ID('[Reports].[sp_Dashboard_GetSupplierDebts]', 'P') IS NOT NULL DROP PROCEDURE [Reports].[sp_Dashboard_GetSupplierDebts];
GO
CREATE PROCEDURE [Reports].[sp_Dashboard_GetSupplierDebts]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 50
        p.PartnerID,
        p.PartnerName,
        ISNULL(SUM(JE.CreditAmount - JE.DebitAmount), 0) AS Balance
    FROM [Sales].[Partners] p
    INNER JOIN [Accounting].[JournalEntries] JE ON JE.AccountID = p.AccountID
    WHERE p.PartnerType IN ('Supplier', 'Both')
    GROUP BY p.PartnerID, p.PartnerName
    HAVING ISNULL(SUM(JE.CreditAmount - JE.DebitAmount), 0) > 0
    ORDER BY Balance DESC;
END
GO
