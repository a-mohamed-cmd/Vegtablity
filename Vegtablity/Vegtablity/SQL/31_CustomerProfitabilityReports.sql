-- =============================================
-- 31_CustomerProfitabilityReports.sql
-- =============================================

-- 1. [Sales].[sp_Report_CustomerSalesSummary]
-- ملخص مبيعات العملاء: يوضح إجمالي المبيعات، التكلفة، والربح لكل عميل
IF OBJECT_ID('[Sales].[sp_Report_CustomerSalesSummary]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_CustomerSalesSummary];
GO
CREATE PROCEDURE [Sales].[sp_Report_CustomerSalesSummary]
    @StartDate DATETIME,
    @EndDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PartnerID,
        p.PartnerName,
        p.AccountID,
        COUNT(h.InvID) AS InvoiceCount,
        SUM(h.NetAmount) AS TotalSales,
        SUM(ISNULL(Det.TotalCost, 0)) AS TotalCOGS,
        SUM(h.NetAmount) - SUM(ISNULL(Det.TotalCost, 0)) AS TotalProfit
    FROM [Sales].[Partners] p
    INNER JOIN [Sales].[InvoiceHeader] h ON p.PartnerID = h.PartnerID
    LEFT JOIN (
        SELECT InvID, SUM(Quantity * CostPrice) AS TotalCost
        FROM [Sales].[InvoiceDetails]
        GROUP BY InvID
    ) Det ON h.InvID = Det.InvID
    WHERE h.InvType = 'Sales' AND h.IsPosted = 1
      AND h.InvDate BETWEEN @StartDate AND @EndDate
    GROUP BY p.PartnerID, p.PartnerName, p.AccountID
    ORDER BY TotalSales DESC;
END
GO

-- 2. [Sales].[sp_Report_CustomerInvoicesDetail]
-- فواتير عميل معين: يسرد الفواتير مع توضيح ربحية كل فاتورة
IF OBJECT_ID('[Sales].[sp_Report_CustomerInvoicesDetail]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_CustomerInvoicesDetail];
GO
CREATE PROCEDURE [Sales].[sp_Report_CustomerInvoicesDetail]
    @PartnerID INT,
    @StartDate DATETIME,
    @EndDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        h.InvID,
        h.InvDate,
        h.ReferenceNo,
        h.TotalAmount,
        h.Discount,
        h.NetAmount,
        ISNULL(Det.TotalCost, 0) AS TotalCOGS,
        h.NetAmount - ISNULL(Det.TotalCost, 0) AS Profit
    FROM [Sales].[InvoiceHeader] h
    LEFT JOIN (
        SELECT InvID, SUM(Quantity * CostPrice) AS TotalCost
        FROM [Sales].[InvoiceDetails]
        GROUP BY InvID
    ) Det ON h.InvID = Det.InvID
    WHERE h.InvType = 'Sales' AND h.IsPosted = 1
      AND h.PartnerID = @PartnerID
      AND h.InvDate BETWEEN @StartDate AND @EndDate
    ORDER BY h.InvDate DESC;
END
GO

-- 3. [Sales].[sp_Report_CustomerProductSales]
-- مبيعات الأصناف لكل عميل: مجمع حسب الصنف والعميل
IF OBJECT_ID('[Sales].[sp_Report_CustomerProductSales]', 'P') IS NOT NULL DROP PROCEDURE [Sales].[sp_Report_CustomerProductSales];
GO
CREATE PROCEDURE [Sales].[sp_Report_CustomerProductSales]
    @PartnerID INT, -- اختياري (إذا كان 0 يعرض للكل)
    @StartDate DATETIME,
    @EndDate   DATETIME
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        p.PartnerName,
        prod.ProductName,
        SUM(d.Quantity) AS TotalQty,
        SUM(d.TotalPrice) AS TotalSalesValue,
        SUM(d.Quantity * d.CostPrice) AS TotalCostValue,
        SUM(d.TotalPrice) - SUM(d.Quantity * d.CostPrice) AS NetProfit
    FROM [Sales].[InvoiceDetails] d
    INNER JOIN [Sales].[InvoiceHeader] h ON d.InvID = h.InvID
    INNER JOIN [Sales].[Partners] p ON h.PartnerID = p.PartnerID
    INNER JOIN [Inventory].[Products] prod ON d.ProductID = prod.ProductID
    WHERE h.InvType = 'Sales' AND h.IsPosted = 1
      AND (@PartnerID = 0 OR h.PartnerID = @PartnerID)
      AND h.InvDate BETWEEN @StartDate AND @EndDate
    GROUP BY p.PartnerName, prod.ProductName
    ORDER BY p.PartnerName, TotalSalesValue DESC;
END
GO

PRINT N'✅ تم إنشاء تقارير ربحية العملاء بنجاح';
GO
